"""Secret-free checks for release preparation's fail-closed boundaries."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('android_release', Path(__file__).resolve().parents[1]/'tools/android_release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseBoundaries(unittest.TestCase):
    def test_long_maven_jar_path_becomes_short_verified_classpath(self):
        with tempfile.TemporaryDirectory(prefix='release-cache-') as directory:
            cache = Path(directory)
            modules = cache/'gradle-user-home/caches/modules-2/files-2.1'
            parent = modules/('m' * max(1, 250-len(str(modules))-1))
            jar = parent/'bundletool-1.16.0.jar'
            native = Path('\\\\?\\' + str(jar.resolve())) if os.name == 'nt' else jar
            native.parent.mkdir(parents=True)
            payload = b'original deterministic dependency bytes'
            native.write_bytes(payload)
            try:
                path = release.make_classpath({'cache': str(cache)})
                entries = path.read_text().splitlines()
                self.assertEqual(len(entries), 1)
                self.assertLess(len(entries[0]), 260)
                self.assertTrue(Path(entries[0]).is_file())
                self.assertEqual(Path(entries[0]).read_bytes(), payload)
            finally:
                # TemporaryDirectory's Windows cleanup cannot see the long file.
                native.unlink(missing_ok=True)

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
