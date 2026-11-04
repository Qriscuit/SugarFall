"""Verify that the final AAC stream contains the current synced review mix."""
import json
import subprocess
import wave
from pathlib import Path
import numpy as np

root=Path(__file__).resolve().parents[3]
out=root/'outputs/trailer-v1-20261104'
ffmpeg=root/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
video=out/'Sugarfall-Trailer-V1-Review.mp4'
decoded=subprocess.run([str(ffmpeg),'-v','error','-i',str(video),'-map','0:a:0',
    '-f','f32le','-ar','48000','-ac','2','pipe:1'],capture_output=True,check=True,
    creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0)).stdout
actual=np.frombuffer(decoded,dtype='<f4').reshape(-1,2).astype(np.float64)
with wave.open(str(out/'trailer-v1-mix.wav'),'rb') as stream:
    reference=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float64)/32768
count=min(len(reference),len(actual))
correlation=float(np.corrcoef(reference[:count].ravel(),actual[:count].ravel())[0,1])
peak=float(np.max(np.abs(actual)))
rms=float(np.sqrt(np.mean(actual**2)))
assert count>=1440000 and correlation>.985 and peak<1
result=dict(passed=True,comparison='Decoded final AAC vs current capture-synced WAV',
    matched_samples_per_channel=count,correlation=round(correlation,7),decoded_peak=round(peak,7),
    decoded_rms_dbfs=round(20*np.log10(rms),3),decoded_samples_at_or_above_one=int(np.count_nonzero(np.abs(actual)>=1)),
    note='AAC is lossy; correlation verifies the current mixed source, not byte parity or subjective audio acceptance.')
(out/'qa/audio-validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
