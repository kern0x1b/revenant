#!/usr/bin/env python3
"""The host checks and the JavaScript batteries, as tiers Charon runs.

    charon test --tier host
    charon test --tier batteries

Charon installs what a tier declares and hands it over, so the tiers are run
through it. The one direct call is the batteries, against the engine build
Charon names or against a tree it does not manage:

    ENGINE_BUILD=/path/to/build tests/run-tests.py
"""
import argparse
import hashlib
import logging
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import NamedTuple

ROOT = Path(__file__).resolve().parents[1]


def harness():
    folder = str(ROOT / "tests" / "device")
    if folder not in sys.path:
        sys.path.insert(0, folder)
    import harness as loaded
    return loaded


def transport():
    return harness().transport()

MARKER = Path("conan") / "charon-deps.env"
DEVICE_DIR = "/tmp/jscrun"
FRAMEWORKS = ("JavaScriptCore", "WebCore", "WebKitLegacy")
LIBCXX = {"libc++.1.0.dylib": "libc++.1.dylib", "libc++abi.1.0.dylib": "libc++abi.1.dylib"}
VERDICT = re.compile(r"ALL OK|FAILURE", re.IGNORECASE)
BROKEN = re.compile(r"^FAIL|Exception|Segmentation", re.IGNORECASE)
REPORTED = re.compile(r"^FAIL|Exception|Segmentation|FAILURE", re.IGNORECASE)

log = logging.getLogger("run-tests")


class DependencyInstallError(Exception):
    pass


class Verdict(NamedTuple):
    status: str
    line: str
    failed: bool
    reported: list


