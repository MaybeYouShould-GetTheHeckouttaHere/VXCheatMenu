"""Build the install-only release ZIP using an explicit runtime allowlist."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from build import build


RUNTIME_FILES = (
    'Install.cmd', 'Install.ps1', 'Uninstall.cmd',
    'cheat/ArchivePatch.cs', 'cheat/bootstrap.rvdata2',
    'cheat/core.rb', 'cheat/display.rb', 'cheat/input.dll',
    'cheat/input.rb', 'cheat/storage.rb', 'cheat/translate.rb', 'cheat/ui.rb',
)


def package():
    build()
    root = Path(__file__).resolve().parent
    destination = root / 'dist' / 'VXAceCheatMenuImproved.zip'
    destination.parent.mkdir(exist_ok=True)
    files = [root / name for name in RUNTIME_FILES]
    files.extend(sorted((root / 'cheat/panels').glob('*.rb')))
    if not any(path.parent.name == 'panels' for path in files):
        raise RuntimeError('No menu panels found')
    for path in files:
        if not path.is_file():
            raise FileNotFoundError(path)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.relative_to(root))
    print(destination)


if __name__ == '__main__':
    package()
