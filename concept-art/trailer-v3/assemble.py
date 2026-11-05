"""Compose the V3 greeting and painted brand card over the verified V2 picture base."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v3-20261104'
V2=ROOT/'outputs/trailer-v2-20261104'
FFMPEG=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
V2_SHA='43e39e4b5a4f6a2586eb3b59082d80b3bb3910415981e99b64c23dea38537195'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def prepare_edl():
    OUT.mkdir(parents=True,exist_ok=True)
    edl=json.loads((V2/'edit-decision-list.json').read_text(encoding='utf-8-sig'))
    edl['version']='V3'
    edl['picture_base']='outputs/trailer-v2-20261104/picture-base-clean.mp4'
    edl['picture_base_sha256']=sha(ROOT/edl['picture_base'])
    edl['foreground']={'start':14.4,'end':20.6166666667,'frames':373,
        'action':'Greeting hold followed by the unchanged three recorded Gelato handoffs'}
    edl['ending']={'start':27.1,'end':30,'frames':174,'action':'Painted Sugarfall brand card with Mabel, food collisions and Play now'}
    (OUT/'edit-decision-list.json').write_text(json.dumps(edl,indent=2)+'\n',encoding='utf-8')
    return edl

def run(label,args):
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run([str(FFMPEG),'-hide_banner','-y',*map(str,args)],stdout=log,stderr=subprocess.STDOUT,
            check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    print(label+': complete',flush=True)

def assemble(output):
    edl=prepare_edl()
    assert sha(V2/'Sugarfall-Trailer-V2-Review.mp4')==V2_SHA, 'V2 master changed'
    for folder,count in [('mabel',373),('ending',174)]:
        actual=list((OUT/folder).glob('frame_*.png'))
        assert len(actual)==count,(folder,len(actual),count)
        assert all((OUT/folder/f'frame_{i:05d}.png').is_file() for i in range(count))
    mix=OUT/'trailer-v3-mix.wav';assert mix.is_file(), 'Build the V3 audio mix first'
    graph=("[1:v]format=rgba,setpts=PTS-STARTPTS+14.4/TB[m];"
        "[0:v][m]overlay=x=0:y=0:enable='gte(t,14.4)*lt(t,20.616667)':eof_action=pass[painted];"
        "[2:v]format=rgba,fade=t=in:st=0:d=0.35:alpha=1,setpts=PTS-STARTPTS+27.1/TB[end];"
        "[painted][end]overlay=x=0:y=0:enable='gte(t,27.1)':eof_action=pass,format=yuv420p[final]")
    (OUT/'overlay-filter.txt').write_text(graph+'\n',encoding='utf-8')
    run('final-render',['-threads','2','-i',ROOT/edl['picture_base'],
        '-framerate','60','-i',OUT/'mabel/frame_%05d.png',
        '-framerate','60','-i',OUT/'ending/frame_%05d.png',
        '-i',mix,'-filter_complex_threads','2','-filter_complex',graph,
        '-map','[final]','-map','3:a','-frames:v','1800','-t','30','-c:v','libx264','-preset','fast','-crf','18',
        '-threads','6','-profile:v','high','-level:v','4.2','-r','60','-pix_fmt','yuv420p',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv',
        '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',
        '-metadata','title=Sugarfall — Trailer V3 local review',
        '-metadata','comment=Painted mascot and brand-card overlays. Supplied music reference; publication permission unresolved.',OUT/output])
    final=OUT/output
    print(json.dumps(dict(file=str(final),bytes=final.stat().st_size,sha256=sha(final)),indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--prepare',action='store_true');parser.add_argument('--output',default='Sugarfall-Trailer-V3-Review.mp4');args=parser.parse_args()
    assert Path(args.output).name==args.output
    if args.prepare:prepare_edl();print('V3 EDL prepared')
    else:assemble(args.output)
