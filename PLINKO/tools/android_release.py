"""Checked local Android release preparation. Never loads signing credentials.

Requires installed Python 3.10+, Godot 4.6.3 with its official templates,
JDK 21, Android SDK 36/build-tools 36.1.0/NDK 29.0.14206865 and accepted
SDK licenses. Setup may resolve Gradle dependencies; it does not install SDKs
or accept licenses. Use the adjacent PowerShell entrypoints on Windows.
"""
from __future__ import annotations
import argparse
import configparser
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

PROJECT = Path(__file__).resolve().parent.parent
ROOT = PROJECT.parent
SOURCE_SHA = 'c260fe8ab52ee0627d4d27a07117f7a7f04ce2a73cef7356a032fac0e1998009'
CERT_SHA = 'e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29'
PUBLIC_PACKAGE = 'com.sungati.sugarfall'
SECRET_PREFIXES = ('GODOT_ANDROID_KEYSTORE_RELEASE_', 'ORG_GRADLE_PROJECT_release_keystore_')
PRODUCTION_ADS_PATH = 'data/production_ads.json'
PREVIEW_ADS_PATH = 'data/preview_ads.json'
DEMO_AD_PUBLISHER = '3940256099942544'


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def validate_production_ads(payload):
    def unique_object(pairs):
        result = dict(pairs)
        if len(result) != len(pairs):
            raise ValueError('AdMob configuration contains duplicate JSON keys')
        return result

    def reject_constant(value):
        raise ValueError(f'Invalid JSON value in AdMob configuration: {value}')

    ads = json.loads(payload, object_pairs_hook=unique_object, parse_constant=reject_constant)
    if not isinstance(ads, dict) or ads.get('enabled') is not True or ads.get('use_test_ads') is not False:
        raise ValueError('Production ads require enabled=true and use_test_ads=false')
    if f'ca-app-pub-{DEMO_AD_PUBLISHER}' in json.dumps(ads):
        raise ValueError('Google demo inventory is reserved for preview builds')
    publishers = set()
    for field, separator in [('app_id', '~'), ('rewarded_unit_id', '/'), ('interstitial_unit_id', '/')]:
        value = ads.get(field)
        match = re.fullmatch(r'ca-app-pub-([0-9]{16})' + separator + r'[0-9]{10}', value) if isinstance(value, str) else None
        if match is None:
            raise ValueError(f'Enter a valid owner AdMob {field}')
        publishers.add(match[1])
    if len(publishers) != 1:
        raise ValueError('AdMob app and units must share an owner publisher ID')
    if ads['rewarded_unit_id'] == ads['interstitial_unit_id']:
        raise ValueError('Rewarded and interstitial ads require separate ad units')
    consent = ads.get('consent', {})
    if not isinstance(consent, dict):
        raise ValueError('AdMob consent configuration must be an object')
    if 'test_device_ids' in ads or {'test_device_hashed_ids', 'debug_geography'} & consent.keys():
        raise ValueError('Production ads cannot include test-device or consent-debug settings')
    if type(ads.get('muted', False)) is not bool or type(consent.get('tag_for_under_age_of_consent', False)) is not bool:
        raise ValueError('AdMob muted and consent age settings must be booleans')
    if ads.get('max_ad_content_rating', 'PG') not in ('G', 'PG', 'T', 'MA'):
        raise ValueError('AdMob maximum content rating must be G, PG, T, or MA')
    for field in ['tag_for_child_directed_treatment', 'tag_for_under_age_of_consent']:
        value = ads.get(field, -1)
        if type(value) not in (int, float) or value not in (-1, 0, 1):
            raise ValueError(f'AdMob {field} must be -1, 0, or 1')
    return ads


