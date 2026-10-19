#!/usr/bin/env python3
"""check_host.py - the host's own framework against the transcription of what it answered once.

    ./probe <framework-path> <class>            # one class per process: see run.sh
    python3 check_host.py <framework> <the probe's output for that class>

Reads expectations.tsv and the probe's output, and prints one line per class: what the host says now
against what it said when the table was written. A difference is not a failure of the port, it is the
oracle having moved - which is the one thing this table exists to notice, because a table that is never
re-read is a table that has stopped being evidence.

Only the rows whose `oracle` is `host` are asked of the host: a row measured out of a real release's
cache is that release's own answer and this host cannot confirm it. Exits non-zero on any difference and
on a class the host no longer declares at all.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LINE = re.compile(r"^CLASS (\S+) own-init=(\d) own-new=(\d) "
                  r"init=(ok \S+|raises \S+ \([^)]*\)) new=(ok \S+|raises \S+ \([^)]*\))$")


def rows_of(path):
    header, rows = None, []
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        fields = line.rstrip("\n").split("\t")
        if header is None:
            header = fields
            continue
        rows.append(dict(zip(header, fields)))
    return rows


def main():
    if len(sys.argv) != 3:
        sys.exit("check_host.py: pass the framework name and the probe's output for one class")
    framework, output = sys.argv[1], sys.argv[2]
    expected = [r for r in rows_of(os.path.join(HERE, "expectations.tsv"))
                if r["framework"] == framework and r.get("oracle") == "host"]
    if not expected:
        print("SKIP %s: expectations.tsv holds no row measured on the host" % framework)
        return 0
    found, failures, ok = {}, [], 0
    for line in open(output, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("NOFRAMEWORK"):
            # Said out loud, and it is a failure when the table's rows name this host as their oracle:
            # those rows were not checked, and a run that passes over them has proved nothing. A framework
            # this host never carried - HomeKit, whose directory holds only PlugIns - has no host rows,
            # and that is the SKIP.
            if expected:
                failures.append("%s could not be opened on this host, so its %d rows were not checked"
                                % (framework, len(expected)))
                print("FAIL %s cannot be opened here: %s" % (framework, line.split()[1]))
            else:
                print("SKIP %s: this host carries no %s, and the table holds no row of its own for it"
                      % (framework, line.split()[1].split("/")[-1]))
                return 0
        match = LINE.match(line)
        if not match:
            failures.append("unparsed probe line: %s" % line)
            continue
        name, own_init, own_new, _, new = match.groups()
        found[name] = (own_init, own_new, new)
    for row in expected:
        name = row["class"]
        if name not in found:
            failures.append("%s: the host does not declare it any more" % name)
            print("%-44s ABSENT on the host" % name)
            continue
        own_init, own_new, new = found[name]
        want_new = ("raises %s (%s)" % (row["exception"], row["reason"])) if row["answer"] == "raises" \
            else None
        same = own_init == row["own-init"] and own_new == row["own-new"] and \
            (new.split(" ", 1)[1] == want_new.split(" ", 1)[1] if want_new else new.startswith("ok"))
        if same:
            ok += 1
            print("%-44s own-init=%s own-new=%s  %s" % (name, own_init, own_new, new.split(" ", 1)[1]))
        else:
            failures.append("%s: the host answers own-init=%s own-new=%s %s, and the table says "
                            "own-init=%s own-new=%s %s" % (name, own_init, own_new, new.split(" ", 1)[1],
                                                           row["own-init"], row["own-new"],
                                                           want_new.split(" ", 1)[1] if want_new else "ok"))
            print("%-44s DIFFERS from the table: %s" % (name, new.split(" ", 1)[1]))
    for name in sorted(set(found) - {r["class"] for r in expected}):
        failures.append("%s is answered by the host and is not in the table" % name)
    for failure in failures:
        print("FAIL " + failure)
    print("unavailable-init-host %s: %d of %d classes as the table says, %d failures%s"
          % (framework, ok, len(expected), len(failures), "" if not failures else "  <- SEE FAIL"))
    return 1 if failures else 0


sys.exit(main())
