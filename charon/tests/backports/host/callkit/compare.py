# Holds the port's records to the host's, apart from the ones the host is no
# oracle for, which have to differ.
import json, sys

system, port = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
divergent = sys.argv[3].split()
failed = False
for key in sorted(system):
    if key in divergent:
        continue
    if system[key] != port.get(key):
        failed = True
        print("DIFF", key)
        print("  system", system[key][:400])
        print("  port  ", str(port.get(key))[:400])
for key in sorted(port):
    if key not in system:
        failed = True
        print("ONLY IN THE PORT", key, port[key][:400])
for key in divergent:
    if system.get(key) == port.get(key):
        failed = True
        print("NO LONGER DIVERGENT", key, "-", system.get(key))
    else:
        print("differs on purpose:", key, "| system", system.get(key), "| port", port.get(key))
sys.exit(1 if failed else 0)
