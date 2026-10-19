#!/usr/bin/env python3
"""Replace the one statement in NSBatchInsertRequest's -init that raises, with one that compiles
and does not raise — so the per-initialiser listing goes red because the BEHAVIOUR changed, and
not because the mutant failed to build.

    mutant-init.py <source> <output>

The raise is TWO lines in the source, and a one-line edit of it is what produced the two failures
this replaces: a `sed` that removed `[NSException raise:NSInternalInconsistencyException` and left
`format:@…];` behind made the mutant red by NOT COMPILING, and an earlier attempt at this file
corrupted its own driver by ending a nested heredoc. So the whole statement is matched as a
regular expression, the count is asserted to be exactly one, and the text is printed so a reader
can see what was replaced.
"""
import difflib
import re
import sys

# -init's raise: [NSException raise:NSInternalInconsistencyException, then the format: line, then
# the closing ];. Whitespace-tolerant on the continuation, and the reason text is matched
# literally because it is Apple's own and a change to it would be a different exception.
RAISE = re.compile(
    r"[ \t]*\[NSException raise:NSInternalInconsistencyException\s*\n"
    r"[ \t]*format:@\"-init results in undefined behavior for NSBatchInsertRequest\"\];")

REPLACEMENT = ("    // MUTANT: the raise is gone, so -init answers a request where Apple's answers\n"
               "    // an NSInternalInconsistencyException. The listing prints raised=0 and non-nil\n"
               "    // here, against the host's raised=1 and nil, and that is the red.\n"
               "    return [super init];")


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: mutant-init.py <source> <output>\n")
        return 2
    source, output = sys.argv[1], sys.argv[2]
    text = open(source).read()

    found = RAISE.findall(text)
    matches = list(RAISE.finditer(text))
    if len(matches) != 1:
        sys.stderr.write(
            "mutant-init: found %d occurrences of the raise, and exactly one is required:\n"
            % len(matches))
        for m in matches:
            sys.stderr.write("  %r\n" % m.group(0))
        sys.stderr.write("the text it looks for is:\n  %r\n" % RAISE.pattern)
        return 3

    print("mutant-init: the ONE statement it replaces, exactly:")
    for line in matches[0].group(0).splitlines():
        print("    | %s" % line)

    after = RAISE.sub(REPLACEMENT, text, count=1)
    with open(output, "w") as fh:
        fh.write(after)

    diff = list(difflib.unified_diff(text.splitlines(True), after.splitlines(True),
                                     fromfile=source, tofile=output, n=1))
    print("mutant-init: the diff it made, %d hunk(s):" %
          sum(1 for d in diff if d.startswith("@@")))
    for d in diff:
        sys.stdout.write(d if d.endswith("\n") else d + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
