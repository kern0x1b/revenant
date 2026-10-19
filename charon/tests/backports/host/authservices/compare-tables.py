#!/usr/bin/env python3
"""compare-tables -- the changed rows between two of this suite's tables, and the verdict on them.

Used by the mutant runs, and runnable on its own, because a claim a run makes about itself has to be
checkable by the person reading it:

    compare-tables.py <plain-table> <mutant-table>

**What counts as a change.** The rows the check MEASURES, and not the whole file. A raw comparison over
the file is satisfied by a relocated method address -- every mutation of any size moves one, because the
object is a different size -- and that is how the operation mutant was reported as caught when the only
thing that had changed was `built -init imp`. The `built` rows are excluded for the same reason, and
they are not a measurement: the two builds are SUPPOSED to be different classes, which is the control.

So: every `port` row that does not start with `built` is taken from each table, and the ones whose
value moved are printed by name, with the old and the new. Exit 0 when nothing moved, which is the
mutant-was-inert case, and 1 when something did.
"""
import re
import sys


def rows(path):
    """{(side, column, property): value} for one table, or {} and a note if it has no rows."""
    out, side = {}, None
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line in ("host", "port"):
            side = line
            continue
        if not side or not line.startswith("  "):
            continue
        parts = [p for p in re.split(r"\s{2,}", line.strip()) if p]
        if len(parts) >= 2:
            out[(side, parts[0], parts[1])] = parts[-1]
    return out


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: compare-tables <plain-table> <mutant-table>\n")
        return 2
    plain, mutant = rows(argv[1]), rows(argv[2])
    if not mutant:
        sys.stderr.write("FAIL: the mutant's table has no port rows, so nothing was measured at all\n")
        return 1
    measured = {key[1:] for key in mutant if key[0] == "port" and not key[1].startswith("built")}
    changed = sorted(key for key in measured if plain.get(("port",) + key) != mutant.get(("port",) + key))
    for key in changed:
        print("CHANGED %-46s was %-12s now %s"
              % (key[1], plain.get(("port",) + key, "(absent)"), mutant.get(("port",) + key, "(absent)")))
    print("VERDICT %d of %d measured rows differ" % (len(changed), len(measured)))
    return 1 if changed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
