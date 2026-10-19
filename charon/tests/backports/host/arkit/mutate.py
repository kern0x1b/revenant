#!/usr/bin/env python3
"""Change one thing in a copy of a source file, for a mutant run.

The file is a copy under `.agent-work`, never the tree: a mutant that edited the checkout would leave
the band holding mutated source, and one that restored through git would take out whatever else was
uncommitted. Both have happened.

    mutate.py <file> <from> <to>

Refuses to run if the text is not there exactly once, so a mutant cannot silently apply to nothing
and read as a surviving mutant.
"""

import sys


def main(argv):
    if len(argv) != 4:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    path, old, new = argv[1], argv[2], argv[3]
    text = open(path).read()
    count = text.count(old)
    if count != 1:
        print("the text to mutate is in %s %d times, and must be once" % (path, count), file=sys.stderr)
        return 1
    open(path, "w").write(text.replace(old, new))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
