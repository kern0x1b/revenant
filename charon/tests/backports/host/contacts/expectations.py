# What the device is held to: the host's answers, with the records the host is
# no oracle for taken from the values run.sh pins for them (key=value).
import json, sys

system = json.load(open(sys.argv[1]))
for entry in sys.argv[2].split():
    key, pinned = entry.split("=", 1)
    system[key] = pinned
json.dump(system, open(sys.argv[3], "w"), indent=4, sort_keys=True)