def read_env_file(path: Path) -> dict:
    values = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].lstrip()
        key, sep, value = line.partition("=")
        if not sep:
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def install_dependencies(argv: list, log_path: Path, env_file, required: tuple, env=None) -> dict:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("wb") as install_log:
        try:
            subprocess.run([str(part) for part in argv], stdout=install_log, stderr=subprocess.STDOUT,
                           env=env, check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            raise DependencyInstallError(f"conan install failed, see {log_path}") from error
    env_file = env_file() if callable(env_file) else env_file
    if not env_file.is_file():
        raise DependencyInstallError(f"conan install left no {env_file}, see {log_path}")
    libraries = read_env_file(env_file)
    missing = [key for key in required if key not in libraries]
    if missing:
        raise DependencyInstallError(f"{env_file} has no {', '.join(missing)}")
    return libraries


def recipe_and_profile(build: Path) -> tuple:
    written = build / "charon"
    if (written / "conanfile.py").is_file() and (written / "profile").is_file():
        return written, written / "profile"
    raise DependencyInstallError(
        f"{written} holds no generated recipe and profile - "
        "run charon build, so the libraries the batteries need can be installed")


def device_libraries(root: Path, build: Path) -> dict:
    where, profile = recipe_and_profile(build)
    return install_dependencies(
        ["conan", "install", where, "-pr:h", profile, "-pr:b", "default", "--build=missing"],
        root / "build" / "deps-install.log",
        build / MARKER,
        ("CHARON_HOST_LIBCXX",), env=dict(os.environ))


def as_text(value) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return value or ""


def relay_stderr(result: subprocess.CompletedProcess) -> None:
    sys.stderr.write(as_text(result.stderr))
    sys.stderr.flush()


def print_last_lines(argv: list, count: int) -> bool:
    try:
        result = subprocess.run([str(part) for part in argv], stdout=subprocess.PIPE, text=True, errors="replace")
    except OSError as error:
        log.error("%s: %s", argv[0], error.strerror)
        return False
    for line in result.stdout.splitlines()[-count:]:
        print(line)
    return result.returncode == 0


def run_host_tests(root: Path, packages: dict) -> int:
    speak()
    if "icu" not in packages:
        log.error("host tests: the tier installed %s and none of them is icu",
                  ", ".join(sorted(packages)) or "nothing")
        return 1
    icu = Path(packages["icu"])

    failures = 0
    binaries = Path(os.environ.get("TMPDIR") or "/tmp") / "revenant-tests"
    binaries.mkdir(parents=True, exist_ok=True)
    host = root / "tests" / "host"

    subprocess.run([sys.executable, str(host / "gen-required-encodings.py")], stdout=subprocess.DEVNULL)

    for name in ("icu-sanity", "icu-locales"):
        try:
            subprocess.run(["clang++", "-o", str(binaries / name), str(host / f"{name}.cpp"),
                            "-I", str(icu / "include"), "-L", str(icu / "lib"),
                            "-licui18n", "-licuuc", "-licudata"], check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            log.error("%s: %s", name, error)
            failures += 1

    print("== icu-sanity ==")
    if not print_last_lines([binaries / "icu-sanity", host / "required-encodings.txt",
                             host / "known-missing-encodings.txt"], 6):
        failures += 1
    print("== icu-locales ==")
    if not print_last_lines([binaries / "icu-locales"], 2):
        failures += 1
    return failures


def remote_hashes(listing: str) -> dict:
    hashes = {}
    for line in listing.splitlines():
        name, marker, digest = line.partition(")= ")
        if marker and name.startswith("MD5("):
            hashes[name[len("MD5("):]] = digest.strip()
    return hashes


def digest_of(path: Path) -> str:
    reader = hashlib.md5()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            reader.update(block)
    return reader.hexdigest()


def push_if_changed(local: Path, remote: str, hashes: dict, device) -> bool:
    try:
        digest = digest_of(local)
        size = local.stat().st_size
    except OSError as error:
        log.error("cannot sync %s: %s", local, error.strerror)
        return False
    if hashes.get(remote) == digest:
        return True
    log.info("  syncing %s (%d KB)", PurePosixPath(remote).name, size // 1024)
    return device.copy(local, remote)


def build_jsc(build: Path, libraries: dict) -> bool:
    jsc = build / "jsc"
    if not jsc.is_file():
        if build.is_dir():
            try:
                subprocess.run(["ninja", "jsc"], cwd=build, env={**os.environ, **libraries},
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except OSError as error:
                log.error("ninja: %s", error.strerror)
        else:
            log.error("no engine build at %s", build)
    return jsc.is_file()


def sync_engine(root: Path, build: Path, device) -> bool:
    try:
        libraries = device_libraries(root, build)
    except DependencyInstallError as error:
        log.error("device tests: %s", error)
        return False
    if not build_jsc(build, libraries):
        log.error("cannot build jsc")
        return False

    relay_stderr(device.run(30, f"mkdir -p {DEVICE_DIR}/Frameworks"))
    listing = device.run(180, f"for f in {DEVICE_DIR}/jsc {DEVICE_DIR}/Frameworks/*.dylib "
                              f"{DEVICE_DIR}/Frameworks/*.framework/*; do openssl md5 \"$f\" 2>/dev/null; done")
    relay_stderr(listing)
    hashes = remote_hashes(as_text(listing.stdout))

    if not push_if_changed(build / "jsc", f"{DEVICE_DIR}/jsc", hashes, device):
        return False
    libcxx = Path(libraries["CHARON_HOST_LIBCXX"]) / "lib"
    for built_name, device_name in LIBCXX.items():
        if not push_if_changed(libcxx / built_name, f"{DEVICE_DIR}/Frameworks/{device_name}", hashes, device):
            return False

    missing = [framework for framework in FRAMEWORKS
               if not (build / f"{framework}.framework" / framework).is_file()]
    if missing:
        log.error("device tests: %s holds no %s - the batteries would run against whatever the phone "
                  "already has", build, ", ".join(missing))
        return False

    for framework in FRAMEWORKS:
        binary = build / f"{framework}.framework" / framework
        remote_framework = f"{DEVICE_DIR}/Frameworks/{framework}.framework"
        relay_stderr(device.run(30, f"mkdir -p {remote_framework}"))
        if not push_if_changed(binary, f"{remote_framework}/{framework}", hashes, device):
            return False
    return True


def battery_verdict(output: str, returncode: int) -> Verdict:
    body, marker, status = output.rstrip("\n").rpartition("EXIT=")
    if not marker:
        body, status = output, str(returncode)
    lines = [line for line in body.splitlines() if line.strip()]
    verdicts = [line for line in lines if VERDICT.search(line)]
    verdict = verdicts[-1] if verdicts else ""
    failed = status != "0" or not verdict or any(BROKEN.search(line) for line in lines)
    reported = [line for line in lines if REPORTED.search(line)][:10]
    return Verdict(status, verdict, failed, reported)


def default_engine_build(root: Path) -> Path:
    named = os.environ.get("ENGINE_BUILD")
    if named:
        return Path(named)
    try:
        return harness().driver().engine_build(root)
    except LookupError as refused:
        raise SystemExit(f"{refused} - or set ENGINE_BUILD to the build the batteries should use")


def speak() -> None:
    if log.handlers or logging.getLogger().handlers:
        return
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    log.addHandler(handler)
    log.setLevel(logging.INFO)


def run_device_tests(root: Path, build: Path, device) -> int:
    speak()
    if not device.reachable(12):
        log.error("device tests: the phone is not reachable - check device.env (see device.env.example)")
        return 1

    if not sync_engine(root, build, device):
        return 1

    batteries = sorted((root / "tests" / "js").glob("*.js"))
    if not batteries:
        log.error("device tests: no batteries under %s", root / "tests" / "js")
        return 1
    for battery in batteries:
        device.copy(battery, f"{DEVICE_DIR}/")

    failures = 0
    for battery in batteries:
        result = device.run(300, f"cd {DEVICE_DIR} && DYLD_FRAMEWORK_PATH={DEVICE_DIR}/Frameworks "
                                 f"./jsc {battery.name} 2>&1; echo EXIT=$?")
        relay_stderr(result)
        verdict = battery_verdict(as_text(result.stdout), result.returncode)
        if not verdict.failed:
            print(f"{battery.name}: {verdict.line}")
            continue
        failures += 1
        print(f"== {battery.name} FAILED (exit {verdict.status}) ==")
        for line in verdict.reported:
            print(line)
        if not verdict.line:
            print("  no verdict line: battery did not finish")
    return failures


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    sys.stdout.reconfigure(line_buffering=True)
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    failures = run_device_tests(ROOT, default_engine_build(ROOT), transport())
    print()
    print(f"run-tests: FAILED ({failures})" if failures else "run-tests: PASSED")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
