"""Read-only signed Sugarfall APK/AAB verification using public build tools.

No signing key or password is accepted. Python's standard library checks payloads,
ELF load alignment and JAR entry digests; Android/JDK/bundletool verify signatures
and metadata. A frozen source manifest links the audit to the export inputs.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile

CERTIFICATE='e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29'
FORBIDDEN=re.compile(r'(?i)(?:^|/)(?:tests|tools|verification|docs|related_materials|concept-art|qa|report|builds|private|\.qa_data|\.git|\.aws)(?:/|$)|\.(?:keystore|jks|pfx|p12|pem|key)$|(?:^|/)(?:\.env(?:\.[^/]*)?|credentials(?:\.[^/]*)?|signing[-.]credentials(?:\.[^/]*)?|signing\.properties)$')
AUTHORING_METADATA=re.compile(r'(?i)(?:^|/)data/(?:art/(?:.*/)?(?:sources\.json|README\.txt|palette-refresh-sources\.json)|audio/.*\.provenance\.json)$')


def sha(data): return hashlib.sha256(data).hexdigest()
def read_json(path):return json.loads(path.read_text(encoding='utf-8-sig'))


def elf_loads(data):
    if data[:6]!=b'\x7fELF\x02\x01': raise ValueError('Expected little-endian ELF64')
    if struct.unpack_from('<H',data,18)[0]!=183: raise ValueError('Expected AArch64 ELF')
    offset=struct.unpack_from('<Q',data,32)[0]
    stride,count=struct.unpack_from('<HH',data,54)
    result=[]
    for index in range(count):
        kind,_flags,position,address,_physical,size,memory,alignment=struct.unpack_from('<IIQQQQQQ',data,offset+index*stride)
        if kind==1:result.append({'offset':position,'address':address,'size':size,'memory_size':memory,'alignment':alignment})
    return result


def config_values(data):
    if data[:4]!=b'ECFG':raise ValueError('Expected Godot ECFG')
    position=8;result={}
    for _ in range(struct.unpack_from('<I',data,4)[0]):
        length=struct.unpack_from('<I',data,position)[0];position+=4
        key=data[position:position+length].decode();position+=length
        length=struct.unpack_from('<I',data,position)[0];position+=4
        value=data[position:position+length];position+=length
        kind=struct.unpack_from('<I',value)[0]&0xffff
        if kind==4:result[key]=value[8:8+struct.unpack_from('<I',value,4)[0]].decode()
        elif kind==1:result[key]=bool(struct.unpack_from('<I',value,4)[0])
        elif kind==2:result[key]=struct.unpack_from('<q' if len(value)>=12 else '<i',value,4)[0]
        elif kind==20:result[key]=list(struct.unpack_from('<4f',value,4))
    return result


def xml_manifest(text):
    match=re.search(r'<manifest\b.*</manifest>',text,re.S)
    if not match:raise ValueError('No manifest XML returned by bundletool')
    return ET.fromstring(match[0])


def sparse_pack_entries(data):
    """Parse the pinned Godot4.6.3 standalone sparse-PCK v3 directory.

    Format: godotengine/godot 4.6.3-stable core/io/file_access_pack.cpp
    PackedSourcePCK::try_open_pack and editor/export/editor_export_platform.cpp
    _store_header/_encrypt_and_store_directory. Directory order is not semantic;
    every path, offset, size, MD5 and flag remains part of the comparison.
    """
    expected_header=(0x43504447,3,4,6,3,6,0,104)
    if len(data)<108 or struct.unpack_from('<6I2Q',data,0)!=expected_header:
        raise ValueError('Expected unencrypted Godot4.6.3 sparse-PCK v3 header')
    if any(data[40:104]):raise ValueError('Unexpected sparse-PCK reserved header data')
    count=struct.unpack_from('<I',data,104)[0]
    if count>(len(data)-108)//44:raise ValueError('Impossible sparse-PCK record count')
    position=108;entries={}
    for _ in range(count):
        if position+4>len(data):raise ValueError('Truncated sparse-PCK path length')
        length=struct.unpack_from('<I',data,position)[0];position+=4
        if not length or length%4 or length>4096 or position+length+36>len(data):
            raise ValueError('Invalid or truncated sparse-PCK record')
        padded=data[position:position+length];position+=length
        name=padded.rstrip(b'\0')
        if len(padded)-len(name)>3 or b'\0' in name:
            raise ValueError('Invalid sparse-PCK path padding')
        try:path=name.decode('utf-8')
        except UnicodeDecodeError as error:raise ValueError('Invalid sparse-PCK UTF8 path') from error
        pure=PurePosixPath(path)
        if not path or path!=pure.as_posix() or pure.is_absolute() or '..' in pure.parts or ':' in path or '\\' in path:
            raise ValueError('Unsafe sparse-PCK path')
        if path in entries:raise ValueError('Duplicate sparse-PCK path: '+path)
        offset,size=struct.unpack_from('<2Q',data,position);position+=16
        digest=data[position:position+16].hex();position+=16
        flags=struct.unpack_from('<I',data,position)[0];position+=4
        if offset or flags:raise ValueError('Unsupported sparse-PCK offset or file flags')
        entries[path]={'offset':offset,'size':size,'md5':digest,'flags':flags}
    if position!=len(data):raise ValueError('Unexpected sparse-PCK trailing content')
    return {'header':list(expected_header),'entries':entries}


def sparse_payload_errors(index,names,read_payload):
    """Prove the index covers exactly the external payload and hashes each file."""
    # Android writes _cl_ after export_project_files; it is platform launcher
    # metadata, outside the sparse index. It still gets exact cross-artifact
    # byte comparison below (export_plugin.cpp, assets/_cl_ write).
    expected=set(index['entries']);actual=set(names)-{'assets.sparsepck','_cl_'}
    errors=[]
    if expected!=actual:
        errors.append({'missing_payload':sorted(expected-actual),'unindexed_payload':sorted(actual-expected)})
    for path in sorted(expected&actual):
        data=read_payload(path);entry=index['entries'][path]
        if len(data)!=entry['size'] or hashlib.md5(data).hexdigest()!=entry['md5']:
            errors.append({'payload_hash_or_size_mismatch':path})
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    for name in ['apk','aab','output','build-tools','java-home','bundletool-classpath-file','source-manifest','release-template']:
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--version-name',required=True)
    parser.add_argument('--version-code',type=int,required=True)
    parser.add_argument('--package',default='com.qriscuit.sugarfall')
    parser.add_argument('--certificate',default=CERTIFICATE)
    parser.add_argument('--min-sdk',type=int,default=24)
    parser.add_argument('--target-sdk',type=int,default=36)
    args=parser.parse_args()
    project=args.project.resolve();out=args.output.resolve()
    if out.exists():raise SystemExit('Use a new verification output directory.')
    out.mkdir(parents=True)
    checks=[];commands=[]
    def check(name,passed,details=None):
        checks.append({'check':name,'passed':bool(passed),'details':details})
    def run(name,program,arguments):
        p=subprocess.run([str(program),*map(str,arguments)],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        text=p.stdout+p.stderr;(out/(name+'.txt')).write_text(text,encoding='utf-8')
        commands.append({'name':name,'program':str(program),'arguments':list(map(str,arguments)),'exit_code':p.returncode,'log':name+'.txt','log_sha256':sha(text.encode())})
        check('Tool exits successfully: '+name,p.returncode==0,p.returncode)
        return text
    original={name:{'path':str(path.resolve()),'bytes':path.stat().st_size,'sha256':sha(path.read_bytes())} for name,path in [('apk',args.apk),('aab',args.aab)]}
    frozen=read_json(args.source_manifest)
    if isinstance(frozen,list):frozen={item['path']:item['sha256'] for item in frozen}
    if 'files' in frozen and isinstance(frozen['files'],list):frozen={item['path']:item['sha256'] for item in frozen['files']}
    frozen={path.removeprefix('res://'):digest for path,digest in frozen.items()}
    invalid=[path for path in frozen if Path(path).is_absolute() or '..' in Path(path).parts or not isinstance(frozen[path],str)]
    check('Frozen input manifest uses safe project-relative paths',not invalid,invalid)
    if invalid:raise ValueError('Unsafe source manifest paths')
    expected_scripts={path.relative_to(project).as_posix() for path in (project/'scripts').glob('*.gd')}
    check('Frozen source manifest covers every runtime script',expected_scripts<=set(frozen),sorted(expected_scripts-set(frozen)))
    changed=[path for path,digest in frozen.items() if not (project/path).is_file() or sha((project/path).read_bytes())!=digest]
    check('Frozen export inputs match current source before audit',not changed,changed)
    java=args.java_home/'bin/java.exe';tools=args.build_tools
    badging=run('apk-badging',tools/'aapt.exe',['dump','badging',args.apk])
    apk_manifest=run('apk-manifest',tools/'aapt.exe',['dump','xmltree',args.apk,'AndroidManifest.xml'])
    extracted_native=bool(re.search(r'android:extractNativeLibs[^\n]*=\(type 0x12\)0xffffffff',apk_manifest))
    signature=run('apk-signature',java,['-jar',tools/'lib/apksigner.jar','verify','--verbose','--print-certs',args.apk])
    alignment=run('apk-alignment',tools/'zipalign.exe',['-c','-P','16','-v','4',args.apk])
    package=re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",badging,re.M)
    check('APK identity and version',package and package[1]==args.package and package[2]==str(args.version_code) and package[3]==args.version_name,list(package.groups()) if package else None)
    labels=re.findall(r"^application-label(?:-[^:]+)?:'([^']+)'$",badging,re.M)
    check('All APK localized labels are Sugarfall',bool(labels) and set(labels)=={'Sugarfall'},sorted(set(labels)))
    check('APK minimum and target SDK',f"sdkVersion:'{args.min_sdk}'" in badging and f"targetSdkVersion:'{args.target_sdk}'" in badging)
    check('APK is nondebug', 'application-debuggable' not in badging)
    check('APK ARM64 only',re.findall(r'^native-code: (.+)$',badging,re.M)==["'arm64-v8a'"])
    check('APK requests no permissions',not re.findall(r'^uses-permission[^:]*:',badging,re.M))
    signer=re.search(r'Signer #1 certificate SHA-256 digest: (\w+)',signature)
    check('APK expected single release certificate',signer and signer[1].lower()==args.certificate.lower() and 'Number of signers: 1' in signature,signer[1] if signer else None)
    check('APK v2 and v3 cryptographic signatures verify',all(f'Verified using v{version} scheme (APK Signature Scheme v{version}): true' in signature for version in [2,3]))
    check('APK zipalign validates 16KiB native and four-byte boundaries','Verification successful' in alignment and 'BAD' not in alignment)
    classpath_text=args.bundletool_classpath_file.read_text(encoding='utf-8-sig').strip()
    classpath=json.loads(classpath_text) if classpath_text.startswith('[') else [line for line in classpath_text.splitlines() if line.strip()]
    if len(classpath)==1 and ';' in classpath[0]:classpath=classpath[0].split(';')
    if not classpath or not all(Path(path).is_file() for path in classpath):raise ValueError('Bundletool classpath must list existing public JARs')
    def bundle(name,arguments):
        def quote(value):return '"'+str(value).replace('\\','/').replace('"','\\"')+'"'
        argument_file=out/(name+'-args.txt')
        argument_file.write_text('\n'.join(['-cp',quote(os.pathsep.join(classpath)),'com.android.tools.build.bundletool.BundleToolMain',*map(quote,arguments)])+'\n',encoding='utf-8')
        return run(name,java,['@'+str(argument_file)])
    validation=bundle('aab-validate',['validate','--bundle='+str(args.aab.resolve())])
    manifest=bundle('aab-manifest',['dump','manifest','--bundle='+str(args.aab.resolve()),'--module=base'])
    config_text=bundle('aab-config',['dump','config','--bundle='+str(args.aab.resolve())])
    jar=run('aab-signature',args.java_home/'bin/jarsigner.exe',['-verify','-verbose','-certs',args.aab])
    certificate=run('aab-certificate',args.java_home/'bin/keytool.exe',['-printcert','-jarfile',args.aab])
    check('Bundletool accepts AAB structure','App Bundle information' in validation and not re.search(r'(?m)^(?:Error:|Exception in thread|\[BT:.*Error:)',validation))
    check('AAB cryptographic JAR verification','jar verified.' in jar and 'jar is unsigned' not in jar)
    cert=re.search(r'SHA256:\s*([0-9A-F:]+)',certificate)
    check('AAB expected release certificate',cert and cert[1].replace(':','').lower()==args.certificate.lower(),cert[1] if cert else None)
    xml=xml_manifest(manifest);android='{http://schemas.android.com/apk/res/android}'
    sdk=xml.find('uses-sdk');app=xml.find('application')
    check('AAB identity and version',xml.get('package')==args.package and xml.get(android+'versionCode')==str(args.version_code) and xml.get(android+'versionName')==args.version_name)
    check('AAB minimum and target SDK',sdk is not None and sdk.get(android+'minSdkVersion')==str(args.min_sdk) and sdk.get(android+'targetSdkVersion')==str(args.target_sdk))
    check('AAB is nondebug',app is not None and app.get(android+'debuggable','false')=='false')
    check('AAB requests no permissions',not any(item.tag.startswith('uses-permission') for item in xml))
    config=json.loads(config_text[config_text.index('{'):config_text.rindex('}')+1])
    native_delivery=config.get('optimizations',{}).get('uncompressNativeLibraries',{})
    check('AAB requests 16KiB alignment for delivered native libraries',native_delivery.get('enabled') is True and native_delivery.get('alignment')=='PAGE_ALIGNMENT_16K')
    imports=[];scripts=[];native=[]
    with zipfile.ZipFile(args.apk) as apk,zipfile.ZipFile(args.aab) as aab,zipfile.ZipFile(args.release_template) as official:
        for label,archive in [('APK',apk),('AAB',aab)]:
            names=archive.namelist()
            check(label+' ZIP integrity and unique paths',archive.testzip() is None and len(names)==len(set(names)))
            forbidden=[name for name in names if FORBIDDEN.search(name)]
            check(label+' excludes development, private and credential files',not forbidden,forbidden)
            profiles=[name for name in names if re.search(r'(?i)(?:sugarfall|peg_foundry).*(?:save|profile|areas).*\.json$',name)]
            check(label+' excludes player profiles',not profiles,profiles)
            provenance=[name for name in names if AUTHORING_METADATA.search(name)]
            check(label+' excludes art/audio authoring provenance and inventory',not provenance and not any(name.endswith('/FILE_INVENTORY.json') for name in names),provenance)
        entries=set(apk.namelist())
        for relative in sorted(expected_scripts):
            compiled='assets/'+relative[:-3]+'.gdc';remap='assets/'+relative+'.remap'
            valid=compiled in entries and remap in entries and apk.read(compiled).startswith(b'GDSC') and ('res://'+relative[:-3]+'.gdc') in apk.read(remap).decode()
            check('Compiled runtime/remap: '+relative,valid)
            scripts.append({'source':relative,'source_sha256':sha((project/relative).read_bytes()),'compiled_entry':compiled,'compiled_sha256':sha(apk.read(compiled)) if compiled in entries else None})
        check('Exactly the current compiled runtime inventory is packaged',{name for name in entries if name.endswith('.gdc')}=={item['compiled_entry'] for item in scripts})
        for name in sorted(entries):
            if name.startswith('assets/data/') and not name.endswith(('.import','/')):
                source=project/name.removeprefix('assets/')
                if source.is_file():check('Packaged raw source: '+name,apk.read(name)==source.read_bytes())
            if name.startswith('assets/') and name.endswith('.import'):
                targets=re.findall(r'^path(?:\.[^=]+)?="res://([^\"]+)"',apk.read(name).decode().rstrip('\x00'),re.M)
                valid=bool(targets) and all('assets/'+target in entries and (project/target).is_file() and apk.read('assets/'+target)==(project/target).read_bytes() for target in targets)
                check('Imported resource current-byte parity: '+name,valid,targets)
                imports.append({'descriptor':name,'targets':targets})
            if name.startswith('assets/') and name.endswith('.remap'):
                targets=re.findall(r'^path="res://([^\"]+)"',apk.read(name).decode(),re.M)
                check('Resource remap resolves: '+name,bool(targets) and all('assets/'+target in entries for target in targets))
        required=[p.relative_to(project).as_posix() for p in (project/'data').glob('*.json')]+['data/licenses/GODOT_LICENSE.txt','data/licenses/GODOT_COPYRIGHT.txt','data/fonts/Fraunces-OFL.txt','data/fonts/Nunito-OFL.txt','data/art/branding/studio_boot.png']
        for relative in required:check('Required current data/license/boot payload: '+relative,'assets/'+relative in entries and apk.read('assets/'+relative)==(project/relative).read_bytes())
        for scene in ['main','startup']:check('Required production scene: '+scene,'assets/'+scene+'.tscn.remap' in entries)
        binary=apk.read('assets/project.binary');settings=config_values(binary)
        check('Public capability feature is packaged',b'sugarfall_public' in binary)
        check('Developer custom feature is absent',b'developer' not in binary)
        for key,value in {'application/config/name':'Sugarfall','application/config/use_custom_user_dir':True,'application/config/custom_user_dir_name':'Godot/app_userdata/Peg Foundry','application/run/main_scene':'res://startup.tscn','application/boot_splash/image':'res://data/art/branding/studio_boot.png','display/window/stretch/aspect':'expand'}.items():check('Packaged setting: '+key,settings.get(key)==value,settings.get(key))
        libraries={name for name in entries if name.startswith('lib/') and name.endswith('.so')}
        check('Native libraries match the official ARM64 release template',bool(libraries) and all(name.startswith('lib/arm64-v8a/') and name in official.namelist() and apk.read(name)==official.read(name) for name in libraries),sorted(libraries))
        raw=args.apk.read_bytes()
        for name in sorted(libraries):
            data=apk.read(name);segments=elf_loads(data)
            check('ELF PT_LOAD 16KiB alignment: '+name,bool(segments) and all(item['alignment']>=16384 and item['alignment']&(item['alignment']-1)==0 and (item['address']-item['offset'])%16384==0 for item in segments),segments)
            info=apk.getinfo(name);length,extra=struct.unpack_from('<HH',raw,info.header_offset+26)
            data_offset=info.header_offset+30+length+extra
            # The stock direct-APK template compresses native libraries and
            # explicitly extracts them at install. ZIP page alignment applies
            # to uncompressed in-place loading; ELF alignment applies to both.
            in_place=info.compress_type==zipfile.ZIP_STORED
            valid_zip=(data_offset%16384==0) if in_place else extracted_native
            check('APK native loading satisfies ZIP/extraction contract: '+name,valid_zip,{'data_offset':data_offset,'compression':info.compress_type,'extract_native_libs':extracted_native,'zip_page_alignment_applies':in_place})
            native.append({'entry':name,'sha256':sha(data),'segments':segments,'zip_data_offset':data_offset,'compression':info.compress_type,'zip_page_alignment_applies':in_place,'extract_native_libs':extracted_native})
        bundle_names=set(aab.namelist())
        asset_names=[name for name in bundle_names if '/assets/' in name and not name.endswith('/')]
        asset_map={name.split('/',1)[1]:name for name in asset_names}
        baseline={'assets/dexopt/baseline.prof','assets/dexopt/baseline.profm'}
        apk_assets={name for name in entries if name.startswith('assets/') and not name.endswith('/')}-baseline
        check('AAB game asset names unique and identical to APK',len(asset_names)==len(asset_map) and set(asset_map)==apk_assets,{'APK':len(apk_assets),'AAB':len(asset_map)})
        sparse_name='assets/assets.sparsepck'
        apk_index=sparse_pack_entries(apk.read(sparse_name))
        aab_index=sparse_pack_entries(aab.read(asset_map[sparse_name]))
        apk_payload={name.removeprefix('assets/'):name for name in apk_assets}
        aab_payload={name.removeprefix('assets/'):entry for name,entry in asset_map.items()}
        apk_index_errors=sparse_payload_errors(apk_index,apk_payload,lambda path:apk.read(apk_payload[path]))
        aab_index_errors=sparse_payload_errors(aab_index,aab_payload,lambda path:aab.read(aab_payload[path]))
        check('APK sparse index covers and hashes every project payload',not apk_index_errors,apk_index_errors)
        check('AAB sparse index covers and hashes every project payload',not aab_index_errors,aab_index_errors)
        check('Godot sparse-pack headers and all logical records match',apk_index==aab_index,{'APK_records':len(apk_index['entries']),'AAB_records':len(aab_index['entries'])})
        mismatches=[name for name in (apk_assets&set(asset_map))-{sparse_name} if apk.read(name)!=aab.read(asset_map[name])]
        check('Every actual AAB game payload byte matches APK',not mismatches,mismatches)
        sparse_proof={'format':'Godot4.6.3 sparse-PCK v3','entry_count':len(apk_index['entries']),
            'raw_directory_bytes_match':apk.read(sparse_name)==aab.read(asset_map[sparse_name]),
            'logical_records_match':apk_index==aab_index,'all_actual_payload_bytes_match':not mismatches,
            'apk_index_sha256':sha(apk.read(sparse_name)),'aab_index_sha256':sha(aab.read(asset_map[sparse_name])),
            'canonical_records_sha256':sha(json.dumps(apk_index,sort_keys=True,separators=(',',':')).encode()),
            'format_sources':['https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/file_access_pack.cpp',
                              'https://github.com/godotengine/godot/blob/4.6.3-stable/editor/export/editor_export_platform.cpp',
                              'https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp'],
            'note':'Directory record order may differ; headers and each unique path/offset/size/MD5/flags must agree, and every indexed external payload is verified in each artifact. Android launcher _cl_ is outside the project index but remains covered by exact cross-artifact byte parity.'}
        all_bundle_libs={name for name in bundle_names if '/lib/' in name and name.endswith('.so')}
        bundle_libs={name.removeprefix('base/'):name for name in all_bundle_libs if name.startswith('base/lib/')}
        check('AAB native release libraries match APK exactly',len(all_bundle_libs)==len(bundle_libs) and set(bundle_libs)==libraries and all(aab.read(bundle_libs[name])==apk.read(name) for name in libraries&set(bundle_libs)))
        icons={name for name in entries if name.startswith('res/mipmap') and name.endswith(('.webp','.png'))}
        check('All24 Sugarfall launcher bitmaps agree across artifacts',len(icons)==24 and all('base/'+name in bundle_names and aab.read('base/'+name)==apk.read(name) for name in icons))
        for module in sorted({name.split('/',1)[0] for name in asset_names}-{'base'}):
            text=bundle('aab-manifest-'+module,['dump','manifest','--bundle='+str(args.aab.resolve()),'--module='+module])
            asset_manifest=xml_manifest(text);dist='{http://schemas.android.com/apk/distribution}'
            check('Game asset module is install-time: '+module,asset_manifest.find('.//'+dist+'install-time') is not None and asset_manifest.find('.//'+dist+'on-demand') is None)
        jar_manifest=aab.read('META-INF/MANIFEST.MF').decode().replace('\r\n','\n');jar_manifest=re.sub(r'\n ','',jar_manifest)
        records={}
        for section in jar_manifest.split('\n\n'):
            fields=dict(line.split(': ',1) for line in section.splitlines() if ': ' in line)
            if 'Name' in fields:records[fields['Name']]=fields
        signature_metadata=re.compile(r'(?i)^META-INF/(?:MANIFEST\.MF|[^/]+\.(?:SF|RSA|DSA|EC)|SIG-[^/]+)$')
        content={name for name in bundle_names if not name.endswith('/') and not signature_metadata.match(name)}
        bad=[name for name in content if name not in records or records[name].get('SHA-256-Digest')!=base64.b64encode(hashlib.sha256(aab.read(name)).digest()).decode()]
        check('JAR signature digests cover every non-signature-metadata entry exactly',not bad,bad)
        check('AAB has one RSA signing block',len([name for name in bundle_names if name.startswith('META-INF/') and name.endswith('.RSA')])==1)
    changed=[path for path,digest in frozen.items() if sha((project/path).read_bytes())!=digest]
    check('Export input hashes remain unchanged after verification',not changed,changed)
    for label,path in [('apk',args.apk),('aab',args.aab)]:check(label.upper()+' remains unchanged during verification',sha(path.read_bytes())==original[label]['sha256'])
    report={'passed':all(item['passed'] for item in checks),'checks_passed':sum(item['passed'] for item in checks),'checks_total':len(checks),'checks':checks,'artifacts':original,'expected_identity':{'package':args.package,'version_code':args.version_code,'version_name':args.version_name,'certificate_sha256':args.certificate},'source_manifest_sha256':sha(args.source_manifest.read_bytes()),'frozen_source_inputs':frozen,'scripts':scripts,'imports':imports,'native_libraries':native,'sparse_pack_parity':sparse_proof,'commands':commands,
        'scope':'Static signed artifacts and export-input parity. Compiled-script inventory/remaps are checked, not decompiled back to source. No Play upload, phone/emulator execution or real purchase verification.',
        'phone_verified':False,'play_uploaded':False,'real_billing_verified':False}
    (out/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report[key] for key in ['passed','checks_passed','checks_total']}))
    for item in checks:
        if not item['passed']:print('FAIL:',item['check'],item['details'])
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
