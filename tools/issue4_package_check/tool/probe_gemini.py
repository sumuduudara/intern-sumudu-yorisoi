"""Manual live probe with validated output. Never prints config, keys, or raw errors."""
import argparse
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

MODEL = 'gemini-3.5-flash-lite'
SENTENCE = '今日は友達と会えなくて、とても寂しいです。'
CODES = {'sad', 'lonely', 'anxious', 'stressed', 'angry', 'happy', 'calm', 'other'}


def validate(data):
    candidates = data.get('candidates', [])
    if len(candidates) != 1 or candidates[0].get('finishReason') != 'STOP':
        raise ValueError('Missing candidate or unsuccessful finish reason')
    parts = candidates[0].get('content', {}).get('parts', [])
    value = ''.join(p.get('text', '') for p in parts if not p.get('thought')).strip().lower()
    if value not in CODES or value != 'lonely':
        raise ValueError('Response did not match expected emotion lonely')
    return value


def probe(config, opener=urllib.request.urlopen):
    project = config.get('FIREBASE_PROJECT_ID', '')
    key = config.get('FIREBASE_API_KEY', '')
    if (not isinstance(key, str) or not isinstance(project, str) or not key or not project
            or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in project)):
        print('FAIL: missing or invalid local Firebase client configuration', file=sys.stderr)
        return 2
    url = f'https://firebasevertexai.googleapis.com/v1beta/projects/{project}/models/{MODEL}:generateContent'
    body = {'contents': [{'role': 'user', 'parts': [{'text':
        '次の文章の感情をsad, lonely, anxious, stressed, angry, happy, calm, otherから1つ選び、コードだけ返してください。' + SENTENCE}]}]}
    headers = {'Content-Type': 'application/json', 'x-goog-api-key': key}
    token = os.environ.get('FIREBASE_APP_CHECK_TOKEN')
    if token:
        headers['X-Firebase-AppCheck'] = token
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    try:
        with opener(request, timeout=30) as response:
            if response.status != 200:
                print(f'FAIL: HTTP {response.status}', file=sys.stderr)
                return 1
            emotion = validate(json.load(response))
        print(f'PASS: HTTP 200, emotion={emotion}')
        return 0
    except urllib.error.HTTPError as error:
        print(f'FAIL: HTTP {error.code} (check provider setup, App Check, restrictions and quota)', file=sys.stderr)
    except (urllib.error.URLError, TimeoutError, OSError):
        print('FAIL: network or timeout error', file=sys.stderr)
    except (ValueError, TypeError, KeyError, AttributeError):
        print('FAIL: invalid response or expected lonely not returned', file=sys.stderr)
    return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path, help='Local runtime JSON outside Git')
    args = parser.parse_args()
    try:
        config = json.loads(args.config.read_text())
        if not isinstance(config, dict):
            raise ValueError('Configuration must be an object')
    except (OSError, ValueError):
        print('FAIL: local configuration cannot be read', file=sys.stderr)
        return 2
    return probe(config)


if __name__ == '__main__':
    raise SystemExit(main())
