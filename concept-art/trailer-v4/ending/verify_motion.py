"""Verify the ending frame sequence and the rendered static hold."""
import hashlib,json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[3]
out=root/'outputs/trailer-v4-20261104/ending'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
frames=sorted(out.glob('frame_*.png'));assert len(frames)==174
modes=set()
for path in frames:
    with Image.open(path) as im:
        assert im.size==(1080,1920) and im.mode=='RGBA'
        modes.add(im.mode)
with Image.open(frames[0]) as im:assert im.getchannel('A').getextrema()==(0,0)
hold={sha(out/f'frame_{index:05d}.png') for index in range(69,174)}
assert len(hold)==1
card=Path(__file__).with_name('exports')/'sugarfall-end-card.png'
assert sha(frames[-1])==sha(card)
result=dict(passed=True,frames=174,fps=60,seconds=2.9,png_modes=sorted(modes),first_frame_transparent=True,
    hold_frames=105,hold_range=[1.15,2.9],hold_unique_frame_hashes=len(hold),
    final_matches_static_png=True,final_sha256=sha(frames[-1]))
(out/'motion-acceptance.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
