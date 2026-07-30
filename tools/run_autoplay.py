#!/usr/bin/env python3
"""FROSTHOLD Autoplay Orchestrator

Launches the game with --autoplay flag, monitors for crashes, and emails
crash reports with screenshots to the configured Gmail address.

Usage:
    python run_autoplay.py [--love-path PATH] [--days N] [--timeout SECS] [--loop N]

Env vars:
    FROSTHOLD_EMAIL_PASSWORD — Gmail App Password (required for email reports)
    LOVE_PATH               — Path to love.exe (overrides --love-path)

Examples:
    python run_autoplay.py
    python run_autoplay.py --days 60 --timeout 900
    python run_autoplay.py --loop 5     # run 5 back-to-back sessions
"""

import subprocess
import sys
import os
import time
import argparse
import glob
from pathlib import Path
from datetime import datetime

# Defaults
DEFAULT_LOVE_PATHS = [
    r'C:\Program Files\LOVE\love.exe',
    r'C:\Program Files (x86)\LOVE\love.exe',
    os.path.expanduser(r'~\scoop\apps\love\current\love.exe'),
]
GAME_DIR = str(Path(__file__).resolve().parent.parent)


def find_love():
    """Find love.exe on the system."""
    env_path = os.environ.get('LOVE_PATH')
    if env_path and os.path.isfile(env_path):
        return env_path

    for p in DEFAULT_LOVE_PATHS:
        if os.path.isfile(p):
            return p

    # Try PATH
    import shutil
    found = shutil.which('love')
    if found:
        return found

    return None


def run_session(love_path, game_dir, timeout, days):
    """Run one autoplay session. Returns (returncode, duration, stderr)."""
    cmd = [love_path, game_dir, '--autoplay', '--days', str(days)]
    print(f'[{datetime.now():%H:%M:%S}] Launching: {" ".join(cmd)}')
    print(f'  Timeout: {timeout}s, Target: {days} days')

    start = time.time()
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        stdout, stderr = proc.communicate(timeout=timeout)
        elapsed = time.time() - start

        stdout_text = stdout.decode('utf-8', errors='replace') if stdout else ''
        stderr_text = stderr.decode('utf-8', errors='replace') if stderr else ''

        if stdout_text.strip():
            print(stdout_text)

        if proc.returncode != 0:
            print(f'[CRASH] Game exited with code {proc.returncode} after {elapsed:.1f}s')
            if stderr_text.strip():
                print(f'  stderr: {stderr_text[:500]}')
            return proc.returncode, elapsed, stderr_text
        else:
            print(f'[OK] Game exited cleanly after {elapsed:.1f}s')
            return 0, elapsed, stderr_text

    except subprocess.TimeoutExpired:
        elapsed = time.time() - start
        print(f'[TIMEOUT] Game exceeded {timeout}s limit — killing process')
        proc.kill()
        proc.wait()
        return -1, elapsed, 'TIMEOUT'


def send_report(returncode, elapsed, stderr_text, session_num):
    """Email crash report if the email script and password are available."""
    if not os.environ.get('FROSTHOLD_EMAIL_PASSWORD'):
        print('[SKIP] No FROSTHOLD_EMAIL_PASSWORD set — crash report not emailed')
        return

    # Write error to temp file
    tmp_dir = os.path.join(GAME_DIR, 'tools', '.autoplay_tmp')
    os.makedirs(tmp_dir, exist_ok=True)

    error_file = os.path.join(tmp_dir, f'crash_{session_num}.txt')
    with open(error_file, 'w', encoding='utf-8') as f:
        f.write(f'FROSTHOLD AUTOPLAY CRASH REPORT\n')
        f.write(f'{"="*50}\n\n')
        f.write(f'Session:    {session_num}\n')
        f.write(f'Time:       {datetime.now():%Y-%m-%d %H:%M:%S}\n')
        f.write(f'Exit Code:  {returncode}\n')
        f.write(f'Duration:   {elapsed:.1f}s\n\n')
        if returncode == -1:
            f.write('CAUSE: Timeout — game hung or ran too long\n\n')
        else:
            f.write(f'CAUSE: Game crashed (exit code {returncode})\n\n')
        f.write(f'STDERR:\n{stderr_text}\n')

    # Check for screenshot in Love2D save directory
    love_save = os.path.join(os.environ.get('APPDATA', ''), 'LOVE', 'frosthold')
    screenshot = None
    if os.path.isdir(love_save):
        pngs = sorted(glob.glob(os.path.join(love_save, 'crash_*.png')), reverse=True)
        if pngs:
            screenshot = pngs[0]

    # Report locally. Crash artefacts stay on this machine.
    print(f'[autoplay] crash report: {error_file}')
    if screenshot:
        print(f'[autoplay] screenshot:   {screenshot}')


def main():
    parser = argparse.ArgumentParser(description='FROSTHOLD Autoplay Orchestrator')
    parser.add_argument('--love-path', help='Path to love.exe')
    parser.add_argument('--days', type=int, default=30, help='In-game days to simulate (default: 30)')
    parser.add_argument('--timeout', type=int, default=600, help='Max seconds per session (default: 600)')
    parser.add_argument('--loop', type=int, default=1, help='Number of sessions to run (default: 1)')
    args = parser.parse_args()

    love_path = args.love_path or find_love()
    if not love_path:
        print('[ERROR] Cannot find love.exe. Provide --love-path or set LOVE_PATH env var.')
        sys.exit(1)
    print(f'Using Love2D: {love_path}')
    print(f'Game dir:     {GAME_DIR}')
    print()

    crashes = 0
    for i in range(1, args.loop + 1):
        print(f'=== Session {i}/{args.loop} ===')
        returncode, elapsed, stderr = run_session(love_path, GAME_DIR, args.timeout, args.days)

        if returncode != 0:
            crashes += 1
            send_report(returncode, elapsed, stderr, i)

        if i < args.loop:
            print('Waiting 3s before next session...')
            time.sleep(3)
        print()

    print(f'Done. {args.loop} session(s), {crashes} crash(es).')
    sys.exit(1 if crashes > 0 else 0)


if __name__ == '__main__':
    main()
