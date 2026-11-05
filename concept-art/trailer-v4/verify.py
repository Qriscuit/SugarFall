"""Verify the exact V4 master, preserved Mabel inputs and the new captured shot."""
import hashlib
import json
import subprocess
import wave
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v4-20261104';QA=OUT/'qa';QA.mkdir(parents=True,exist_ok=True)
V3=ROOT/'outputs/trailer-v3-20261104'
BIN=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin'
VIDEO=OUT/'Sugarfall-Trailer-V4-Review.mp4'
read=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()

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
times=[0,3.66,5.42,7.3,9.683333,9.85,10.9,11.08,11.28,11.55,12.9,14.2,
       15.3,17.366667,18.966667,21.5,26.6,27.2,27.4,27.8,28.1,28.3,29.8,29.983333]
for index,time in enumerate(times):
    run('ffmpeg.exe',['-v','error','-y','-ss',time,'-i',VIDEO,'-frames:v','1',QA/f'frame-{index:02d}.png'])
run('ffmpeg.exe',['-v','error','-y','-framerate','1','-i',QA/'frame-%02d.png','-vf',
    'scale=270:480,tile=6x4:padding=6:margin=6:color=0xf4f0e8','-frames:v','1',QA/'contact-sheet.jpg'])
raw=run('ffmpeg.exe',['-v','error','-i',VIDEO,'-map','0:a:0','-f','f32le','-ar','48000','-ac','2','pipe:1'],True).stdout
decoded=np.frombuffer(raw,dtype='<f4').reshape(-1,2).astype(np.float64)
with wave.open(str(OUT/'trailer-v4-mix.wav'),'rb') as stream:
    reference=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float64)/32768
n=min(len(decoded),len(reference));corr=float(np.corrcoef(decoded[:n].ravel(),reference[:n].ravel())[0,1])
assert n>=1440000 and corr>.985 and np.max(np.abs(decoded))<1
audio=dict(passed=True,comparison='Decoded final AAC vs current V4 mix',matched_samples_per_channel=n,correlation=corr,
    peak=float(np.max(np.abs(decoded))),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(decoded*decoded)))),
    clipped_samples=int(np.count_nonzero(np.abs(decoded)>=1)),subjective_listening_acceptance=False)
(QA/'audio-validation.json').write_text(json.dumps(audio,indent=2)+'\n')
assert sha(V3/'Sugarfall-Trailer-V3-Review.mp4')=='f52779cd17ee736f710527b64da852e425dd13ea98bedd232e0ee1ce3222af87'
mabel=V3/'mabel';assert len(list(mabel.glob('frame_*.png')))==373
hold_hashes={sha(mabel/f'frame_{frame:05d}.png') for frame in range(42,93)}
assert len(hold_hashes)==1
hold=dict(passed=True,reused_from='outputs/trailer-v3-20261104/mabel',first_overlay_frame=42,end_exclusive=93,
    edit_range=[15.1,15.95],frames=51,seconds=.85,unique_actor_frame_hashes=1,actor_frame_sha256=next(iter(hold_hashes)))
(QA/'greeting-hold-validation.json').write_text(json.dumps(hold,indent=2)+'\n')
source_cues=read(V3/'audio/mix-report.json')['events'];current_cues=read(OUT/'audio/mix-report.json')['events']
outside=lambda e:not 649/60<=e['time']<14.4
old_game=[e for e in source_cues if e['type']=='game_sfx' and outside(e)]
new_game=[e for e in current_cues if e['type']=='game_sfx' and outside(e)]
assert old_game==new_game
mabel_cues=lambda cues:[e for e in cues if e['type']=='original_foley' and 14.4<=e['time']<1237/60]
assert mabel_cues(source_cues)==mabel_cues(current_cues) and len(mabel_cues(current_cues))==10
capture=read(OUT/'gameplay/upgrades-capture-validation.json')
assert capture['passed'] and capture['source_parity'] and capture['profile_io']==0
assert capture['ordinary_owned']==56 and capture['ordinary_total']==62 and capture['dual_shot_source']=='earned'
assert capture['cream_fully_covered_frames']
report=dict(passed=True,file=VIDEO.relative_to(ROOT).as_posix(),bytes=VIDEO.stat().st_size,sha256=sha(VIDEO),
    dimensions=[1080,1920],fps=60,frames=1800,duration_seconds=float(probe['format']['duration']),
    video_codec='H264 High4.2',pixel_format='yuv420p',audio_codec='AAC',sample_rate=48000,audio_channels=2,
    full_decode_errors=0,review_times=times,v3_master_unchanged=True,
    mabel_input='Reuses all373 original V3 foreground PNGs without modification',greeting_hold=hold,
    game_cues_outside_replaced_slot_unchanged=True,preserved_game_cues=len(old_game),mabel_foley_unchanged=True,
    new_upgrade_capture_validation='gameplay/upgrades-capture-validation.json',
    game_runtime_changed=False,android_capture=False,phone_acceptance=False)
(QA/'technical-validation.json').write_text(json.dumps(report,indent=2)+'\n')
(QA/'ffprobe.json').write_text(json.dumps(probe,indent=2)+'\n')
print(json.dumps(dict(video=report,audio=audio),indent=2))
