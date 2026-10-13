# Original generated MP3 test tone

`test.mp3` is generated locally by `../../tool/generate_tone.py` for Issue #4.
It contains a mathematical 440 Hz sine wave, one second of mono PCM at 44,100 Hz,
12% peak amplitude with 20 ms fade-in/out, encoded to 64 kbit/s MP3. Encoder delay
and padding can make decoded duration slightly longer than one second.
No recordings, third-party audio, voices, music, cloud TTS or paid services were
used. The former Firebase SDK recording is not included in this package.

Fixture dedication: **CC0-1.0**, see LICENSE. This applies to the generated
waveform/audio, not to the separately installed encoder. The generator and
pinned encoder dependency make the provenance reproducible without relying on
a third-party recording's redistribution rights.

From this package directory, regenerate with a local virtual environment:

```sh
python3 -m venv /tmp/yorisoi-tone-venv
/tmp/yorisoi-tone-venv/bin/python -m pip install -r tool/requirements-tone.txt
/tmp/yorisoi-tone-venv/bin/python tool/generate_tone.py
```

Encoder: `lameenc==1.8.1` (installed separately, not vendored). SHA-256 of the
fixture generated on this Mac:

```text
11dfe6e263ccbbe371046f7b00b50e84a0d1a31e34a999a5bfd375d49db16463
```

The PCM algorithm is deterministic; encoded bytes may differ across encoder
builds/platforms. Playback is a separate check from regeneration and hashing.
The earlier Chrome/iOS playback passes were for the replaced recording, not this
tone. See the package README and service policy for replacement-tone test status.
This is a test signal, not a production wellness story.

## Replacement-tone verification (October 13, 2026)

Regeneration twice produced identical hashes on this Mac. `afinfo` recognized
44.1 kHz mono MP3, approximately 1.045 seconds. Actual Flutter Web `just_audio`
playback in the in-app browser reached Completed: PASS for playback lifecycle.
Audible output quality and playback of this new tone on iOS/Android have not
been verified. Earlier Chrome/iOS audible/lifecycle passes used the old recording.
