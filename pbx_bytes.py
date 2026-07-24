#!/usr/bin/env python3
import os, sys
os.chdir('/var/mobile/Containers/Shared/AppGroup/.jbroot-97752FEDAA4867A5/var/mobile/终端')

with open('NewTerm.xcodeproj/project.pbxproj', 'rb') as f:
    raw = f.read()

# Look for non-ASCII bytes in first 300 lines
lines = raw.split(b'\n')
print("Total lines:", len(lines))
print("Header line 1:", repr(lines[0]))
print("Header line 2:", repr(lines[1]))

# Show first 30 lines with explicit byte repr to detect embedded characters
for i in range(0, 30):
    line = lines[i]
    has_non_ascii = any(b > 127 for b in line)
    has_ctrl = any(b < 32 and b not in (9,) for b in line)
    marker = ''
    if has_non_ascii: marker += ' NON-ASCII'
    if has_ctrl: marker += ' CTRL'
    if marker:
        print('%d%s:' % (i+1, marker))
        print('  ', repr(line))

# Now look at lines 240-270 with byte-level inspection
print('\n=== lines 240-270 ===')
for i in range(239, 270):
    line = lines[i]
    has_non_ascii = any(b > 127 for b in line)
    has_ctrl = any(b < 32 and b not in (9,) for b in line)
    marker = ''
    if has_non_ascii: marker += ' NON-ASCII'
    if has_ctrl: marker += ' CTRL'
    if marker:
        print('%d%s:' % (i+1, marker))
        print('  ', repr(line))
    else:
        print('%d: %s' % (i+1, line.decode('utf-8', errors='replace')))
