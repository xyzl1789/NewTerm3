#!/usr/bin/env python3
import subprocess, os, sys

with open('NewTerm.xcodeproj/project.pbxproj','rb') as f:
    data = f.read().decode('utf-8')

lines = data.split('\n')

# plutil reports the error at "line 264" in the FULL file.
# Strategy: truncate to first N lines, append enough closing braces, check if plutil errors.
# But naive truncation closes dicts early so may pass even with an early error.
# Better strategy: take the FULL file and try removing pairs of lines, see if the error line shifts.
# OR: try inserting a known-good key right before line 264's entry. If still fails at 264, the error is AFTER. If it goes away, the error was BEFORE.

# Simplest first approach: try plutil on lines 1..N for N=263,264,265
for N in [262, 263, 264, 265, 266, 270, 280, 290, 300]:
    chunk = '\n'.join(lines[:N])
    if not chunk.rstrip().endswith('}'):
        chunk += '\n}'
    fname = '/rootfs/tmp/head.%d.plist' % N
    with open(fname, 'w') as f:
        f.write('// !$*UTF8*$!\n' + chunk)
    r = subprocess.run(['plutil', '-lint', fname], capture_output=True, text=True)
    err_line = ''
    for line in r.stderr.split('\n'):
        if 'line' in line:
            err_line = line.strip()[:180]
            break
    print('N=%d rc=%d %s' % (N, r.returncode, err_line if err_line else 'OK'))
    os.unlink(fname)
