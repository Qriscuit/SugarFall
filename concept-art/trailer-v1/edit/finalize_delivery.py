"""Freeze evidence for the delivered private-review video and authored SVG assets."""
import hashlib
import json
from pathlib import Path

root=Path(__file__).resolve().parents[3]
out=root/'outputs/trailer-v1-20261104'
base=root/'concept-art/trailer-v1'
read=lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
technical=read(out/'qa/technical-validation.json')
audio=read(out/'qa/audio-validation.json')
visual=read(out/'qa/cut02/targeted-visual-validation.json')
capture=read(out/'gameplay/capture-report.json')
source=read(out/'gameplay/source-evidence.json')
mix=read(out/'audio/mix-report.json')
delivery=read(base/'delivery.json')
assets=read(base/'mabel/asset-manifest.json')
video=out/'Sugarfall-Trailer-V1-Review.mp4'
digest=lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert technical['passed'] and audio['passed'] and source['source_parity'] and capture['profile_io']==0
assert digest(video)==technical['sha256']==delivery['local_sha256']
assert video.stat().st_size==delivery['bytes']==10060724
assert mix['original_source_unchanged'] and mix['clipped_samples']==0
assert not list(base.rglob('*.mp3')) and not list(base.rglob('*.mp4'))
for path in (base/'mabel').glob('*.svg'):
    text=path.read_text(encoding='utf-8')
    assert '<image' not in text and '<script' not in text
manifest=dict(date='2026-11-04',status='Trailer V1 private review delivered',
    video=technical, delivery='delivery.json',
    gameplay=dict(source='Fresh current-workspace public nondebug Windows renderer',
                  raw_clips=len(capture['clips']),raw_frames=sum(c['frames'] for c in capture['clips']),
                  raw_seconds=sum(c['frames']/c['fps'] for c in capture['clips']),
                  source_revision=source['source_revision'],frozen_source_files=source['source_files'],
                  source_parity=True,profile_io=0,physics_and_drawing_changed=False,
                  staged_progress_and_wallets=True,android_device_capture=False),
    mabel=dict(format='Authored editable SVG paths/shapes/gradients; transparent PNG derivatives',
               svg_count=len(list((base/'mabel').glob('*.svg'))),asset_manifest='mabel/asset-manifest.json',
               overlay_ranges=[[17.55,20.616667],[27.233333,30]],
               action='Enter, catch three paper doughnuts, balance and shuffle; return beside title',
               pose_updates_per_second=12,promotional_overlay=True),
    music=dict(source=mix['original_source'],source_sha256=mix['original_source_sha256'],
               source_unchanged=True,range=[0,30],speed=1,
               permission='Publication permission unresolved; supplied performance is used for private review'),
    audio_verification=audio,
    visual_verification='../../outputs/trailer-v1-20261104/qa/cut02/targeted-visual-validation.json',
    edit_decisions='../../outputs/trailer-v1-20261104/edit-decision-list.json',
    source_evidence='../../outputs/trailer-v1-20261104/gameplay/source-evidence.json',
    production_brief='../../PLINKO/docs/store/TRAILER_V1.md',
    review='review.html',game_runtime_changed=False,apk_rebuilt=False,publicly_published=False,phone_acceptance=False)
(base/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(passed=True,sha256=technical['sha256'],bytes=video.stat().st_size,
                     raw_clips=len(capture['clips']),svg_assets=manifest['mabel']['svg_count'],
                     audio_correlation=audio['correlation']),indent=2))
