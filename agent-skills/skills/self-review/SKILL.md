---
name: self-review
description: Review your own work on an old-iOS app for crutches before you hand it to the user — hard-coded values standing in for behaviour, stubbed or faked APIs, private API where a public one or a backport exists, disabled availability checks, waived Charon checks, swallowed errors, special cases for one device or release, copied files in place of a build step, evidence claimed but not produced. Use every time before you tell the user a step is done, record evidence in PROJECT.md, hand over a .deb, or publish to a repository.
---

# Self-review before handing over

Every change you make to the user's app is the correct, native one: the way the system and the
stack intend it to be done, even when that takes longer. This skill is how you check your own work
against that before the user sees it. A finding is fixed, not explained away. Run it at the end of
every step of the journey, before its evidence goes into `PROJECT.md` under `## Progress`.

## 1. What to review

Everything the step changed or produced, not only the last edit:

- the project's files: sources, `xmake.lua`, `Info.plist`, resources, packaging files. If the project
  is a git repository, `git diff` against the commit the step started from; otherwise read every file
  the step touched;
- anything outside the project the result depends on (a script you ran by hand, a file you copied in);
- the evidence you are about to record: the log, the verdict line, the `.deb` path.

## 2. What counts as a crutch

Go through the change once per row. The question each time: *is this the native, correct way, or a
way to make it look done?*

| Look for | Crutch when | Native when |
| --- | --- | --- |
| Literal values: sizes, offsets, colours, versions, strings | it stands in for behaviour the system provides or that could be measured (a hard-coded screen size, status bar height, OS version) | it is a design decision of the app, or read from the system at run time |
| `return nil` / `NO` / `0` / empty, an empty method body | it replaces behaviour the app was asked to have | it is the real answer for that case |
| `TODO`, `FIXME`, `XXX`, `HACK`, "not implemented" | always, in anything handed over | — |
| A branch on one device model, one release, one test input | it makes one case pass instead of the general one working | the behaviour really differs there, and `respondsToSelector:`, `#available` or the release's own API decides it |
| Private classes, selectors, ivars by name, swizzling | a public API or a Charon backport does the job | no public way exists on that release, you checked the release's own library, the user agreed, and it is under `## Limits` |
| `-Xfrontend -disable-availability-checking` | always: it makes every `#available` true, so the check is taken on a release that lacks the API | — (guard with `#available`, or use a backport) |
| `charon.waive.weak-imports` | it was added to get `xmake deb` through | every use of each symbol it covers sits behind a check for it (`respondsToSelector:`, a class or function-pointer test, `#available`), the value says so, the user agreed, and it is under `## Limits`. The symbols the compiler emits itself (the ARC entry points, the block runtime) are refused whatever the waiver says: fix the link or add the package that carries them |
| Any other `charon.waive.<check>` (`pagezero`, `input-minimum.<package>`, …) | it was added to turn a refused build green | the check does not apply to this target, shown by a measurement and not assumed, the value says why, the user agreed, and it is under `## Limits` |
| `-fobjc-arc` on the compile but not on the link | always. Nothing hides it: below iOS 5.0 Charon refuses the build and names the ARC entry points the link did not carry (`should carry it from arclite`); from 6.0 the build is green without the flag, so it is lost unnoticed until `apple_minimum` moves down | both `add_mflags` and `add_ldflags` (skill `project`) |
| `-w`, a warning turned off | it hides what the build is telling you | — |
| `|| true`, `2>/dev/null` on a step whose failure matters, an empty `@catch`, an ignored `NSError` | always | — |
| A file copied into the project in place of what a build step produces (a prebuilt binary, a plist from elsewhere, a library from another project) | always | the build produces it |
| A file, a sample or fragments strung together taken from these skills, or code taken from another app | always: the project is written for this app | — (the single line a skill gives for one step, an `xmake.lua` line, a flag or a call, is meant to be used) |
| Progress evidence | the log, verdict or `.deb` was not produced by a command you ran in this step | you ran it and the recorded line is in its output |
| Anything of Apple's in the project (firmware, dyld cache, SDK header, framework, artwork) | always | — |

A quick scan over the project, as a start, not as the review:

```
grep -rnE 'TODO|FIXME|XXX|HACK|not implemented|disable-availability-checking|charon\.waive|\|\| true|2>/dev/null|@catch *\([^)]*\) *\{ *\}|method_exchangeImplementations|object_getIvar|valueForKey:@"_' --exclude-dir=build --exclude-dir=.xmake .
```

## 3. What to do with a finding

1. **Fix it natively now**, then re-run everything the step needs: the build (skill `build`), the
   emulator check (skill `emulate`), the package (skill `package`). A fix that has not been re-run is
   not a fix.
2. **Only if it truly cannot be done natively** — the stack lacks the API on that release and no
   backport provides it, or Charon or the emulator cannot do what the step needs — stop and tell the
   user: what is missing, on which release or device, what you measured to know it, and what would
   remove the limit. Write the same under `## Limits` in `PROJECT.md`. Do not ship the crutch
   without the user's decision. "It is hard" or "it takes long" is not a reason.

## 4. What you tell the user

When you report a step as done, say one of:

- **Self-review: clean** — you went through §2 and found nothing, or fixed what you found (one line
  each);
- **Self-review: limits left** — each entry you wrote under `## Limits`, first, before anything else.

## Traps

- Reviewing only the last edit → review the whole step; a crutch added early survives otherwise.
- A green build as proof → the build proves it links against the release. A probe's verdict in the
  emulator proves the code it exercises; only the device proves the app itself launches and draws
  (skill `emulate`, "Checking an app").
- Recording evidence from memory → copy the line from the output of the command you ran.
