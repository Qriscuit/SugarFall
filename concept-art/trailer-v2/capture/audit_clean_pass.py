"""Verify source immutability and localize the presentation-only frame changes."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[3]
fixture = Path(__file__).parent
frozen = root / 'verification/trailer-v1-20261104/capture/run-01'
work = root / 'verification/mabel-rethink-20261104/clean-pass'
output = root / 'outputs/trailer-v2-20261104/gameplay/06-twin-clean'
source_frames = root / 'outputs/trailer-v1-20261104/gameplay/06-twin-growth'
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

validation = json.loads((output / 'validation.json').read_text())
report = json.loads((output / 'clean-pass-report.json').read_text())
trace = {frame['frame']: frame for frame in report['frames']}

sources = []
for original in sorted((frozen / 'project').rglob('*')):
    if not original.is_file():
        continue
    relative = original.relative_to(frozen / 'project')
    if '.godot' in relative.parts:
        continue
    sha256 = digest(original)
    # Only the isolated project's scene entry point is intentionally different.
    if str(relative).replace('\\', '/') != 'project.godot':
        assert digest(work / 'project' / relative) == sha256, str(relative)
    sources.append(dict(path=relative.as_posix(), sha256=sha256))

pixels = []
for item in report['changed_frames']:
    frame = item['source_frame']
    original_path = source_frames / item['file']
    clean_path = output / item['file']
    a = np.asarray(Image.open(original_path).convert('RGB')).astype(np.int16)
    b = np.asarray(Image.open(clean_path).convert('RGB')).astype(np.int16)
    assert a.shape == b.shape == (1920, 1080, 3)
    delta = np.max(np.abs(a - b), axis=2)
    significant = delta > 35
    allowed = np.zeros((1920, 1080), dtype=bool)
    for ball in trace[frame]['balls']:
        if ball['id'] not in item['hidden_ids']:
            continue
        # Includes the rendered diameter and the neighboring JPEG MCU blocks.
        x, y = ball['x'], ball['y']
        allowed[max(0, int(y - 42)):min(1920, int(y + 43)),
                max(0, int(x - 42)):min(1080, int(x + 43))] = True
    outside = int(np.count_nonzero(significant & ~allowed))
    assert outside == 0, (frame, outside)
    mean = float(np.abs(a - b).mean())
    assert mean < .05, (frame, mean)
    ys, xs = np.where(significant)
    pixels.append(dict(source_frame=frame, original_sha256=digest(original_path),
                       clean_sha256=digest(clean_path), mean_absolute_rgb=mean,
                       pixels_gt35=int(significant.sum()),
                       outside_selected_food_gt35=outside,
                       bbox_gt35=([int(xs.min()), int(ys.min()), int(xs.max()+1),
                                   int(ys.max()+1)] if len(xs) else None)))

manifest = dict(
    original_frozen_binary_sha256=digest(frozen / 'Sugarfall-Trailer-Capture.exe'),
    clean_capture_binary_sha256=digest(work / 'Sugarfall-Clean-Pass.exe'),
    frozen_project_files=sources,
    frozen_resources_equal_in_isolated_copy_except_project_entry=True,
    fixture_files=[dict(path=p.relative_to(root).as_posix(), sha256=digest(p))
                   for p in sorted(fixture.glob('*')) if p.is_file()],
    source_clip_metadata_sha256=digest(source_frames / 'clip.json'),
    trace_sha256=digest(root / 'outputs/mabel-rethink-20261104/twin-ball-trace.json'),
    frame_comparisons=pixels)
(output / 'source-hashes.json').write_text(json.dumps(manifest, indent=2) + '\n')
validation['frozen_project_resource_files_matched'] = len(sources) - 1
validation['changed_frame_pixel_audit'] = dict(frames_checked=len(pixels),
    threshold_rgb=35, maximum_mean_absolute_rgb=max(p['mean_absolute_rgb'] for p in pixels),
    outside_selected_food_pixels_gt35=0)
validation['original_frozen_binary_sha256'] = manifest['original_frozen_binary_sha256']
validation['source_hashes'] = 'source-hashes.json'
validation['before'] = report['before']
validation['after'] = report['after']
validation['min_balls'] = report['min_balls']
validation['max_balls'] = report['max_balls']
(output / 'validation.json').write_text(json.dumps(validation, indent=2) + '\n')
print(json.dumps(dict(source_files_matched=len(sources)-1,
                     changed_frames_audited=len(pixels), outside_food_changes_gt35=0)))
