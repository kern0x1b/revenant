# Writes the header that compiles the port's classes under names of their own,
# so they stand in one process beside the host's and are told apart by name.
import json, sys

names = set()
for entry in json.load(open(sys.argv[1]))["entries"]:
    if entry["kind"] in ("class", "constant", "function"):
        names.add(entry["api"].replace("()", ""))
with open(sys.argv[2], "w") as out:
    for name in sorted(names):
        out.write("#define %s Charon%s\n" % (name, name))
