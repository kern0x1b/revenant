#!/usr/bin/env python3
"""Compare the host's answers to the record cases with the port's, and say which differ.

The two files are both produced by the same cases file, so a difference is a difference in behaviour
and not in the questions. Three kinds of answer cannot match and are not treated as defects:

  * a pointer address, which is an address and says nothing;
  * the name of a private Foundation class. -objectForKey: on the host answers an _NSInlineData for
    two bytes of data and a __NSCFNumber for a number, and the port's own objects are the right
    answer for a port. What has to agree is the *kind* of value, so the comparison normalises the
    class name to the public one it stands for and fails if it cannot;
  * the byte length of an archive. A port ships its own archive keys and cannot reproduce Apple's
    binary archive, and the thing that has to hold is that the round trip decodes to an equal object.
    The length is printed and not compared.

A case only one side has is a defect: it means one of them asked something the other did not, or
refused where the other did not.
"""

import json
import re
import sys

# The private Foundation classes the host answers, and the public type each one is. Anything not in
# this table that looks like a Foundation private class is a difference the port has to explain.
PRIVATE = {
    "_NSInlineData": "NSData",
    "__NSCFData": "NSData",
    "__NSCFString": "NSString",
    "__NSCFConstantString": "NSString",
    "__NSCFNumber": "NSNumber",
    "__NSCFBoolean": "NSNumber",
    "__NSTaggedPointerString": "NSString",
    "__NSTaggedPointerNumber": "NSNumber",
}

ADDRESS = re.compile(r"0x[0-9a-f]+")
# A record that is given no name of its own is given a UUID, on both sides, and two UUIDs never match.
# The thing that has to hold is that each is a UUID and of the same shape, so they are compared by
# shape and the value is not.
UUID = re.compile(r"\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\b")

# The keys that are not compared at all, each with why.
SKIPPED = {
    # The size of an archive. A port ships its own archive keys and cannot reproduce Apple's binary
    # archive; what has to hold is the round trip, which the .equal key above it does check.
    "archive.CKRecord.bytes": "archive size: a port's own keys cannot match Apple's binary archive",
    "archive.CKRecordID.bytes": "archive size",
    "archive.CKRecordZone.bytes": "archive size",
    "archive.CKRecordZoneID.bytes": "archive size",
    "archive.CKReference.bytes": "archive size",
    # The two runners' own account of the conditions they ran under, in their own words. The host
    # harness says it built nothing and touched nothing; the port runner says it linked no framework.
    # Both are true and neither is an answer, and comparing prose written separately would fail every
    # run for a difference nobody can act on.
    "conditions": "the runner's own statement of its conditions, not an answer",
    "assertion": "the host runner's statement that its cases named no network operation",
}


def normalise(key, value):
    """Strip what cannot match, and reduce a private class to the public one it is.

    Recursive, because the answers are nested: the zone's description lives inside
    cases.<construction>.description, and an address in there is an address just as much as one at the
    top level. A normaliser that only looked at the top level left every nested address comparing
    unequal, which is a difference no port can act on.
    """
    if isinstance(value, str):
        value = ADDRESS.sub("0xADDR", value)
        value = UUID.sub("<UUID>", value)
        for private, public in PRIVATE.items():
            value = value.replace(private, public)
    elif isinstance(value, dict):
        value = {k: normalise(k, v) for k, v in value.items()}
    elif isinstance(value, list):
        value = [normalise(key, v) for v in value]
    return value


def main():
    host_path, port_path = sys.argv[1], sys.argv[2]
    host = json.load(open(host_path))
    port = json.load(open(port_path))

    only_host = sorted(set(host) - set(port) - set(SKIPPED))
    only_port = sorted(set(port) - set(host))
    different = []
    skipped = 0
    for key in sorted(set(host) & set(port)):
        if key in SKIPPED:
            skipped += 1
            continue
        want, got = normalise(key, host[key]), normalise(key, port[key])
        if want != got:
            different.append((key, want, got))

    print("host answers: %d   port answers: %d" % (len(host), len(port)))
    for key in only_host:
        print("only the host answered %s = %s" % (key, host[key]))
    for key in only_port:
        print("only the port answered %s = %s" % (key, port[key]))
    if different:
        print("\n%d differ:" % len(different))
        for key, want, got in different:
            print("  %s\n      host: %s\n      port: %s" % (key, want, got))
    else:
        print("all %d compared answers agree (%d skipped)" % (len(set(host) & set(port)) - skipped, skipped))
    for key, why in sorted(SKIPPED.items()):
        if key in host:
            print("skipped %-32s %s" % (key, why))
    return 1 if (only_host or only_port or different) else 0


if __name__ == "__main__":
    raise SystemExit(main())
