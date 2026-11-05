"""Freeze exact V4 media, source identity and independent visual evidence."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
BASE=Path(__file__).resolve().parent
OUT=ROOT/'outputs/trailer-v4-20261104'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
technical=read(OUT/'qa/technical-validation.json')
audio=read(OUT/'qa/audio-validation.json')
watch=read(OUT/'qa/watch-validation.json')
hold=read(OUT/'qa/greeting-hold-validation.json')
ending=read(OUT/'ending/render-validation.json')
layout=read(OUT/'ending/layout-validation.json')
motion=read(OUT/'ending/motion-acceptance.json')
capture=read(OUT/'gameplay/upgrades-capture-validation.json')
encoded_map=read(OUT/'qa/upgrade-left-final-validation.json')
encoded_ending=read(OUT/'qa/ending-final-validation.json')
visual=read(OUT/'qa/visual-validation.json')
assert all(item['passed'] for item in [technical,audio,watch,hold,ending,layout,motion,capture,encoded_map,encoded_ending,visual])
video=ROOT/technical['file'];assert sha(video)==technical['sha256']
assert watch['video_sha256']==technical['sha256']
for evidence in [encoded_map,encoded_ending,visual]:
    bound_hash=evidence.get('video_sha256') or evidence.get('sha256') or evidence.get('master_sha256') or evidence.get('source_sha256')
    assert bound_hash==technical['sha256'], 'Visual evidence must be bound to the exact master'
assert ending['first_frame_transparent'] and ending['hold_pixel_stable'] and motion['hold_frames']==105
assert capture['source_parity'] and capture['profile_io']==0 and capture['ordinary_owned']==56 and capture['ordinary_total']==62
edl=read(OUT/'edit-decision-list.json')
assert sha(ROOT/edl['picture_base'])==edl['picture_base_sha256']
assert edl['preserved_mabel']['source']=='outputs/trailer-v3-20261104/mabel'
mabel=ROOT/edl['preserved_mabel']['source']
sequence=hashlib.sha256()
for i in range(373):sequence.update(hashlib.sha256((mabel/f'frame_{i:05d}.png').read_bytes()).digest())
asset_paths=[ROOT/'concept-art/trailer-v3/source'/name for name in ['sugarfall-wordmark.png','food-collision-board.png','mabel-end.png','mabel-hello.png','play-now-button.png']]
asset_paths += [ROOT/'PLINKO/data/art'/name for name in ['food/countertop.png','gelato/food/countertop.png','arc_props/flower_planter.png']]
assets=[]
for path in asset_paths:
    with Image.open(path) as im:
        item=dict(file=path.relative_to(ROOT).as_posix(),dimensions=list(im.size),mode=im.mode,bytes=path.stat().st_size,sha256=sha(path))
        if im.mode=='RGBA':item['alpha_extrema']=list(im.getchannel('A').getextrema())
        assets.append(item)
card=BASE/'ending/exports/sugarfall-end-card.png'
assert sha(card)==sha(OUT/'ending/frame_00173.png')
capture_summary={k:v for k,v in capture.items() if k!='frozen_resource_hashes'}
last=ending['samples'][-1];gap=last['food'][1]-(last['title'][1]+last['title'][3])
mix=read(OUT/'audio/mix-report.json')
manifest=dict(date='2026-11-04',status='V4 local review rendered and verified',video=technical,
    review='watch.html',storyboard='storyboard.md',timing='timing.json',production_record='../../PLINKO/docs/store/TRAILER_V4.md',
    artwork='Approved V3 Imagegen PNGs arranged natively with existing painted background artwork',
    prompts='../trailer-v3/prompts.json',source_art_assets=assets,
    left_closeup=dict(range=[433/60,649/60],zoom=[1,1.45],anchor=[288,900],actual_wafer_center=[288,800.4],
        recorded_contact_edit_times=[581/60,591/60],encoded_visual=encoded_map),
    upgrade_reveal=dict(range=[649/60,14.4],source='gameplay/09-upgrades-rich',source_frames=270,used_frames=215,
        capture=capture_summary,full_capture_validation='../../outputs/trailer-v4-20261104/gameplay/upgrades-capture-validation.json',
        capture_validation_sha256=sha(OUT/'gameplay/upgrades-capture-validation.json'),encoded_visual=encoded_map),
    mabel=dict(source=edl['preserved_mabel']['source'],frames=373,range=[14.4,1237/60],
        all_frames_reused_without_modification=True,sequence_sha256=sequence.hexdigest(),greeting_hold=hold,
        handoff_times=[1042/60,1111/60,1138/60],foley_unchanged=True),
    ending=dict(range=[27.1,30],card=card.relative_to(ROOT).as_posix(),card_sha256=sha(card),
        visible_title_to_tray_gap_px=gap,text=['Sugarfall','Play now'],layer_arrivals=ending['layer_arrivals'],
        stable_full_hold=[28.25,30],hold_frames=105,render=ending,layout=layout,motion=motion,encoded_visual=encoded_ending),
    audio=audio,audio_cue_counts=dict(game=mix['game_event_count'],foley=mix['foley_count']),
    review_page=watch,visual_review=visual,edl='../../outputs/trailer-v4-20261104/edit-decision-list.json',
    local_delivery=dict(user_choice='Keep this video local',drive_uploaded=False,sharing_changed=False),
    source_music_permission=mix['permission'],game_runtime_changed=False,apk_rebuilt=False,publicly_published=False,phone_acceptance=False)
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(passed=True,bytes=technical['bytes'],sha256=technical['sha256'],source_art_assets=len(assets),local_only=True),indent=2))
