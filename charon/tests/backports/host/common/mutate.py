#!/usr/bin/env python3
"""host/common/mutate.py - change one line of a copy of the port's source, for a case's mutants.sh.

It is here for the same reason the reader is: every mutants.sh in this tree needs a mutator that
refuses a line it cannot find, and a copy per case is a copy to keep right.

The copy is a mutant's own, so the change is written to it and never to the tree's file. Two things
about that are checked rather than assumed:

  * the line has to be there, and MUTATE_NTH says which occurrence. The three chart classes each write
    the same two-line title setter, so a text that matches all three and changed the first would break
    one rule and look like it had broken three.
  * the result has to be the whole file. The first version of this read `parts[nth]` as the text after
    the nth occurrence and took only the second piece of it, so a line that occurred twice lost
    everything from the second occurrence to the end of the file - and the mutant then failed to compile
    for a reason that had nothing to do with the rule under test, which is a mutant that tested nothing.
    A mutation whose result is shorter than the change accounts for is refused, and the end of the file
    is compared before anything is written.

Usage: MUTATE=<file> MUTATE_OLD=<text> MUTATE_NEW=<text> MUTATE_NTH=<n> mutate.py
"""

import os
import sys

# How much of the end of the file has to survive a mutation, and how much shorter the result may be
# than the text it was made from, counted in lines.
TAIL = 200
SLACK = 4


def main():
    path = os.environ.get("MUTATE", "")
    old = os.environ.get("MUTATE_OLD", "")
    new = os.environ.get("MUTATE_NEW", "")
    nth_text = os.environ.get("MUTATE_NTH", "")
    if not path or not old or not nth_text:
        print("usage: MUTATE=<file> MUTATE_OLD=<text> MUTATE_NEW=<text> MUTATE_NTH=<n> mutate.py",
              file=sys.stderr)
        return 2
    text = open(path).read()
    found = text.count(old)
    nth = int(nth_text)
    if nth < 1 or found < nth:
        print("the mutant's line is in the file %d times and the mutant wants the %d of them: %r"
              % (found, nth, old), file=sys.stderr)
        return 1

    # Everything before the nth occurrence, then the occurrence replaced, then everything after it.
    parts = text.split(old)
    head = parts[0]
    for part in parts[1:nth]:
        head += old + part
    tail = old.join(parts[nth:])
    result = head + new + tail

    # The whole file has to be there. The end of the original is the part a slicing mistake loses, and a
    # line count that fell by more than the mutation's own lines is the other half of the same check.
    if not text.strip().endswith(tail.strip()[-TAIL:]) and tail.strip()[-TAIL:] not in text:
        print("the mutation dropped the end of the file, so it is refused rather than written", file=sys.stderr)
        return 1
    if len(result.splitlines()) < len(text.splitlines()) - abs(len(new.splitlines()) - len(old.splitlines())) - SLACK:
        print("the mutation made the file %d lines shorter than the change accounts for, so it is refused"
              % (len(text.splitlines()) - len(result.splitlines())), file=sys.stderr)
        return 1
    open(path, "w").write(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
