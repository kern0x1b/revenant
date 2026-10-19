#!/usr/bin/env python3
"""Fetch the engine submodule.

    ./fetch-source.py
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ENGINE = ROOT / "webkit-254"


def run(*args):
    return subprocess.run(args, cwd=ROOT, check=True, capture_output=True, text=True).stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.parse_args()

    try:
        subprocess.run(["git", "submodule", "update", "--init", "--depth", "1", ENGINE.name],
                       cwd=ROOT, check=True)
        revision = run("git", "-C", str(ENGINE), "rev-parse", "--short", "HEAD").strip()
        size = run("du", "-sh", str(ENGINE)).split("\t")[0]
    except subprocess.CalledProcessError as error:
        print("fetch-source: {} failed".format(" ".join(error.cmd)), file=sys.stderr)
        return error.returncode
    print("{} at {} ({})".format(ENGINE.name, revision, size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
