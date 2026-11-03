"""Render Sugarfall's original warm studio hum; no recorded/game audio is used."""
import hashlib
import json
import math
import re
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
DURATION = 1.3
FIRST_RISE_START = .06
FIRST_PEAK = .28
FIRST_RELEASE_END = .63
SECOND_RISE_START = .65
SECOND_PEAK = .78
SECOND_RELEASE_END = 1.04
SECOND_STRENGTH = .50
COUNT = round(RATE * DURATION)
DEST = ROOT / 'data/audio/studio_warm_hum.wav'


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


frames = []
# Keep generated notes and the runtime animation on the same authored clock.
# Generation fails if timing changes on only one side of the asset contract.
startup = (ROOT / 'scripts/startup.gd').read_text(encoding='utf-8')
for name, value in {'BEAT_SECONDS':DURATION, 'FIRST_RISE_START':FIRST_RISE_START,
                    'FIRST_PEAK':FIRST_PEAK, 'FIRST_RELEASE_END':FIRST_RELEASE_END,
                    'SECOND_RISE_START':SECOND_RISE_START, 'SECOND_PEAK':SECOND_PEAK,
                    'SECOND_RELEASE_END':SECOND_RELEASE_END, 'SECOND_STRENGTH':SECOND_STRENGTH}.items():
    match = re.search(r'^const '+name+r' = ([.\d]+)$', startup, re.MULTILINE)
    assert match and float(match[1]) == value, f'Runtime timing differs: {name}'
for i in range(COUNT):
    t = i/RATE
    first = smooth(FIRST_RISE_START,FIRST_PEAK,t)*(1-smooth(FIRST_PEAK,FIRST_RELEASE_END,t))
    second = smooth(SECOND_RISE_START,SECOND_PEAK,t)*(1-smooth(SECOND_PEAK,SECOND_RELEASE_END,t))
    envelope = first+SECOND_STRENGTH*second
    channels = []
    for channel in range(2):
        # A gentle fifth and octave, soft breath harmonics and a tiny upward
        # bend suggest restorative energy without a bass thump or alarm edge.
        value = 0.0
        for hz, weight, phase in [(246.94165,.56,0), (370.412475,.23,.24), (493.8833,.13,.7), (740.82495,.055,1.2), (987.7666,.025,2.0)]:
            drift = .8*math.sin(math.tau*.65*t) + .35*t
            stereo = (channel-.5)*.012*(hz/246.94165)
            value += weight*math.sin(math.tau*(hz*t+drift*.008)+phase+stereo)
        channels.append(value*envelope)
    frames.append(channels)

peak = max(abs(v) for frame in frames for v in frame)
gain = .50/peak
pcm = bytearray()
sum_sq = 0.0
for frame in frames:
    for value in frame:
        sample = round(value*gain*32767)
        assert -32768 < sample < 32767
        pcm.extend(struct.pack('<h', sample))
        sum_sq += (sample/32768)**2
assert all(byte == 0 for byte in pcm[:round(FIRST_RISE_START*RATE)*4])
assert all(byte == 0 for byte in pcm[round(SECOND_RELEASE_END*RATE)*4:])
DEST.parent.mkdir(parents=True,exist_ok=True)
with wave.open(str(DEST),'wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(pcm)
report = {
    'asset':'data/audio/studio_warm_hum.wav',
    'method':'Original deterministic additive synthesis; no sampled or third-party game audio.',
    'generator':'tools/generate_studio_hum.py',
    'sample_rate':RATE,'channels':2,'sample_width_bits':16,
    'frames':COUNT,'duration_seconds':DURATION,
    'peak_dbfs':20*math.log10(.5),'rms_dbfs':20*math.log10(math.sqrt(sum_sq/(COUNT*2))),
    'timing':{'first_rise_start':FIRST_RISE_START,'first_peak':FIRST_PEAK,
              'first_release_end':FIRST_RELEASE_END,'second_rise_start':SECOND_RISE_START,
              'second_peak':SECOND_PEAK,'second_release_end':SECOND_RELEASE_END,
              'second_strength':SECOND_STRENGTH},
    'quiet_tail_seconds':DURATION-SECOND_RELEASE_END,'clipped_samples':0,
    'sha256':hashlib.sha256(DEST.read_bytes()).hexdigest()
}
(DEST.parent/'studio_warm_hum.provenance.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
