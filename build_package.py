"""Package the installable payload and source; exclude local settings and validators."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from build import build


def package():
    build()
    root = Path(__file__).resolve().parent
    destination = root / 'dist' / 'VXAceCheatMenuImproved.zip'
    destination.parent.mkdir(exist_ok=True)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob('*')):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if any(part in ('.validation', '__pycache__', 'cheat-settings', 'dist', '.git') for part in relative.parts):
                continue
            if path.name in ('original_path.rb', 'original_scripts.rvdata2', 'archive-backup.bin', '.gitignore') or path.name.endswith('-x86.a'):
                continue
            archive.write(path, relative)
    print(destination)


if __name__ == '__main__':
    package()
