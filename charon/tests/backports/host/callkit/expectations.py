# What the device is held to: the host's answers, with the records the host is
# no oracle for taken from the port itself.
import json, sys

system, port = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
for key in sys.argv[3].split():
    system[key] = port[key]
json.dump(system, open(sys.argv[4], "w"), indent=4, sort_keys=True)
