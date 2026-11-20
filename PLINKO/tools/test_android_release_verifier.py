"""Focused guards for sparse-PCK semantic comparison in release verification."""
import hashlib
import io
import json
import struct
import unittest
import zipfile
from native_android_audit import ADMOB_APP_METADATA, audit_production_ads, manifest_metadata
from verify_android_release import AUTHORING_METADATA, FORBIDDEN, sparse_pack_entries, sparse_payload_errors


def pack(payload,order=None,mutate=None):
    output=bytearray(struct.pack('<6I2Q',0x43504447,3,4,6,3,6,0,104)+bytes(64))
    order=list(payload) if order is None else order
    output.extend(struct.pack('<I',len(order)))
    for path in order:
        raw=path.encode();padded=raw+bytes((-len(raw))%4)
        size=len(payload[path]);digest=hashlib.md5(payload[path]).digest();offset=flags=0
        if mutate:offset,size,digest,flags=mutate(path,offset,size,digest,flags)
        output.extend(struct.pack('<I',len(padded))+padded+struct.pack('<2Q',offset,size)+digest+struct.pack('<I',flags))
    return bytes(output)


class SparsePackVerificationTests(unittest.TestCase):
    def setUp(self):
        self.payload={'scripts/main.gdc':b'GDSC123','data/numbers.json':b'{"value":1}','project.binary':b'ECFG567'}

    def test_reordering_only_is_equivalent_and_all_payloads_match(self):
        first=sparse_pack_entries(pack(self.payload))
        second=sparse_pack_entries(pack(self.payload,list(reversed(self.payload))))
        self.assertEqual(first,second)
        self.assertFalse(sparse_payload_errors(first,set(self.payload)|{'assets.sparsepck'},self.payload.__getitem__))
        self.assertFalse(sparse_payload_errors(first,set(self.payload)|{'assets.sparsepck','_cl_'},self.payload.__getitem__))

    def test_changed_hash_or_size_is_not_equivalent_and_fails_payload_match(self):
        original=sparse_pack_entries(pack(self.payload))
        for size_delta,digest in [(1,None),(0,bytes(16))]:
            changed=sparse_pack_entries(pack(self.payload,mutate=lambda p,o,s,h,f:(o,s+size_delta,h if digest is None else digest,f)))
            self.assertNotEqual(original,changed)
            self.assertTrue(sparse_payload_errors(changed,self.payload,self.payload.__getitem__))

    def test_changed_payload_same_size_fails(self):
        index=sparse_pack_entries(pack(self.payload));altered=dict(self.payload)
        altered['project.binary']=b'ECFG999'
        self.assertTrue(sparse_payload_errors(index,altered,altered.__getitem__))

    def test_missing_or_unindexed_payload_fails(self):
        index=sparse_pack_entries(pack(self.payload))
        self.assertTrue(sparse_payload_errors(index,set(self.payload)-{'project.binary'},self.payload.__getitem__))
        self.assertTrue(sparse_payload_errors(index,set(self.payload)|{'extra.file'},self.payload.__getitem__))

    def test_duplicate_path_fails(self):
        with self.assertRaises(ValueError):sparse_pack_entries(pack(self.payload,['project.binary']*2))

    def test_unsafe_and_noncanonical_paths_fail(self):
        for path in ['../private.key','/absolute','C:/private.key','a\\b','a/../b','a//b','./a','a\0b']:
            with self.subTest(path=path),self.assertRaises(ValueError):sparse_pack_entries(pack({path:b'x'}))

    def test_unsupported_offsets_and_flags_fail(self):
        for offset,flags in [(1,0),(0,1),(0,2),(0,4)]:
            with self.subTest(offset=offset,flags=flags),self.assertRaises(ValueError):
                sparse_pack_entries(pack(self.payload,mutate=lambda p,o,s,h,f:(offset,s,h,flags)))

    def test_header_corruption_and_truncation_fail(self):
        original=pack(self.payload)
        for position in [0,4,8,12,16,20,24,32,40,104,108]:
            data=bytearray(original);data[position]^=1
            with self.subTest(position=position),self.assertRaises(ValueError):sparse_pack_entries(bytes(data))
        for length in [0,20,104,108,len(original)-1]:
            with self.subTest(length=length),self.assertRaises(ValueError):sparse_pack_entries(original[:length])

    def test_trailing_data_and_excess_padding_fail(self):
        with self.assertRaises(ValueError):sparse_pack_entries(pack(self.payload)+b'\0')
        data=bytearray(pack({'a':b'x'}));data[112:116]=bytes(4)
        with self.assertRaises(ValueError):sparse_pack_entries(bytes(data))

    def test_concept_art_metadata_is_not_publishable_payload(self):
        self.assertTrue(FORBIDDEN.search('assets/concept-art/results-v1/prompts.json'))
        self.assertTrue(FORBIDDEN.search('assetPackInstallTime/assets/concept-art/results-v1/prompts.json'))
        self.assertFalse(FORBIDDEN.search('assets/data/art/bakery_ability/jam_donut.png'))

    def test_authoring_provenance_excluded_and_runtime_data_retained(self):
        for path in ['data/art/bakery/palette-refresh-sources.json','data/art/menu/sources.json',
                     'data/art/menu/README.txt','data/audio/studio_warm_hum.provenance.json']:
            self.assertTrue(AUTHORING_METADATA.search('assets/'+path))
            self.assertTrue(AUTHORING_METADATA.search('assetPackInstallTime/assets/'+path))
        for path in ['assets/data/numbers.json','assets/data/licenses/GODOT_LICENSE.txt',
                     'assets/data/art/bakery_ability/jam_donut.png','assets/data/audio/studio_warm_hum.wav']:
            self.assertFalse(AUTHORING_METADATA.search(path))


