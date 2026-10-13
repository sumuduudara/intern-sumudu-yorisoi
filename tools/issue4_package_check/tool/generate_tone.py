"""Generate original 440 Hz sine PCM; encode locally, without recordings/TTS."""
import argparse
import hashlib
import math
from pathlib import Path
import struct
import lameenc


def generate(output):
    rate = 44100
    seconds = 1
    samples = rate * seconds
    fade = int(rate * 0.02)
    pcm = bytearray()
    for index in range(samples):
        envelope = min(1.0, index / fade, (samples - 1 - index) / fade)
        value = round(32767 * 0.12 * envelope * math.sin(2 * math.pi * 440 * index / rate))
        pcm.extend(struct.pack('<h', value))
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(64)
    encoder.set_in_sample_rate(rate)
    encoder.set_channels(1)
    encoder.set_quality(2)
    data = encoder.encode(bytes(pcm)) + encoder.flush()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    print(f'Generated {len(data)} bytes; SHA256 {hashlib.sha256(data).hexdigest()}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'assets/audio/test.mp3')
    generate(parser.parse_args().output)
