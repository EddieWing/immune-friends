"""Run registered Godot regressions; browser cases must be verified separately."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--suite', choices=['smoke', 'full'], default='smoke')
parser.add_argument('--case', help='Run automated checks related to RG-NNN')
parser.add_argument('--status', action='store_true', help='Count commits since last round')
parser.add_argument('--list', action='store_true', help='List selected tests without executing')
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'D:/Create/Godot/Godot_v4.7.2-stable_win64_console.exe' if os.name == 'nt' else 'godot'))
parser.add_argument('--timeout', type=int, default=180)
args = parser.parse_args()
manifest = json.loads((HERE / 'regression.json').read_text(encoding='utf-8'))
out_root = ROOT / '.build/regression'

def git(*arguments):
    result = subprocess.run(['git', '-C', str(ROOT), *arguments], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None

if args.status:
    checkpoint = out_root / 'checkpoint.json'
    baseline = json.loads(checkpoint.read_text())['commit'] if checkpoint.exists() else manifest['baseline_commit']
    count = git('rev-list', '--first-parent', '--count', f'{baseline}..HEAD')
    if count is None or git('merge-base', '--is-ancestor', baseline, 'HEAD') is None:
        print('UNKNOWN: baseline is unavailable or not an ancestor; compare with the published branch.')
        sys.exit(2)
    print(f'{count} commits since {baseline[:7]}; target approximately {manifest["cadence_commits"]}.')
    print('DUE' if int(count) >= manifest['cadence_commits'] else 'Not due by count; risky changes may require an earlier round.')
    print('Full round = automated suite + browser checklist; automated success alone is insufficient.')
    sys.exit(0)

names = manifest['suites'][args.suite]
if args.case:
    case = next((case for case in manifest['cases'] if case['id'] == args.case), None)
    if case is None:
        parser.error('Unknown case ID')
    names = case['automated_tests']
    print(f'{case["id"]}: {case["title"]}')
    if not names:
        print('MANUAL: no automated coverage. Execute the recorded browser steps.')
        sys.exit(2)
missing = [name for name in names if not (HERE / f'{name}.gd').is_file()]
if missing:
    parser.error('Missing scripts: ' + ', '.join(missing))
if args.list:
    print('\n'.join(names))
    sys.exit(0)

stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
output = out_root / stamp
output.mkdir(parents=True)
env = os.environ.copy()
# Separate save/config directory for every run; never touch the player's profile.
profile = output / 'profile'
profile.mkdir()
env['APPDATA'] = str(profile)
env['XDG_DATA_HOME'] = str(profile)
env['XDG_CONFIG_HOME'] = str(profile)
results = []
for name in names:
    started = time.monotonic()
    try:
        result = subprocess.run([args.godot, '--headless', '--path', str(ROOT / 'game'), '--script', f'res://tests/{name}.gd'], env=env, capture_output=True, encoding='utf-8', errors='replace', timeout=args.timeout)
        log = result.stdout + result.stderr
        failed = result.returncode != 0 or re.search(r'SCRIPT ERROR|Assertion failed|^FAIL(?:\b|:)', log, re.M)
        status = 'Failed' if failed else 'Passed'
    except subprocess.TimeoutExpired as error:
        log = str(error)
        status = 'Timed Out'
    except OSError as error:
        log = str(error)
        status = 'Blocked'
    (output / f'{name}.log').write_text(log, encoding='utf-8')
    results.append({'test': name, 'status': status, 'seconds': round(time.monotonic() - started, 3)})
    print(name, status, flush=True)
    if status == 'Blocked':
        break
passed = len(results) == len(names) and all(row['status'] == 'Passed' for row in results)
report = {'commit': git('rev-parse', 'HEAD'), 'dirty': bool(git('status', '--porcelain', '--untracked-files=no')), 'started_utc': stamp, 'suite': args.suite, 'case': args.case, 'automatic_result': 'Passed' if passed else 'Failed', 'browser_result': 'Not Run', 'results': results}
(output / 'results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('Report:', output / 'results.json')
print('Browser cases remain separate. This run does not advance the full-round checkpoint.')
sys.exit(0 if passed else 1)
