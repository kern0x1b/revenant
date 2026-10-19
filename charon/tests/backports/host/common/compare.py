#!/usr/bin/env python3
"""host/common/compare.py - the two answers of a host differential against what the case declares.

It lives here and not in one case's folder because two of them need it: a reader that answers
"identical" on two empty files is a reader every case in this tree can be made to pass, and a second
copy of it would be a second reader to keep right.

The file the port's differential reads, expected-differences.tsv, holds the cases the two answers are
expected to differ on, and **it currently holds none**: the three rows it had are gone, because the
family carries the system's behaviour and the port's copies now drop the same three value-typed fields
the system's do. The file is kept because the mechanism is worth keeping - a row added to it has to
carry what the system answers, what the port answers and why - and because a file that says in its own
lines why it is empty is a record where a deleted file is not. What pins those three answers is three
mutants of the case, one per field, not a declaration: a declaration cannot catch a port that starts
agreeing with the host, which is exactly the direction the parity policy cares about.

Four things fail here, and each is a failure of the case rather than a detail it can pass over:

  * a case that differs and is not declared
  * a declared case whose system-side answer has moved
  * a declared case whose port-side answer has moved
  * a declared case that no longer differs at all, so the declaration is stale
  * a side that holds no case at all, which is not a pass and the first version of this reader called it
    one: two empty files are equal, and it printed "0 undeclared or moved" and exited 0

A check that examined nothing would pass every one of these, so the summary line counts the cases it
read and the differences it compared, and both come from the two files on disk.

    Usage: compare.py <host.tsv> <port.tsv> <expected-differences.tsv>
"""

import sys


def read_rows(path):
    """label -> value, from the two programs' output. A label twice is a case that cannot be compared."""
    rows = {}
    for number, line in enumerate(open(path), 1):
        label, tab, value = line.rstrip("\n").partition("\t")
        if not tab:
            print("FAIL: %s line %d is not a label and a value: %r" % (path, number, line))
            sys.exit(1)
        if label in rows:
            print("FAIL: %s names %s twice, so the two answers cannot be lined up" % (path, label))
            sys.exit(1)
        rows[label] = value
    return rows


def read_declarations(path):
    """label -> (system, port, why), from the file the case declares its differences in."""
    declared, why = {}, {}
    for number, line in enumerate(open(path), 1):
        if number == 1 or not line.strip():
            continue
        if line.startswith("#"):
            # A line that says why the file has no rows is not a row. Skipping it here is what lets the
            # file record the decision that emptied it without the reader failing on every line.
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 4:
            print("FAIL: %s line %d has no reason, so a difference could be declared without one"
                  % (path, number))
            sys.exit(1)
        declared[parts[0]] = (parts[1], parts[2])
        why[parts[0]] = "\t".join(parts[3:])
    return declared, why


def main():
    host_path, port_path, expected_path = sys.argv[1:4]
    host = read_rows(host_path)
    port = read_rows(port_path)
    declared, why = read_declarations(expected_path)

    # A side with no cases at all is not a pass. The first version of this read two empty files, found no
    # difference between nothing and nothing, and printed "0 undeclared or moved" and exited 0 - a
    # comparison that examined nothing reporting that everything matched. Both counts are printed, and a
    # case that asks nothing has to be told apart from a case that agrees.
    failures = 0
    if not host:
        print("FAIL: %s holds no case, so there is nothing to compare and the run is not a pass" % host_path)
        failures += 1
    if not port:
        print("FAIL: %s holds no case, so there is nothing to compare and the run is not a pass" % port_path)
        failures += 1
    if failures:
        print("cases read: %d a side; declared differences: %d; undeclared or moved: %d"
              % (len(host), len(declared), failures))
        return 1

    for label in sorted(set(host) | set(port)):
        system, mine = host.get(label), port.get(label)
        if label in declared:
            want_system, want_port = declared[label]
            if system != want_system:
                print("DECLARED DIFFERENCE MOVED (system): %s answers %r, the case declares %r"
                      % (label, system, want_system))
                print("  why: " + why[label])
                failures += 1
            if mine != want_port:
                print("DECLARED DIFFERENCE MOVED (port): %s answers %r, the case declares %r"
                      % (label, mine, want_port))
                print("  why: " + why[label])
                failures += 1
            if system == mine:
                print("DECLARED DIFFERENCE GONE: %s answers %r on both sides, so the case is stale"
                      % (label, system))
                print("  why: " + why[label])
                failures += 1
            else:
                print("declared difference: %s: system %s, port %s" % (label, system, mine))
        elif system != mine:
            print("UNDECLARED DIFFERENCE: %s: system %r, port %r" % (label, system, mine))
            failures += 1

    compared = len(set(host) | set(port))
    print("cases read: %d a side; declared differences: %d; undeclared or moved: %d"
          % (compared, len(declared), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
