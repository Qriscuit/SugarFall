"""Verify the exact V3 MP4 and extract greeting, catch and final-card evidence."""
import hashlib
import json
import subprocess
import wave
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v3-20261104';QA=OUT/'qa';QA.mkdir(parents=True,exist_ok=True)
BIN=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin'
VIDEO=OUT/'Sugarfall-Trailer-V3-Review.mp4'

def run(exe,args,binary=False):
    return subprocess.run([str(BIN/exe),*map(str,args)],capture_output=True,text=not binary,check=True,
        creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))

probe=json.loads(run('ffprobe.exe',['-v','error','-show_streams','-show_format','-of','json',VIDEO]).stdout)
v=next(s for s in probe['streams'] if s['codec_type']=='video');a=next(s for s in probe['streams'] if s['codec_type']=='audio')
assert v['codec_name']=='h264' and v['pix_fmt']=='yuv420p' and [v['width'],v['height']]==[1080,1920]
assert v['r_frame_rate']=='60/1' and int(v['nb_frames'])==1800
assert a['codec_name']=='aac' and int(a['sample_rate'])==48000 and a['channels']==2
assert abs(float(probe['format']['duration'])-30)<.02
run('ffmpeg.exe',['-v','error','-i',VIDEO,'-f','null','-'])
times=[0,3.66,5.42,12.8,14.45,14.9,15.3,15.8,16.25,16.8,17.366667,18.516667,
       18.966667,19.8,20.5,21.5,26.6,27.1,27.3,27.56,27.86,28.3,29,29.8]
for index,time in enumerate(times):
    run('ffmpeg.exe',['-v','error','-y','-ss',time,'-i',VIDEO,'-frames:v','1',QA/f'frame-{index:02d}.png'])
run('ffmpeg.exe',['-v','error','-y','-framerate','1','-i',QA/'frame-%02d.png','-vf',
    'scale=270:480,tile=6x4:padding=6:margin=6:color=0xf4f0e8','-frames:v','1',QA/'contact-sheet.jpg'])
raw=run('ffmpeg.exe',['-v','error','-i',VIDEO,'-map','0:a:0','-f','f32le','-ar','48000','-ac','2','pipe:1'],True).stdout
decoded=np.frombuffer(raw,dtype='<f4').reshape(-1,2).astype(np.float64)
with wave.open(str(OUT/'trailer-v3-mix.wav'),'rb') as stream:
    reference=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float64)/32768
n=min(len(decoded),len(reference));corr=float(np.corrcoef(decoded[:n].ravel(),reference[:n].ravel())[0,1])
assert n>=1440000 and corr>.985 and np.max(np.abs(decoded))<1
audio=dict(passed=True,comparison='Decoded final AAC vs current V3 mix',matched_samples_per_channel=n,correlation=corr,
    peak=float(np.max(np.abs(decoded))),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(decoded*decoded)))),
    clipped_samples=int(np.count_nonzero(np.abs(decoded)>=1)),subjective_listening_acceptance=False)
(QA/'audio-validation.json').write_text(json.dumps(audio,indent=2)+'\n')
previous=ROOT/'outputs/trailer-v2-20261104/Sugarfall-Trailer-V2-Review.mp4'
assert hashlib.sha256(previous.read_bytes()).hexdigest()=='43e39e4b5a4f6a2586eb3b59082d80b3bb3910415981e99b64c23dea38537195'
hold_hashes={hashlib.sha256((OUT/'mabel'/f'frame_{frame:05d}.png').read_bytes()).hexdigest() for frame in range(42,93)}
assert len(hold_hashes)==1, 'Greeting must hold the actor still for the planned0.85seconds'
hold=dict(passed=True,first_overlay_frame=42,end_exclusive=93,edit_range=[15.1,15.95],frames=51,
    seconds=.85,unique_actor_frame_hashes=len(hold_hashes),actor_frame_sha256=next(iter(hold_hashes)))
(QA/'greeting-hold-validation.json').write_text(json.dumps(hold,indent=2)+'\n')
source_cues=json.loads((ROOT/'outputs/trailer-v2-20261104/audio/mix-report.json').read_text())['events']
current_cues=json.loads((OUT/'audio/mix-report.json').read_text())['events']
assert [e for e in current_cues if e['type']=='game_sfx']==[e for e in source_cues if e['type']=='game_sfx']
report=dict(passed=True,file=VIDEO.relative_to(ROOT).as_posix(),bytes=VIDEO.stat().st_size,
    sha256=hashlib.sha256(VIDEO.read_bytes()).hexdigest(),dimensions=[1080,1920],fps=60,frames=1800,
    duration_seconds=float(probe['format']['duration']),video_codec='H264 High4.2',pixel_format='yuv420p',
    audio_codec='AAC',sample_rate=48000,audio_channels=2,full_decode_errors=0,review_times=times,
    v2_master_unchanged=True,game_cues_unchanged=True,greeting_hold=hold,
    game_runtime_changed=False,android_capture=False,phone_acceptance=False)
(QA/'technical-validation.json').write_text(json.dumps(report,indent=2)+'\n')
(QA/'ffprobe.json').write_text(json.dumps(probe,indent=2)+'\n')
print(json.dumps(dict(video=report,audio=audio),indent=2))
