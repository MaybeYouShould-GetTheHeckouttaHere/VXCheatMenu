import io
from pathlib import Path
import subprocess
import shutil
import re
import struct
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]

def crypt(data, key):
    result = bytearray()
    for index in range(0, len(data), 4):
        mask = struct.pack('<I', key)
        result.extend(byte ^ mask[i] for i, byte in enumerate(data[index:index+4]))
        key = (key * 7 + 3) & 0xffffffff
    return bytes(result)


def make_archive(entries):
    seed = 12345
    key = seed * 9 + 3
    mask = struct.pack('<I', key)
    offset = 12 + sum(16 + len(name.encode()) for name, _ in entries) + 16
    table, payloads = bytearray(), bytearray()
    for index, (name, payload) in enumerate(entries):
        raw = name.encode()
        file_key = index + 257
        table.extend(struct.pack('<4I', *(v ^ key for v in (offset, len(payload), file_key, len(raw)))))
        table.extend(byte ^ mask[i % 4] for i, byte in enumerate(raw))
        payloads.extend(crypt(payload, file_key))
        offset += len(payload)
    table.extend(struct.pack('<4I', key, key, key, key))
    return b'RGSSAD\x00\x03' + struct.pack('<I', seed) + table + payloads


def extract_archive(data):
    key = struct.unpack_from('<I', data, 8)[0] * 9 + 3
    mask = struct.pack('<I', key)
    result, position = {}, 12
    while True:
        offset, size, file_key, length = [v ^ key for v in struct.unpack_from('<4I', data, position)]
        position += 16
        if offset == 0:
            return result
        name = bytes(b ^ mask[i % 4] for i, b in enumerate(data[position:position+length])).decode()
        position += length
        result[name] = crypt(data[offset:offset+size], file_key)


class MarshalReader:
    """Independent reader for the small subset accepted by RGSS script archives."""
    def __init__(self, data):
        self.stream = io.BytesIO(data)

    def long(self):
        c = int.from_bytes(self.stream.read(1), 'little', signed=True)
        if c == 0:
            return 0
        if c > 4:
            return c - 5
        if c < -4:
            return c + 5
        raw = self.stream.read(abs(c))
        return int.from_bytes(raw, 'little') if c > 0 else int.from_bytes(raw, 'little') - (1 << (-c * 8))

    def read(self):
        tag = self.stream.read(1)
        if tag == b'[':
            return [self.read() for _ in range(self.long())]
        if tag == b'i':
            return self.long()
        if tag == b'"':
            return self.stream.read(self.long())
        raise AssertionError(f'Unexpected Marshal tag {tag!r}')


