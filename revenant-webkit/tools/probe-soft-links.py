#!/usr/bin/env python3
"""Generate a device probe for every constant PAL soft-links.

PAL's soft-linked constant accessors assert when the symbol is not there, so on
an OS this old each absent constant is a crash waiting for the first page that
reaches it. Chasing them one backtrace at a time is endless; this asks the
device for the whole list at once, and the answer is a finite set to guard.
"""
import pathlib
import re
import sys

PAL = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                   "webkit-trunk/Source/WebCore/PAL/pal")

LOCATION = {
    "AVFoundation": "/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
    "CoreMedia": "/System/Library/Frameworks/CoreMedia.framework/CoreMedia",
    "VideoToolbox": "/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox",
    "UIKit": "/System/Library/Frameworks/UIKit.framework/UIKit",
    "Contacts": "/System/Library/Frameworks/Contacts.framework/Contacts",
    "Vision": "/System/Library/Frameworks/Vision.framework/Vision",
    "PassKitCore": "/System/Library/PrivateFrameworks/PassKitCore.framework/PassKitCore",
    "CoreMaterial": "/System/Library/PrivateFrameworks/CoreMaterial.framework/CoreMaterial",
    "MediaExperience": "/System/Library/PrivateFrameworks/MediaExperience.framework/MediaExperience",
    "DataDetectorsUI": "/System/Library/PrivateFrameworks/DataDetectorsUI.framework/DataDetectorsUI",
    "ScreenCaptureKit": "/System/Library/Frameworks/ScreenCaptureKit.framework/ScreenCaptureKit",
    "AppSSO": "/System/Library/PrivateFrameworks/AppSSO.framework/AppSSO",
    "WebPrivacy": "/System/Library/PrivateFrameworks/WebPrivacy.framework/WebPrivacy",
}

pattern = re.compile(r"SOFT_LINK_CONSTANT_(?:MAY_FAIL_)?FOR_HEADER\("
                     r"\s*PAL\s*,\s*([A-Za-z0-9_]+)\s*,\s*([A-Za-z0-9_]+)")

found = set()
for path in PAL.rglob("*.h"):
    for framework, symbol in pattern.findall(path.read_text(errors="replace")):
        found.add((framework, symbol))

by_framework = {}
for framework, symbol in sorted(found):
    by_framework.setdefault(framework, []).append(symbol)

out = ['#include <stdio.h>', '#include <dlfcn.h>', '', 'int main(void)', '{',
       '    void *handle; int missing = 0, present = 0;']
for framework, symbols in sorted(by_framework.items()):
    where = LOCATION.get(framework)
    if not where:
        out.append('    /* %s: install location unknown, skipped */' % framework)
        continue
    out.append('')
    out.append('    handle = dlopen("%s", RTLD_LAZY);' % where)
    out.append('    if (!handle)')
    out.append('        printf("FRAMEWORK MISSING %s\\n");' % framework)
    out.append('    else {')
    for symbol in symbols:
        out.append('        if (dlsym(handle, "%s")) present++;' % symbol)
        out.append('        else { missing++; printf("missing %s %s\\n"); }'
                   % (framework, symbol))
    out.append('    }')
out += ['', '    printf("present %d missing %d\\n", present, missing);',
        '    return 0;', '}']
print("\n".join(out))
