#!/usr/bin/env python3
"""Put the handler cross-assignment back into NSBatchInsertRequest — the defect a724920f found,
as a mutation, so the ONE check a reviewer reads is the one that goes red on it.

    mutant-ivar.py <source> <output>

The two initialisers that take an entity and a handler each ended with one block and one
assignment. This adds back the second handler assignment — the wrong one — so a request built by
either has BOTH handler ivars set, which is the defect in its exact shape.

Like mutant-init.py, this is a whole file rather than a line of shell, because a multi-line edit
made through a nested heredoc spliced python into a shell script once already, and because a
one-line `sed` that removed half a statement left the rest behind and the mutant went red by NOT
COMPILING — which proves nothing about the behaviour.
"""
import difflib
import re
import sys

# ONE assignment per form is the shape the fix has; this adds the other ivar back.
ASSIGN = re.compile(
    r"(        // ONE block, ONE assignment\. This carried three, and the first put the handler in the\n"
    r"        // OTHER ivar, so a request built here had BOTH handler ivars set and nothing said so\.\n"
    r"        // initWithEntity:objects: has already stored the entity and its name\.\n)"
    r"        _charon(?P<which>Dictionary|ManagedObject)Handler = \[handler copy\];")

WRONG = {"Dictionary": "_charonManagedObjectHandler", "ManagedObject": "_charonDictionaryHandler"}


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: mutant-ivar.py <source> <output>\n")
        return 2
    source, output = sys.argv[1], sys.argv[2]
    text = open(source).read()

    hits = list(ASSIGN.finditer(text))
    if len(hits) != 2:
        sys.stderr.write("mutant-ivar: found %d of the two fixed assignments, and two are "
                         "required:\n" % len(hits))
        for h in hits:
            sys.stderr.write("  %r\n" % h.group(0))
        return 3

    out = text
    for hit in reversed(hits):
        which = hit.group("which")
        wrong = WRONG[which]
        original = hit.group(0)
        mutated = original + "\n        %s = [handler copy];  // MUTANT" % wrong
        out = out[:hit.start()] + mutated + out[hit.end():]
        print("mutant-ivar: %s initialiser now sets %s as well" % (which, wrong))

    with open(output, "w") as fh:
        fh.write(out)
    diff = list(difflib.unified_diff(text.splitlines(True), out.splitlines(True),
                                     fromfile=source, tofile=output, n=1))
    print("mutant-ivar: %d hunk(s)" % sum(1 for d in diff if d.startswith("@@")))
    for d in diff:
        sys.stdout.write(d if d.endswith("\n") else d + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
