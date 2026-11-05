"""Encode the frozen rich-map capture at its normal speed."""
import hashlib,json,subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[3]
out=root/'outputs/trailer-v4-20261104'
source=out/'gameplay/09-upgrades-rich'
dest=out/'encoded';dest.mkdir(parents=True,exist_ok=True)
ffmpeg=root/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
ffprobe=ffmpeg.with_name('ffprobe.exe')
video=dest/'09-upgrades-rich.mp4'
clip=json.loads((source/'clip.json').read_text())
assert clip['frames']==270 and clip['fps']==60 and clip['profile_io']==0
with (dest/'09-upgrades-rich.log').open('w') as log:
    subprocess.run([str(ffmpeg),'-hide_banner','-y','-threads','2','-framerate','60','-start_number','0','-i',str(source/'frame_%05d.jpg'),
        '-frames:v','270','-an','-vf','scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p',
        '-c:v','libx264','-preset','veryfast','-crf','16','-threads','6','-r','60',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv','-movflags','+faststart',str(video)],
        stdout=log,stderr=subprocess.STDOUT,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
probe=json.loads(subprocess.check_output([str(ffprobe),'-v','error','-show_streams','-show_format','-of','json',str(video)],creationflags=subprocess.CREATE_NO_WINDOW))
v=probe['streams'][0]
assert [v['width'],v['height']]==[1080,1920] and v['r_frame_rate']=='60/1' and int(v['nb_frames'])==270 and float(probe['format']['duration'])==4.5
subprocess.run([str(ffmpeg),'-v','error','-i',str(video),'-f','null','-'],check=True,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
report=dict(passed=True,path=video.relative_to(root).as_posix(),bytes=video.stat().st_size,sha256=hashlib.sha256(video.read_bytes()).hexdigest(),
    frames=270,fps=60,seconds=4.5,dimensions=[1080,1920],normal_speed=True,full_decode_errors=0,source='gameplay/09-upgrades-rich/clip.json')
(dest/'09-upgrades-rich-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
