"""Encode original twin footage with exactly23 verified draw-only replacements."""
import hashlib
import json
import os
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v2-20261104'
ORIGINAL=ROOT/'outputs/trailer-v1-20261104/gameplay/06-twin-growth'
CLEAN=OUT/'gameplay/06-twin-clean'
SEQ=OUT/'gameplay/twin-sequence';SEQ.mkdir(parents=True,exist_ok=True)
validation=json.loads((CLEAN/'validation.json').read_text())
assert validation['passed'] and validation['full_ball_states_matched_frames']==420 and validation['profile_io']==0
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
replacements={entry['source_frame']:entry for entry in validation['files']}
assert len(replacements)==23
frames=[]
for index in range(420):
    name=f'frame_{index:05d}.jpg'
    source=CLEAN/name if index in replacements else ORIGINAL/name
    if index in replacements:assert sha(source)==replacements[index]['sha256']
    target=SEQ/name
    # A new hard link is read-only input to FFmpeg. Never overwrite a linked file.
    if not target.exists():os.link(source,target)
    assert sha(source)==sha(target)
    frames.append(dict(frame=index,file=name,clean_replacement=index in replacements,sha256=sha(source)))
ffmpeg=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
video=OUT/'gameplay/06-twin-clean.mp4'
with (OUT/'gameplay/encode-clean.log').open('w') as log:
    subprocess.run([str(ffmpeg),'-hide_banner','-y','-threads','2','-framerate','60','-start_number','0',
        '-i',str(SEQ/'frame_%05d.jpg'),'-frames:v','420','-an',
        '-vf','scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p',
        '-c:v','libx264','-preset','veryfast','-crf','16','-threads','6','-r','60',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv',
        '-movflags','+faststart',str(video)],stdout=log,stderr=subprocess.STDOUT,check=True,
        creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
report={**validation,'original_frames_reused':397,'encoded_clip':video.relative_to(ROOT).as_posix(),
    'encoded_sha256':sha(video),'sequence_frames':frames}
(OUT/'gameplay/clean-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(passed=True,frames=420,replacements=23,source_events_matched=validation['source_events_matched'],clip=str(video)),indent=2))
