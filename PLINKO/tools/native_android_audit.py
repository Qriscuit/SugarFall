"""Read-only native-commerce checks shared by preview and public APK audits.

DEX class_defs prove classes exist; arbitrary string matches cannot satisfy them.
Manifest input is Android build-tools `aapt dump xmltree APK AndroidManifest.xml`.
This module neither signs nor changes an APK and never accepts credentials.
"""
import hashlib
import json
import re
import struct
from android_release import PREVIEW_ADS_PATH, PRODUCTION_ADS_PATH, validate_production_ads

DEMO_APP_ID = 'ca-app-pub-3940256099942544~3347511713'
DEMO_REWARDED = 'ca-app-pub-3940256099942544/5224354917'
DEMO_INTERSTITIAL = 'ca-app-pub-3940256099942544/1033173712'
ADMOB_APP_METADATA = 'com.google.android.gms.ads.APPLICATION_ID'
REQUIRED_PERMISSIONS = {'android.permission.INTERNET', 'android.permission.ACCESS_NETWORK_STATE', 'com.android.vending.BILLING'}
OPTIONAL_PERMISSIONS = {'com.google.android.gms.permission.AD_ID', 'android.permission.ACCESS_ADSERVICES_AD_ID',
                        'android.permission.ACCESS_ADSERVICES_ATTRIBUTION', 'android.permission.ACCESS_ADSERVICES_TOPICS',
                        # Exact GMA1.6 and its WorkManager2.7 manifests; review:
                        # verification/android-preview-v0717/sdk-permission-review.json.
                        'android.permission.READ_BASIC_PHONE_STATE', 'android.permission.WAKE_LOCK', 'android.permission.FOREGROUND_SERVICE'}
POING_PLUGINS = ['PoingGodotAdMob', 'PoingGodotAdMobAdView', 'PoingGodotAdMobAdSize', 'PoingGodotAdMobInterstitialAd',
                 'PoingGodotAdMobRewardedAd', 'PoingGodotAdMobRewardedInterstitialAd', 'PoingGodotAdMobConsentInformation',
                 'PoingGodotAdMobUserMessagingPlatform', 'PoingGodotAdMobAppOpenAd', 'PoingGodotAdMobNativeOverlayAd']
EXPECTED_PLUGINS = {'org.godotengine.plugin.v2.' + name: 'com.poingstudios.godot.admob.ads.' + name for name in POING_PLUGINS}
EXPECTED_PLUGINS['org.godotengine.plugin.v2.GodotGooglePlayBilling'] = 'org.godotengine.plugin.googleplaybilling.GodotGooglePlayBilling'
SDK_CLASSES = {'Lcom/google/android/libraries/ads/mobile/sdk/MobileAds;', 'Lcom/google/android/ump/UserMessagingPlatform;',
               'Lcom/android/billingclient/api/BillingClient;'}


def import_targets(exported_descriptor, source_descriptor=None):
    """Resolve exported import outputs, including Godot's CSV translations.

    Godot strips CSV [deps] from the packaged descriptor. For that one importer,
    callers supply its frozen source descriptor, then still verify every declared
    .translation output against packaged bytes and the frozen source manifest.
    """
    targets = re.findall(r'^path(?:\.[^=]+)?="res://([^"]+)"', exported_descriptor.rstrip('\0'), re.M)
    if targets: return targets
    if source_descriptor is None: return []
    if not all(re.search(r'^importer="csv_translation"$', text, re.M) for text in [exported_descriptor.rstrip('\0'), source_descriptor]): return []
    match = re.search(r'^dest_files=(\[[^\r\n]*\])$', source_descriptor, re.M)
    if not match: return []
    try: files = json.loads(match[1])
    except ValueError: return []
    if not isinstance(files, list) or not files or not all(isinstance(path, str) and path.startswith('res://') and path.endswith('.translation') for path in files): return []
    return [path.removeprefix('res://') for path in files]


def manifest_metadata(text):
    """Read direct application metadata and retain duplicate names."""
    result = {}
    record = None
    elements = []
    def finish():
        if record is not None and 'name' in record:
            result.setdefault(record['name'], []).append(record.get('value'))
    for line in text.splitlines():
        element = re.match(r'^(\s*)E:\s+(\S+)', line)
        if element:
            finish()
            record = None
            indentation = len(element[1])
            while elements and elements[-1][0] >= indentation:
                elements.pop()
            if element[2] == 'meta-data' and elements and elements[-1][1] == 'application':
                record = {}
            elements.append((indentation, element[2]))
        attribute = re.match(r'^\s*A:\s+android:(name|value)(?:\([^)]*\))?="([^"]*)"', line)
        if record is not None and attribute:
            record[attribute[1]] = attribute[2]
    finish()
    return result


