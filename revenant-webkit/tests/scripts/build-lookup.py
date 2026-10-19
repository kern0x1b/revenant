#!/usr/bin/env python3
"""Check how the tests find the engine build, without a phone or a build.

    tests/scripts/build-lookup.py

The port keeps no rule of its own for this: it takes the engine build Charon
names and keeps only ENGINE_BUILD as an override. What is checked here is that
it asks the driver and nothing else - trees the port's old marker search took,
and the driver does not, are refused. The engine build itself is defined and
tested in the toolchain.
"""
import importlib.util
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = Path("conan") / "charon-deps.env"


def tests_module():
    spec = importlib.util.spec_from_file_location("revenant_run_tests", ROOT / "tests" / "run-tests.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def environment(root: Path, *parts: str) -> Path:
    folder = root.joinpath(*parts)
    (folder / MARKER.parent).mkdir(parents=True, exist_ok=True)
    (folder / MARKER).write_text("CHARON_HOST_LIBCXX=/nowhere\n")
    return folder


def built(root: Path, *parts: str) -> Path:
    tree = environment(root, *parts)
    (tree / "CMakeCache.txt").write_text("")
    framework = tree / "stage" / "Frameworks" / "Engine.framework"
    framework.mkdir(parents=True)
    (framework / "Engine").write_text("")
    return tree


def report(passed: bool, claim: str) -> bool:
    print("{:<6} {}".format("ok" if passed else "FAIL", claim))
    return passed


def refusal(call) -> str:
    try:
        call()
    except SystemExit as stop:
        return str(stop)
    return ""


def main() -> int:
    tests = tests_module()
    os.environ.pop("ENGINE_BUILD", None)
    verdicts = []

    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        only = built(root, "build", "system")
        verdicts.append(report(tests.default_engine_build(root) == only,
                               "the one built engine directly under build/ is the answer"))

        os.environ["ENGINE_BUILD"] = str(root / "somewhere-else")
        verdicts.append(report(tests.default_engine_build(root) == root / "somewhere-else",
                               "ENGINE_BUILD names the build and the driver is not asked"))
        os.environ.pop("ENGINE_BUILD")

    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        retired = built(root, "build", "engine", "armv7-system")
        said = refusal(lambda: tests.default_engine_build(root))
        verdicts.append(report("ENGINE_BUILD" in said,
                               "{} is built but not directly under build/, so that layout is retired, not "
                               "searched: {}".format(retired.relative_to(root), said or "it was taken")))

    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        packages = environment(root, "build", "system-imports")
        said = refusal(lambda: tests.default_engine_build(root))
        verdicts.append(report("ENGINE_BUILD" in said,
                               "{} holds a dependency environment and a variant in its name, and is not an "
                               "engine build: {}".format(packages.relative_to(root), said or "it was taken")))

    with tempfile.TemporaryDirectory() as folder:
        said = refusal(lambda: tests.default_engine_build(Path(folder)))
        verdicts.append(report("ENGINE_BUILD" in said,
                               "no tree at all refuses and says so: " + (said or "it did not")))

    print("build lookup intact" if all(verdicts) else "BUILD LOOKUP BROKEN")
    return 0 if all(verdicts) else 1


if __name__ == "__main__":
    sys.exit(main())
