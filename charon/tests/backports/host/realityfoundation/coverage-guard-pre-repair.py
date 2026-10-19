"""The guard as it was before r4: **do not fix this file.**

Kept ONLY so `coverage-control.sh` can show, on every suite run, that the guard this series shipped
in r3 would have accepted a tree where a row the differential measures says nothing measures it. The
bug is the point: `what_this_row_should_say` tests the *verdict* in slot 0, and the call site built the
hit as `(token, number, subject)`, so slot 0 held the token, the covered branch was dead, and the
expected text for a covered row was the declaration-only sentence - which is exactly what all 140
covered rows said. The guard was self-consistent and blind: it caught a hand edit and could not catch
that.

The control asserts three things with this file, and **fails the suite** if any of them does not
hold - it is not a demonstration that is allowed to degrade into an echo:

  1. this fixture exits 0 on the pre-repair copy            (the bug, as shipped)
  2. the real guard exits non-zero on that same copy
  3. and the rows it flags are exactly the covered rows

It is fetched from the working tree, not from `git show HEAD:`, on purpose. A history-relative
addressing would name a different file after a `git am` on another base or after the next commit lands
on top - which is how r4's control came to compare the repaired guard with itself while printing that
it had caught the row.

The two functions below are the r3 versions, byte for byte, and nothing else from the r3 script is
here: the loop that builds the hit, the report and the --write mode all live in coverage.py.
"""

COVERED = ("measured by the host differential, tests/backports/host/realityfoundation, the check "
           "at main.swift:%s: %s")
DECLARATION = ("the declaration in packages/s/swift-runtime/files/, which "
               "tests/backports/host/swiftregistry holds to a name, and the interface line it was "
               "read from. No check in this series measures it")
CLAIMS_A_MEASUREMENT = ("host differential", "the differential")


def what_this_row_should_say(hit):
    # the defect, kept: hit[0] is the token, so this is never "covered" and every row - covered or
    # not - is expected to carry the declaration-only sentence
    if hit[0] == "covered":
        return COVERED % (hit[1], hit[2][:58])
    return DECLARATION
