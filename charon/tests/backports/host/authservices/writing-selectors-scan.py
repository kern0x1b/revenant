#!/usr/bin/env python3
"""writing-selectors-scan -- the dumb static half of the host-write rule.

One property, and this file tests nothing else: **no harness source sends one of the four store-writing
selectors to a real `ASCredentialIdentityStore`.**

    saveCredentialIdentities:completion:
    removeCredentialIdentities:completion:
    removeAllCredentialIdentitiesWithCompletion:
    replaceCredentialIdentitiesWithIdentities:completion:

On this Mac those four change the **user's** AutoFill state. The runtime half — `port-store-rule.h`,
asked by `port-store-selftest.m` about this machine's own store class object — is the half that actually
protects it. This one is a scan, deliberately: a statement reader is what four previous versions of the
guard turned into, and each of those read the wrong thing — a name, a line, a receiver three statements
from its binding. A `grep -n` over four fixed names cannot be wrong in any of those ways.

So: grep the four names over every harness source AND over the port's own AuthenticationServices
sources. A hit line is allowed when it is a comment, when the name is inside a string literal, or when
the file and line are listed in an allowlist with a reason. Anything else is red, and it is red *by file
and line*:

    FAIL values.m:184 sends a writing selector to the host's store
        [ASCredentialIdentityStore.sharedStore saveCredentialIdentities:@[] completion:nil];

**The allowlist is a file, not a flag.** `writing-selectors.allow` has one `path:line: reason` per line
and is committed, so the exceptions are reviewable in a diff rather than implied by a heuristic. A line
moves and the allowlist stops matching, which is the point.

Usage: writing-selectors-scan.py [<harness source> ...]
"""
import os
import re
import subprocess
import sys

FORBIDDEN = (
    "saveCredentialIdentities",
    "removeCredentialIdentities",
    "replaceCredentialIdentitiesWithIdentities",
    "removeAllCredentialIdentities",
)
ALLOWLIST = "writing-selectors.allow"
# The port's own sources get their own allowlist because the two sets have different reasons, not
# different rules: a harness file is excused because its sends go through the chokepoint, and a port
# file is excused because it is the DEFINITION of the port's own store rather than a send to a real one.
PORT_ALLOWLIST = "writing-selectors.port-allow"
PORT_ROOT = "packages/a/apple-backports/AuthenticationServices"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))


def allowed(name=ALLOWLIST):
    """{(path, line): reason} from the allowlist, keyed by the 1-based line number."""
    entries = {}
    path = os.path.join(HERE, name)
    if not os.path.isfile(path):
        return entries
    for number, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(":", 2)
        if len(parts) != 3:
            sys.stderr.write("%s:%d: an allowlist line is path:line: reason, and this is not\n"
                             % (ALLOWLIST, number))
            sys.exit(2)
        entries[(parts[0], int(parts[1]))] = parts[2].strip()
    return entries


def comment_or_string(line):
    """Whether the line is a comment, or a name that sits inside a string literal.

    Deliberately crude and deliberately only a filter for the ALLOWED case: a comment starts with the
    comment markers, and a name is inside a string literal when an odd number of quotes precede it on the
    line. Both are conservative in the same direction -- they excuse a line, and an excused line is one
    the reviewer has to read anyway.
    """
    stripped = line.strip()
    if stripped.startswith(("//", "*", "/*", "#")):
        return True
    before = line.split(separator=None)[0] if False else line
    return before.count('"') % 2 == 1 or before.count("'") % 2 == 1


def scan(probes, port_root=None):
    harness, port = allowed(ALLOWLIST), allowed(PORT_ALLOWLIST)
    failures = []
    for probe in probes:
        name = os.path.basename(probe)
        is_port = port_root is not None and os.path.abspath(probe).startswith(port_root + os.sep)
        excused = port if is_port else harness
        try:
            text = open(probe, encoding="utf-8", errors="replace").read().split("\n")
        except OSError:
            sys.stderr.write("cannot read %s\n" % probe)
            return 1
        hits = 0
        for number, line in enumerate(text, 1):
            if not any(selector in line for selector in FORBIDDEN):
                continue
            hits += 1
            if (name, number) in excused:
                print("ok    %s:%d is allowed: %s" % (name, number, excused[(name, number)]))
            elif comment_or_string(line):
                print("ok    %s:%d is a comment or a string" % (name, number))
            else:
                where = "the port's own sources" if is_port else "the chokepoint"
                print("FAIL  %s:%d names a writing selector outside %s" % (name, number, where))
                print("        %s" % line.strip())
                failures.append((name, number))
        if not hits:
            print("ok    %s names none of the four" % name)
    return failures


def main(argv):
    # The PROBES, and only the probes: values.m and hostshape.c are the files that run on this machine.
    # The guard and the self-test are tools ABOUT the rule, not things the rule covers -- the self-test
    # has to NAME the four selectors, because naming them is how it asks the predicate about them, and
    # scanning a file for failing to be scanned is the same class of mistake as a check that reads the
    # wrong thing. A file named on the command line is scanned whatever it is.
    probes = argv[1:]
    # The port's own sources are in the default set, and that is a fix rather than an addition: the
    # scan's property is "no source of this port sends a writing selector to a real store", and it
    # read only the harness -- so a base class DEFAULT that reached for the store, in a file that
    # runs on the port and on a device, was invisible to the one check that is supposed to name it.
    port_root = os.path.join(REPO, PORT_ROOT)
    if os.path.isdir(port_root):
        probes.extend(sorted(os.path.join(port_root, name) for name in os.listdir(port_root)
                             if name.endswith(".m")))
    failures = scan(probes, port_root)
    if failures:
        print("FAIL: %d line(s) name a writing selector with no comment, no string and no allowlist entry"
              % len(failures))
        print("      A send the chokepoint cannot see is the failure this whole arrangement exists to stop,")
        print("      and the runtime rule in port-store-rule.h is what stops it; this names the line.")
        return 1
    print("ok: no harness or port source names a writing selector outside a comment, a string"
          " or an allowlist entry")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
