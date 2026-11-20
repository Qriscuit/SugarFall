"""Exercise developer and public policy in real debug and nondebug Windows exports.

This disposable harness sets an isolated entry scene, user directory and export presets.
It never reads a signing key or the normal player's profile.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    source=args.project.resolve();out=args.output.resolve();engine=args.godot.resolve()
    if out.exists():raise SystemExit('Use a new output directory.')
    project=out/'project';project.mkdir(parents=True)
    (out/'.gdignore').write_text('')
    env=dict(os.environ)
    for variable,folder in [('APPDATA','appdata'),('LOCALAPPDATA','localappdata'),('TEMP','temp'),('TMP','temp')]:
        env[variable]=str(out/folder);(out/folder).mkdir(exist_ok=True)
    namespace='sugarfall-public-qa-'+uuid.uuid4().hex
    # Native wrappers are dynamically loaded on Android, but their scripts and
    # editor/export dependencies must also be present during desktop import.
    copied_folders=['scripts','data','addons']
    files=[path for folder in copied_folders for path in (source/folder).rglob('*') if path.is_file()]
    files += [source/'main.tscn',source/'startup.tscn',source/'tests/public_release_qa.gd']
    hashes={path.relative_to(source).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    for item in copied_folders:shutil.copytree(source/item,project/item)
    for item in ['project.godot','main.tscn','startup.tscn']:shutil.copy2(source/item,project/item)
    if (source/'.godot/imported').is_dir():shutil.copytree(source/'.godot/imported',project/'.godot/imported')
    (project/'tests').mkdir()
    shutil.copy2(source/'tests/public_release_qa.gd',project/'tests/public_release_qa.gd')
    (project/'tests/public_release_entry.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/public_release_qa.gd" id="1"]\n[node name="PublicReleaseQA" type="Node"]\nscript = ExtResource("1")\n')
    configuration=(project/'project.godot').read_text(encoding='utf-8')
    configuration=re.sub(r'(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\n?','',configuration)
    configuration=configuration.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+namespace+'"')
    configuration=re.sub(r'(?m)^run/main_scene=.*$','run/main_scene="res://tests/public_release_entry.tscn"',configuration)
    (project/'project.godot').write_text(configuration,encoding='utf-8')
    public_preset='''[preset.0]
name="Public QA Windows"
platform="Windows Desktop"
runnable=true
custom_features="sugarfall_public"
export_filter="all_resources"
include_filter="data/*.json,data/art/*/regions.json,data/art/gelato/*/regions.json,data/art/crystal/*/regions.json,data/art/branding/studio_boot.png"
exclude_filter="builds/*,docs/*,qa/*,verification/*,addons/admob/gdscript/sample/*,addons/admob/assets/music.ogg"
export_path=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
debug/export_console_wrapper=2
application/modify_resources=true
application/product_name="Sugarfall Public Capability QA"
'''
    legacy_preset=public_preset.replace('[preset.0', '[preset.1').replace(
        'name="Public QA Windows"', 'name="Legacy Developer QA Windows"'
    ).replace('runnable=true', 'runnable=false').replace(
        'custom_features="sugarfall_public"', 'custom_features="developer"'
    )
    (project/'export_presets.cfg').write_text(public_preset+'\n'+legacy_preset,encoding='utf-8')
    probe=out/'isolation.gd'
    probe.write_text('extends SceneTree\nfunc _initialize():\n\tprint("PUBLIC_QA_USER_DIR=",OS.get_user_data_dir())\n\tquit()\n')
    results=[]
    def run(name,program,arguments,expected):
        started=time.monotonic()
        process=subprocess.run([str(program),*map(str,arguments)],cwd=project,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        text=process.stdout+process.stderr
        (out/(name+'.log')).write_text(text,encoding='utf-8')
        clean=re.sub(r'(?m)^ERROR: Failed to read the root certificate store\.\r?\n','',text)
        valid=process.returncode==0 and re.search(expected,text) and not re.search(r'(?m)SCRIPT ERROR:|^ERROR:|^FAIL:',clean)
        results.append({'name':name,'passed':bool(valid),'exit_code':process.returncode,'log':name+'.log',
            'program':str(program),'arguments':list(map(str,arguments)),'seconds':round(time.monotonic()-started,2)})
        (out/'processes.json').write_text(json.dumps(results,indent=2)+'\n')
        if not valid:raise RuntimeError(name+' failed; inspect '+str(out/(name+'.log')))
        print(name+': passed',flush=True)
        return text
    base=['--headless','--audio-driver','Dummy','--path',project]
    text=run('isolation',engine,base+['--script',probe],r'PUBLIC_QA_USER_DIR=')
    user=Path(re.search(r'PUBLIC_QA_USER_DIR=(.+)',text)[1].strip()).resolve()
    assert user==(Path(env['APPDATA'])/namespace).resolve(),'Actual profile path is not disposable.'
    run('import',engine,base+['--editor','--import','--quit'],r'Godot Engine')
    preview=run('preview-policy',engine,base,r'PUBLIC_RELEASE_QA_RESULT passed=\d+ failed=0 debug=true public=false')
    debug_binary=out/'Sugarfall-Public-QA-debug.exe'
    run('export-debug',engine,base+['--export-debug','Public QA Windows',debug_binary],r'Godot Engine')
    debug_public=run('debug-public-policy',debug_binary,['--headless','--audio-driver','Dummy','--','--expect-public-debug'],r'PUBLIC_RELEASE_QA_RESULT passed=\d+ failed=0 debug=true public=true')
    binary=out/'Sugarfall-Public-QA.exe'
    run('export-nondebug',engine,base+['--export-release','Public QA Windows',binary],r'Godot Engine')
    release=run('release-policy',binary,['--headless','--audio-driver','Dummy','--','--expect-release'],r'PUBLIC_RELEASE_QA_RESULT passed=\d+ failed=0 debug=false public=true')
    legacy_binary=out/'Sugarfall-Legacy-Developer-QA.exe'
    run('export-legacy-debug',engine,base+['--export-debug','Legacy Developer QA Windows',legacy_binary],r'Godot Engine')
    legacy_args=['--headless','--audio-driver','Dummy','--','--expect-legacy-player']
    legacy_expected=r'PUBLIC_RELEASE_QA_RESULT passed=\d+ failed=0 debug=true public=false'
    legacy_self_test=run('legacy-player-self-test',legacy_binary,legacy_args+['--self-test'],legacy_expected)
    legacy_capture=run('legacy-player-capture',legacy_binary,legacy_args+['--capture'],legacy_expected)
    parity=all(hashlib.sha256((source/path).read_bytes()).hexdigest()==digest==hashlib.sha256((project/path).read_bytes()).hexdigest() for path,digest in hashes.items())
    assert parity,'Source changed during public QA.'
    policy_runs=[
        ('preview',preview),('debug_public',debug_public),('nondebug_public',release),
        ('legacy_player_self_test',legacy_self_test),('legacy_player_capture',legacy_capture),
    ]
    counts={name:int(re.search(r'QA_RESULT passed=(\d+)',text)[1]) for name,text in policy_runs}
    report={'passed':True,'counts':counts,'failures':0,'actual_user_directory':str(user),'source_hashes':hashes,'source_parity':True,
        'harness_only_changes':['Entry scene','Unique disposable custom user directory','Windows QA presets with sugarfall_public and legacy developer features'],
        'debug_binary_sha256':hashlib.sha256(debug_binary.read_bytes()).hexdigest(),
        'nondebug_binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),
        'legacy_debug_binary_sha256':hashlib.sha256(legacy_binary.read_bytes()).hexdigest(),
        'runner_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'source_project_sha256':hashlib.sha256((source/'project.godot').read_bytes()).hexdigest(),
        'processes':results,'android_execution':False,'phone_verified':False}
    (out/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':True,'counts':counts,'source_inputs':len(hashes),'output':str(out)}),flush=True)


if __name__=='__main__':main()
