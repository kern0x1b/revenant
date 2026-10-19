#!/usr/bin/env python3
"""Apply the Rev class prefix to a linker exported-symbols list.

The classes are renamed by a force-included header, which the .exp file knows
nothing about, so every _OBJC_CLASS_$_Foo it names has to be renamed too.
"""
import re
import sys

header, source, dest = sys.argv[1:4]

renames = dict(re.findall(r'^#define (\w+) (Rev\w+)$', open(header).read(), re.M))

out = []
for line in open(source):
    m = re.match(r'^(_OBJC_(?:CLASS|METACLASS|IVAR)_\$_)(\w+?)(\..*)?$', line.strip())
    if m and m.group(2) in renames:
        line = m.group(1) + renames[m.group(2)] + (m.group(3) or '') + '\n'
    out.append(line)

open(dest, 'w').writelines(out)
print(f'{sum(1 for a, b in zip(out, open(source)) if a != b)} symbols renamed')
