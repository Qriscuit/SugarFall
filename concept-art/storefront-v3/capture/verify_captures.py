"""Validate exact screenshot files and capture provenance, without altering their pixels."""
import hashlib
import json
import struct
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'PLINKO/project.godot').is_file())
OUT = ROOT / 'outputs/storefront-20261105/screenshots'
QA = OUT.parent / 'qa'
QA.mkdir(exist_ok=True)
REPORT = json.loads((OUT / 'capture-report.json').read_text())
assert REPORT['debug'] is False and REPORT['public_feature'] is True
assert REPORT['profile_io'] == 0 and REPORT['game_draw_functions_changed'] is False
assert len(REPORT['captures']) == 7
records = []
for shot in REPORT['captures']:
    path = OUT / shot['file']
    data = path.read_bytes()
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert (width, height, depth, color) == (1080, 1920, 8, 2)
    assert shot['profile_io'] == 0
    with Image.open(path) as image:
        image.verify()
    records.append(dict(file=path.name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                        width=width, height=height, bit_depth=depth, png_color_type=color,
                        format='RGB PNG without alpha'))
assert REPORT['captures'][3]['bank'] == 748 and REPORT['captures'][3]['ordinary_owned'] == 22
assert len(REPORT['map_purchases']) == 22
assert REPORT['captures'][4]['jam'] is True and REPORT['captures'][5]['twins'] is True
assert REPORT['captures'][5]['levels'][1] == 0
assert REPORT['prism_duplication']['before'] == 5 and REPORT['prism_duplication']['after'] == 10
assert REPORT['prism_duplication']['duplicated'] == REPORT['prism_duplication']['live_before'] == 5
assert REPORT['captures'][6]['prism_collected'] == 1 and REPORT['captures'][6]['balls'] == 10
source = json.loads((OUT / 'source-evidence.json').read_text())
assert source['source_parity'] is True
assert all(hashlib.sha256((ROOT / 'PLINKO' / path).read_bytes()).hexdigest() == digest
           for path, digest in source['runtime_hashes'].items())
validation = dict(structural_passed=True, captures=records, source_revision=source['source_revision'],
                  source_working_tree=True, source_inputs=source['source_files'], source_unchanged=True,
                  staged_campaign_state=True, nondebug_public_renderer=True, android_device_capture=False,
                  phone_acceptance=False, play_uploaded=False, no_image_compositing=True,
                  notes=['First three show actual gameplay in all three areas.',
                         'Map wallet748 after22 real coin purchases.',
                         'Crystal real Prism collection duplicates5 live balls to10; advanced0.2seconds for image7.',
                         'Review Android presentation against exact signed release before submission.'])
# Independent visual QA, when present, is separate from the deterministic structural checks.
qa_path = QA / 'independent-screenshots-review.json'
if qa_path.exists():
    visual = json.loads(qa_path.read_text())
    assert visual['status'] == 'passed' and visual['all_images_visually_reviewed'] is True
    assert {item['file']: item['sha256'] for item in visual['images']} == {
        item['file']: item['sha256'] for item in records}
    assert visual['source_evidence_sha256'] == hashlib.sha256((OUT / 'source-evidence.json').read_bytes()).hexdigest()
    assert visual['capture_report_sha256'] == hashlib.sha256((OUT / 'capture-report.json').read_bytes()).hexdigest()
    validation['visual_passed'] = True
    validation['passed'] = True
    validation['visual_review_evidence'] = qa_path.relative_to(ROOT).as_posix()
    validation['visual_review_sha256'] = hashlib.sha256(qa_path.read_bytes()).hexdigest()
    validation['visual_review'] = visual
else:
    validation['visual_passed'] = False
    validation['passed'] = False
(OUT / 'screenshots-validation.json').write_text(json.dumps(validation, indent=2) + '\n')
canvas = Image.new('RGB', (1120, 1080), '#182629')
draw = ImageDraw.Draw(canvas)
for index, shot in enumerate(REPORT['captures']):
    x, y = 20 + (index % 4) * 280, 20 + (index // 4) * 540
    with Image.open(OUT / shot['file']) as image:
        canvas.paste(image.resize((270, 480), Image.Resampling.LANCZOS), (x, y + 28))
    draw.text((x, y), shot['file'].split('.')[0], fill='white')
canvas.save(QA / 'seven-screenshots-contact-sheet.png')
print(json.dumps(dict(structural_passed=True, images=len(records), source_inputs=source['source_files'])))
