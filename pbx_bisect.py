#!/usr/bin/env python3
import subprocess, os, sys

with open('NewTerm.xcodeproj/project.pbxproj','rb') as f:
    data = f.read().decode('utf-8')

lines = data.split('\n')

# Find section boundaries
boundaries = []
for i, line in enumerate(lines):
    if line.startswith('/* End ') or line.startswith('/* Begin '):
        boundaries.append(i)
boundaries.append(len(lines) - 1)

# Test progressively larger boundaries
prev_pass = -1
for b in boundaries:
    chunk = '\n'.join(lines[:b+1])
    if not chunk.endswith('}'):
        chunk += '\n}'
    fname = '/rootfs/tmp/test_pbx.%d.plist' % b
    with open(fname, 'w') as f:
        f.write('// !$*UTF8*$!\n' + chunk)
    r = subprocess.run(['plutil', '-lint', fname], capture_output=True, text=True)
    if r.returncode != 0:
        print('FAIL at line %d (%s): %s' % (b+1, lines[b].strip()[:80], r.stderr.split(chr(10))[0][:200]))
        print('  prev_pass boundary:', prev_pass+1, lines[prev_pass].strip() if prev_pass>=0 else 'START')
        # Now binary search between prev_pass+1 and b
        lo = prev_pass + 1
        hi = b
        while lo < hi - 1:
            mid = (lo + hi) // 2
            chunk = '\n'.join(lines[:mid+1])
            if chunk.rstrip()[-1] != '}':
                chunk += '\n}'
            fname2 = '/rootfs/tmp/test_pbx.mid.%d.plist' % mid
            with open(fname2, 'w') as f:
                f.write('// !$*UTF8*$!\n' + chunk)
            r2 = subprocess.run(['plutil', '-lint', fname2], capture_output=True, text=True)
            if r2.returncode == 0:
                lo = mid
            else:
                hi = mid
            os.unlink(fname2)
        print('First failing line: %d (range %d-%d)' % (hi, prev_pass+2, b+1))
        print('Line %d: %s' % (hi, lines[hi-1] if 0 < hi-1 < len(lines) else 'N/A'))
        # Print 5 lines around the first failure
        for j in range(max(0, hi-3), min(len(lines), hi+2)):
            print('  %d: %s' % (j+1, lines[j][:160]))
        break
    prev_pass = b
else:
    print('All boundaries passed')
