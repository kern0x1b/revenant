# settings - what the check covers, and what it owes

`run.sh` builds the port's own four settings objects and one program against them, and runs it. It does
not compare with the system's Accessibility framework, and each row says why: the five settings values
read a *user's* preference, which on a host is the signed-in Mac's; `AXOpenSettingsFeature` opens the
Settings app, so calling it there puts a window on somebody's screen; and the three hearing functions are
`API_UNAVAILABLE(macos)`, the header's own statement that a Mac has no such device, with the answer that
would be the signed-in user's own accessory list.

So the oracle for every answer here is `axs-census.lua` - the release's own accessibility preferences,
with two controls - and the reading is named next to the assertion it holds. `check.m` counts its own
assertions as it runs them and prints the total - it is never written down here, because a number in a
file is a number no run maintains - and `mutants.sh` covers them with eleven mutations: ten killed and
one control green.
The census is its own tool and its own output, and it is committed with the rows that depend on it.

## Owed

**The three hearing answers are never run here.** Their declarations are `API_UNAVAILABLE(macos)`, so no
macOS program can call them, and this machine has no iOS runtime - `xcrun --show-sdk-path --sdk
iphonesimulator` answers `SDK "iphonesimulator" cannot be located`. What holds the three rows is:

  * `hearing-check.m`, compiled for `armv7-apple-ios6.0` against the 16.4 SDK, which holds the compiler to
    the SDK's own declarations of the three functions;
  * `nm` over the built `CharonHearing15.o`, which `run.sh` **asserts** rather than prints - it is what
    mutant M9 turns red on;
  * `axs-census.lua`, which is the measurement the answers are readings of, and which is narrower than
    what the code first claimed: the release's Accessibility surface holds 28 hearing-named exports, all
    of them preferences about a hearing-aid feature and four of them about a paired-UUIDs preference, and
    none of the 28 is an `AXMFiHearingDevice` symbol. That last part is what the three answers rest on,
    and the census prints the list so the reading can be checked.

The program that can run them is `tests/backports/device/hearing.m` - the tree's device-program shape,
compiled clean for the port's own target, which asks the port's three functions for the answers the
census says they must give and prints the release's own where the release has the functions at all. It is
not run by anything in a band; the gate is what runs a device program, and that is when these three rows
stop being held by three measurements.
Until then the run prints `hearing: OWED` as its own last line and the three registry rows carry
`HELD NOT BY RUN` in their `source`, so nothing reads as though a program had produced those answers.

**`AXNameFromColor()` is owed to another series and has no row here at all.** The host answers a curated
named-colour vocabulary with a nearest-match rule rather than the components of a colour, so the work is
a black-box fit and not a lookup: probe the host densely, identify the vocabulary and the decision rule,
implement the port's own rule and the port's own prototype table from those measurements, and report the
agreement over a held-out sample of at least 200,000 colours that were not in the fit set. Nineteen of
the probe's answers are in the accessibility3 worktree's run directory. The owed line is in
`facts/Accessibility/Accessibility.md` under Owed, and the registry has no row for the function - not an
`absent` one either, because `absent` says the API is not carried and that is not what is true here.
