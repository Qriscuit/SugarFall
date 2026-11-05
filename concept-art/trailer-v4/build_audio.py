"""Preserve the approved action audio and remap the new upgrade/cream shot."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v4-20261104'
V1=ROOT/'concept-art/trailer-v1/audio/build_mix.py'
spec=importlib.util.spec_from_file_location('mix_helpers',V1)
helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
FFMPEG=helpers.DEFAULT_FFMPEG
RATE=48000

def build(ending_cues):
    source_report=json.loads((ROOT/'outputs/trailer-v3-20261104/audio/mix-report.json').read_text(encoding='utf-8-sig'))
    slot_start,slot_end=649/60,14.4
    selected=[dict(e) for e in source_report['events'] if e['type']=='game_sfx' and not slot_start<=e['time']<slot_end]
    removed=[e for e in source_report['events'] if e['type']=='game_sfx' and slot_start<=e['time']<slot_end]
    selected.extend(dict(e) for e in source_report['events'] if e['type']=='original_foley' and 14.4<=e['time']<20.616667)
    capture=json.loads((OUT/'gameplay/09-upgrades-rich/clip.json').read_text(encoding='utf-8-sig'))
    for event in capture['events']:
        raw=float(event['time']);name=event['event']
        if not 0<=raw<215/60:continue
        path=f'PLINKO/data/audio/feedback/{name}.wav'
        if not (ROOT/path).is_file():continue
        selected.append(dict(time=round(slot_start+raw,7),file=path,gain=.23,pan=0,label='Gelato upgrade map: '+name,
            type='game_sfx',event=name,source_clip='09-upgrades-rich',source_time=raw,pitch=float(event.get('options',{}).get('pitch',1))))
    # Original soft-noise Foley supports the visible cream wash; it is not a new game sound.
    selected.append(dict(time=slot_start+.10,file='concept-art/trailer-v1/audio/foley/paper_rustle.wav',gain=.27,pan=0,
        label='Cream page wash',type='original_foley'))
    assert ending_cues.is_file(), 'Ending artist must freeze audio-cues.json before mixing'
    end=json.loads(ending_cues.read_text(encoding='utf-8-sig'))
    for item in (end if isinstance(end,list) else end.get('events',[])):
        cue=dict(item)
        cue['time']=round(27.1+float(cue.pop('relative_time')),7)
        cue.setdefault('gain',.35);cue.setdefault('pan',0);cue.setdefault('type','original_foley')
        assert 27.1<=cue['time']<30 and (ROOT/cue['file']).is_file()
        selected.append(cue)
    selected.sort(key=lambda e:e['time'])
    work=OUT/'audio';work.mkdir(parents=True,exist_ok=True)
    source=helpers.SOURCE
    assert hashlib.sha256(source.read_bytes()).hexdigest()==helpers.SOURCE_SHA
    music_path=ROOT/'verification/trailer-v1-20261104/audio/music-48k-reference.wav'
    music=helpers.read_pcm(music_path)[:30*RATE]
    t=np.arange(30*RATE)/RATE
    gain=np.full(len(t),.90)*(1-.20*helpers.smooth_gate(t,14.55,20.35,.12))
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
    target=OUT/'trailer-v4-mix.wav';helpers.write_wav(target,mix)
    loaded=helpers.read_pcm(target);assert loaded.shape==(1440000,2) and np.max(np.abs(loaded))<.95
    assert hashlib.sha256(source.read_bytes()).hexdigest()==helpers.SOURCE_SHA
    report=dict(date='2026-11-04',source_sha256=helpers.SOURCE_SHA,source_unchanged=True,music_range=[0,30],speed=1,
        permission='Private supplied recording reference; publication clearance remains unresolved',events=selected,
        game_event_count=sum(e['type']=='game_sfx' for e in selected),foley_count=sum(e['type']=='original_foley' for e in selected),
        peak=float(np.max(np.abs(loaded))),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(loaded*loaded)))),clipped_samples=0,
        output_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),mabel_music_duck_range=[14.55,20.35],
        preserved_game_cues_outside_replaced_slot=True,replaced_slot=[slot_start,slot_end],removed_game_cues=removed,
        mabel_foley_unchanged_from_v3=True,ending_cues=ending_cues.relative_to(ROOT).as_posix())
    (work/'mix-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['game_event_count','foley_count','peak','rms_dbfs','clipped_samples']},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--ending-cues',type=Path,default=ROOT/'concept-art/trailer-v4/ending/audio-cues.json');args=parser.parse_args()
    build(args.ending_cues)
