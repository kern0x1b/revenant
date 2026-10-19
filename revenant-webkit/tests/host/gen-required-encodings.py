#!/usr/bin/env python3
"""Regenerate required-encodings.txt from the engine's ICU codec table.

    tests/host/gen-required-encodings.py
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CODEC_TABLE = ROOT / "webkit-254" / "Source" / "WebCore" / "PAL" / "pal" / "text" / "TextCodecICU.cpp"
OUTPUT = ROOT / "tests" / "host" / "required-encodings.txt"
DECLARATION = re.compile(r'DECLARE_ENCODING_NAME(?:_NO_ALIASES)?\("([^"\n]+)"')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.parse_args()

    try:
        source = CODEC_TABLE.read_text(errors="replace")
    except OSError as error:
        print("gen-required-encodings: cannot read {}: {}".format(CODEC_TABLE, error.strerror), file=sys.stderr)
        return 2
    names = set(DECLARATION.findall(source))
    if not names:
        print("gen-required-encodings: {} declares no encodings".format(CODEC_TABLE), file=sys.stderr)
        return 1
    names.add("UTF-8")
    OUTPUT.write_text("".join(name + "\n" for name in sorted(names)))
    print("{} encodings -> {}".format(len(names), OUTPUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
