"""Read-only frame validation and a labelled QA contact sheet, not trailer art."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

root=Path(__file__).resolve().parents[3]
out=root/'outputs/trailer-v1-20261104/gameplay'
report=json.loads((out/'capture-report.json').read_text())
evidence=json.loads((out/'source-evidence.json').read_text())
assert report['profile_io']==0 and report['debug'] is False and report['public_feature'] is True
assert evidence['source_parity'] is True
assert all(report[key] is False for key in ['game_draw_functions_changed','physics_changed','android_device_capture'])
indices=[120,120,80,150,120,240,120,125]
sheet=Image.new('RGB',(1080,1040),(243,243,240))
draw=ImageDraw.Draw(sheet)
records=[]
for index,(clip,frame) in enumerate(zip(report['clips'],indices)):
    folder=out/clip['name']
    files=sorted(folder.glob('frame_*.jpg'))
    assert len(files)==clip['frames']
    assert files[0].name=='frame_00000.jpg'
    assert files[-1].name==f"frame_{clip['frames']-1:05d}.jpg"
    selected=folder/f'frame_{frame:05d}.jpg'
    with Image.open(selected) as im:
        assert im.mode=='RGB' and im.size==(1080,1920)
        thumb=im.resize((270,480),Image.Resampling.LANCZOS)
        x=(index%4)*270;y=(index//4)*520
        sheet.paste(thumb,(x,y))
        draw.text((x+8,y+484),clip['name'],fill=(36,53,46))
        draw.text((x+8,y+501),f'frame{frame} /60fps',fill=(36,53,46))
    records.append(dict(name=clip['name'],frame_count=len(files),selected_frame=frame,
                        selected_sha256=hashlib.sha256(selected.read_bytes()).hexdigest(),
                        event_count=len(clip['events'])))
sheet.save(out/'capture-contact-sheet.jpg',quality=94)
trace=json.loads((out/'impact-trace.json').read_text())
for clip in report['clips'][:3]:
    expected=len([e for e in clip['events'] if e['event'] in ['peg_hit','peg_break']])
    actual=len([e for e in trace['hits'] if e['clip']==clip['name']])
    assert actual==expected,(clip['name'],actual,expected)
validation=dict(passed=True,fps=60,dimensions=[1080,1920],clips=records,
    total_frames=sum(c['frame_count'] for c in records),profile_io=0,source_parity=True,
    prism=dict(before=report['clips'][2]['prism_before'],after=report['clips'][2]['prism_after'],time=1.0),
    purchase=dict(time=2.2,bank_before=report['clips'][3]['before']['bank'],bank_after=report['clips'][3]['after']['bank']),
    clear=dict(last_peg_time=1.98333,won=report['clips'][-1]['after']['level_won']),
    impact_trace_counts_match_capture_events=True,contact_sheet='capture-contact-sheet.jpg')
(out/'capture-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
print(json.dumps(validation,indent=2))
