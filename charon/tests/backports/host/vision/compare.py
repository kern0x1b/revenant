#!/usr/bin/env python3
"""The Vision host differential's comparison: every recorded key must hold the same value on both
sides.

Every key is compared, including the *scores* of a Core ML prediction. Those were reported rather
than failed on until 2026-10-03, because the model the case runs is nn_image and this port's
prediction of it was a measured divergence apart -- the cause was this port applying the network's
own scaler to an array input, which neither Core ML nor coremltools does, and
facts/CoreML/CoreML.md carries the measurement. They now agree, and the keys keep the name they
were recorded under in device/vision-expectations.h, so an older expectation file is still
readable; what changed is that a difference in them is now a failure rather than a line of
output. Compared as well: the classes of observation, their identifiers, how many there are, the
crop and scale option, the refusal of a model with no image input, and every case the file
already had.
"""
import json
import sys

def main(system_path, port_path):
    system, port = json.load(open(system_path)), json.load(open(port_path))
    hard = 0
    for key in sorted(set(system) | set(port)):
        if system.get(key) != port.get(key):
            hard = 1
            print("DIFF", key)
            print("  system", str(system.get(key))[:400])
            print("  port  ", str(port.get(key))[:400])
    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
