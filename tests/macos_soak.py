#!/usr/bin/env python3
"""Real-ROM default-preset soak. Launch through script/build_and_run.sh --soak."""
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import time
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
preset = os.environ.get('CANNONBALL_PRESET', 'macos-release')
assert preset == 'macos-release', 'Performance measurement requires Release'
seconds = int(os.environ.get('CANNONBALL_SOAK_SECONDS', '1800'))
assert seconds >= 10
rom = Path(os.environ['CANNONBALL_ROM_PATH']).resolve()
assert rom.is_file() or rom.is_dir()
out = root / 'test-results' / time.strftime('soak-%Y%m%d-%H%M%S')
out.mkdir(parents=True)
state = out / 'state'
state.mkdir()
config = ET.Element('config')
video = ET.SubElement(config, 'video')
for key, value in dict(mode=0, widescreen=0, fps=2, vsync=0, hires=1,
                       shader_mode=0, blargg=0, pixel_scaler=0).items():
    ET.SubElement(video, key).text = str(value)
ET.SubElement(ET.SubElement(video, 'window'), 'scale').text = '2'
ET.SubElement(ET.SubElement(config, 'menu'), 'enabled').text = '0'
ET.ElementTree(config).write(state / 'config.xml')
binary = root / 'build' / preset / 'cannonball-dx.app/Contents/MacOS/cannonball-dx'
metadata = dict(binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                preset=preset, scenario='animated attract/demo, 4:3, 60 fps, window scale 2, vsync off',
                os=subprocess.check_output(['sw_vers'], text=True),
                power=subprocess.check_output(['pmset', '-g', 'batt'], text=True))
(out/'environment.json').write_text(json.dumps(metadata, indent=2))
env = dict(os.environ, CANNONBALL_USER_DATA=str(state), CANNONBALL_ROM_PATH=str(rom),
           CANNONBALL_TEST_SECONDS=str(seconds), CANNONBALL_SOAK='1')
for test in ['--metal-self-test', '--audio-self-test']:
    result = subprocess.run([str(binary), test], env=env, capture_output=True, text=True, timeout=30)
    (out/(test[2:]+'.log')).write_text(result.stdout+result.stderr)
    assert result.returncode == 0, f'{test} failed; see {out}'
print(f'Soak output: {out}', flush=True)
started = time.monotonic()
samples = []
with (out/'run.log').open('w') as log:
    process = subprocess.Popen([str(binary)], env=env, stdout=log, stderr=subprocess.STDOUT)
    # Keep this bounded test awake, without changing persistent system settings.
    awake = subprocess.Popen(['/usr/bin/caffeinate', '-di', '-w', str(process.pid)])
    try:
        while process.poll() is None:
            elapsed = time.monotonic()-started
            if elapsed > seconds+60:
                process.kill()
                raise TimeoutError('Soak did not shut down on time')
            ps = subprocess.run(['ps', '-p', str(process.pid), '-o', 'rss=,%cpu='], capture_output=True, text=True)
            fields = ps.stdout.split()
            if len(fields) == 2:
                samples.append(dict(seconds=round(elapsed, 2), rss_kib=int(fields[0]), cpu_percent=float(fields[1])))
                (out/'resources.json').write_text(json.dumps(samples, indent=2))
            if len(samples) % 12 == 1:
                therm = subprocess.run(['pmset', '-g', 'therm'], capture_output=True, text=True)
                with (out/'thermal.log').open('a') as thermal:
                    thermal.write(f'\nElapsed {elapsed:.1f}s\n{therm.stdout}{therm.stderr}')
                print(f'Elapsed {elapsed:.0f}s; RSS {fields[0] if fields else "?"} KiB', flush=True)
            time.sleep(5)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        awake.terminate()
        awake.wait()
elapsed = time.monotonic()-started
text = (out/'run.log').read_text()
fps = [float(v) for v in re.findall(r'Measured FPS: ([0-9.]+)', text)]
metrics = [dict((k,float(v)) for k,v in re.findall(r'(\w+)=([0-9.]+)', line))
           for line in text.splitlines() if line.startswith('Soak metrics:')]
(out/'metrics.json').write_text(json.dumps(metrics, indent=2))
# Exclude startup and report trends; never treat process survival alone as success.
warm = [s for s in samples if s['seconds'] >= 60]
steady = [f for f,m in zip(fps, metrics) if m['seconds'] >= 60]
last = metrics[-1] if metrics else {}
first = next((m for m in metrics if m['seconds'] >= 60), last)
result = dict(duration_requested=seconds, elapsed=round(elapsed, 2), exit_code=process.returncode,
              fps_samples=len(fps), steady_fps_median=statistics.median(steady) if steady else None,
              steady_fps_min=min(steady) if steady else None,
              steady_fps_below_57=sum(f<57 for f in steady),
              rss_first_kib=warm[0]['rss_kib'] if warm else None,
              rss_final_kib=warm[-1]['rss_kib'] if warm else None,
              rss_max_kib=max((s['rss_kib'] for s in warm), default=None),
              last_metrics=last,
              steady_audio_underruns=last.get('audio_underruns', 0)-first.get('audio_underruns', 0))
result['passed'] = (process.returncode == 0 and elapsed >= seconds and bool(metrics)
                    and last.get('seconds', 0) >= seconds-5 and last.get('paused', 1) == 0
                    and last.get('audio_callbacks', 0) > seconds*50
                    and result['steady_audio_underruns'] == 0
                    and (not steady or (result['steady_fps_median'] >= 59
                         and result['steady_fps_below_57'] <= max(1, len(steady)*0.01)))
                    and not re.search(r'Metal.*failed|runtime error:|ERROR: AddressSanitizer', text))
(out/'result.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2), flush=True)
raise SystemExit(0 if result['passed'] else 1)
