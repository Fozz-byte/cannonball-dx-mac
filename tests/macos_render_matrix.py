#!/usr/bin/env python3
"""Bounded real-ROM rendering tests; keeps all mutable data in a temporary folder."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
binary = root / 'build/macos-release/cannonball-dx.app/Contents/MacOS/cannonball-dx'
rom = Path(os.environ['CANNONBALL_ROM_PATH']).resolve()
assert rom.exists(), rom
output = Path(tempfile.mkdtemp(prefix='cannonball-matrix-'))
cases = [
    ('standard-30', 0, 0, 0, 0, 0),
    ('standard-60', 0, 2, 0, 0, 0),
    ('standard-120', 0, 3, 0, 0, 0),
    ('wide-16-9', 1, 2, 0, 0, 0),
    ('wide-21-9', 2, 2, 0, 0, 0),
    ('crt-fast', 0, 2, 1, 0, 0),
    ('crt-full-ntsc', 0, 2, 2, 1, 0),
    ('xbrz-3', 0, 2, 0, 0, 2),
    ('xbrz-4', 0, 2, 0, 0, 3),
    ('xbrz-5', 0, 2, 0, 0, 4),
    ('xbrz-6', 0, 2, 0, 0, 5),
    ('hqx-3', 0, 2, 0, 0, 7),
    ('hqx-4', 0, 2, 0, 0, 8),
]
results = []
for name, aspect, fps, shader, ntsc, scaler in cases:
    state = output / name
    state.mkdir()
    config = ET.Element('config')
    video = ET.SubElement(config, 'video')
    values = dict(mode=0, widescreen=aspect, fps=fps, vsync=0, hires=1,
                  shader_mode=shader, blargg=ntsc, pixel_scaler=scaler,
                  shadow_mask=2 if shader else 0, maskDim=75, maskBoost=125,
                  warpX=12 if shader else 0, warpY=6 if shader else 0)
    for key, value in values.items():
        ET.SubElement(video, key).text = str(value)
    ET.SubElement(ET.SubElement(video, 'window'), 'scale').text = '1'
    ET.SubElement(ET.SubElement(config, 'menu'), 'enabled').text = '0'
    ET.ElementTree(config).write(state / 'config.xml')
    env = dict(os.environ, CANNONBALL_USER_DATA=str(state), CANNONBALL_ROM_PATH=str(rom),
               CANNONBALL_TEST_SECONDS=os.environ.get('CANNONBALL_MATRIX_SECONDS', '10'))
    with (state / 'run.log').open('w') as log:
        run = subprocess.run([str(binary)], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
    text = (state / 'run.log').read_text()
    samples = [float(v) for v in re.findall(r'Measured FPS: ([0-9.]+)', text)]
    result = dict(case=name, exit_code=run.returncode, fps=samples,
                  passed=run.returncode == 0 and bool(samples) and 'Metal renderer:' in text)
    results.append(result)
    (output / 'results.json').write_text(json.dumps(results, indent=2))
    print(json.dumps(result), flush=True)
print(f'Results: {output}', flush=True)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
