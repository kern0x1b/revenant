#!/usr/bin/env python3
"""Put the two call-test runs side by side and say where they differ.

The same generated file is run twice — once against the host's own framework, where it is the
oracle, and once against the port — and each run writes one line per event. The question this
answers is not "did both pass" but **where they differ**, because a difference is where a port's
answer and the system's answer have come apart, and every one of them is either a decision the
facts file records or a finding.

What counts as a difference, in the order it is reported:

  * **a name the port does not answer that the host does** — a member the registry carries and
    `libIntentsBackports` has no accessor for. The gate cannot see this (check_registry marks a
    member built as soon as its owner class is exported), which is why the test exists.
  * **a name the host does not answer that the port does** — expected where the host's framework
    is older or, for IntentsUI, where the class is iOS-only; reported, not failed.
  * **a different answer to the same call** — printed with both answers, for a reader to judge
    against the facts. A divergence is a finding unless the facts name it.
  * **a refusal or a crash on one side only** — the strongest signal there is, and always a
    finding.

Usage:
    compare.py <host.log> <port.log> [--facts <facts file>] [--strict]

Exit status is non-zero when the port answers a name the host answers and the port does not, or
when the port crashes where the host does not. Everything else is printed and counted.
"""

import argparse
import collections
import sys


def read(path):
    """One run's events: the classes, the members, the answers, the refusals and the crashes."""
    seen = {"present": {}, "missing": collections.Counter(), "answered": {},
            "refused": {}, "crashed": []}
    for line in open(path, errors="replace").read().split("\n"):
        if not line.strip():
            continue
        if line.startswith("present "):
            seen["present"][line[8:]] = True
        elif line.startswith("missing "):
            seen["missing"][line[8:]] += 1
        elif line.startswith("crashed "):
            seen["crashed"].append(line[8:])
        elif line.startswith("refused "):
            # "refused <class> <selector> raised <name>: <reason>"
            body = line[8:]
            name, _, rest = body.partition(" raised ")
            seen["refused"][name] = rest
        elif line.startswith("answered "):
            # "answered <class> <selector> -> <value>", and the property form "-<name> -> <value>"
            body = line[9:]
            head, _, value = body.rpartition(" -> ")
            seen["answered"][head] = value
    return seen


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("host")
    parser.add_argument("port")
    parser.add_argument("--strict", action="store_true",
                        help="fail on any difference at all, not only on the two the exit status names")
    options = parser.parse_args()

    host, port = read(options.host), read(options.port)
    host_answered = set(host["answered"])
    port_answered = set(port["answered"])
    host_classes, port_classes = set(host["present"]), set(port["present"])

    print("classes: host %d, port %d" % (len(host_classes), len(port_classes)))
    only_port = sorted(port_classes - host_classes)
    only_host = sorted(host_classes - port_classes)
    if only_port:
        print("  the port has %d the host does not: %s" % (len(only_port), " ".join(only_port[:12])))
    if only_host:
        print("  the host has %d the port does not: %s" % (len(only_host), " ".join(only_host[:12])))

    # The two that fail the run: the port answering nothing where the host answers something, and
    # the port crashing where the host does not.
    lost = sorted(name for name in host_answered - port_answered)
    gained = sorted(name for name in port_answered - host_answered)
    print("members answered: host %d, port %d (the port has %d the host does not, and is missing %d)"
          % (len(host_answered), len(port_answered), len(gained), len(lost)))
    for name in lost:
        print("  LOST      %s" % name)
    for name in gained:
        print("  EXTRA     %s" % name)

    port_crashes = set(port["crashed"])
    host_crashes = set(host["crashed"])
    for name in sorted(port_crashes - host_crashes):
        print("  CRASHED   only in the port: %s" % name)
    for name in sorted(host_crashes - port_crashes):
        print("  CRASHED   only on the host: %s" % name)

    differing = sorted(name for name in host_answered & port_answered
                       if host["answered"][name] != port["answered"][name])
    print("answers that differ: %d of %d members both answered" % (len(differing), len(host_answered & port_answered)))
    for name in differing[:40]:
        print("  %s\n      host: %s\n      port: %s" % (name, host["answered"][name], port["answered"][name]))
    if len(differing) > 40:
        print("  ... and %d more" % (len(differing) - 40))

    refused_port = sorted(set(port["refused"]) - set(host["refused"]))
    refused_host = sorted(set(host["refused"]) - set(port["refused"]))
    print("refused the neutral value: host %d, port %d (only in the port %d, only on the host %d)"
          % (len(host["refused"]), len(port["refused"]), len(refused_port), len(refused_host)))
    for name in refused_port:
        print("  REFUSED   only in the port: %s (%s)" % (name, port["refused"][name]))
    for name in refused_host:
        print("  REFUSED   only on the host: %s (%s)" % (name, host["refused"][name]))

    failed = bool(lost or (port_crashes - host_crashes))
    if options.strict and (differing or gained or only_port or only_host):
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
