import importlib.util
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('sweep_temp_aliases',Path(__file__).parents[1]/'tools/sweep_ios_sdk.py')
sweep=importlib.util.module_from_spec(spec);spec.loader.exec_module(sweep)

class TempAliasTests(unittest.TestCase):
    def test_actual_tempfile_path_without_resolving_alias(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);target=root/'receipt.json'
            sweep.atomic(target,{'actualTempfile':True})
            self.assertEqual(json.loads(target.read_text()),{'actualTempfile':True})
            temporary=sweep.exclusive_temp(root/'record.jsonl')
            self.assertTrue(temporary.exists());temporary.unlink()
    def test_actual_tmp_alias_is_supported_as_ancestor(self):
        with tempfile.TemporaryDirectory(dir='/tmp') as directory:
            target=Path(directory)/'receipt.json';sweep.atomic(target,{'ok':True})
            self.assertEqual(json.loads(target.read_text()),{'ok':True})
    def test_user_alias_to_system_temp_is_still_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);link=root/'user-link';link.symlink_to('/private/tmp' if sys.platform=='darwin' else '/tmp',target_is_directory=True)
            with self.assertRaisesRegex(ValueError,'symlink'):sweep.reject_symlinks(link/'never-written')
            self.assertFalse(sweep.trusted_system_alias(link))
    def test_exact_output_symlink_is_not_allowed(self):
        if Path('/tmp').is_symlink():
            with self.assertRaisesRegex(ValueError,'symlink output'):sweep.reject_symlinks(Path('/tmp'))
        else:self.assertFalse(sweep.trusted_system_alias(Path('/tmp')))
    def test_untrusted_alias_owner_target_and_private_permissions(self):
        root_link=SimpleNamespace(st_uid=0,st_mode=stat.S_IFLNK|0o777)
        user_link=SimpleNamespace(st_uid=501,st_mode=stat.S_IFLNK|0o777)
        private=SimpleNamespace(st_uid=0,st_mode=stat.S_IFDIR|0o755)
        writable_private=SimpleNamespace(st_uid=0,st_mode=stat.S_IFDIR|0o777)
        with patch.object(sweep.sys,'platform','darwin'):
            with patch.object(sweep.os,'lstat',return_value=user_link):self.assertFalse(sweep.trusted_system_alias(Path('/var')))
            with patch.object(sweep.os,'lstat',return_value=root_link),patch.object(sweep.os,'readlink',return_value='/private/tmp'):
                self.assertFalse(sweep.trusted_system_alias(Path('/var')))
            with patch.object(sweep.os,'lstat',side_effect=[root_link,writable_private,private]),patch.object(sweep.os,'readlink',return_value='private/var'):
                self.assertFalse(sweep.trusted_system_alias(Path('/var')))
            with patch.object(sweep.os,'lstat',side_effect=[root_link,private,user_link]),patch.object(sweep.os,'readlink',return_value='private/var'):
                self.assertFalse(sweep.trusted_system_alias(Path('/var')))

if __name__=='__main__':unittest.main()
