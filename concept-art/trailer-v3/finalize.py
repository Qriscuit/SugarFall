"""Freeze the local V3 master and its image, audio and playback evidence."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
BASE=Path(__file__).resolve().parent
OUT=ROOT/'outputs/trailer-v3-20261104'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
technical=read(OUT/'qa/technical-validation.json')
audio=read(OUT/'qa/audio-validation.json')
watch=read(OUT/'qa/watch-validation.json')
hold=read(OUT/'qa/greeting-hold-validation.json')
ending=read(OUT/'ending/render-validation.json')
layout=read(OUT/'ending/layout-validation.json')
greeting_visual=read(OUT/'qa/greeting-visual-validation.json')
encoded_ending=read(OUT/'qa/ending-final-validation.json')
parity=read(OUT/'qa/catch-overlay-parity.json')
assert all(item['passed'] for item in [technical,audio,watch,hold,ending,layout,greeting_visual,encoded_ending])
assert parity['byte_identical_frames']==parity['compared_frames']==209 and not parity['different_frame_indices']
assert ending['hold_pixel_stable']
video=ROOT/technical['file'];assert sha(video)==technical['sha256']
assert encoded_ending['video_sha256']==technical['sha256'] and encoded_ending['bytes']==technical['bytes']
assets=[]
for path in sorted((BASE/'source').glob('*.png')):
    with Image.open(path) as im:
        item=dict(file=path.relative_to(ROOT).as_posix(),dimensions=list(im.size),mode=im.mode,
            bytes=path.stat().st_size,sha256=sha(path))
        if im.mode=='RGBA':item['alpha_extrema']=list(im.getchannel('A').getextrema())
        assets.append(item)
card=BASE/'ending/exports/sugarfall-end-card.png'
assert sha(card)==sha(OUT/'ending/frame_00173.png')
manifest=dict(date='2026-11-04',status='V3 local review rendered and verified',video=technical,
    review='watch.html',storyboard='storyboard.md',timing='timing.json',prompts='prompts.json',
    production_record='../../PLINKO/docs/store/TRAILER_V3.md',
    generation_tool='Built-in Imagegen',source_assets=assets,
    greeting=dict(enter=[14.55,15.1],hold=hold,turn_and_step=[15.95,16.45],ready=[16.45,17.13],
        greeting_text=None,spoken_line=None,visual=greeting_visual),catch_overlay_parity=parity,
    catches=dict(times=[17.3666667,18.5166667,18.9666667],items=['Pink scoop','Pink scoop','Small red fruit'],
        unchanged_from_v2=True),
    ending=dict(range=[27.1,30],card=card.relative_to(ROOT).as_posix(),card_sha256=sha(card),
        text=['Sugarfall','Play now'],render=ending,layout=layout,encoded_visual=encoded_ending,
        illustrated_plate_food=['Pink-frosted doughnut','Pink ice cream']),
    audio=audio,review_page=watch,edl='../../outputs/trailer-v3-20261104/edit-decision-list.json',
    local_delivery=dict(user_choice='Keep this video local',drive_uploaded=False,sharing_changed=False),
    source_music_permission=read(OUT/'audio/mix-report.json')['permission'],
    game_runtime_changed=False,apk_rebuilt=False,publicly_published=False,phone_acceptance=False)
visual=OUT/'qa/visual-validation.json'
if visual.exists():
    evidence=read(visual);assert evidence['passed'];manifest['visual_review']=evidence
    manifest['status']='V3 local review rendered and verified'
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(passed=True,bytes=technical['bytes'],sha256=technical['sha256'],assets=len(assets),local_only=True),indent=2))
