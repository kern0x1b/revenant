#!/usr/bin/env python3
"""List the selectors a class answers to, read out of a Mach-O's ObjC metadata.

    tools/objc-surface.py <binary> <ClassName>

Covers the class, its metaclass and every category on it, which is what the
runtime would report. Prints one selector per line, '-' for instance methods
and '+' for class methods.
"""
import re
import subprocess
import sys


def otool(binary):
    out = subprocess.run(["otool", "-arch", "armv7", "-oV", binary],
                         capture_output=True, text=True)
    if out.returncode:
        sys.exit(out.stderr.strip() or "otool failed")
    return out.stdout.splitlines()


CLASS_START = re.compile(r"^[0-9a-f]+ 0x[0-9a-f]+ _OBJC_(META)?CLASS_\$_(\S+)")
CATEGORY_CLS = re.compile(r"^\s+cls\s+0x[0-9a-f]+ _OBJC_CLASS_\$_(\S+)")
METHOD_LIST = re.compile(r"^\s+(baseMethods|instanceMethods|classMethods)\s+(\S+)")
METHOD_NAME = re.compile(r"^\s+name\s+0x[0-9a-f]+ (.*)$")


def selectors(lines, wanted):
    found = set()
    owner = None          # class the current block belongs to
    is_meta = False       # class methods rather than instance methods
    collecting = None     # '+' or '-' while inside a method list

    for line in lines:
        if line.startswith("Contents of"):
            owner, is_meta, collecting = None, False, None
            continue

        start = CLASS_START.match(line)
        if start:
            owner, is_meta, collecting = start.group(2), False, None
            continue

        if line == "Meta Class":
            is_meta, collecting = True, None
            continue

        category = CATEGORY_CLS.match(line)
        if category:
            owner, is_meta, collecting = category.group(1), False, None
            continue

        block = METHOD_LIST.match(line)
        if block:
            kind = block.group(1)
            if kind == "classMethods":
                collecting = "+"
            elif kind == "instanceMethods":
                collecting = "-"
            else:
                collecting = "+" if is_meta else "-"
            if block.group(2) == "0x0":
                collecting = None
            continue

        if collecting and owner == wanted:
            name = METHOD_NAME.match(line)
            if name:
                found.add(collecting + name.group(1))
                continue

        if collecting and re.match(r"^\s+(?!name|types|imp|entsize|count)\S", line):
            collecting = None

    return found


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    binary, wanted = sys.argv[1], sys.argv[2]
    for selector in sorted(selectors(otool(binary), wanted)):
        print(selector)


if __name__ == "__main__":
    main()
