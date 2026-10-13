import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import json

spec = importlib.util.spec_from_file_location('forever_watch', Path(__file__).resolve().parents[1] / 'tools' / 'forever_watch.py')
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)


class WatchTests(unittest.TestCase):
    def test_interface_is_version_not_build(self):
        self.assertEqual(watch.version_interface('1.60.1.70338'), 16001)
        self.assertEqual(watch.version_interface('1.60.2.70400'), 16002)
        for invalid in ('12.1.0.70338', '1.15.8.70000', '1.60.1', '1.60.100.70400'):
            with self.assertRaises(ValueError):
                watch.version_interface(invalid)

    def test_toc_keeps_version_and_game_type(self):
        before = '## Interface: 16001\n## Version: 1.0.0\n## AllowLoadGameType: camelot\nCore.lua\n'
        after = watch.update_toc(before, 16002)
        self.assertEqual(after, before.replace('16001', '16002'))
        with self.assertRaises(ValueError):
            watch.update_toc('## Version: 1.0.0\n', 16002)

    def test_new_patch_only_changes_metadata_and_reports_sensitive_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / '.github').mkdir()
            old = dict(repository=watch.SOURCE, branch='forever', commit='a' * 40, version='1.60.1.70338', interface=16001)
            (root / watch.BASELINE).write_text(json.dumps(old))
            for name in ('WizPetRings.toc', 'WizPetRings_Camelot.toc'):
                (root / name).write_text('## Interface: 16001\nCore.lua\n')
            (root / 'Core.lua').write_text('-- protected action implementation\n')
            responses = [{'commit': {'sha': 'b' * 40}}, {'status': 'ahead', 'files': [
                {'filename': 'Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua'},
                {'filename': 'Interface/AddOns/Blizzard_Map/Map.lua'}]}]
            with patch.object(watch, 'ROOT', root), patch.object(watch, 'PLAN', root / 'dist' / 'plan.json'), patch.object(watch, 'api', side_effect=responses), patch.object(watch, 'raw_version', return_value='1.60.2.70400'):
                watch.prepare()
                plan = json.loads(watch.PLAN.read_text())
                self.assertTrue(plan['changed'])
                self.assertEqual(len(plan['changes']), 3)
                self.assertEqual(len(plan['relevant']), 1)
            self.assertEqual((root / 'Core.lua').read_text(), '-- protected action implementation\n')
            self.assertIn('16002', (root / 'WizPetRings.toc').read_text())


if __name__ == '__main__':
    unittest.main()
