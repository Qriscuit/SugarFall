"""Retain the reference music and remap real feedback to the revised clip trim."""
from __future__ import annotations
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v2-20261104'
V1=ROOT/'concept-art/trailer-v1/audio/build_mix.py'
spec=importlib.util.spec_from_file_location('mix_helpers',V1)
helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
FFMPEG=helpers.DEFAULT_FFMPEG
RATE=48000

def build():
    edl=json.loads((OUT/'edit-decision-list.json').read_text())
    candidates=[]
    gains={'launch':.11,'peg_hit':.21,'peg_break':.33,'cup_catch':.25,'prism':.32,'upgrade':.30,'jam_splash':.29,'ui_tap':.23}
    groups={'peg_hit':'peg','peg_break':'peg','cup_catch':'cup','launch':'launch'}
    priority={'prism':0,'upgrade':0,'jam_splash':0,'ui_tap':0,'peg_break':1,'peg_hit':2,'cup_catch':3,'launch':4}
    for index,seg in enumerate(edl['segments']):
        clip=json.loads((ROOT/'outputs/trailer-v1-20261104/gameplay'/seg['clip']/'clip.json').read_text())
        for event in clip['events']:
            name=event['event'];raw=float(event['time'])
            if name not in gains or not seg['source_start']-1e-5<=raw<seg['source_start']+seg['frames']/60-1e-5:continue
            time=seg['edit_start']+raw-seg['source_start']
            if not 0<=time<27.1:continue
            area=event['area'];filename=f'{area}_{name}' if name in groups else name
            candidates.append(dict(time=round(time,7),file=f'PLINKO/data/audio/feedback/{filename}.wav',gain=gains[name],pan=0,
                label=f'{area}: {name}',type='game_sfx',event=name,area=area,source_clip=seg['clip'],source_time=raw,
                edit_segment=index,edit_frame=round(time*60),pitch=float(event.get('options',{}).get('pitch',1))))
    per_frame={}
    for cue in sorted(candidates,key=lambda e:(e['edit_frame'],priority[e['event']],e['time'])):per_frame.setdefault(cue['edit_frame'],cue)
    selected=[e for e in per_frame.values() if e['event'] not in groups]
    for group,gap in [('peg',.25),('cup',.50),('launch',.80)]:
        chosen=[]
        for e in sorted((e for e in per_frame.values() if groups.get(e['event'])==group),key=lambda e:(0 if e['event']=='peg_break' else 1,e['time'])):
            if not any(abs(e['time']-o['time'])<gap-1e-5 for o in chosen):chosen.append(e)
        selected+=chosen
    # Original Foley, now attached to the visible action instead of unrelated props.
    for time,name,gain,pan,label in [
        (16.67,'shoe_step',.32,-.8,'Mabel enters'),(16.87,'shoe_step',.34,-.55,'Mabel approaches'),
        (17.13,'shoe_step',.39,-.25,'Mabel brakes'),
        (17+22/60,'food_landing',.65,-.15,'First real scoop handoff'),
        (18+31/60,'food_landing',.69,-.17,'Second scoop during recovery'),
        (18+58/60,'food_landing',.74,.02,'Small fruit, easy catch'),
        (19.54,'shoe_step',.31,.25,'Mabel leaves with food'),(19.79,'shoe_step',.30,.6,'Mabel exits'),
        (27.62,'food_landing',.50,0,'Closing doughnut lands'),(27.64,'tray_settle',.25,0,'Closing cup settles')]:
        selected.append(dict(time=time,file=f'concept-art/trailer-v1/audio/foley/{name}.wav',gain=gain,pan=pan,label=label,type='original_foley'))
    selected.sort(key=lambda e:e['time'])
    work=OUT/'audio';work.mkdir(parents=True,exist_ok=True)
    source=helpers.SOURCE
    assert hashlib.sha256(source.read_bytes()).hexdigest()==helpers.SOURCE_SHA
    music_path=ROOT/'verification/trailer-v1-20261104/audio/music-48k-reference.wav'
    music=helpers.read_pcm(music_path)[:30*RATE]
    t=np.arange(30*RATE)/RATE
    gain=np.full(len(t),.90)*(1-.24*helpers.smooth_gate(t,16.55,20.35,.12))
    for e in selected:
        if e['type']=='game_sfx':gain*=1-.10*helpers.smooth_gate(t,e['time']-.025,e['time']+.17,.025)
    gain*=np.clip((30-t)/.30,0,1)
    mix=music*gain[:,None]
    for index,e in enumerate(selected):
        dest=work/f'event-{index:03d}.wav';pitch=e.get('pitch',1)
        subprocess.run([str(FFMPEG),'-hide_banner','-loglevel','error','-y','-i',str(ROOT/e['file']),'-af',
            f'aresample={RATE},asetrate={RATE}*{pitch:.8f},aresample={RATE}','-ar',str(RATE),'-ac','1','-c:a','pcm_s16le',str(dest)],
            check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        samples=helpers.read_pcm(dest)[:,0]*e['gain'];pan=e['pan']
        stereo=np.column_stack([samples*np.sqrt((1-pan)/2),samples*np.sqrt((1+pan)/2)])
        start=round(e['time']*RATE);count=min(len(stereo),len(mix)-start);mix[start:start+count]+=stereo[:count]
    peak_before=float(np.max(np.abs(mix)));normalization=min(1,.94/peak_before);mix*=normalization
    target=OUT/'trailer-v2-mix.wav';helpers.write_wav(target,mix)
    loaded=helpers.read_pcm(target);assert loaded.shape==(1440000,2) and np.max(np.abs(loaded))<.95
    report=dict(date='2026-11-04',source_sha256=helpers.SOURCE_SHA,source_unchanged=True,music_range=[0,30],speed=1,
        permission='Private supplied recording reference; publication clearance remains unresolved',events=selected,
        game_event_count=sum(e['type']=='game_sfx' for e in selected),foley_count=sum(e['type']=='original_foley' for e in selected),
        peak=float(np.max(np.abs(loaded))),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(loaded*loaded)))),clipped_samples=0,
        output_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),mabel_music_duck_range=[16.55,20.35])
    (work/'mix-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['game_event_count','foley_count','peak','rms_dbfs','clipped_samples']},indent=2))

if __name__=='__main__':build()
