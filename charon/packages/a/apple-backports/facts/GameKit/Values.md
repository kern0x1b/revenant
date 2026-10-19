# The Game Center value classes of iOS 7.0 and 8.0, carried over the release's own Game Center

**What the release has, measured.** The 6.1.3 armv7 cache's GameKit image carries **304 classes** —
`GKPlayer`, `GKLeaderboard`, `GKAchievement`, `GKMatchmaker`, `GKScore`, `GKMatch`, `GKSession`,
`GKChallenge`, `GKSavedGame` is not among them — and its selector list has **`displayName`,
`playerID`, `score`, `rank`, `isAuthenticated`, `loadImage`**, which is the *modern* Game Center: iOS 6
already answers the questions the iOS 7 API asks of a player. What it has none of is the **set**:
`loadLeaderboardsWithIDs` is not in the release's selector list, so there is no call to make a
`GKLeaderboardSet` from, and a set that was not loaded has nothing to report.

So the three classes in this delivery are carried in the shape the release can support:

- **`GKBasePlayer`** carries the two things a player has on any Game Center, `playerID` and
  `displayName`, both read-only, plus the port's own initialiser. It is the base of the cloud player.
- **`GKCloudPlayer`** and its one class method answer the **release's own `GKLocalPlayer`** when it is
  authenticated — its `playerID` and `displayName`, the pair `GKBasePlayer` carries — and otherwise
  `nil` with `GKErrorDomain` code 1, which is `GKErrorAuthenticationFailed` (the SDK's own `GKError.h`).
- **`GKLeaderboardSet`** carries the three properties the server sends for a set (`identifier`, `title`,
  `groupIdentifier`), read-only, and survives secure coding. Its **four load calls** answer what the
  release's own Game Center answers for a request it has no call for: an empty array or a nil image with
  `GKErrorDomain` code 3, **`GKErrorCommunicationsFailure`** — the SDK's own constant. That is a
  documented failure, and it is deliberately **not** "no sets exist": the device cannot reach the
  container, and saying otherwise would be a claim the release cannot support.

## One divergence from Apple's own hierarchy, named

`GKBasePlayer` is, in Apple's headers, the abstract superclass of `GKPlayer` and `GKCloudPlayer`. **The
release's `GKPlayer` is a class of iOS 6 and cannot be re-parented**, so on this port
`GKBasePlayer` is the base of the *cloud* player and of what this package makes, and a
`[GKLocalPlayer class]` is not a `GKBasePlayer`. An application that writes
`isKindOfClass:` against a base class will get the release's own answer for a local player, and that is
recorded here rather than papered over with a category that cannot exist.

## What the differential holds this to

`tests/backports/host/gamekit` runs the port's own sources against the **host's own GameKit** and
against the SDK's declarations:

    checks=15 failures=0
    and with the port built with -DCHARON_MUTATE_SETLOAD:
    FAIL the port's set load answers no sets: 1
    FAIL and an error rather than a value: no error at all
    checks=13 failures=2

**The mutation is in the port, behind a compile-time switch, and that placement is the point.** Every
answer on this surface is that the release has no such call — no sets, no image, no title, no
identifier, no container record — so a probe that perturbs its own arguments has nothing to change:
three shapes of that were tried and each was a tautology (inverting the expectation on a flag, setting a
read-only property through KVC, and skipping the call so the checks disappear rather than fail). The
switch is `CHARON_MUTATE_SETLOAD` in `GKLeaderboardSet7.m`: a load that answers one set and no error,
where the release has no call that makes a set at all.

**One trap the probe found, and it is worth the record.** `GKErrorDomain` is a `GK_EXTERN_WEAK` global.
The guard reads well and passes — the symbol is *not* nil in the linked binary — and the trap is
`[GKErrorDomain description]`, because a weak global is a load the optimiser cannot prove strong and
`objc_opt_respondsToSelector` is a trap, not a no-op. The object is never messaged now: its class is
read through the runtime's `class_getName`, a C function. The same trap stopped the probe four times in
four disguises.
