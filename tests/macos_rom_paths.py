#!/usr/bin/env python3
"""Validate ZIP, loose files, and failure paths without putting ROMs in the repo."""
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile
root = Path(__file__).resolve().parents[1]
binary = root / 'build/macos-release/cannonball-dx.app/Contents/MacOS/cannonball-dx'
archive = Path(os.environ['CANNONBALL_ROM_PATH']).resolve()
work = Path(tempfile.mkdtemp(prefix='cannonball-rom-check-'))
loose = work / 'Loose ROMs with spaces'
loose.mkdir()
with zipfile.ZipFile(archive) as z:
    for info in z.infolist():
        if info.is_dir():
            continue
        destination = (loose / info.filename).resolve()
        assert destination.is_relative_to(loose.resolve()), 'Unsafe ZIP entry'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(z.read(info))
empty = work / 'empty'
empty.mkdir()
corrupt = work / 'corrupt.zip'
corrupt.write_bytes(b'not a ZIP archive')
for name, path, expected in [('zip', archive, 0), ('loose', loose, 0),
                             ('missing', work / 'missing.zip', 2),
                             ('empty', empty, 2), ('corrupt', corrupt, 2)]:
    env = dict(os.environ, CANNONBALL_USER_DATA=str(work/name/'state'), CANNONBALL_ROM_PATH=str(path))
    run = subprocess.run([str(binary), '--check-roms'], env=env, capture_output=True, text=True, timeout=30)
    (work/(name+'.log')).write_text(run.stdout+run.stderr)
    assert run.returncode == expected, f'{name}: exit {run.returncode}; see {work}'
    print(f'{name}: PASS', flush=True)
print(f'Validation data: {work}')
