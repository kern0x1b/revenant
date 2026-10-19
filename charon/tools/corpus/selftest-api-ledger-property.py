#!/usr/bin/env python3
"""
Does a property row whose owner is a protocol get read as missing while the protocol declares it?

A property row's owner is named without saying whether it is a class or a protocol, and the
surface has both. classify_method has searched classes and protocols since the 2026-09-27 review
(`-[CLLocationManagerDelegate locationManager:didDetermineState:forRegion:]` read missing while
the 6.1.3 cache declared it); classify_property did not, so every property of a protocol read
missing. Over the 145245-row surface at 6.1.3 that is 423 rows whose owner is a protocol and no
class, of which 383 are answered by that protocol's own selectors.

The accessors are what is looked for, in both selector sets, because a `@property (class,
readonly)` is read through a class method and never through an instance one.

    python3 selftest-api-ledger-property.py

Exit 0 when every check holds. The inventories are written here, so nothing on this machine can
make it pass or fail.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
spec = importlib.util.spec_from_file_location("api_ledger", os.path.join(HERE, "api-ledger.py"))
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)

failures = []


def check(what, got, want):
    if got == want:
        print("ok   %s" % what)
    else:
        print("FAIL %s\n       got  %r\n       want %r" % (what, got, want))
        failures.append(what)


def entry(instance=(), klass=(), library="Backports", protocols=()):
    return {"instance": set(instance), "class": set(klass), "protocols": set(protocols),
            "superclass": "", "image": "", "library": library}


# A protocol that declares a property's getter, one that declares only the setter, and one that
# declares a @property (class, readonly) -- a class property is read through a class selector.
# The class selector is written with a leading "-" and not a "+", because that is how the inventory
# holds it: run_objc_inventory's own docstring says so, and the built libraries agree --
# ARPositionalTrackingConfiguration carries ["-isSupported", "-new"] in its class set.
BUILT_PROTOCOLS = {
    "Answering": entry(instance=["-answer", "-setAnswer:"]),
    "Writable": entry(instance=["-setWritable:"]),
    "ClassAnswering": entry(klass=["-shared"]),
    "Silent": entry(),
}
RELEASE_PROTOCOLS = {
    "OldAnswering": entry(instance=["-oldAnswer"], library=""),
}
BUILT_CLASSES = {"Concrete": entry(instance=["-name", "-setName:"], library="UIKitBackports")}
RELEASE_CLASSES = {"OldConcrete": entry(instance=["-oldName"], library="")}

status, reason = ledger.classify_property(
    "Answering.answer", BUILT_CLASSES, RELEASE_CLASSES, BUILT_PROTOCOLS, RELEASE_PROTOCOLS)
check("a protocol that declares the getter answers the row", status, "implemented")
check("and the reason names the protocol", "(the protocol Answering declares it)" in reason, True)

check("a protocol that declares only the setter answers it too",
      ledger.classify_property("Writable.writable", BUILT_CLASSES, RELEASE_CLASSES,
                               BUILT_PROTOCOLS, RELEASE_PROTOCOLS)[0], "implemented")

check("a class property is read through the class selector",
      ledger.classify_property("ClassAnswering.shared", BUILT_CLASSES, RELEASE_CLASSES,
                               BUILT_PROTOCOLS, RELEASE_PROTOCOLS)[0], "implemented")

check("a protocol that declares neither accessor leaves the row missing",
      ledger.classify_property("Silent.silent", BUILT_CLASSES, RELEASE_CLASSES,
                               BUILT_PROTOCOLS, RELEASE_PROTOCOLS)[0], "missing")

check("a release protocol answers as well",
      ledger.classify_property("OldAnswering.oldAnswer", BUILT_CLASSES, RELEASE_CLASSES,
                               BUILT_PROTOCOLS, RELEASE_PROTOCOLS)[0], "implemented")

check("a class still answers, and is preferred",
      ledger.classify_property("Concrete.name", BUILT_CLASSES, RELEASE_CLASSES,
                               BUILT_PROTOCOLS, RELEASE_PROTOCOLS)[0], "implemented")

# Without the protocol arguments -- how the caller reached this function before -- the same rows
# read missing. This is the mutation the fix is: two optional arguments and one loop.
status, reason = ledger.classify_property("Answering.answer", BUILT_CLASSES, RELEASE_CLASSES)
check("and with no protocol arguments the row reads missing again", status, "missing")
check("with the old reason", reason.startswith("owner class Answering not in"), True)

# An owner that is neither a class nor a protocol anywhere keeps its own reason.
check("an owner in no inventory at all still reads missing",
      ledger.classify_property("Nowhere.gone", BUILT_CLASSES, RELEASE_CLASSES,
                               BUILT_PROTOCOLS, RELEASE_PROTOCOLS)[1],
      "owner class Nowhere not in the built libraries or the 6.1.3 cache")

# The call site, which is a defect of its own: a matcher that is right and a caller that forgets to
# hand it the protocols moves nothing, and every check above still passes. Checked against main's
# source text rather than by running it, because build() needs a gate, a dyld cache and an SDK to
# reach that line; it is a wiring check and says so. Dropping `built_protocols` from the call leaves
# every other check in this file green. The sixth argument is the declared getter the surface
# records (selftest-api-ledger-getter.py), which arrived after this one and has its own checks, and
# the seventh is the decided rows (selftest-api-ledger-chain.py), which keep their registry decision
# against the superclass walk the same way they keep it against `+new`, and the eighth is the surface's
# own NS_UNAVAILABLE column, which holds the walk back from a row Apple's header refuses a program, and
# the ninth is what the 26.2 headers declare a superclass for, which decides whether a release chain
# may be climbed at all (selftest-api-ledger-chain.py).
source = open(os.path.join(HERE, "api-ledger.py"), encoding="utf-8").read()
call = re.search(r"classify_property\(([^)]*)\)", source[source.index("def main("):])
check("main() passes both protocol inventories to classify_property",
      sorted(part.strip().split("=")[0] for part in call.group(1).split(",") if part.strip()),
      ['api', 'built_classes', 'built_protocols', 'decided', 'getter', 'header', 'release_classes',
       'release_protocols', 'unavailable'])

print("\n%d checks, %d failures" % (10 + len(failures), len(failures)))
sys.exit(1 if failures else 0)