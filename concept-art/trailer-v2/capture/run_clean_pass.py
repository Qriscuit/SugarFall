"""Supplemental draw-only frames from an isolated export of frozen V1 sources."""
import hashlib,json,os,re,shutil,subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[3]
work=root/'verification/mabel-rethink-20261104/clean-pass'
work.mkdir(parents=True,exist_ok=True)
output=root/'outputs/trailer-v2-20261104/gameplay/06-twin-clean'
output.mkdir(parents=True,exist_ok=True)
frozen=root/'verification/trailer-v1-20261104/capture/run-01'
script=Path(__file__).with_name('clean_pass.gd')
project=work/'project'
godot=root/'tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
if not project.exists():
    shutil.copytree(frozen/'project',project)
shutil.copy2(script,project/'capture/clean_pass.gd')
(project/'capture/clean_entry.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://capture/clean_pass.gd" id="1"]\n[node name="CleanDrawPass" type="Node"]\nscript = ExtResource("1")\n')
config=(project/'project.godot').read_text()
config=re.sub(r'(?m)^run/main_scene=.*$','run/main_scene="res://capture/clean_entry.tscn"',config)
(project/'project.godot').write_text(config)
binary=work/'Sugarfall-Clean-Pass.exe'
env=dict(os.environ)
for key,name in [('APPDATA','appdata'),('LOCALAPPDATA','localappdata'),('TEMP','temp'),('TMP','temp')]:
    path=work/name;path.mkdir(exist_ok=True);env[key]=str(path)
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
for label,args in [('import',['--headless','--audio-driver','Dummy','--path',str(project),'--log-file',str(work/'import-godot.log'),'--editor','--import','--quit']),
                   ('export',['--headless','--audio-driver','Dummy','--path',str(project),'--log-file',str(work/'export-godot.log'),'--export-release','Trailer Capture Public',str(binary)])]:
    with (work/(label+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run([str(godot),*args],cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW,check=True)
    print(label+': passed',flush=True)
binary_before=digest(binary)
with (work/'run.log').open('w',encoding='utf-8') as log:
    result=subprocess.run([str(binary),'--audio-driver','Dummy','--rendering-method','gl_compatibility',
        '--disable-vsync','--max-fps','240','--position','-4000,-4000','--log-file',str(work/'godot.log'),
        '--','--output='+str(output)],cwd=project,env=env,
        stdout=log,stderr=subprocess.STDOUT,timeout=600,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW)
text=(work/'run.log').read_text(encoding='utf-8')
if result.returncode or 'CLEAN_PASS_OK' not in text or 'SCRIPT ERROR:' in text:
    raise RuntimeError(text[-6000:])
assert digest(binary)==binary_before
report=json.loads((output/'clean-pass-report.json').read_text())
original=json.loads((root/'outputs/trailer-v1-20261104/gameplay/06-twin-growth/clip.json').read_text())
trace=json.loads((root/'outputs/mabel-rethink-20261104/twin-ball-trace.json').read_text())
assert report['profile_io']==0 and report['before']['balls']==10 and report['after']['balls']==31
assert report['before']['bank']==original['before']['bank']==report['after']['bank']
assert report['before']['levels']==original['before']['levels']==report['after']['levels']
assert report['min_balls']==original['min_balls'] and report['max_balls']==original['max_balls']
for stage in ['before','after']:
    for key in report[stage]:
        assert report[stage][key]==original[stage][key],(stage,key,report[stage][key],original[stage][key])
assert len(report['events'])==len(original['events'])
assert all(a['event']==b['event'] and a['area']==b['area'] and abs(a['time']-b['time'])<.00002 and a['options']==b['options'] for a,b in zip(report['events'],original['events']))
assert report['frames']==trace['frames']
expected={*range(225,234),*range(294,302),*range(321,327)}
actual={item['source_frame'] for item in report['changed_frames']}
assert actual==expected,(actual,expected)
validation=dict(passed=True,debug=report['debug'],public_feature=report['public_feature'],
    clean_capture_binary_sha256=binary_before,source_events_matched=len(original['events']),
    full_ball_states_matched_frames=420,physics_economy_and_progress_equal=True,profile_io=0,
    contact_inclusive=True,changed_frames=sorted(actual),
    ranges=[dict(id=1,first=225,last=233),dict(id=7,first=294,last=301),dict(id=15,first=321,last=326)],
    files=[dict(file=item['file'],source_frame=item['source_frame'],hidden_ids=item['hidden_ids'],sha256=digest(output/item['file'])) for item in report['changed_frames']])
(output/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
print(json.dumps({k:validation[k] for k in ['passed','debug','public_feature','source_events_matched','full_ball_states_matched_frames','profile_io','ranges']},indent=2))
subprocess.run([os.sys.executable,str(script.with_name('audit_clean_pass.py'))],cwd=root,check=True)
