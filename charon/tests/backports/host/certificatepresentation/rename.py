# Writes the header that compiles the port's classes under names of their
# own, so a build that never links the real Contacts.framework builds
# anyway, and the two builds are never confused for one another even though
# the Contacts and AddressBook frameworks of the host load in both.
import json, sys

names = set()
for path in sys.argv[1:-1]:
    for entry in json.load(open(path))["entries"]:
        if entry["kind"] in ("class", "constant", "function"):
            names.add(entry["api"].replace("()", ""))
with open(sys.argv[-1], "w") as out:
    for name in sorted(names):
        out.write("#define %s Charon%s\n" % (name, name))
