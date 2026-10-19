import argparse
import glob
import os
import subprocess
import sys

DEFINED = {"T", "D", "B", "S", "C"}


def defined_symbols(paths):
    symbols = set()
    for start in range(0, len(paths), 400):
        out = subprocess.run(["nm", *paths[start:start + 400]], capture_output=True, text=True).stdout
        for line in out.splitlines():
            parts = line.split()
            if len(parts) == 3 and parts[1] in DEFINED:
                symbols.add(parts[2])
    return symbols


def engine_objects(build):
    objects = []
    for base, _, names in os.walk(build):
        if os.sep + "compat" in base:
            continue
        objects.extend(os.path.join(base, name) for name in names if name.endswith(".o"))
    return objects


def main():
    parser = argparse.ArgumentParser(
        description="Refuse a compat library whose stubs define a symbol the engine or ICU already defines.")
    parser.add_argument("--compat", required=True, help="libios6compat.a")
    parser.add_argument("--engine-build", required=True, help="the engine's build folder")
    parser.add_argument("--icu", required=True, help="the ICU package folder")
    args = parser.parse_args()

    objects = engine_objects(args.engine_build)
    if not objects:
        sys.exit(f"no object files under {args.engine_build}")
    stubs = defined_symbols([args.compat])
    engine = defined_symbols(objects + sorted(glob.glob(os.path.join(args.icu, "lib", "*.a"))))
    clash = sorted(s for s in stubs & engine if not s.startswith("__OBJC_"))
    if clash:
        print("these stubs shadow the engine's own definitions:")
        print("\n".join(clash))
        sys.exit(1)
    print(f"audit: none of the {len(stubs)} stub symbols shadows one of the engine's {len(engine)}")


main()
