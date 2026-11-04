"""Embed the authored timing data into the local review page; no network reads."""
import json
from pathlib import Path

base = Path(__file__).resolve().parent
plan = json.loads((base / 'storyboard.json').read_text(encoding='utf-8-sig'))
template = (base / 'preview.template.html').read_text(encoding='utf-8')
marker = '/*__STORYBOARD_DATA__*/{}'
assert template.count(marker) == 1
payload = json.dumps(plan, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
page = template.replace(marker, payload)
(base / 'preview.html').write_text(page, encoding='utf-8')
print(f"Built {base / 'preview.html'} with {len(plan['shots'])} shots")
