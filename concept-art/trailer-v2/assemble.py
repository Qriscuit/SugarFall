"""Build a private V2 review without changing the approved V1 media or game."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v2-20261104';OUT.mkdir(parents=True,exist_ok=True)
V1=ROOT/'outputs/trailer-v1-20261104'
FFMPEG=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
edl=json.loads((V1/'edit-decision-list.json').read_text())
edl['segments'][6]['source_start']=155/60
edl['segments'][6]['title']='Twin launchers and painted Mabel, three tracked catches'
edl['segments'][9]['title']='Real last peg and cup catches; closing art starts27.1'
(OUT/'edit-decision-list.json').write_text(json.dumps(edl,indent=2)+'\n')

def run(label,args):
    with (OUT/(label+'.log')).open('w') as log:
        subprocess.run([str(FFMPEG),'-hide_banner','-y',*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    print(label+': complete',flush=True)

def make_base():
    base=OUT/'picture-base-clean.mp4'
    if base.exists():return base
    original=V1/'picture-base-56eb02fa1b88.mp4'
    twin=OUT/'gameplay/06-twin-clean.mp4'
    assert twin.exists(), 'Run encode_clean.py after the verified draw-only pass'
    graph='[0:v]split=2[a][b];[a]trim=start_frame=0:end_frame=972,setpts=PTS-STARTPTS[p];[1:v]trim=start_frame=155:end_frame=420,setpts=PTS-STARTPTS[q];[b]trim=start_frame=1237:end_frame=1800,setpts=PTS-STARTPTS[r];[p][q][r]concat=n=3:v=1:a=0[base]'
    run('picture-base',['-i',original,'-i',twin,'-filter_complex_threads','2','-filter_complex',graph,'-map','[base]','-an',
        '-c:v','libx264','-preset','veryfast','-crf','17','-threads','6','-r','60','-pix_fmt','yuv420p',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv','-movflags','+faststart',base])
    return base

def assemble(output):
    base=make_base()
    # Transparent painted foreground is limited to the existing twin shot.
    # The full-art ending dissolves over the recorded cup catches from27.1.
    graph=("[1:v]format=rgba,setpts=PTS-STARTPTS+16.2/TB[m];"
        "[0:v][m]overlay=x=0:y=0:enable='gte(t,16.2)*lt(t,20.616667)':eof_action=pass[painted];"
        "[2:v]format=rgba,fade=t=in:st=0:d=0.35:alpha=1,setpts=PTS-STARTPTS+27.1/TB[end];"
        "[painted][end]overlay=x=0:y=0:enable='gte(t,27.1)':eof_action=pass,format=yuv420p[final]")
    (OUT/'overlay-filter.txt').write_text(graph+'\n')
    run('final-render',['-threads','2','-i',base,
        '-framerate','60','-i',OUT/'mabel/frame_%05d.png',
        '-framerate','60','-i',OUT/'ending/frame_%05d.png',
        '-i',OUT/'trailer-v2-mix.wav','-filter_complex_threads','2','-filter_complex',graph,
        '-map','[final]','-map','3:a','-frames:v','1800','-t','30','-c:v','libx264','-preset','fast','-crf','18',
        '-threads','6','-profile:v','high','-level:v','4.2','-r','60','-pix_fmt','yuv420p',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv',
        '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',
        '-metadata','title=Sugarfall — Trailer V2 private review',
        '-metadata','comment=Painted mascot overlay over recorded gameplay. Supplied music reference; publication permission unresolved.',OUT/output])
    final=OUT/output
    print(json.dumps(dict(file=str(final),bytes=final.stat().st_size,sha256=hashlib.sha256(final.read_bytes()).hexdigest()),indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--base-only',action='store_true');parser.add_argument('--output',default='Sugarfall-Trailer-V2-Review.mp4');args=parser.parse_args()
    assert Path(args.output).name==args.output
    if args.base_only:make_base()
    else:assemble(args.output)