def preflight_production_ads(project):
    try:
        validate_production_ads((project / PRODUCTION_ADS_PATH).read_bytes())
    except (OSError, ValueError) as error:
        raise RuntimeError(f'Configure {PRODUCTION_ADS_PATH} before building a public release. {error}') from error


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else hashlib.sha256(stream.read()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def clean_environment(config):
    env = {k: v for k, v in os.environ.items() if not any(k.upper().startswith(p.upper()) for p in SECRET_PREFIXES)}
    # Do not inherit unrelated Java/Gradle injection or per-user signing options.
    for key in ['JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS', 'JDK_JAVA_OPTIONS', 'GRADLE_OPTS']:
        env.pop(key, None)
    cache = Path(config['cache'])
    env.update(JAVA_HOME=config['java_home'], ANDROID_HOME=config['android_sdk'], ANDROID_SDK_ROOT=config['android_sdk'],
               ANDROID_USER_HOME=str(cache/'android-user-home'), GRADLE_USER_HOME=str(cache/'gradle-user-home'),
               JAVA_TOOL_OPTIONS=f'-Duser.home="{cache / "java-user-home"}"',
               GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=2')
    return env


def run(command, log, config, cwd=None):
    # Commands here contain public paths/options only. Signing lives in PowerShell.
    with Path(log).open('w', encoding='utf-8') as output:
        result = subprocess.run([str(x) for x in command], cwd=cwd, env=clean_environment(config),
                                stdout=output, stderr=subprocess.STDOUT, check=False, timeout=900,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    require(result.returncode == 0, f'Command failed ({result.returncode}); inspect {log}')
    return Path(log).read_text(encoding='utf-8', errors='replace')


def configuration(args):
    cache = Path(args.cache or ROOT/'tools/android-release-cache').resolve()
    godot = Path(args.godot or ROOT/'tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe').resolve()
    settings = godot.parent/'editor_data/editor_settings-4.6.tres'
    require(settings.is_file(), f'Portable Godot editor settings missing: {settings}')
    text = settings.read_text(encoding='utf-8')
    def editor_path(key):
        match = re.search(r'^' + re.escape(key) + r'\s*=\s*(".*")$', text, re.M)
        require(match, f'Set {key} in this Godot installation first')
        return Path(json.loads(match.group(1))).resolve()
    java = Path(args.java_home).resolve() if args.java_home else editor_path('export/android/java_sdk_path')
    sdk = Path(args.android_sdk).resolve() if args.android_sdk else editor_path('export/android/android_sdk_path')
    require(java == editor_path('export/android/java_sdk_path'), 'JAVA_HOME must match Godot editor Java SDK Path')
    require(sdk == editor_path('export/android/android_sdk_path'), 'Android SDK must match Godot editor Android SDK Path')
    return dict(cache=str(cache), godot=str(godot), java_home=str(java), android_sdk=str(sdk),
                build_tools=str(sdk/'build-tools/36.1.0'),
                templates=str(godot.parent/'editor_data/export_templates/4.6.3.stable'),
                project=str(PROJECT), python=sys.executable)


def preset_identity():
    cfg = configparser.ConfigParser(interpolation=None, strict=True)
    cfg.read(PROJECT/'export_presets.cfg', encoding='utf-8')
    identities = []
    for index, kind in [(5, 'APK'), (6, 'AAB')]:
        head, opt = cfg[f'preset.{index}'], cfg[f'preset.{index}.options']
        require(head['name'] == f'"Android Release Candidate {kind}"', 'Public preset name changed')
        require(head['custom_features'] == '"sugarfall_public"', 'Missing public feature')
        require(opt['package/unique_name'] == f'"{PUBLIC_PACKAGE}"', 'Public package identity changed. Expected ' + PUBLIC_PACKAGE)
        require(opt['package/signed'] == 'false', 'Godot must export unsigned; signing happens afterward')
        require(all(opt.get(k, '""') == '""' for k in ['keystore/release', 'keystore/release_user', 'keystore/release_password']), 'Signing values must not be stored in presets')
        require(opt['architectures/arm64-v8a'] == 'true' and all(opt[k] == 'false' for k in ['architectures/armeabi-v7a', 'architectures/x86', 'architectures/x86_64']), 'Expected ARM64-only public export')
        requested={k for k,v in opt.items() if k.startswith('permissions/') and v=='true'}
        require(requested=={'permissions/internet','permissions/access_network_state'}, 'Native providers require only explicit Internet/network permissions; library manifest permissions are independently audited')
        require(opt['gradle_build/use_gradle_build'] == 'true', 'Native providers require Gradle for APK and AAB')
        if kind == 'AAB':
            require(opt['gradle_build/min_sdk'] == '"24"' and opt['gradle_build/target_sdk'] == '"36"', 'Public SDK24/36 changed')
        identities.append(dict(version_name=json.loads(opt['version/name']), version_code=int(opt['version/code'])))
    require(identities[0] == identities[1], 'Public APK and AAB versions differ')
    require(re.fullmatch(r'[A-Za-z0-9.-]+', identities[0]['version_name']), 'Unsafe version name')
    return identities[0]


def preflight(config, output, *, toolchain_only=False):
    if not toolchain_only:
        preflight_production_ads(PROJECT)
    output.mkdir(parents=True, exist_ok=True)
    templates, sdk = Path(config['templates']), Path(config['android_sdk'])
    required = [Path(config['godot']), templates/'android_release.apk', templates/'android_source.zip',
                sdk/'platforms/android-36/android.jar', sdk/'platform-tools/adb.exe',
                sdk/'ndk/29.0.14206865/source.properties', sdk/'licenses/android-sdk-license']
    required += [Path(config['build_tools'])/p for p in ['aapt.exe', 'aapt2.exe', 'zipalign.exe', 'lib/apksigner.jar']]
    required += [Path(config['java_home'])/'bin'/p for p in ['java.exe', 'jarsigner.exe', 'keytool.exe']]
    for path in required:
        require(path.is_file() and path.stat().st_size > 0, f'Required installed tool/template/license missing: {path}')
    require(sha(templates/'android_source.zip') == SOURCE_SHA, 'Android source template is not the pinned Godot4.6.3 template')
    godot_version = run([config['godot'], '--version'], output/'godot-version.log', config).strip()
    java_version = run([Path(config['java_home'])/'bin/java.exe', '-version'], output/'java-version.log', config)
    require(godot_version.startswith('4.6.3.stable'), 'Expected Godot4.6.3 standard')
    require(re.search(r'(?:version|openjdk) "?21[.\s"]', java_version), 'Expected installed JDK21')
    with zipfile.ZipFile(templates/'android_source.zip') as z:
        wrapper = z.read('gradle/wrapper/gradle-wrapper.properties').decode()
        gradle_config = z.read('config.gradle').decode()
        require('gradle-8.11.1-bin.zip' in wrapper, 'Unexpected Gradle wrapper')
        for value in ['8.6.1', '2.1.21', '29.0.14206865']:
            require(value in gradle_config, f'Template pin missing: {value}')
    identity = preset_identity()
    record = dict(status='passed', **identity, toolchain=config, godot_version=godot_version,
                  gradle='8.11.1', android_gradle_plugin='8.6.1', kotlin='2.1.21',
                  target_sdk=36, min_sdk=24, ndk='29.0.14206865', build_tools='36.1.0',
                  template_sha256={p.name: sha(p) for p in [templates/'android_source.zip', templates/'android_release.apk']},
                  sdk_license_sha256={p.name: sha(p) for p in (sdk/'licenses').iterdir() if p.is_file()},
                  new_licenses_accepted=False, signing_credentials_read=False)
    write_json(output/'preflight.json', record)
    return identity


def prepare_cache(config, seed=None):
    cache = Path(config['cache'])
    for name in ['gradle-user-home', 'android-user-home', 'java-user-home']:
        (cache/name).mkdir(parents=True, exist_ok=True)
    if seed:
        source, target = Path(seed).resolve(), cache/'gradle-user-home'
        require(source != target.resolve(), 'Cache seed and destination must differ')
        require((source/'caches/modules-2/files-2.1').is_dir(), 'Seed is not a warmed Gradle user home')
        # Deliberately omit user gradle.properties, init scripts, daemon state and credentials.
        # Maven files/metadata and wrapper distributions are relocatable; generated
        # transforms embed old absolute paths and are regenerated in the new cache.
        for name in ['caches/modules-2', 'wrapper']:
            src, dst = source/name, target/name
            if src.is_dir():
                # The old bootstrap's deep Maven metadata paths exceed MAX_PATH.
                def native_long(path):
                    return '\\\\?\\' + str(path) if os.name == 'nt' else str(path)
                shutil.copytree(native_long(src), native_long(dst), dirs_exist_ok=True,
                                ignore=shutil.ignore_patterns('*.lock', '*.lck', 'gc.properties'))
    build = cache/'template-project/android/build'
    build.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(Path(config['templates'])/'android_source.zip') as z:
        for info in z.infolist():
            target = (build/info.filename).resolve()
            require(target.is_relative_to(build.resolve()), 'Unsafe path in Android source template')
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                data = z.read(info)
                if not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
                else:
                    require(target.read_bytes() == data, f'Persistent template differs from official source: {info.filename}')
    (build.parent/'.build_version').write_text('4.6.3.stable\n')
    (build/'.gdignore').touch()
    return build


def make_classpath(config):
    cache = Path(config['cache']).resolve()
    manifest = cache/'bundletool-dependencies.json'
    require(manifest.is_file(), 'Run Setup-AndroidRelease.ps1 to resolve the isolated bundletool graph')
    selection = json.loads(manifest.read_text(encoding='utf-8-sig'))
    require(isinstance(selection, dict) and selection.get('schema_version') == 1
            and selection.get('root') == 'com.android.tools.build:bundletool:1.16.0'
            and selection.get('configuration') == 'sugarfallBundletoolRuntime',
            'Invalid or unpinned bundletool dependency manifest; rerun setup')
    artifacts = selection.get('artifacts')
    require(isinstance(artifacts, list) and 0 < len(artifacts) <= 256,
            'Bundletool dependency manifest must contain the resolved runtime JARs')
    modules = (cache/'gradle-user-home/caches/modules-2/files-2.1').resolve()
    versions, seen, selected = {}, set(), []
    for artifact in artifacts:
        require(isinstance(artifact, dict), 'Invalid bundletool artifact record')
        for field in ['group', 'name', 'version']:
            require(isinstance(artifact.get(field), str) and re.fullmatch(r'[A-Za-z0-9_.+-]+', artifact[field]),
                    'Invalid bundletool module coordinate')
        require(artifact.get('extension') == 'jar' and isinstance(artifact.get('file'), str)
                and Path(artifact['file']).is_absolute(), 'Bundletool artifact must be an absolute cached JAR path')
        classifier = artifact.get('classifier')
        require(classifier is None or isinstance(classifier, str) and re.fullmatch(r'[A-Za-z0-9_.+-]+', classifier),
                'Invalid bundletool artifact classifier')
        jar = Path(artifact['file']).resolve()
        require(jar.is_relative_to(modules) and jar.suffix == '.jar', 'Bundletool JAR is outside the dependency cache')
        relative = jar.relative_to(modules)
        require(len(relative.parts) == 5 and relative.parts[:3] ==
                (artifact['group'], artifact['name'], artifact['version']),
                'Bundletool JAR path does not match its resolved module coordinate')
        module = artifact['group'] + ':' + artifact['name']
        require(module not in versions or versions[module] == artifact['version'],
                f'Multiple resolved versions of bundletool module: {module}')
        versions[module] = artifact['version']
        identity = (module, classifier)
        require(identity not in seen, 'Duplicate bundletool artifact in the resolved graph')
        seen.add(identity)
        source = Path('\\\\?\\' + str(jar)) if os.name == 'nt' else jar
        digest = artifact.get('sha256', '')
        require(isinstance(digest, str) and re.fullmatch(r'[a-f0-9]{64}', digest)
                and source.is_file() and sha(source) == digest,
                f'Resolved bundletool dependency changed or is missing: {module}')
        selected.append((artifact, jar, source, digest))
    require(versions.get('com.android.tools.build:bundletool') == '1.16.0',
            'Resolved graph does not contain the pinned bundletool 1.16.0')
    # Some Maven paths exceed Windows MAX_PATH even in the relocated cache.
    # Give Java and the strict verifier short immutable content-addressed copies.
    libraries = cache/'bundletool-libs'
    require(libraries.resolve().is_relative_to(cache), 'Bundletool short-copy directory leaves the selected cache')
    libraries.mkdir(exist_ok=True)
    entries, provenance = [], []
    for artifact, jar, source, digest in selected:
        target = libraries/(digest + '.jar')
        if not target.exists():
            shutil.copyfile(source, target)
        require(sha(target) == digest, f'Cached verifier dependency differs: {jar.name}')
        entries.append(target.resolve().as_posix())
        provenance.append(dict(source=jar.as_posix(), sha256=digest, cached_path=target.as_posix(),
                               group=artifact['group'], name=artifact['name'], version=artifact['version'],
                               classifier=artifact.get('classifier'), selected_manifest_sha256=sha(manifest)))
    path = cache/'bundletool-classpath.txt'
    pending = path.with_suffix('.tmp')
    pending.write_text('\n'.join(dict.fromkeys(entries)) + '\n', encoding='utf-8')
    pending.replace(path)
    write_json(cache/'bundletool-libraries.json', provenance)
    return path


def resolve_bundletool(config, offline=False):
    """Refresh only the verifier graph; never export, sign or mutate the template."""
    cache = Path(config['cache']).resolve()
    build = cache/'template-project/android/build'
    require((build/'gradlew.bat').is_file(), 'Prepare the official release template cache with setup first')
    command = [str(build/'gradlew.bat'), '--no-daemon', '--console=plain', '--max-workers=2',
               '-Pperform_signing=false', f'-Pexport_package_name={PUBLIC_PACKAGE}',
               '--init-script', str(PROJECT/'tools/resolve-release-dependencies.gradle'),
               '-Psugarfall_bundletool_manifest=' + str(cache/'bundletool-dependencies.json'),
               'resolveSugarfallBundletoolClasspath']
    if offline:
        command.append('--offline')
    log = run(command, cache/'bundletool-resolution.log', config, build)
    require('BUILD SUCCESSFUL' in log and 'SUGARFALL_BUNDLETOOL_RESOLVED ' in log
            and 'BUILD FAILED' not in log, 'Isolated bundletool resolution did not complete')
    return make_classpath(config)


def setup(config, args):
    cache = Path(config['cache'])
    if args.require_production_ads:
        preflight_production_ads(PROJECT)
    preflight(config, cache/'preflight', toolchain_only=True)
    build = prepare_cache(config, args.seed_gradle_cache)
    command = [str(build/'gradlew.bat'), '--no-daemon', '--console=plain', '--max-workers=2',
               '-Pperform_signing=false', f'-Pexport_package_name={PUBLIC_PACKAGE}',
               '--init-script', str(PROJECT/'tools/resolve-release-dependencies.gradle'),
               '-Psugarfall_bundletool_manifest=' + str(cache.resolve()/'bundletool-dependencies.json'),
               'resolveSugarfallBundletoolClasspath', 'warmSugarfallReleaseDependencies', 'compileStandardReleaseJavaWithJavac']
    if args.offline:
        command.append('--offline')
    log = run(command, cache/'setup-gradle.log', config, build)
    require('BUILD SUCCESSFUL' in log and 'SUGARFALL_BUNDLETOOL_RESOLVED ' in log
            and 'BUILD FAILED' not in log, 'Gradle setup did not complete')
    classpath = make_classpath(config)
    write_json(cache/'toolchain.json', {**config, 'bundletool_classpath_file': str(classpath)})
    write_json(cache/'setup.json', dict(status='passed', offline=args.offline, signing_credentials_read=False,
                                      gradle_log_sha256=sha(cache/'setup-gradle.log'), classpath_jars=len(classpath.read_text().splitlines())))
    print(f'Release toolchain ready. Cache: {cache}', flush=True)


def source_manifest():
    # Freeze all runtime/import inputs, not QA, docs, caches or generated Android build files.
    paths = [PROJECT/'project.godot', PROJECT/'export_presets.cfg']
    for folder in ['scripts', 'scenes', 'data', 'addons']:
        paths.extend(p for p in (PROJECT/folder).rglob('*') if p.is_file())
    paths.extend(p for p in PROJECT.glob('*.tscn'))
    return {p.relative_to(PROJECT).as_posix(): sha(p) for p in sorted(set(paths))}


def export_diagnostics(log, config):
    allowed = {
        'ERROR: Failed to read the root certificate store.',
        'ERROR: Could not create child process: ' + str(Path(config['android_sdk'])/'build-tools/36.0.0/apksigner.bat') + ' --version',
    }
    errors = [re.sub(r'\x1b\[[0-9;]*m', '', line).strip() for line in log.splitlines()
              if re.search(r'(?:SCRIPT ERROR:|ERROR:)', line)]
    unexpected = [line for line in errors if line not in allowed]
    require(not unexpected, 'Unexpected export diagnostics: ' + '; '.join(unexpected[:5]))
    return dict(known_host_diagnostics=errors, unexpected_errors=[],
                scope='Known host probes only; final signature and package checks remain mandatory')


def export(config, args):
    preflight_production_ads(PROJECT)
    require((Path(config['cache'])/'setup.json').is_file(), 'Run Setup-AndroidRelease.ps1 first')
    identity = preset_identity()
    stamp = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
    output = Path(args.output or PROJECT/'builds/android-release'/f'{identity["version_name"]}-code{identity["version_code"]}'/stamp).resolve()
    require(not output.exists(), f'Refusing to overwrite a release directory: {output}')
    output.mkdir(parents=True)
    preflight(config, output)
    classpath = make_classpath(config)
    frozen = source_manifest()
    write_json(output/'source-sha256.json', frozen)
    name = f'Sugarfall-v{identity["version_name"]}-Android'
    plan = dict(**config, **identity, output=str(output), apk=str(output/(name+'.apk')), aab=str(output/(name+'.aab')),
                unsigned_apk=str(output/(name+'-unsigned.apk')), unsigned_aab=str(output/(name+'-unsigned.aab')),
                aligned_apk=str(output/(name+'-aligned.apk')), source_manifest=str(output/'source-sha256.json'),
                bundletool_classpath_file=str(classpath), release_template=str(Path(config['templates'])/'android_release.apk'),
                expected_certificate_sha256=CERT_SHA)
    write_json(output/'build-plan.json', plan)
    # A mutable pointer is local convenience; every release has its own immutable plan.
    write_json(Path(config['cache'])/'latest-build-plan.json', plan)
    diagnostics = {}
    for kind in ['apk', 'aab']:
        command = [config['godot'], '--headless', '--path', str(PROJECT), '--log-file', str(output/f'godot-export-{kind}.log')]
        if kind in ('apk','aab'):
            android_version = PROJECT/'android/.build_version'
            if not (PROJECT/'android/build/gradlew.bat').exists():
                command.append('--install-android-build-template')
            else:
                require(android_version.is_file() and android_version.read_text().strip() == '4.6.3.stable', 'Generated Android template version differs; inspect before rebuilding')
        command += ['--export-release', f'Android Release Candidate {kind.upper()}', plan['unsigned_'+kind]]
        print(f'Exporting unsigned {kind.upper()}...', flush=True)
        log = run(command, output/f'export-{kind}.log', config)
        require(Path(plan['unsigned_'+kind]).is_file(), f'Godot produced no {kind.upper()}')
        require('Export failed' not in log and 'BUILD FAILED' not in log, f'Export failed; inspect export-{kind}.log')
        diagnostics[kind] = export_diagnostics(log, config)
        write_json(output/'export-diagnostics.json', diagnostics)
    require(source_manifest() == frozen, 'Export inputs changed during build; do not sign these artifacts')
    write_json(output/'unsigned-export.json', dict(status='passed', source_inputs_unchanged=True,
                signing_credentials_read=False, files={kind: {'sha256': sha(plan['unsigned_'+kind]), 'bytes': Path(plan['unsigned_'+kind]).stat().st_size} for kind in ['apk', 'aab']}))
    print(f'Unsigned export ready: {output}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['preflight', 'setup', 'export'])
    for option in ['cache', 'godot', 'java-home', 'android-sdk', 'seed-gradle-cache', 'output']:
        parser.add_argument('--'+option)
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--require-production-ads', action='store_true', help='Check live AdMob configuration before dependency setup')
    args = parser.parse_args()
    config = configuration(args)
    if args.action == 'setup':
        setup(config, args)
    elif args.action == 'preflight':
        preflight(config, Path(args.output or Path(config['cache'])/'preflight'))
        print('Toolchain and public export preflight passed; no signing credential was read.')
    else:
        export(config, args)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile, subprocess.TimeoutExpired) as error:
        print(f'Release preparation failed: {error}', file=sys.stderr)
        sys.exit(1)
