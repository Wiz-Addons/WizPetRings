"""Build the installable addon ZIP without machine-specific files or Git data."""
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent
toc = (ROOT / 'WizPetRings_Camelot.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version:\s*(.+)$', toc, re.MULTILINE).group(1).strip()
destination = ROOT / 'dist' / f'WizPetRings-{version}.zip'
destination.parent.mkdir(exist_ok=True)
files = sorted(p for p in ROOT.iterdir() if p.is_file() and
               (p.suffix in {'.lua', '.toc', '.xml', '.md'} or p.name == 'LICENSE'))
files += sorted(p for p in (ROOT / 'Media').rglob('*') if p.is_file())
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, 'WizPetRings/' + file.relative_to(ROOT).as_posix())
print(destination.name)
