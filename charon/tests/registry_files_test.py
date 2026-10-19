#!/usr/bin/env python3
"""Check that the readers of the backports' registry refuse a name that two files give a status.

    tests/registry_files_test.py

A framework's rows live in packages/a/apple-backports/registry/<Framework>.json or in
registry/<Framework>/<part>.json, and every reader of that tree takes both. The gate's reader
(modules/apple/backports.lua) is covered by the light guard's registry_test; this covers the tools that
decide the ledger: tests/backports/tools/surface-diff.py, which the two tools/corpus copies of it
measure against, and tests/backports/tools/probe-exports.py, which asks a release about every constant
and function the registry lists as absent. A name in two files is a contradiction no gate sees through -
whichever file is read last decides the status - so it has to stop the tool, naming both files.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(path):
    """A tool of this repository whose name holds a dash, loaded from its path."""
    spec = importlib.util.spec_from_file_location(path.stem.replace("-", "_"), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def entry(api, status="implemented", kind="function"):
    return {"api": api, "kind": kind, "introduced": "9.0", "status": status, "effect": "none", "reason": "because"}


def registry(root, flat, parts):
    os.makedirs(os.path.join(root, "Fix"), exist_ok=True)
    if flat is not None:
        with open(os.path.join(root, "Fix.json"), "w") as stream:
            json.dump({"framework": "Fix", "entries": flat}, stream)
    for name, rows in parts.items():
        with open(os.path.join(root, "Fix", name), "w") as stream:
            json.dump({"framework": "Fix", "entries": rows}, stream)


def surface_diff(root, flat, parts):
    """What surface-diff.py does with a registry, as its own exit and its own sentence."""
    with tempfile.TemporaryDirectory() as work:
        registry(os.path.join(work, "registry"), flat, parts)
        tool = subprocess.run([sys.executable, str(HERE / "backports" / "tools" / "surface-diff.py"),
                               "--registry", os.path.join(work, "registry"), "Fix"],
                              capture_output=True, text=True)
    return tool.returncode, (tool.stdout + tool.stderr)


def probe_exports(root, flat, parts):
    """What probe-exports.py's registry reader does, which is the part that has no SDK to read first. It
    takes the package root, where its registry folder is, where surface-diff.py takes the folder itself."""
    with tempfile.TemporaryDirectory() as work:
        registry(os.path.join(work, "registry"), flat, parts)
        tool = load(HERE / "backports" / "tools" / "probe-exports.py")
        try:
            return 0, str(tool.registry_names(work))
        except SystemExit as refusal:
            return 1, str(refusal)


def main():
    failures = []
    for name, run in (("surface-diff.py", surface_diff), ("probe-exports.py", probe_exports)):
        code, said = run(None, [entry("fix_one")], {"part.json": [entry("fix_two")]})
        if code != 0:
            failures.append("%s refuses a registry where each name is in one file: %s" % (name, said.strip()))
        code, said = run(None, [entry("fix_both")], {"part.json": [entry("fix_both", "absent")]})
        if code == 0 or "fix_both" not in said or "Fix.json" not in said or "part.json" not in said:
            failures.append("%s must refuse a name in registry/Fix.json and registry/Fix/part.json naming both, and it says: %s"
                            % (name, said.strip()))
        code, said = run(None, [entry("fix_both"), entry("fix_other")], {"part.json": [entry("fix_both")]})
        if code == 0 or "Fix.json" not in said or "part.json" not in said:
            failures.append("%s must refuse a name held by two files however many names each holds, and it says: %s"
                            % (name, said.strip()))
    for failure in failures:
        print("FAIL " + failure)
    print("%d checks, %d failed" % (6, len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
