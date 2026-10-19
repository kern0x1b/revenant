#!/usr/bin/env python3
"""Keep the phone's dyld shared cache where check:imports reads it.

    charon test --tier imports

check:imports runs in every build and checks the stage and the application
bundle against the device's shared cache, held at ~/.charon/dyld. A build must
finish on a machine with no phone attached, so fetching that cache is this tier's
job, done once per machine: after it, every build proves what it produced loads.
"""
import sys
import tomllib
from pathlib import Path

REMOTE = "/System/Library/Caches/com.apple.dyld/dyld_shared_cache_{arch}"
HELD = Path.home() / ".charon" / "dyld"
MANIFEST = "charon.toml"
DEVICE_ARCH = {"armv7": "armv7", "armv8": "arm64"}


def hold_cache(root, device):
    with (root / MANIFEST).open("rb") as handle:
        arch = tomllib.load(handle).get("platform", {}).get("arch")
    if arch not in DEVICE_ARCH:
        print("FAIL  {} declares [platform] arch {}, and no shared cache name is known for it".format(
            root / MANIFEST, arch))
        return 1
    held = HELD / "dyld_shared_cache_{}".format(DEVICE_ARCH[arch])
    if held.is_file() and held.stat().st_size:
        print("ok    {} is held; check:imports reads it in every build".format(held))
        return 0
    HELD.mkdir(parents=True, exist_ok=True)
    remote = REMOTE.format(arch=DEVICE_ARCH[arch])
    print("fetching {} from the phone; this happens once".format(remote))
    device.fetch(remote, str(held))
    if not held.is_file() or not held.stat().st_size:
        print("FAIL  {} did not arrive from the phone".format(remote))
        return 1
    print("ok    {} is held; check:imports reads it in every build".format(held))
    return 0


if __name__ == "__main__":
    print("this runs as a tier, which is what supplies the phone: charon test --tier imports")
    sys.exit(2)