def dex_classes(data):
    """Return actual class descriptors from a standard little-endian DEX file."""
    if len(data) < 112 or data[:4] != b'dex\n' or data[7] != 0 or struct.unpack_from('<I', data, 40)[0] != 0x12345678:
        raise ValueError('Unsupported or truncated DEX header')
    if struct.unpack_from('<I', data, 32)[0] != len(data):
        raise ValueError('DEX declared size differs from actual payload')
    string_count, string_offset = struct.unpack_from('<II', data, 56)
    type_count, type_offset = struct.unpack_from('<II', data, 64)
    class_count, class_offset = struct.unpack_from('<II', data, 96)
    for count, offset, stride in [(string_count, string_offset, 4), (type_count, type_offset, 4), (class_count, class_offset, 32)]:
        if count > len(data) // stride or offset > len(data) or offset + count * stride > len(data):
            raise ValueError('DEX table exceeds payload bounds')
    result = set()
    for index in range(class_count):
        type_index = struct.unpack_from('<I', data, class_offset + index * 32)[0]
        if type_index >= type_count: raise ValueError('Invalid DEX class type index')
        string_index = struct.unpack_from('<I', data, type_offset + type_index * 4)[0]
        if string_index >= string_count: raise ValueError('Invalid DEX descriptor string index')
        position = struct.unpack_from('<I', data, string_offset + string_index * 4)[0]
        # Skip the bounded ULEB128 UTF16 length before reading the descriptor.
        for _ in range(5):
            if position >= len(data): raise ValueError('Truncated DEX string length')
            value = data[position]; position += 1
            if value < 128: break
        else: raise ValueError('Invalid DEX string length')
        end = data.find(b'\0', position)
        if end < 0: raise ValueError('Unterminated DEX descriptor')
        name = data[position:end].decode('utf-8')
        if not name.startswith('L') or not name.endswith(';'): raise ValueError('Invalid DEX class descriptor')
        if name in result: raise ValueError('Duplicate class definition within DEX')
        result.add(name)
    return result


def audit_production_ads(archive, assets, manifest_app_ids, frozen_sha256):
    """Check the live config and the exact manifest value for one artifact."""
    production_entry = assets.get('assets/' + PRODUCTION_ADS_PATH)
    checks = [{'name': 'Preview ad configuration is absent',
               'passed': 'assets/' + PREVIEW_ADS_PATH not in assets}]
    try:
        payload = archive.read(production_entry) if production_entry else b''
        ads = validate_production_ads(payload)
    except (KeyError, ValueError) as error:
        checks.append({'name': 'Packaged live AdMob configuration is valid', 'passed': False, 'actual': str(error)})
        return checks
    checks.extend([
        {'name': 'Packaged live AdMob configuration is valid', 'passed': True},
        {'name': 'Live AdMob configuration matches frozen source',
         'passed': hashlib.sha256(payload).hexdigest() == frozen_sha256, 'actual': production_entry},
        {'name': 'Manifest has exactly one matching live AdMob app ID',
         'passed': manifest_app_ids == [ads['app_id']], 'actual': manifest_app_ids},
    ])
    return checks


