"""Freeze the exact media, art and verification evidence for the V2 review."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
BASE=Path(__file__).resolve().parent
OUT=ROOT/'outputs/trailer-v2-20261104'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
technical=read(OUT/'qa/technical-validation.json')
audio=read(OUT/'qa/audio-validation.json')
watch=read(OUT/'qa/watch-validation.json')
assert technical['passed'] and audio['passed'] and watch['passed']
video=ROOT/technical['file'];assert sha(video)==technical['sha256']
assets=[]
for path in sorted((BASE/'mabel-painted/source').glob('*.png')):
    with Image.open(path) as im:
        assert im.mode=='RGBA' and im.size==(1024,1536)
        assets.append(dict(file=path.relative_to(ROOT).as_posix(),dimensions=list(im.size),mode=im.mode,
            alpha_extrema=list(im.getchannel('A').getextrema()),bytes=path.stat().st_size,sha256=sha(path)))
assert len(assets)==6
clean=read(OUT/'gameplay/clean-validation.json')
assert clean['passed']
latest_clean=read(OUT/'gameplay/06-twin-clean/validation.json')
assert latest_clean['passed'] and latest_clean['files']==clean['files']
clean={**clean,**latest_clean}
visual=read(OUT/'qa/visual-validation.json');assert visual['passed']
ending=read(OUT/'ending/render-validation.json');assert ending['passed'] and ending['font']['loaded']
final_ending=read(OUT/'qa/ending-final-validation.json');assert final_ending['passed']
manifest=dict(date='2026-11-04',status='V2 private review rendered and verified',video=technical,
    review='watch.html',design_review='review.html',production_record='../../PLINKO/docs/store/TRAILER_V2.md',
    assets=assets,mabel=dict(style='Original painted Mabel, clean transparent cutout edges',
        generation_tool='Built-in imagegen',prompts='mabel-painted/prompts.json',
        overlay_range=[16.55,20.35],real_contact_times=[17.3666667,18.5166667,18.9666667],
        action='Run in, brake, catch scoop, catch second during recovery, reach for fruit, run out',
        pose_and_position_rate=12,alternating_leg_cycle=False,carried_food_separate=True,returns_for_title=False),
    ending=dict(concept='A — Last catch',range=[27.1,30],contact=27.62,title='Bundled Fraunces, exact game axes',render_validation='../../outputs/trailer-v2-20261104/ending/render-validation.json'),
    gameplay=dict(source='Existing V1 frozen nondebug Windows recording',normal_speed=True,
        twin_trim=[155/60,7],drawing_only_clean_pass=True,clean_validation=clean,
        production_game_code_changed=False,player_saves_changed=False,physical_phone_capture=False),
    audio=audio,visual=visual,encoded_ending=final_ending,review_page=watch,delivery='delivery.json',
    music=read(OUT/'audio/mix-report.json')['permission'],v1_unchanged=True,
    apk_rebuilt=False,publicly_published=False,phone_acceptance=False)
if (BASE/'delivery.json').exists():
    delivery=read(BASE/'delivery.json');assert delivery['local_sha256']==technical['sha256'] and delivery['bytes']==technical['bytes']
    manifest['status']='V2 private review delivered' if delivery.get('status')=='uploaded_verified' else 'V2 local review rendered and verified; user requested no Drive upload'
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(passed=True,sha256=technical['sha256'],bytes=technical['bytes'],painted_poses=len(assets)),indent=2))
