"""Inspect original PNGs and write Godot metadata; never modify image pixels."""
from pathlib import Path
import argparse
import json
import re
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1] / 'PLINKO' / 'data' / 'art' / 'gelato'
FAMILIES = ('cookie_normal', 'cookie_armored', 'cookie_prism', 'cookie_clock')
BACKGROUNDS = {'home_counter', 'play_counter', 'upgrade_counter', 'journey_backdrop', 'countertop'}


def inspect(path):
    with Image.open(path) as image:
        alpha = image.convert('RGBA').getchannel('A')
        bounds = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
        assert bounds, f'Empty image: {path}'
        w, h = image.size
        box = [max(0, bounds[0]-4)/w, max(0, bounds[1]-4)/h,
               min(w, bounds[2]+4)/w, min(h, bounds[3]+4)/h]
        extrema = alpha.getextrema()
        if path.stem not in BACKGROUNDS:
            assert extrema[0] == 0 and extrema[1] == 255, f'Missing true alpha: {path}'
        return box, {'size': [w, h], 'alpha_range': list(extrema), 'bytes': path.stat().st_size}


def metadata():
    report = {}
    paths = list(ROOT.glob('*/*.png'))
    assert len(paths) == 34, f'Expected 34 PNGs, found {len(paths)}'
    for group in ('food', 'environment', 'ui'):
        boxes = {}
        for path in sorted((ROOT/group).glob('*.png')):
            boxes[path.stem], report[str(path.relative_to(ROOT))] = inspect(path)
        if group == 'food':
            for family in FAMILIES:
                keys = [family] + [f'{family}_damage_{stage}' for stage in range(1, 4)]
                union = [min(boxes[key][axis] for key in keys) for axis in (0, 1)]
                union += [max(boxes[key][axis] for key in keys) for axis in (2, 3)]
                for key in keys:
                    boxes[key] = union[:]
        regions = {key: [round(box[0], 8), round(box[1], 8), round(box[2]-box[0], 8), round(box[3]-box[1], 8)]
                   for key, box in boxes.items()}
        (ROOT/group/'regions.json').write_text(json.dumps(regions, indent=2)+'\n', encoding='utf-8')
    (HERE/'asset-inspection.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(f'Inspected {len(paths)} untouched source PNGs; wrote normalized frames and alpha report.')


def imports():
    for path in ROOT.glob('*/*.png'):
        config_path = path.with_suffix('.png.import')
        assert config_path.exists(), f'Run Godot import first: {config_path}'
        if path.stem in BACKGROUNDS:
            limit = 1536
        elif path.stem in ('tray', 'panel', 'level_selector'):
            limit = 1024
        elif path.parent.name == 'environment' or path.stem == 'level_badge_muted':
            limit = 512
        else:
            limit = 256
        text = config_path.read_text(encoding='utf-8')
        for key, value in {'mipmaps/generate': 'true', 'process/fix_alpha_border': 'true', 'process/size_limit': str(limit)}.items():
            text, count = re.subn(r'^'+re.escape(key)+r'=.*$', key+'='+value, text, flags=re.M)
            assert count == 1, f'Missing import setting: {key} in {config_path}'
        config_path.write_text(text, encoding='utf-8')
    print('Updated 34 Godot import limits, mipmaps, and alpha-border settings.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--imports', action='store_true')
    args = parser.parse_args()
    imports() if args.imports else metadata()