class PackageTests(unittest.TestCase):
    def test_defaults_match_supplied_mv_mz(self):
        source_path = ROOT.parent / 'cheat/js/GlobalShortcut.js'
        if not source_path.is_file():
            self.skipTest('MV reference is not beside this distribution')
        source = source_path.read_text(encoding='utf-8').split('// immutable')[0]
        defaults = dict(re.findall(r"(\w+):\s*\{\s*shortcut:\s*'([^']*)'", source))
        names = {'toggleCheatModal':'toggle','toggleCheatModalToSaveLocationComponent':'locations',
                 'quickSave':'quick_save','quickLoad':'quick_load','openSaveScene':'save',
                 'openLoadScene':'load','gotoTitle':'title','forceVictory':'victory',
                 'forceDefeat':'defeat','forceEscape':'escape','toggleNoClip':'noclip',
                 'enemyWound':'enemy_wound','enemyRecovery':'enemy_recover',
                 'partyWound':'party_wound','partyRecovery':'party_recover',
                 'setSpeed':'speed','skipMessage':'skip'}
        ruby = (ROOT / 'cheat/core.rb').read_text(encoding='utf-8').split('KEY_LABELS')[0]
        actual = dict(re.findall(r"'([^']+)'=>'([^']*)'", ruby))
        self.assertEqual(set(defaults) - set(names), {'openDevTool'})
        self.assertEqual(actual, {names[k]: v for k, v in defaults.items() if k in names})

    def test_bootstrap_archive(self):
        data = (ROOT / 'cheat/bootstrap.rvdata2').read_bytes()
        self.assertEqual(data[:2], b'\x04\x08')
        reader = MarshalReader(data[2:])
        scripts = reader.read()
        self.assertEqual(reader.stream.read(), b'')
        self.assertEqual(len(scripts), 1)
        identifier, name, compressed = scripts[0]
        self.assertIsInstance(identifier, int)
        self.assertEqual(name, b'VXCheat bootstrap')
        self.assertEqual(zlib.decompress(compressed), (ROOT / 'cheat/bootstrap.rb').read_bytes())

    def run_installer(self, root, *args):
        return subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', str(ROOT / 'Install.ps1'), '-GameDirectory', str(root), *args],
            capture_output=True, text=True)

    def fixture(self, root, library='RGSS301.dll'):
        original = f'[Game]\r\nLibrary=System\\{library}\r\nScripts=Data\\Scripts.rvdata2\r\nTitle=Test\r\n'.encode()
        (root / 'Game.ini').write_bytes(original)
        shutil.copytree(ROOT / 'cheat', root / 'cheat')
        return original

    def test_install_idempotence_and_exact_restore(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            original = self.fixture(root)
            result = self.run_installer(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'Game.ini.vxcheat-backup').read_bytes(), original)
            self.assertIn('Scripts=cheat\\bootstrap.rvdata2', (root / 'Game.ini').read_text())
            self.assertEqual((root / 'cheat/original_path.rb').read_text(),
                             "VXCHEAT_ORIGINAL_SCRIPTS = 'Data/Scripts.rvdata2'\n")
            result = self.run_installer(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'Game.ini.vxcheat-backup').read_bytes(), original)
            result = self.run_installer(root, '-Uninstall')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'Game.ini').read_bytes(), original)
            result = self.run_installer(root)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_vx_rejected_without_changes(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            original = self.fixture(root, 'RGSS202E.dll')
            self.assertNotEqual(self.run_installer(root).returncode, 0)
            self.assertEqual((root / 'Game.ini').read_bytes(), original)
            self.assertFalse((root / 'Game.ini.vxcheat-backup').exists())

    def test_existing_backup_preserved(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            original = self.fixture(root)
            (root / 'Game.ini.vxcheat-backup').write_bytes(b'keep this')
            self.assertNotEqual(self.run_installer(root).returncode, 0)
            self.assertEqual((root / 'Game.ini').read_bytes(), original)
            self.assertEqual((root / 'Game.ini.vxcheat-backup').read_bytes(), b'keep this')

    def test_missing_dll_rejected_without_ini_changes(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            original = self.fixture(root)
            (root / 'cheat/input.dll').unlink()
            self.assertNotEqual(self.run_installer(root).returncode, 0)
            self.assertEqual((root / 'Game.ini').read_bytes(), original)
            self.assertFalse((root / 'Game.ini.vxcheat-backup').exists())

    def test_encrypted_install_and_exact_restore(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            original_ini = self.fixture(root)
            original_scripts = b'\x04\x08original scripts fixture'
            entries = [('Data\\Actors.rvdata2', b'actor bytes'),
                       ('Data\\Scripts.rvdata2', original_scripts),
                       ('Graphics\\Picture.png', b'picture bytes' * 32)]
            original_archive = make_archive(entries)
            archive = root / 'Game.rgss3a'
            archive.write_bytes(original_archive)
            result = self.run_installer(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'Game.ini').read_bytes(), original_ini)
            patched = archive.read_bytes()
            content = extract_archive(patched)
            self.assertEqual(content['Data\\Scripts.rvdata2'], (ROOT / 'cheat/bootstrap.rvdata2').read_bytes())
            self.assertEqual(content['Data\\Actors.rvdata2'], entries[0][1])
            self.assertEqual(content['Graphics\\Picture.png'], entries[2][1])
            self.assertEqual((root / 'cheat/original_scripts.rvdata2').read_bytes(), original_scripts)
            self.assertIn('VXCHEAT_ORIGINAL_BYTES_FILE', (root / 'cheat/original_path.rb').read_text())
            result = self.run_installer(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(archive.read_bytes(), patched, 'reinstall appended a second bootstrap')
            result = self.run_installer(root, '-Uninstall')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(archive.read_bytes(), original_archive)
            self.assertEqual((root / 'Game.ini').read_bytes(), original_ini)
            self.assertFalse((root / 'cheat/archive-backup.bin').exists())

    def test_encrypted_restore_refuses_unrelated_changes(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as folder:
            root = Path(folder)
            self.fixture(root)
            original = make_archive([('Data\\Scripts.rvdata2', b'\x04\x08scripts'), ('data', b'asset')])
            archive = root / 'Game.rgss3a'
            archive.write_bytes(original)
            result = self.run_installer(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            changed = bytearray(archive.read_bytes())
            changed[len(original)-1] ^= 1
            archive.write_bytes(changed)
            result = self.run_installer(root, '-Uninstall')
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(archive.read_bytes(), changed)


if __name__ == '__main__':
    unittest.main()
