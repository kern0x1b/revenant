#!/usr/bin/env python3
"""
Does a `+[X new]` row read missing while the release answers it through NSObject?

`+new` is NSObject's, and every class inherits it. classify_method looked for the selector in the
owner's own method lists only, so every `+[X new]` row whose class does not declare one read
"selector new is not" -- for a selector the release carries. Measured in the release's own 6.1.3
cache: NSObject declares `+new` in its metaclass, and 2 of 11378 classes declare one of their own
(NSObject and _PFCachedNumber), so 11376 inherit it. The port's libraries do not declare it and do
not need to: they are loaded beside the device's libSystem, whose NSObject has it.

The rule is narrow on purpose, and this file holds every edge of it:

  - only `+new`, the class factory. An instance method that happens to be called `new` is a
    different API and NSObject declares no `-new`: `-[WKWebsiteDataStore new]` is NS_UNAVAILABLE in
    Apple's own header. And `-init`, though NSObject's too, is not universal -- 2549 of the same
    11378 release classes declare their own -- so v-audio/v-health/v-metal are deciding those per
    class by measurement and `-[X init]` is their row, not this one.
  - only a class owner. A protocol has no metaclass chain to inherit from.
  - never a row a registry has decided. `+[VNFaceLandmarkRegion new]` is answered by NSObject's
    `+new` only to call the class's own NS_UNAVAILABLE `-init`; that is a measurement somebody took
    and an inference from the release's metadata does not overrule it. 16 `+[X new]` rows are in
    that state and this is what keeps all 16.

    python3 selftest-api-ledger-new.py

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

CHECKS = []
failures = []


def check(what, got, want):
    CHECKS.append(what)
    if got == want:
        print("ok   %s" % what)
    else:
        print("FAIL %s\n       got  %r\n       want %r" % (what, got, want))
        failures.append(what)


def entry(instance=(), klass=(), library="Backports"):
    return {"instance": set(instance), "class": set(klass), "protocols": set(),
            "superclass": "", "image": "", "library": library}


BUILT = {"Widget": entry(instance=["-go"], library="UIKitBackports")}
RELEASE = {"OldWidget": entry(instance=["-oldGo"]), "Speaker": entry(klass=["-new"])}
PROTOCOLS_BUILT = {"Shape": entry(instance=["-area"], library="UIKitBackports")}
PROTOCOLS_RELEASE = {}
# The same row as the first check, and the registry has decided it. The owner is deliberately a class
# in an inventory: with an owner that is in neither, the row reads missing whatever the guard does,
# and the check would pass for the wrong reason -- which is how the first version of this file read
# green with the guard deleted.
DECIDED = {"+[Widget new]"}


def status(api, decided=None, classes=None, release=None):
    return ledger.classify_method(
        api, BUILT if classes is None else classes, RELEASE if release is None else release,
        PROTOCOLS_BUILT, PROTOCOLS_RELEASE, decided=decided)[0]


# The row. A class in the built libraries that declares no `+new` of its own: before, missing with a
# reason that names a selector the release carries.
check("a class that does not declare +new itself reads implemented",
      status("+[Widget new]"), "implemented")
check("and the reason says what answers it",
      "NSObject" in ledger.classify_method("+[Widget new]", BUILT, RELEASE, PROTOCOLS_BUILT,
                                           PROTOCOLS_RELEASE)[1], True)

# The mutation this fixes: the same row with no decided set handed over and no release class of the
# same name still reads implemented -- the rule does not depend on the caller. What it does depend on
# is that the owner is a class.
check("a class that is in neither inventory still reads missing",
      status("+[Nowhere new]"), "missing")
check("with the reason that says the owner is absent",
      ledger.classify_method("+[Nowhere new]", BUILT, RELEASE, PROTOCOLS_BUILT, PROTOCOLS_RELEASE)[1],
      "owner Nowhere is neither a class nor a protocol in the built libraries or the 6.1.3 cache")

# A protocol owner: no metaclass chain, so nothing is inherited.
check("a protocol's +new is not answered by inheritance", status("+[Shape new]"), "missing")

# A class that declares its own +new is answered by that, not by NSObject, and the reason names it.
own = {"Widget": entry(instance=["-go"], klass=["-new"], library="UIKitBackports")}
check("a class that declares its own +new is answered by it",
      ledger.classify_method("+[Widget new]", own, RELEASE, PROTOCOLS_BUILT, PROTOCOLS_RELEASE)[1],
      "built: UIKitBackports")

# Only `new`, and only as the class factory. An INSTANCE method called `new` is a different API:
# `-[WKWebsiteDataStore new]` is declared NS_UNAVAILABLE in Apple's own header, and NSObject declares
# no `-new`, so nothing inherits it. The first version of this rule did not look at the sign and
# credited five of those (`-[WKWebsiteDataStore new]`, `-[ARRaycastQuery new]`,
# `-[ARRaycastResult new]`, `-[ARTrackedRaycast new]`, `-[WKWebExtensionAction new]`); the run below
# is what caught it.
check("an instance method named new is not answered by inheritance",
      status("-[Widget new]"), "missing")

# A row a registry has decided keeps its decision: this is the guard, and it is the reason the
# `decided` argument exists at all. Same row, same owner, same inventories as the first check.
check("the same row reads implemented when no registry has decided it",
      status("+[Widget new]"), "implemented")
check("and missing once one has", status("+[Widget new]", decided=DECIDED), "missing")

# Only `new`. `-init` is NSObject's as well and is deliberately NOT answered here.
check("-[Widget init] is not answered by inheritance", status("-[Widget init]"), "missing")
check("and neither is any other class selector",
      status("+[Widget makeOne]"), "missing")

# A method row that does not parse is still undecided, not implemented.
check("an api that does not parse stays undecided",
      ledger.classify_method("nonsense", BUILT, RELEASE, PROTOCOLS_BUILT, PROTOCOLS_RELEASE)[0],
      "undecided")

# The call site, a wiring check against main's source text rather than a run: build() needs a gate, a
# dyld cache and an SDK to reach that line. It is a wiring check and says so. Dropping `decided=` from
# the call leaves every behavioural check above green while the 16 decided rows are over-credited.
source = open(os.path.join(HERE, "api-ledger.py"), encoding="utf-8").read()
call = re.search(r"classify_method\(([^)]*)\)", source[source.index("def main("):])
check("main() hands classify_method the decided rows", "decided=decided_apis" in call.group(1), True)
check("and the decided set is the registries' own decisions",
      'entry[0] in DECIDED_STATUSES' in source, True)

print("\n%d checks, %d failures" % (len(CHECKS), len(failures)))
sys.exit(1 if failures else 0)