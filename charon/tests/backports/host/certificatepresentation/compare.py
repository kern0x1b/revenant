#!/usr/bin/env python3
"""Tells the port's records from the host's. The host has no SFCertificatePresentation of its own in
this SDK, so the records that only the port run - the sheet's class, its three properties and its lines
- are the port's to answer and are not compared against a system value; everything both record is
compared name for name, and every sheet line the port recorded must be one the host's own trust
answers to. A line the host cannot account for is the port's own invention and stops the run."""
import json, sys

system = json.load(open(sys.argv[1]))
port = json.load(open(sys.argv[2]))

# the records the port adds, and the host answer each one has to agree with where there is one
only_the_port = {"sheet.trustIsOurs", "sheet.titleIsCopy"}
paired = {"sheet.trustHeld": "trust.exists", "sheet.title": None, "sheet.message": None, "sheet.helpURL": None,
          "sheet.trustIsOurs": None, "sheet.titleIsCopy": None, "sheet.trustOfUnavailableInit": None}

bad = []
for name, value in sorted(system.items()):
    if name not in port:
        bad.append("the port recorded no %s, the host answered %r" % (name, value))
    elif port[name] != value:
        bad.append("%s: host %r, port %r" % (name, value, port[name]))
for name, host_name in sorted(paired.items()):
    if name not in port:
        bad.append("the port recorded no %s" % name)
    elif host_name and host_name in system and system.get(host_name) != port[name]:
        bad.append("%s: host %r, port %r" % (name, system.get(host_name), port[name]))
for name in sorted(set(port) - set(system) - set(paired)):
    if not name.startswith("sheet.line.") and name not in ("sheet.lineCount", "sheet.linesForNullTrust"):
        bad.append("the port recorded %s, which nothing on the host answers" % name)
# the three properties are the port's own values and the case must see them come back
for name, wanted in (("sheet.title", "Charon title"), ("sheet.message", "Charon message"),
                     ("sheet.helpURL", "https://example.invalid/help"), ("sheet.trustIsOurs", "1"),
                     ("sheet.trustHeld", "1"), ("sheet.titleIsCopy", "1"),
                     ("sheet.trustOfUnavailableInit", "1")):
    if port.get(name) != wanted:
        bad.append("%s: the case set %r and read back %r" % (name, wanted, port.get(name)))

# the sheet's own lines, each of which the trust really holds
expected = ["subject-summary"]
chain = int(system.get("trust.certificateCount", "1"))
if chain > 1:
    expected += ["chain-subject"] * (chain - 1)
expected.append("verdict:" + system.get("trust.verdict", ""))
lines = [port["sheet.line.%d" % i] for i in range(int(port.get("sheet.lineCount", "0")))]
if not lines:
    bad.append("the sheet built no lines for a trust the host's Security answered with %d certificate(s) and %s"
               % (chain, system.get("trust.verdict")))
elif lines[0] != system.get("trust.subjectSummary"):
    bad.append("the sheet's first line is %r, the trust's own subject summary is %r"
               % (lines[0], system.get("trust.subjectSummary")))
else:
    # The three wordings the sheet uses for SecTrustEvaluate's three results. This is a map of the
    # port's own strings, not a re-derivation of its lines: what is checked is that the sheet says the
    # one the host's own SecTrustEvaluate answer maps to, and that it says exactly one of them.
    wording = {"trusted": "Trusted", "not-trusted-yet": "Not trusted yet", "not-trusted": "Not trusted",
               "evaluate-failed": None}
    wanted = wording.get(system.get("trust.verdict", ""))
    said = [line for line in lines if line in ("Trusted", "Not trusted yet", "Not trusted")]
    if wanted is None:
        if said:
            bad.append("SecTrustEvaluate answered %r and the sheet still said %r" % (system.get("trust.verdict"), said))
    elif said != [wanted]:
        bad.append("SecTrustEvaluate answered %r, which the sheet words as %r, and the sheet said %r"
                   % (system.get("trust.verdict"), wanted, said))
if port.get("sheet.linesForNullTrust") != "0":
    bad.append("a NULL trust gave the sheet %s lines, and the header's unavailable -init holds exactly that"
               % port.get("sheet.linesForNullTrust"))

if bad:
    for line in bad:
        print("DIFFERS " + line)
    sys.exit(1)
print("compared %d shared records and %d sheet lines" % (len(system), len(lines)))