class ProductionAdsVerificationTests(unittest.TestCase):
    app_id = 'ca-app-pub-1111111111111111~2222222222'
    config = {
        'enabled': True, 'use_test_ads': False, 'app_id': app_id,
        'rewarded_unit_id': 'ca-app-pub-1111111111111111/3333333333',
        'interstitial_unit_id': 'ca-app-pub-1111111111111111/4444444444',
    }

    def audit(self, module='', *, manifest_ids=None, frozen_hash=None, preview=False, config=None):
        data = json.dumps(self.config if config is None else config).encode()
        production_path = 'assets/data/production_ads.json'
        preview_path = 'assets/data/preview_ads.json'
        assets = {production_path: module + production_path}
        with zipfile.ZipFile(io.BytesIO(), 'w') as archive:
            archive.writestr(assets[production_path], data)
            if preview:
                assets[preview_path] = module + preview_path
                archive.writestr(assets[preview_path], '{}')
            return audit_production_ads(archive, assets,
                                        [self.app_id] if manifest_ids is None else manifest_ids,
                                        frozen_hash or hashlib.sha256(data).hexdigest())

    def test_apk_and_aab_asset_pack(self):
        for module in ['', 'assetPackInstallTime/']:
            with self.subTest(module=module):
                self.assertTrue(all(item['passed'] for item in self.audit(module)))

    def test_manifest_mismatch_preview_payload_and_drift_fail(self):
        for kwargs in [{'manifest_ids': []}, {'manifest_ids': [self.app_id, self.app_id]},
                       {'manifest_ids': ['other']}, {'preview': True}, {'frozen_hash': 'changed'},
                       {'config': {**self.config, 'use_test_ads': True}}]:
            with self.subTest(kwargs=kwargs):
                self.assertFalse(all(item['passed'] for item in self.audit(**kwargs)))

    def test_application_metadata_excludes_nested_values_and_retains_duplicates(self):
        metadata = f'      E: meta-data\n        A: android:name="{ADMOB_APP_METADATA}"\n        A: android:value="{self.app_id}"\n'
        nested = '\n'.join('  '+line for line in metadata.splitlines())+'\n'
        manifest = '  E: manifest\n    E: application\n      E: activity\n'+nested+metadata+metadata
        self.assertEqual(manifest_metadata(manifest), {ADMOB_APP_METADATA: [self.app_id, self.app_id]})


if __name__=='__main__':unittest.main(verbosity=2)
