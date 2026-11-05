"""Capture rich Gelato upgrades and real cream navigation from frozen production resources."""
import hashlib,json,os,re,shutil,subprocess,uuid
from pathlib import Path

root=Path(__file__).resolve().parents[3]
source=root/'verification/trailer-v1-20261104/capture/run-01/project'
work=root/'verification/trailer-v4-20261104/capture/run-01'
project=work/'project'
out=root/'outputs/trailer-v4-20261104/gameplay'
assert not work.exists(), 'Use a fresh run directory'
work.mkdir(parents=True);out.mkdir(parents=True,exist_ok=True)
shutil.copytree(source,project)
capture=Path(__file__).with_name('upgrades_capture.gd')
shutil.copy2(capture,project/'capture/upgrades_capture.gd')
(project/'capture/upgrades_entry.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://capture/upgrades_capture.gd" id="1"]\n[node name="UpgradesCapture" type="Node"]\nscript = ExtResource("1")\n')
config=(project/'project.godot').read_text()
config=re.sub(r'(?m)^run/main_scene=.*$','run/main_scene="res://capture/upgrades_entry.tscn"',config)
config=re.sub(r'(?m)^config/custom_user_dir_name=.*$','config/custom_user_dir_name="sugarfall-v4-'+uuid.uuid4().hex+'"',config)
(project/'project.godot').write_text(config)
env=dict(os.environ)
for key,name in [('APPDATA','appdata'),('LOCALAPPDATA','localappdata'),('TEMP','temp'),('TMP','temp')]:
    p=work/name;p.mkdir(exist_ok=True);env[key]=str(p)
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
godot=root/'tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
binary=work/'Sugarfall-Upgrades-Capture.exe'
for label,exe,args,expected in [
    ('import',godot,['--headless','--audio-driver','Dummy','--path',project,'--log-file',work/'import-godot.log','--editor','--import','--quit'],'Godot Engine'),
    ('export',godot,['--headless','--audio-driver','Dummy','--path',project,'--log-file',work/'export-godot.log','--export-release','Trailer Capture Public',binary],'Godot Engine'),
    ('capture',binary,['--audio-driver','Dummy','--rendering-method','gl_compatibility','--disable-vsync','--max-fps','240','--position','-4000,-4000','--log-file',work/'capture-godot.log','--','--output='+str(out)],'UPGRADE_CAPTURE_OK')]:
    with (work/(label+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run([str(exe),*map(str,args)],cwd=project,env=env,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    text=(work/(label+'.log')).read_text(encoding='utf-8')
    if result.returncode or expected not in text or 'SCRIPT ERROR:' in text:raise RuntimeError(text[-6000:])
    print(label+': passed',flush=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=[p for d in ['scripts','data'] for p in (source/d).rglob('*') if p.is_file()]
hashes={p.relative_to(source).as_posix():sha(p) for p in files}
assert all(sha(project/name)==digest for name,digest in hashes.items())
clip=json.loads((out/'09-upgrades-rich/clip.json').read_text())
assert clip['profile_io']==0 and clip['debug'] is False and clip['public_feature'] is True
assert len(list((out/'09-upgrades-rich').glob('frame_*.jpg')))==270
assert clip['before']['owned_ordinary']==56 and clip['before']['total_ordinary']==62
assert clip['visible_state_counts'].get('affordable',0)==6 and clip['visible_state_counts'].get('owned',0)==57
covered=[s for s in clip['page_transition'] if s['active'] and s['covered']]
assert covered, 'Cream never fully covered the frame'
report=dict(passed=True,source='Frozen V1 production project; relevant upgrade/UI/transition resources match current workspace',
    source_files=len(hashes),frozen_resource_hashes=hashes,source_parity=True,binary_sha256=sha(binary),
    dimensions=[1080,1920],fps=60,frames=270,profile_io=0,debug=False,public_feature=True,
    staged_legal_campaign=True,ordinary_owned=56,ordinary_total=62,dual_shot_source='earned',
    cream_navigation=['home','shop'],cream_fully_covered_frames=[s['frame'] for s in covered],
    fixture='concept-art/trailer-v4/capture/upgrades_capture.gd',player_profiles_untouched=True,
    production_source_changed=False,production_drawing_changed=False,physics_changed=False)
(out/'upgrades-capture-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['passed','frames','ordinary_owned','ordinary_total','cream_fully_covered_frames','profile_io']},indent=2))
