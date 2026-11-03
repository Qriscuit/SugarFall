"""Read the actual PCM asset and check slower-pulse timing and audio headroom."""
import argparse
import array
import hashlib
import json
import math
import re
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks = []


def check(condition, label):
    checks.append({'passed': bool(condition), 'label': label})
    print(('PASS: ' if condition else 'FAIL: ') + label)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    output = parser.parse_args().output
    asset = ROOT / 'data/audio/studio_warm_hum.wav'
    provenance = json.loads(asset.with_suffix('.provenance.json').read_text())
    with wave.open(str(asset), 'rb') as sound:
        channels, width, rate, frames = sound.getnchannels(), sound.getsampwidth(), sound.getframerate(), sound.getnframes()
        pcm = array.array('h', sound.readframes(frames))
    if sys.byteorder != 'little':
        pcm.byteswap()
    check((channels, width, rate) == (2, 2, 44100), 'Native asset is stereo 16-bit 44.1 kHz PCM')
    check(frames == 57330, 'One audio loop is exactly 1.30 seconds')
    source = (ROOT / 'scripts/startup.gd').read_text(encoding='utf-8')
    constants = dict(re.findall(r'^const (\w+) = ([.\d]+)$', source, re.MULTILINE))
    check(float(constants['BEAT_SECONDS']) == frames/rate and float(constants['MINIMUM_SECONDS']) == 2*frames/rate,
          'Audio loop and two-cycle presentation hold use matching runtime timing')

    def section(start, end):
        return pcm[round(start*rate)*channels:round(end*rate)*channels]

    def rms(moment):
        samples = section(moment-.012, moment+.012)
        return math.sqrt(sum((value/32768)**2 for value in samples)/len(samples))

    first = rms(.28)
    second = rms(.78)
    check(all(value == 0 for value in section(0, .06)), 'The loop starts with exactly silent samples')
    check(all(value == 0 for value in section(1.04, 1.30)), 'The last 260 ms are exactly silent for a clean handoff')
    check(.42 < second/first < .58, 'The second note is about half the first in the actual PCM')
    check(.4 < rms(.17)/first < .65, 'The first note rises gradually through its midpoint')
    check(.4 < rms(.455)/first < .65, 'The first note releases gradually through its midpoint')
    peak = max(abs(value)/32768 for value in pcm)
    check(.499 < peak < .501 and all(abs(value) < 32767 for value in pcm), 'Half-scale source peak leaves headroom with no clipping')
    largest_step = max(abs(pcm[index+channels]-pcm[index])/32768 for index in range(len(pcm)-channels))
    check(largest_step < .05, 'PCM has no abrupt sample discontinuity or click-sized jump')
    check(hashlib.sha256(asset.read_bytes()).hexdigest() == provenance['sha256'], 'Provenance identifies the generated PCM byte-for-byte')
    logo = ROOT / 'data/art/branding/studio_stamp.png'
    check(hashlib.sha256(logo.read_bytes()).hexdigest() == 'a7e295efc6232750e58fc230372987b7382da3c102ac445dbf8d7e91cd3a2d53',
          'The user-supplied native logo remains byte-for-byte unchanged')
    report = {'passed': sum(item['passed'] for item in checks), 'failed': sum(not item['passed'] for item in checks),
              'checks': checks, 'duration_seconds': frames/rate, 'peak': peak,
              'second_to_first_rms': second/first, 'maximum_sample_step': largest_step,
              'physical_listening': False, 'provenance': 'data/audio/studio_warm_hum.provenance.json'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(f"STUDIO_HUM_ASSET_QA_RESULT passed={report['passed']} failed={report['failed']}")
    return 1 if report['failed'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
