"""Encode completed, immutable real-renderer frame sequences for the edit."""
import argparse
import json
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parents[3]
ffmpeg = root / 'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
raw = root / 'outputs/trailer-v1-20261104/gameplay'
dest = root / 'outputs/trailer-v1-20261104/encoded'
dest.mkdir(parents=True, exist_ok=True)
parser=argparse.ArgumentParser()
parser.add_argument('--wait', action='store_true')
args=parser.parse_args()
encoded = {}
deadline = time.monotonic()+1200
while True:
    for report in sorted(raw.glob('*/clip.json')):
        data=json.loads(report.read_text(encoding='utf-8-sig'))
        name=data['name']
        target=dest/(name+'.mp4')
        if name in encoded:
            continue
        if not target.exists():
            log=dest/(name+'.log')
            cmd=[str(ffmpeg),'-hide_banner','-y','-threads','2','-framerate',str(data['fps']),
                 '-start_number','0','-i',str(report.parent/'frame_%05d.jpg'),
                 '-frames:v',str(data['frames']),'-an',
                 '-vf','scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p',
                 '-c:v','libx264','-preset','veryfast','-crf','16','-threads','6',
                 '-r',str(data['fps']),'-color_primaries','bt709','-color_trc','bt709',
                 '-colorspace','bt709','-color_range','tv','-movflags','+faststart',str(target)]
            with log.open('w',encoding='utf-8') as stream:
                subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,check=True,
                               creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        encoded[name]=dict(path=target.relative_to(root).as_posix(),fps=data['fps'],
                           frames=data['frames'],seconds=data['frames']/data['fps'])
        print('ENCODED '+name,flush=True)
        (dest/'manifest.json').write_text(json.dumps(encoded,indent=2)+'\n')
    if len(encoded)>=8 or not args.wait:
        break
    if time.monotonic()>deadline:
        raise TimeoutError('Waiting for completed capture clips')
    time.sleep(1)
print(json.dumps(dict(encoded=len(encoded),manifest=str(dest/'manifest.json'))),flush=True)
