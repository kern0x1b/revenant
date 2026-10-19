#!/usr/bin/env python3
"""host-write-guard -- refuse to start a host differential that would WRITE to this Mac's AutoFill.

On a Mac, ``ASCredentialIdentityStore``'s four writing methods change the **user's** AutoFill state:

    -saveCredentialIdentities:completion:
    -removeCredentialIdentities:completion:
    -removeAllCredentialIdentitiesWithCompletion:
    -replaceCredentialIdentitiesWithIdentities:completion:

A differential that called them to see what they return would be writing to the reviewer's passwords.
The host side of this family is therefore read-only: only
``-getCredentialIdentityStoreStateWithCompletion:``, and only because it asks the system what it already
holds. The writing half's behaviour is documented from the header, not measured on this Mac, and the
port's own save-then-query runs against the port's own store under ``.agent-work/runs/``.

**The rule is about the receiver, not the name.** The port's own store case does call
``-replaceCredentialIdentitiesWithIdentities:completion:`` -- that is the test the coordinator asked for
-- and it sends it to ``PortASCredentialIdentityStore``, which is the port's class and writes the port's
file. A send to the unprefixed class is the host's and is refused.

**This file tests that per LINE, and it says so.** `code_statements()` drops the comment lines and
returns the rest, and `main()` looks for the unprefixed class in what is left. The property is therefore
narrower than "no send outside the chokepoint" -- that is `writing-selectors-scan.py`, which reads the
four selectors by name and has the allowlist -- and this one answers the other half: a probe that cannot
even NAME this Mac's store cannot hold it. **An earlier version of this docstring claimed a per-statement
test that `main()` never made:** `statements()` was written, correct, and unreferenced, while the
per-line reader was what actually ran. The reader is gone and this paragraph describes the one that is
there, because a comment that describes a check is worse than no comment when the two disagree.

The two earlier versions were the same mistake as the unreferenced reader: the first refused on the name
alone and would have made the port's own store case impossible; the second compared line by line and
caught a selector on a continuation line. Both read where a word is rather than what it is called on.
"""
import os
import sys

HOST_STORE = "ASCredentialIdentityStore"
PORT_PREFIX = "Port"
FORBIDDEN = (
    "saveCredentialIdentities",
    "removeCredentialIdentities",
    "replaceCredentialIdentitiesWithIdentities",
    "removeAllCredentialIdentities",
)
# A LINE is what this reads, and the word is deliberate: a previous version of this comment said
# "statement" while the function below is a per-line filter, and the two disagreed in the same way the
# docstring did. The class the probe resolves is the question, so the comment lines are the only ones
# allowed to name the host's store.
def code_statements(text):
    out = []
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
            continue
        out.append(line)
    return out


def main(argv):
    probes = argv[1:]
    if not probes:
        here = os.path.dirname(os.path.abspath(__file__))
        probes = [os.path.join(here, name) for name in ("values.m", "hostshape.c")
                  if os.path.isfile(os.path.join(here, name))]
    failed = False
    for probe in probes:
        with open(probe, encoding="utf-8", errors="replace") as f:
            text = f.read()
        name = os.path.basename(probe)
        lines = code_statements(text)
        # Every reference to a store class, with the Port prefix removed: what is left is the host's,
        # and finding one is the failure.
        host = [line for line in lines
                if HOST_STORE in line.replace(PORT_PREFIX + HOST_STORE, "")]
        if host:
            failed = True
            print("FAIL  %s names the HOST's credential identity store in code:" % name)
            for line in host:
                print("        %s" % line)
            continue
        print("ok    %s resolves no store class but the port's own" % name)
        used = [n for n in FORBIDDEN if n in text]
        if used:
            print("ok    %s sends %s, and only ever to the port's store" % (name, ", ".join(used)))
        else:
            print("ok    %s sends no writing selector at all" % name)
    if failed:
        print("FAIL: the host half of this family must not write to the machine's AutoFill state")
        return 1
    print("ok: no writing selector is sent to the host's credential identity store")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
