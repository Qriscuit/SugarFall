import hashlib,json,os,re,shutil,subprocess,uuid
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'PLINKO/project.godot').is_file())
SOURCE=ROOT/'PLINKO'
WORK=ROOT/'verification/storefront-20261105/capture-01'
OUT=ROOT/'outputs/storefront-20261105/screenshots'
GODOT=ROOT/'tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
assert not WORK.exists()
PROJECT=WORK/'project';PROJECT.mkdir(parents=True);OUT.mkdir(parents=True,exist_ok=True)
env=dict(os.environ)
for key,folder in [('APPDATA','appdata'),('LOCALAPPDATA','localappdata'),('TEMP','temp'),('TMP','temp')]:
    env[key]=str(WORK/folder);(WORK/folder).mkdir(exist_ok=True)
namespace='sugarfall-store-capture-'+uuid.uuid4().hex
paths=[p for folder in ['scripts','data'] for p in (SOURCE/folder).rglob('*') if p.is_file()]
hashes={p.relative_to(SOURCE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
for folder in ['scripts','data']:shutil.copytree(SOURCE/folder,PROJECT/folder)
for f in ['project.godot','main.tscn','startup.tscn']:shutil.copy2(SOURCE/f,PROJECT/f)
shutil.copytree(SOURCE/'.godot/imported',PROJECT/'.godot/imported')
(PROJECT/'capture').mkdir();shutil.copy2(Path(__file__).with_name('store_capture.gd'),PROJECT/'capture/store_capture.gd')
(PROJECT/'capture/entry.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://capture/store_capture.gd" id="1"]\n[node name="StoreCapture" type="Node"]\nscript = ExtResource("1")\n')
config=(PROJECT/'project.godot').read_text()
config=re.sub(r'(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\n?','',config)
config=config.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+namespace+'"')
config=re.sub(r'(?m)^run/main_scene=.*$','run/main_scene="res://capture/entry.tscn"',config)
(PROJECT/'project.godot').write_text(config)
(PROJECT/'export_presets.cfg').write_text('''[preset.0]
name="Store Capture Public"
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
application/product_name="Sugarfall Store Capture"
''')
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
def run(label,exe,args,expected,timeout=300):
    with (WORK/(label+'.log')).open('w',encoding='utf-8') as log:
        p=subprocess.run([str(exe),*map(str,args)],cwd=PROJECT,env=env,startupinfo=startup,stdout=log,stderr=subprocess.STDOUT,timeout=timeout,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    text=(WORK/(label+'.log')).read_text()
    if p.returncode or expected not in text or 'SCRIPT ERROR:' in text:raise RuntimeError(label+' failed; see log')
    print(label+':passed',flush=True)
run('import',GODOT,['--headless','--audio-driver','Dummy','--path',PROJECT,'--log-file',WORK/'import-godot.log','--editor','--import','--quit'],'Godot Engine')
BINARY=WORK/'Sugarfall-Store-Capture.exe'
run('export',GODOT,['--headless','--audio-driver','Dummy','--path',PROJECT,'--log-file',WORK/'export-godot.log','--export-release','Store Capture Public',BINARY],'Godot Engine')
run('capture',BINARY,['--audio-driver','Dummy','--rendering-method','gl_compatibility','--position','-4000,-4000','--log-file',WORK/'capture-godot.log','--','--output-dir='+str(OUT)],'STOREFRONT_CAPTURE_OK',300)
for name in ['01-bakery-gameplay','02-gelato-aim','03-crystal-prism','04-gelato-upgrades','05-bakery-jam','06-gelato-twins','07-crystal-multiply']:
    if not (OUT/(name+'.png')).is_file():raise RuntimeError('Missing saved capture: '+name)
assert all(hashlib.sha256((SOURCE/f).read_bytes()).hexdigest()==h==hashlib.sha256((PROJECT/f).read_bytes()).hexdigest() for f,h in hashes.items())
evidence={'source_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_working_tree':True,'source_files':len(hashes),'source_parity':True,'runtime_hashes':hashes,'binary_sha256':hashlib.sha256(BINARY.read_bytes()).hexdigest(),'source_modified':False,'android_device_capture':False,'fixture_sha256':hashlib.sha256((PROJECT/'capture/store_capture.gd').read_bytes()).hexdigest(),'fixture_path':'verification/storefront-20261105/store_capture.gd','production_resource_scope':['scripts','data'],'isolated_profiles':True}
evidence['fixture_path']=Path(__file__).with_name('store_capture.gd').relative_to(ROOT).as_posix()
(OUT/'source-evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
print('Fresh capture output: '+str(OUT))
