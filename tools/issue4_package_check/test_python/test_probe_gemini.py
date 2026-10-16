import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
import urllib.error

source = Path(__file__).resolve().parents[1] / 'tool/probe_gemini.py'
spec = importlib.util.spec_from_file_location('probe_gemini', source)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def payload(text='lonely', reason='STOP'):
    return {'candidates': [{'finishReason': reason, 'content': {'parts': [{'text': text}]}}]}


class Response(io.BytesIO):
    status = 200


class ProbeTests(unittest.TestCase):
    config = {'FIREBASE_PROJECT_ID': 'example-test-project', 'FIREBASE_API_KEY': 'test-only-placeholder'}

    def run_probe(self, opener):
        with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as errors:
            result = probe.probe(self.config, opener)
        self.assertNotIn(self.config['FIREBASE_API_KEY'], output.getvalue() + errors.getvalue())
        return result

    def test_validated_success(self):
        self.assertEqual(self.run_probe(lambda *a, **k: Response(json.dumps(payload()).encode())), 0)

    def test_http_failure_is_nonzero(self):
        def fail(*args, **kwargs):
            raise urllib.error.HTTPError('https://example.invalid', 403, 'test-only-placeholder', {}, None)
        self.assertNotEqual(self.run_probe(fail), 0)

    def test_network_failure_is_nonzero(self):
        def fail(*args, **kwargs):
            raise urllib.error.URLError('test-only-placeholder')
        self.assertNotEqual(self.run_probe(fail), 0)

    def test_wrong_emotion_blocked_empty_malformed(self):
        for data in [payload('happy'), payload('', 'SAFETY'), {}, {'candidates': None}, {'candidates': [None]}]:
            with self.subTest(data=data):
                self.assertNotEqual(self.run_probe(lambda *a, **k: Response(json.dumps(data).encode())), 0)
        self.assertNotEqual(self.run_probe(lambda *a, **k: Response(b'not JSON')), 0)

    def test_missing_configuration(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(probe.probe({}), 2)


if __name__ == '__main__':
    unittest.main()
