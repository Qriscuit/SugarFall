"""Probe, decode and extract review frames from the exact rendered MP4."""
import hashlib
import json
import subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[3]
out=root/'outputs/trailer-v1-20261104'
tools=root/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin'
video=out/'Sugarfall-Trailer-V1-Review.mp4'
qa=out/'qa';qa.mkdir(exist_ok=True)
def command(exe,args):
    return subprocess.run([str(tools/exe),*map(str,args)],capture_output=True,text=True,check=True,
                          creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
probe=json.loads(command('ffprobe.exe',['-v','error','-show_streams','-show_format','-of','json',video]).stdout)
v=next(s for s in probe['streams'] if s['codec_type']=='video')
a=next(s for s in probe['streams'] if s['codec_type']=='audio')
assert v['codec_name']=='h264' and v['pix_fmt']=='yuv420p' and [v['width'],v['height']]==[1080,1920]
assert v['r_frame_rate']=='60/1' and int(v['nb_frames'])==1800
assert a['codec_name']=='aac' and int(a['sample_rate'])==48000 and a['channels']==2
assert abs(float(probe['format']['duration'])-30)<.05
command('ffmpeg.exe',['-v','error','-i',video,'-f','null','-'])
times=[0,.8,3.66,5.42,8.5,12.8,16.8,18.4,19.95,21.5,26.6,28.5]
for index,time in enumerate(times):
    command('ffmpeg.exe',['-v','error','-y','-ss',time,'-i',video,'-frames:v','1',qa/('frame-%02d.png'%index)])
command('ffmpeg.exe',['-v','error','-y','-framerate','1','-i',qa/'frame-%02d.png',
                       '-vf','scale=270:480,tile=4x3:padding=6:margin=6:color=0xf4f0e8','-frames:v','1',qa/'contact-sheet.jpg'])
result=dict(passed=True,file=str(video.relative_to(root)).replace('\\','/'),bytes=video.stat().st_size,
    sha256=hashlib.sha256(video.read_bytes()).hexdigest(),duration_seconds=float(probe['format']['duration']),
    dimensions=[1080,1920],fps=60,frames=1800,video_codec='H264',pixel_format='yuv420p',
    audio_codec='AAC',audio_rate=48000,audio_channels=2,full_decode_errors=0,
    review_frame_times=times,phone_review=False)
(qa/'technical-validation.json').write_text(json.dumps(result,indent=2)+'\n')
(qa/'ffprobe.json').write_text(json.dumps(probe,indent=2)+'\n')
print(json.dumps(result,indent=2))
