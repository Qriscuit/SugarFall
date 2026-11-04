"""Reproducible private trailer V1: real captures + vector cutout overlays."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'outputs/trailer-v1-20261104'
FFMPEG=ROOT/'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
FPS=60
clips=['01-bakery-sparse','02-gelato-aim','03-crystal-prism','04-feed-purchase',
       '05-feed-result','06-twin-growth','07-jam-busy','08-real-clear']
# Frame counts sum to exactly 1,800. Source time stays at normal speed.
segments=[
 dict(clip=clips[0],source_start=14/60,frames=219,zoom_start=1,zoom_end=1.50,anchor=[493.5,643.5],title='Bakery opening'),
 dict(clip=clips[1],source_start=14/60,frames=105,zoom_start=1.50,zoom_end=1.50,anchor=[660,675],title='Wafer material cut'),
 dict(clip=clips[2],source_start=7/60,frames=109,zoom_start=1.50,zoom_end=1.50,anchor=[622.5,735],title='Crystal material cut'),
 dict(clip=clips[1],source_start=.6,frames=216,zoom_start=1,zoom_end=1,title='Curve and first contact'),
 dict(clip=clips[3],source_start=0,frames=215,zoom_start=1,zoom_end=1,title='Real Feed purchase'),
 dict(clip=clips[4],source_start=0,frames=108,zoom_start=1,zoom_end=1,title='Faster Feed result'),
 dict(clip=clips[5],source_start=0,frames=265,zoom_start=1,zoom_end=1,title='Twins and foreground Mabel'),
 dict(clip=clips[2],source_start=1/3,frames=213,zoom_start=1,zoom_end=1,title='Real Prism duplication'),
 dict(clip=clips[6],source_start=0,frames=55,zoom_start=1.06,zoom_end=1.06,title='Jam impact'),
 dict(clip=clips[7],source_start=.5,frames=295,zoom_start=1,zoom_end=1,title='Last peg, catches and branded ending'),
]
frame=0
for s in segments:
    s['edit_start_frame']=frame
    s['edit_start']=frame/FPS
    frame+=s['frames']
    s['edit_end']=frame/FPS
assert frame==1800
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'edit-decision-list.json').write_text(json.dumps(dict(fps=FPS,frames=frame,segments=segments),indent=2)+'\n')

def run(label,args):
    log=OUT/(label+'.log')
    with log.open('w',encoding='utf-8') as stream:
        subprocess.run([str(FFMPEG),'-hide_banner','-y',*map(str,args)],stdout=stream,stderr=subprocess.STDOUT,
                       check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    print(label+': complete',flush=True)

signature=hashlib.sha256(json.dumps(segments,sort_keys=True).encode())
for name in clips:
    signature.update(hashlib.sha256((OUT/'encoded'/(name+'.mp4')).read_bytes()).digest())
base=OUT/('picture-base-'+signature.hexdigest()[:12]+'.mp4')
if not base.exists():
    args=[]
    for name in clips:
        path=OUT/'encoded'/(name+'.mp4')
        assert path.is_file(),path
        args += ['-threads','2','-i',path]
    chains=[]
    occurrences={name:[] for name in clips}
    for i,s in enumerate(segments):occurrences[s['clip']].append(i)
    for index,name in enumerate(clips):
        labels=''.join('[src%d]'%i for i in occurrences[name])
        if len(occurrences[name])>1:chains.append('[%d:v]split=%d%s'%(index,len(occurrences[name]),labels))
        else:chains.append('[%d:v]null%s'%(index,labels))
    for i,s in enumerate(segments):
        first=round(s['source_start']*FPS)
        chain='[src%d]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS'%(i,first,first+s['frames'])
        z0,z1=s['zoom_start'],s['zoom_end']
        if z0!=1 or z1!=1:
            zoom='%.6f+(%.6f)*on/%d'%(z0,z1-z0,max(1,s['frames']-1))
            if 'anchor' in s:
                ax,ay=s['anchor']
                xpos='max(0,min(iw-iw/zoom,%.3f-540/zoom))'%ax
                ypos='max(0,min(ih-ih/zoom,%.3f-675/zoom))'%ay
            else:
                xpos='iw/2-iw/(2*zoom)'
                ypos='max(0,min(ih-ih/zoom,ih*.42-ih*.42/zoom))'
            chain+=",zoompan=z='%s':x='%s':y='%s':d=1:s=1080x1920:fps=60"%(zoom,xpos,ypos)
        chain+=',setsar=1,format=yuv420p[seg%d]'%i
        chains.append(chain)
    chains.append(''.join('[seg%d]'%i for i in range(len(segments)))+'concat=n=%d:v=1:a=0[base]'%len(segments))
    graph=OUT/'base-filter.txt';graph.write_text(';\n'.join(chains))
    run('picture-base',args+['-filter_complex_threads','2','-filter_complex',graph.read_text(),'-map','[base]',
        '-an','-c:v','libx264','-preset','veryfast','-crf','17','-threads','6','-r','60',
        '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv',
        '-movflags','+faststart',base])

puppet=ROOT/'concept-art/trailer-v1/mabel'
names=['present','catch','catch-two','balance','balance-step','settle']
args=['-threads','2','-i',base]
for name in names:
    path=puppet/('mabel-'+name+'.png')
    assert path.is_file(),path
    args+=['-loop','1','-framerate','60','-i',path]
title=OUT/'overlays/title.png'
args+=['-loop','1','-framerate','60','-i',title,
       '-loop','1','-framerate','12','-i',puppet/'doughnut-prop.png',
       '-i',OUT/'trailer-v1-mix.wav']
chains=['[0:v]drawbox=x=0:y=0:w=iw:h=ih:color=black@0.38:t=fill:enable=\'gte(t,27.233333)\'[bg]']
for index,name in enumerate(names,1):
    chains.append('[%d:v]scale=468:780,format=rgba[p%d]'%(index,index))
# Quantized placement gives smooth game footage a deliberately stepped paper puppet.
placements=[
 (1,17.55,17.966667,"1080-490*min(1,floor((t-17.55)*12)/5)","845+4*sin(floor((t-17.55)*12)*1.4)"),
 (2,17.966667,18.85,'590','845'),
 (3,18.85,19.766667,'590','843'),
 (4,19.766667,20.05,"590-18*floor((t-19.766667)*12)/3","845-5*abs(sin(floor((t-19.766667)*12)*1.2))"),
 (5,20.05,20.316667,"572-18*floor((t-20.05)*12)/3","845-4*abs(sin(floor((t-20.05)*12)*1.2))"),
 (6,20.316667,20.616667,'554','845'),
 (6,27.233333,30,"1080-490*min(1,floor((t-27.233333)*12)/4)","960+3*sin(floor((t-27.233333)*12)*.7)"),
]
# Settle is used twice; split its input so both overlays receive all frames.
chains.append('[p6]split=2[p6a][p6b]')
previous='bg'
for n,(pose,start,end,x,y) in enumerate(placements):
    sprite='p%d'%pose
    if pose==6:sprite='p6a' if start<21 else 'p6b'
    label='m%d'%n
    chains.append("[%s][%s]overlay=x='%s':y='%s':enable='gte(t,%.6f)*lt(t,%.6f)':shortest=1[%s]"%(previous,sprite,x,y,start,end,label))
    previous=label
chains.append('[8:v]scale=108:85,format=rgba,split=3[drop0][drop1][drop2]')
# Paper props fall toward the tray immediately before the corresponding pose changes.
for n,(start,end,x,target_y) in enumerate([
    (17.633333,17.966667,877,1212),
    (18.516667,18.850000,872,1178),
    (19.433333,19.766667,883,1147),
]):
    label='dropstage%d'%n
    ypos='820+(%.3f-820)*pow(min(1,max(0,floor((t-%.6f)*12)/4)),2)'%(target_y,start)
    chains.append("[%s][drop%d]overlay=x=%d:y='%s':enable='gte(t,%.6f)*lt(t,%.6f)':shortest=1[%s]"%(previous,n,x,ypos,start,end,label))
    previous=label
chains.append('[7:v]format=rgba[title]')
chains.append("[%s][title]overlay=x=0:y=320:enable='gte(t,27.233333)':shortest=1,format=yuv420p[final]"%previous)
graph=OUT/'overlay-filter.txt';graph.write_text(';\n'.join(chains))
parser=argparse.ArgumentParser()
parser.add_argument('--output',default='Sugarfall-Trailer-V1-Review.mp4')
options=parser.parse_args()
assert Path(options.output).name==options.output
final=OUT/options.output
run('final-render',args+['-filter_complex_threads','2','-filter_complex',graph.read_text(),'-map','[final]','-map','9:a',
    '-frames:v','1800','-t','30','-c:v','libx264','-preset','fast','-crf','18','-threads','6',
    '-profile:v','high','-level:v','4.2','-r','60','-pix_fmt','yuv420p',
    '-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-color_range','tv',
    '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',
    '-metadata','title=Sugarfall — Trailer V1 private review',
    '-metadata','comment=Private review with supplied reference recording; publication permission unresolved.',final])
print(str(final),flush=True)