def audit_native_apk(archive, manifest_dump, badging, package, expect_demo_ads=True, expect_empty_billing=True):
    """Return {passed, checks, dex, native_metadata, config} without modifying inputs.

    Each check uses {name, passed, actual}; callers can merge it into their own
    signature/resource/native-origin audit. `archive` is an open ZipFile.
    """
    checks = []
    def check(name, passed, actual=None):
        checks.append({'name': name, 'passed': bool(passed), 'actual': actual})
    names = archive.namelist()
    permissions = set(re.findall(r"^uses-permission[^:]*: name='([^']+)'", badging, re.M))
    allowed = REQUIRED_PERMISSIONS | OPTIONAL_PERMISSIONS | {package + '.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
    check('Native SDK permissions match reviewed allowlist', REQUIRED_PERMISSIONS <= permissions <= allowed, sorted(permissions))
    check('Bogus android.permission.AD_ID is absent', 'android.permission.AD_ID' not in permissions)
    check('SDK-removed boot-completed permission stays absent', 'android.permission.RECEIVE_BOOT_COMPLETED' not in permissions)
    metadata = manifest_metadata(manifest_dump)
    for name, expected in EXPECTED_PLUGINS.items():
        check('Exact native Godot v2 plugin metadata: ' + name, metadata.get(name) == [expected], metadata.get(name))
    if expect_demo_ads:
        check('Google demo AdMob app ID in merged Android manifest', metadata.get(ADMOB_APP_METADATA) == [DEMO_APP_ID], metadata.get(ADMOB_APP_METADATA))
        check('Production ad configuration is absent from preview APK', 'assets/' + PRODUCTION_ADS_PATH not in names)
        try:
            ads = json.loads(archive.read('assets/' + PREVIEW_ADS_PATH))
        except (KeyError, ValueError) as error:
            check('Preview ad configuration is packaged JSON', False, str(error))
        else:
            expected = {'enabled': True, 'app_id': DEMO_APP_ID, 'use_test_ads': True,
                        'rewarded_unit_id': DEMO_REWARDED, 'interstitial_unit_id': DEMO_INTERSTITIAL}
            check('Real SDK test mode and exact Google demo app/ad units',
                  isinstance(ads, dict) and all(ads.get(key) == value and type(ads.get(key)) is type(value)
                                               for key, value in expected.items()), ads)
    classes = set(); dex = []; errors = []
    for name in sorted(n for n in names if re.fullmatch(r'classes(?:\d+)?\.dex', n)):
        payload = archive.read(name)
        try:
            current = dex_classes(payload)
            duplicates = classes & current
            if duplicates: errors.append({'entry': name, 'duplicate_classes': sorted(duplicates)})
            classes.update(current)
            dex.append({'entry': name, 'class_count': len(current), 'sha256': hashlib.sha256(payload).hexdigest()})
        except (ValueError, UnicodeError, struct.error) as error:
            errors.append({'entry': name, 'error': str(error)})
    check('All actual DEX class tables parse without duplicate definitions', bool(dex) and not errors, {'dex': dex, 'errors': errors})
    required = SDK_CLASSES | {'L' + value.replace('.', '/') + ';' for value in EXPECTED_PLUGINS.values()}
    for descriptor in sorted(required):
        check('Actual native or Google SDK class definition: ' + descriptor, descriptor in classes)
    all_plugin_values = {value for key, values in metadata.items() if key.startswith('org.godotengine.plugin.v2.') for value in values if value}
    missing = sorted(value for value in all_plugin_values if 'L' + value.replace('.', '/') + ';' not in classes)
    check('Every declared Godot v2 plugin has a real DEX class', not missing, missing)
    raw_archives = [name for name in names if name.lower().endswith(('.aar', '.jar', '.zip'))]
    check('Build-input AAR/JAR/ZIP archives are not raw APK payloads', not raw_archives, raw_archives)
    internal_testing = [name for name in names if re.search(r'(?i)(?:^|/)(?:NATIVE_BILLING_PLUGIN\.json|ADMOB_PLUGIN_PROVENANCE\.json|pulse-validation\.json|preview-summary\.json|validation\.json|FILE_INVENTORY\.json)$', name)]
    check('Internal QA and plugin-acquisition metadata are absent', not internal_testing, internal_testing)
    samples = [name for name in names if name.startswith('assets/addons/admob/gdscript/sample/')]
    check('Upstream vendor sample scenes and scripts are excluded', not samples, samples)
    config = None
    config_path = 'assets/data/monetization_config.json'
    try:
        config = json.loads(archive.read(config_path))
        if not isinstance(config, dict): raise ValueError('Configuration must be an object')
    except (KeyError, ValueError, UnicodeError) as error:
        check('Native monetization configuration is packaged JSON', False, str(error))
        config = None
    if config is not None:
        check('Shared monetization configuration contains no ad settings', 'ads' not in config)
        if expect_empty_billing:
            billing = config.get('billing', {})
            expected_fields = ['verification_url', 'firebase_web_api_key', 'firebase_project_id']
            check('Unconfigured paid checkout has no backend or Firebase identity', isinstance(billing, dict) and all(billing.get(key) == '' for key in expected_fields), billing)
    return {'passed': all(item['passed'] for item in checks), 'checks': checks, 'dex': dex,
            'native_metadata': metadata, 'config': config, 'required_classes': sorted(required), 'actual_class_count': len(classes)}
