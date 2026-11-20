"""Secret-free checks for release preparation's fail-closed boundaries."""
import argparse
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('android_release', Path(__file__).resolve().parents[1]/'tools/android_release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ProductionAdsPreflight(unittest.TestCase):
    def setUp(self):
        self.ads = {
            'enabled': True, 'use_test_ads': False,
            'app_id': 'ca-app-pub-1111111111111111~2222222222',
            'rewarded_unit_id': 'ca-app-pub-1111111111111111/3333333333',
            'interstitial_unit_id': 'ca-app-pub-1111111111111111/4444444444',
        }

    def test_valid_owner_ids(self):
        self.assertEqual(release.validate_production_ads(json.dumps(self.ads).encode()), self.ads)

    def test_rejects_invalid_modes_units_and_consent(self):
        cases = [
            ({'enabled': False}, 'enabled=true'),
            ({'use_test_ads': 0}, 'use_test_ads=false'),
            ({'app_id': ''}, 'owner AdMob app_id'),
            ({'app_id': 'ca-app-pub-3940256099942544~3347511713'}, 'demo inventory'),
            ({'interstitial_unit_id': 'ca-app-pub-9999999999999999/4444444444'}, 'share an owner'),
            ({'interstitial_unit_id': self.ads['rewarded_unit_id']}, 'separate ad units'),
            ({'rewarded_unit_id': self.ads['app_id']}, 'owner AdMob rewarded_unit_id'),
            ({'test_device_ids': []}, 'test-device'),
            ({'consent': {'debug_geography': 0}}, 'consent-debug'),
            ({'consent': {'test_device_hashed_ids': []}}, 'consent-debug'),
            ({'consent': []}, 'consent configuration must be an object'),
            ({'consent': {'tag_for_under_age_of_consent': 0}}, 'must be booleans'),
            ({'tag_for_child_directed_treatment': True}, 'must be -1, 0, or 1'),
            ({'metadata': {'test_unit': 'ca-app-pub-3940256099942544/5224354917'}}, 'demo inventory'),
        ]
        for changes, expected in cases:
            with self.subTest(changes=changes), self.assertRaisesRegex(ValueError, expected):
                release.validate_production_ads(json.dumps({**self.ads, **changes}).encode())

    def test_public_export_blocks_before_any_tool_runs(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            with patch.object(release, 'PROJECT', project), patch.object(release, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, 'Configure data/production_ads.json'):
                    release.export({'cache': project}, argparse.Namespace())
                run.assert_not_called()


class PublicPackageIdentity(unittest.TestCase):
    def test_console_package_is_pinned_for_both_release_presets(self):
        self.assertEqual(release.PUBLIC_PACKAGE, 'com.sungati.sugarfall')
        configuration = (release.PROJECT / 'export_presets.cfg').read_text(encoding='utf-8')
        release.preset_identity()
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            for wrong_package in ['com.qriscuit.sugarfall', 'org.pegfoundry.prototype.preview']:
                with self.subTest(package=wrong_package):
                    (project / 'export_presets.cfg').write_text(
                        configuration.replace('com.sungati.sugarfall', wrong_package),
                        encoding='utf-8',
                    )
                    with patch.object(release, 'PROJECT', project):
                        with self.assertRaisesRegex(RuntimeError, 'com.sungati.sugarfall'):
                            release.preset_identity()


class ReleaseBoundaries(unittest.TestCase):
    @staticmethod
    def artifact(cache, group='com.android.tools.build', name='bundletool', version='1.16.0', payload=b'bundletool'):
        jar = cache/'gradle-user-home/caches/modules-2/files-2.1'/group/name/version/('a'*40)/(name+'-'+version+'.jar')
        native = Path('\\\\?\\' + str(jar.resolve())) if os.name == 'nt' else jar
        native.parent.mkdir(parents=True, exist_ok=True)
        native.write_bytes(payload)
        return dict(group=group, name=name, version=version, classifier=None, extension='jar',
                    file=str(jar.resolve()), sha256=hashlib.sha256(payload).hexdigest())

    @staticmethod
    def manifest(cache, artifacts):
        (cache/'bundletool-dependencies.json').write_text(json.dumps(dict(schema_version=1,
            root='com.android.tools.build:bundletool:1.16.0', configuration='sugarfallBundletoolRuntime',
            artifacts=artifacts)), encoding='utf-8')

    def test_long_maven_jar_path_becomes_short_verified_classpath(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            modules = cache/'gradle-user-home/caches/modules-2/files-2.1'
            group = 'm' * max(1, 230-len(str(modules)))
            payload = b'original deterministic dependency bytes'
            root = self.artifact(cache)
            dependency = self.artifact(cache, group=group, name='long-path-dependency', version='2', payload=payload)
            jar = Path(dependency['file'])
            native = Path('\\\\?\\' + str(jar)) if os.name == 'nt' else jar
            self.manifest(cache, [root, dependency])
            try:
                self.assertGreater(len(str(jar)), 260)
                path = release.make_classpath({'cache': str(cache)})
                entries = path.read_text().splitlines()
                self.assertEqual(len(entries), 2)
                self.assertTrue(all(len(entry) < 260 and Path(entry).is_file() for entry in entries))
                self.assertEqual(Path(entries[1]).read_bytes(), payload)
            finally:
                # TemporaryDirectory's Windows cleanup cannot see the long file.
                native.unlink(missing_ok=True)
                parent = jar.parent
                while parent != modules:
                    self.assertTrue(parent.is_relative_to(cache))
                    native_parent = Path('\\\\?\\' + str(parent)) if os.name == 'nt' else parent
                    native_parent.rmdir()
                    parent = parent.parent

    def test_only_gradle_selected_guava_version_joins_classpath(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            root = self.artifact(cache)
            old = self.artifact(cache, 'com.google.guava', 'guava', '18.0', b'incompatible Guava')
            selected = self.artifact(cache, 'com.google.guava', 'guava', '32.0.1-jre', b'selected Guava')
            self.manifest(cache, [root, selected])
            path = release.make_classpath({'cache': str(cache)})
            entries = path.read_text().splitlines()
            self.assertEqual(len(entries), 2)
            self.assertEqual(Path(entries[1]).read_bytes(), b'selected Guava')
            self.assertFalse((cache/'bundletool-libs'/(old['sha256']+'.jar')).exists())
            provenance = json.loads((cache/'bundletool-libraries.json').read_text())
            self.assertEqual([item['version'] for item in provenance], ['1.16.0', '32.0.1-jre'])

    def test_missing_selection_manifest_does_not_fall_back_to_cached_jars(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            self.artifact(cache)
            with self.assertRaisesRegex(RuntimeError, 'isolated bundletool graph'):
                release.make_classpath({'cache': str(cache)})

    def test_modified_selected_jar_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            root = self.artifact(cache)
            self.manifest(cache, [root])
            Path(root['file']).write_bytes(b'changed dependency')
            with self.assertRaisesRegex(RuntimeError, 'changed or is missing'):
                release.make_classpath({'cache': str(cache)})

    def test_two_selected_guava_versions_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            self.manifest(cache, [self.artifact(cache),
                self.artifact(cache, 'com.google.guava', 'guava', '18.0', b'old'),
                self.artifact(cache, 'com.google.guava', 'guava', '32.0.1-jre', b'new')])
            with self.assertRaisesRegex(RuntimeError, 'Multiple resolved versions'):
                release.make_classpath({'cache': str(cache)})

    def test_selected_jar_outside_cache_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            root = self.artifact(cache)
            root['file'] = str(cache/'outside.jar')
            Path(root['file']).write_bytes(b'bundletool')
            self.manifest(cache, [root])
            with self.assertRaisesRegex(RuntimeError, 'outside the dependency cache'):
                release.make_classpath({'cache': str(cache)})

    def test_resolver_requests_only_pinned_graph_without_export_or_signing(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            wrapper = cache/'template-project/android/build/gradlew.bat'
            wrapper.parent.mkdir(parents=True)
            wrapper.write_text('test wrapper')
            with patch.object(release, 'run', return_value='SUGARFALL_BUNDLETOOL_RESOLVED 2 jars\nBUILD SUCCESSFUL') as run, \
                    patch.object(release, 'make_classpath', return_value=cache/'bundletool-classpath.txt'):
                release.resolve_bundletool({'cache': str(cache)}, offline=True)
            command = run.call_args.args[0]
            self.assertIn('resolveSugarfallBundletoolClasspath', command)
            self.assertIn('-Pperform_signing=false', command)
            self.assertIn('-Psugarfall_bundletool_manifest='+str(cache/'bundletool-dependencies.json'), command)
            self.assertIn('--offline', command)
            self.assertNotIn('assembleStandardRelease', command)

    def test_unsigned_child_environment_excludes_credentials_and_java_injection(self):
        config = dict(cache=str(Path('cache with spaces').resolve()), java_home='jdk', android_sdk='sdk')
        with patch.dict(os.environ, {'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD': 'dummy-not-a-secret',
                                    'org_gradle_project_release_keystore_password': 'dummy',
                                    '_JAVA_OPTIONS': 'untrusted', 'JDK_JAVA_OPTIONS': 'untrusted',
                                    'UNRELATED_TEST_VALUE': 'retained'}):
            child = release.clean_environment(config)
        self.assertFalse(any(k.lower().startswith(('godot_android_keystore_release_', 'org_gradle_project_release_keystore_')) for k in child))
        self.assertNotIn('_JAVA_OPTIONS', child)
        self.assertNotIn('JDK_JAVA_OPTIONS', child)
        self.assertEqual(child['UNRELATED_TEST_VALUE'], 'retained')
        self.assertIn('-Duser.home="', child['JAVA_TOOL_OPTIONS'])

    def test_only_exact_known_host_probes_are_accepted(self):
        config = {'android_sdk': str(Path('sdk').resolve())}
        known = 'ERROR: Failed to read the root certificate store.\nERROR: Could not create child process: ' + str(Path(config['android_sdk'])/'build-tools/36.0.0/apksigner.bat') + ' --version'
        self.assertEqual(len(release.export_diagnostics(known, config)['known_host_diagnostics']), 2)
        for bad in ['SCRIPT ERROR: Parse error at main.gd:1', 'ERROR: Export failed.',
                    'ERROR: Failed to read the root certificate store. Unexpected suffix',
                    known.replace('36.0.0', '36.1.0')]:
            with self.subTest(bad=bad), self.assertRaises(RuntimeError):
                release.export_diagnostics(bad, config)

    def test_mismatched_public_identity_is_rejected(self):
        import configparser
        original_read = configparser.ConfigParser.read
        def altered_read(parser, *args, **kwargs):
            result = original_read(parser, *args, **kwargs)
            parser['preset.6.options']['package/unique_name'] = '"com.wrong.app"'
            return result
        with patch.object(configparser.ConfigParser, 'read', altered_read), self.assertRaisesRegex(RuntimeError, 'identity changed'):
            release.preset_identity()

    def test_enabling_godot_signing_is_rejected(self):
        import configparser
        original_read = configparser.ConfigParser.read
        def altered_read(parser, *args, **kwargs):
            result = original_read(parser, *args, **kwargs)
            parser['preset.5.options']['package/signed'] = 'true'
            return result
        with patch.object(configparser.ConfigParser, 'read', altered_read), self.assertRaisesRegex(RuntimeError, 'export unsigned'):
            release.preset_identity()


if __name__ == '__main__':
    unittest.main()
