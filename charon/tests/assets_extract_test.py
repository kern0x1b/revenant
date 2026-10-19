#!/usr/bin/env python3
"""Check tools/assets-extract: its command line, its refusal of what is not a catalogue and, given a compiled catalogue
(CHARON_TEST_ASSET_CATALOGUE), that every image the catalogue names comes out as files the plist describes.

    tests/assets_extract_test.py
"""
import json
import os
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "tools" / "assets-extract" / "assets-extract.sh"
found = []


def check(condition, name):
    print(("ok " if condition else "FAIL ") + name)
    if not condition:
        found.append(name)


def run(*arguments):
    return subprocess.run([str(TOOL), *arguments], capture_output=True, text=True)


def main():
    if sys.platform != "darwin" or not Path("/System/Library/PrivateFrameworks/CoreUI.framework").exists():
        print("skipped: assets-extract needs a Mac with CoreUI")
        return 0
    check(run().returncode == 64, "no arguments is a bad command line")
    with tempfile.TemporaryDirectory() as folder:
        not_catalogue = Path(folder) / "Assets.car"
        not_catalogue.write_bytes(b"not a catalogue")
        result = run(str(not_catalogue), str(Path(folder) / "out"))
        check(result.returncode == 65 and "not a compiled asset catalogue" in result.stderr, "a file that is not a catalogue is refused")
        catalogue = os.environ.get("CHARON_TEST_ASSET_CATALOGUE")
        if not catalogue or not Path(catalogue).exists():
            print("skipped the extraction of a catalogue: name one in CHARON_TEST_ASSET_CATALOGUE")
            return 1 if found else 0
        output = Path(folder) / "extracted"
        result = run(catalogue, str(output))
        check(result.returncode == 0 and " images of " in result.stdout, "a catalogue is extracted")
        listing = json.loads(subprocess.run(["assetutil", "--info", catalogue], capture_output=True, text=True).stdout)
        names = {row["Name"] for row in listing[1:] if row.get("AssetType") == "Image" and not row["Name"].startswith("ZZZZ")}
        index = plistlib.loads((output / "AssetCatalogImages.plist").read_bytes())
        icons = plistlib.loads((output / "AssetCatalogIcons.plist").read_bytes())
        missing = sorted(name for name in names if name not in index and name not in icons)
        check(not missing, "every image the catalogue names is extracted: %s" % missing[:5])
        check(not [p for p in output.rglob("*") if "ZZZZPackedAsset" in p.name], "no atlas comes out as an image")
        files = [variant["file"] for variants in index.values() for variant in variants]
        check(files and all((output / name).exists() for name in files), "every file the plist names is there")
        sizes = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(output / files[0])], capture_output=True, text=True).stdout
        first = next(variant for variants in index.values() for variant in variants if variant["file"] == files[0])
        check(str(first["width"]) in sizes and str(first["height"]) in sizes, "the plist gives the pixel size of the file")
        check(all(v["scale"] in (1, 2, 3) and v["idiom"] in ("universal", "phone", "pad") for variants in index.values() for v in variants), "only the scales and idioms of iOS 6 and the later ones asked for")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
