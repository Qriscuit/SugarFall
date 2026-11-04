"""Fresh current-source, isolated public renderer motion capture; no player saves."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'PLINKO'
WORK=ROOT/'verification/trailer-v1-20261104/capture/run-01'
OUT=ROOT/'outputs/trailer-v1-20261104/gameplay'
GODOT=ROOT/'tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
assert not WORK.exists(), 'Use a new isolated work folder for another run'
PROJECT=WORK/'project';PROJECT.mkdir(parents=True);OUT.mkdir(parents=True,exist_ok=True)
env=dict(os.environ)
for key,folder in [('APPDATA','appdata'),('LOCALAPPDATA','localappdata'),('TEMP','temp'),('TMP','temp')]:
    env[key]=str(WORK/folder);(WORK/folder).mkdir(exist_ok=True)
namespace='sugarfall-trailer-capture-'+uuid.uuid4().hex
paths=[p for folder in ['scripts','data'] for p in (SOURCE/folder).rglob('*') if p.is_file()]
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
hashes={p.relative_to(SOURCE).as_posix():digest(p) for p in paths}
for folder in ['scripts','data']:shutil.copytree(SOURCE/folder,PROJECT/folder)
for f in ['project.godot','main.tscn','startup.tscn']:shutil.copy2(SOURCE/f,PROJECT/f)
shutil.copytree(SOURCE/'.godot/imported',PROJECT/'.godot/imported')
(PROJECT/'capture').mkdir()
shutil.copy2(Path(__file__).with_name('trailer_capture.gd'),PROJECT/'capture/trailer_capture.gd')
(PROJECT/'capture/entry.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://capture/trailer_capture.gd" id="1"]\n[node name="TrailerCapture" type="Node"]\nscript = ExtResource("1")\n')
config=(PROJECT/'project.godot').read_text()
config=re.sub(r'(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\n?','',config)
config=config.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+namespace+'"')
config=re.sub(r'(?m)^run/main_scene=.*$','run/main_scene="res://capture/entry.tscn"',config)
(PROJECT/'project.godot').write_text(config)
(PROJECT/'export_presets.cfg').write_text('''[preset.0]
name="Trailer Capture Public"
platform="Windows Desktop"
runnable=true
custom_features="sugarfall_public"
export_filter="all_resources"
include_filter="data/*.json,data/art/*/regions.json,data/art/gelato/*/regions.json,data/art/crystal/*/regions.json,data/art/branding/studio_boot.png"
exclude_filter="builds/*,docs/*,qa/*,verification/*"
export_path=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
debug/export_console_wrapper=2
application/modify_resources=true
application/product_name="Sugarfall Trailer Capture"
''')

def run(label,exe,args,expected,timeout=300):
    startup=subprocess.STARTUPINFO()
    startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow=0
    with (WORK/(label+'.log')).open('w',encoding='utf-8') as log:
        p=subprocess.run([str(exe),*map(str,args)],cwd=PROJECT,env=env,stdout=log,stderr=subprocess.STDOUT,
                         timeout=timeout,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW)
    text=(WORK/(label+'.log')).read_text()
    if p.returncode or expected not in text or 'SCRIPT ERROR:' in text:
        raise RuntimeError(label+' failed; see '+str(WORK/(label+'.log'))+'\n'+text[-6000:])
    print(label+': passed',flush=True)

run('import',GODOT,['--headless','--audio-driver','Dummy','--path',PROJECT,'--log-file',WORK/'godot-import.log','--editor','--import','--quit'],'Godot Engine')
BINARY=WORK/'Sugarfall-Trailer-Capture.exe'
run('export',GODOT,['--headless','--audio-driver','Dummy','--path',PROJECT,'--log-file',WORK/'godot-export.log','--export-release','Trailer Capture Public',BINARY],'Godot Engine')
run('probe',BINARY,['--headless','--audio-driver','Dummy','--log-file',WORK/'godot-probe.log','--','--output-dir='+str(OUT),'--probe'],'TRAILER_PROBE_OK',300)
run('capture',BINARY,['--audio-driver','Dummy','--rendering-method','gl_compatibility','--disable-vsync','--max-fps','240',
                      '--position','-4000,-4000','--log-file',WORK/'godot-capture.log','--','--output-dir='+str(OUT)],'TRAILER_CAPTURE_OK',1800)
report=json.loads((OUT/'capture-report.json').read_text())
for clip in report['clips']:
    frames=list((OUT/clip['name']).glob('frame_*.jpg'))
    assert len(frames)==clip['frames'],clip['name']
    assert (OUT/clip['name']/'frame_00000.jpg').is_file()
assert all(digest(SOURCE/f)==h==digest(PROJECT/f) for f,h in hashes.items())
evidence=dict(source_revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              source_files=len(hashes),source_parity=True,runtime_hashes=hashes,binary_sha256=digest(BINARY),
              source_modified=False,android_device_capture=False,profile_io=report['profile_io'])
(OUT/'source-evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
print('TRAILER_MOTION_COMPLETE '+str(OUT),flush=True)
