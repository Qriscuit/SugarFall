"""V4 keeps Mabel intact, adds an actual rich upgrade map and a left camera move."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'outputs/trailer-v4-20261104';OUT.mkdir(parents=True,exist_ok=True)
V1=ROOT/'outputs/trailer-v1-20261104';V2=ROOT/'outputs/trailer-v2-20261104';V3=ROOT/'outputs/trailer-v3-20261104'
FFMPEG=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def edl():
    data=json.loads((V3/'edit-decision-list.json').read_text(encoding='utf-8-sig'))
    data['version']='V4'
    data['segments'][3].update(zoom_start=1,zoom_end=1.45,anchor=[288,900],title='Wide aim into left wafer contacts')
    data['segments'][4].update(clip='09-upgrades-rich',source_start=0,title='Real cream reveal and late-campaign upgrade map')
    data['picture_base']='outputs/trailer-v4-20261104/picture-base.mp4'
    picture=ROOT/data['picture_base']
    data['picture_base_sha256']=sha(picture) if picture.exists() else None
    data['base_inputs']={'approved_gameplay':'outputs/trailer-v2-20261104/picture-base-clean.mp4',
        'approved_gameplay_sha256':sha(V2/'picture-base-clean.mp4'),
        'left_zoom_source':'outputs/trailer-v1-20261104/encoded/02-gelato-aim.mp4',
        'upgrade_frames':'outputs/trailer-v4-20261104/gameplay/09-upgrades-rich'}
    data['preserved_mabel']={'frames':373,'range':[14.4,20.6166667],'source':'outputs/trailer-v3-20261104/mabel','artwork_and_timing_unchanged':True}
    data['ending']={'start':27.1,'end':30,'frames':174,'action':'Tighter painted composition; background, name, food, Mabel and CTA fade and ease in sequentially'}
    (OUT/'edit-decision-list.json').write_text(json.dumps(data,indent=2)+'\n')
    return data

def run(label,args):
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run([str(FFMPEG),'-hide_banner','-y',*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    print(label+': complete',flush=True)

def encode_upgrade():
    raw=OUT/'gameplay/09-upgrades-rich';report=json.loads((raw/'clip.json').read_text(encoding='utf-8-sig'))
    target=OUT/'gameplay/09-upgrades-rich.mp4'
    if target.exists():return target
    run('encode-upgrades',['-threads','2','-framerate','60','-start_number','0','-i',raw/'frame_%05d.jpg',
        '-frames:v',report['frames'],'-an','-vf','scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p',
        '-c:v','libx264','-preset','veryfast','-crf','16','-threads','6','-r','60',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv','-movflags','+faststart',target])
    return target

def base():
    edl();target=OUT/'picture-base.mp4'
    if target.exists():return target
    upgrade=encode_upgrade()
    graph=("[0:v]split=2[a][b];[a]trim=start_frame=0:end_frame=433,setpts=PTS-STARTPTS[p];"
        "[1:v]trim=start_frame=36:end_frame=252,setpts=PTS-STARTPTS,"
        "zoompan=z='1+0.45*on/215':x='max(0,min(iw-iw/zoom,288-540/zoom))':"
        "y='max(0,min(ih-ih/zoom,900-675/zoom))':d=1:s=1080x1920:fps=60,setsar=1,format=yuv420p[q];"
        "[2:v]trim=start_frame=0:end_frame=215,setpts=PTS-STARTPTS,setsar=1,format=yuv420p[r];"
        "[b]trim=start_frame=864:end_frame=1800,setpts=PTS-STARTPTS[s];"
        "[p][q][r][s]concat=n=4:v=1:a=0[base]")
    (OUT/'base-filter.txt').write_text(graph+'\n')
    run('picture-base',['-i',V2/'picture-base-clean.mp4','-i',V1/'encoded/02-gelato-aim.mp4','-i',upgrade,
        '-filter_complex_threads','2','-filter_complex',graph,'-map','[base]','-an','-c:v','libx264','-preset','veryfast',
        '-crf','17','-threads','6','-r','60','-pix_fmt','yuv420p','-color_primaries','bt709','-color_trc','bt709',
        '-colorspace','bt709','-color_range','tv','-movflags','+faststart',target])
    return target

def assemble():
    picture=base();assert sha(V3/'Sugarfall-Trailer-V3-Review.mp4')=='f52779cd17ee736f710527b64da852e425dd13ea98bedd232e0ee1ce3222af87'
    assert len(list((V3/'mabel').glob('frame_*.png')))==373 and len(list((OUT/'ending').glob('frame_*.png')))==174
    graph=("[1:v]format=rgba,setpts=PTS-STARTPTS+14.4/TB[m];"
        "[0:v][m]overlay=x=0:y=0:enable='gte(t,14.4)*lt(t,20.616667)':eof_action=pass[painted];"
        "[2:v]format=rgba,setpts=PTS-STARTPTS+27.1/TB[end];"
        "[painted][end]overlay=x=0:y=0:enable='gte(t,27.1)':eof_action=pass,format=yuv420p[final]")
    (OUT/'overlay-filter.txt').write_text(graph+'\n')
    final=OUT/'Sugarfall-Trailer-V4-Review.mp4'
    run('final-render',['-threads','2','-i',picture,'-framerate','60','-i',V3/'mabel/frame_%05d.png',
        '-framerate','60','-i',OUT/'ending/frame_%05d.png','-i',OUT/'trailer-v4-mix.wav',
        '-filter_complex_threads','2','-filter_complex',graph,'-map','[final]','-map','3:a','-frames:v','1800','-t','30',
        '-c:v','libx264','-preset','fast','-crf','18','-threads','6','-profile:v','high','-level:v','4.2','-r','60',
        '-pix_fmt','yuv420p','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv',
        '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',
        '-metadata','title=Sugarfall — Trailer V4 local review',final])
    print(json.dumps({'file':str(final),'bytes':final.stat().st_size,'sha256':sha(final)},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--prepare',action='store_true');parser.add_argument('--base-only',action='store_true');args=parser.parse_args()
    if args.prepare:edl();print('V4 EDL prepared')
    elif args.base_only:base()
    else:assemble()
