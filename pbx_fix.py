#!/usr/bin/env python3
import plistlib
import subprocess, os, sys

os.chdir('/var/mobile/Containers/Shared/AppGroup/.jbroot-97752FEDAA4867A5/var/mobile/终端')

with open('NewTerm.xcodeproj/project.pbxproj', 'rb') as f:
    data = f.read()

try:
    root = plistlib.loads(data)
    print("plistlib parse OK")
    print("Top keys:", list(root.keys()))
    objects = root.get('objects', {})
    print("Objects count:", len(objects))
except Exception as e:
    print("plistlib parse failed:", e)
    sys.exit(0)

with open('/rootfs/tmp/pbx_out.plist', 'wb') as f:
    plistlib.dump(root, f, fmt=plistlib.FMT_XML)

print("Written XML. Linting...")
r = subprocess.run(['plutil', '-lint', '/rootfs/tmp/pbx_out.plist'], capture_output=True, text=True)
print("rc:", r.returncode, r.stderr[:200])

# Also convert back to OpenStep format (old-style)
with open('/rootfs/tmp/pbx_out2.plist', 'wb') as f:
    plistlib.dump(root, f, fmt=plistlib.FMT_OPENSTEP)

print("Written OpenStep. Linting...")
r = subprocess.run(['plutil', '-lint', '/rootfs/tmp/pbx_out2.plist'], capture_output=True, text=True)
print("rc:", r.returncode, r.stderr[:200])
print("Size:", os.path.getsize('/rootfs/tmp/pbx_out2.plist'))
