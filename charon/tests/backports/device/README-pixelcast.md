# The pixel cast's device run, prepared

Nothing here has been run. The library the run measures is built by the package, and that comes with
the coordinator's stack-14 push; the installed `libSceneKitBackports` in the store carries **0**
occurrences of `projectPoint` today (measured), so a run now would measure a library without the code
under test. The provenance check is what stops that run from being believed, and it is the same
method as `coordination/reviews/2026-09-28-install-stale.md`: a Mach-O's `LC_UUID` is its build's.

## The three pieces

| file | what it is |
| --- | --- |
| `scenekitprojection.m` (+ `build-scenekitprojection.sh`) | the device test that holds the *backports'* `projectPoint`/`unprojectPoint` to the sixteen answers macOS's renderer gave. Already written, already compiling for `armv7-apple-ios6.1.3` with 0 errors and 0 warnings. |
| `scenekitprojection-probe.swift` | a guest **program**, because `Scene.pixelCast` is a RealityFoundation member of the swift-runtime overlay and an Objective-C device test cannot reach it. It prints what a cast hits rather than deciding pass or fail: a scene with no view (the first nil, and the right one), a cast down the camera's axis through a box at the origin, and a cast beside the box that has to answer nothing. |
| `provenance.sh` | `uuid`, `same`, `prefix`, `check` - the LC_UUID and the bytes up to `LC_CODE_SIGNATURE`, read through `otool` so the byte order of a uuid line is otool's business. |
| `run-pixelcast.sh` | the order, with `RUN=1` to execute it: build, build, record provenance, `xmake emulate install`, check the in-image copies, run the test then the probe, and print the verdicts from `xmake emulate log`. |

## The provenance check, exercised here

Not on the device - on two real armv7 binaries this worktree built, which is the only place it can be
exercised before the push:

```
provenance.sh uuid .agent-work/runs/vec-probe            4B3FC14078FE3F90A4B1DB0CF68B2FB0
provenance.sh same  vec-probe  vec-probe-copy            same build, LC_UUID 4B3FC140...
provenance.sh same  vec-probe  vec-probe-2              NOT the same build   exit 1
provenance.sh prefix /bin/ls .agent-work/runs/ls-copy   the bytes up to LC_CODE_SIGNATURE match (288 288 same)
provenance.sh prefix /bin/ls /bin/cat                   differ (288 288 differ)
```

A copy of one build keeps that build's UUID and a rebuild does not, which is the property the
method rests on and the one the stale-install review measured.

## What the run will decide, and what it cannot

The run can answer whether the port's projection, in a built library on a real iOS 6.1.3, agrees with
macOS SceneKit's own for the sixteen recorded points - that is the device test's verdict. It can
print whether a cast through a box finds that box.

It cannot decide that the pixel cast is *correct* in Apple's sense: there is no Apple to compare it
to on this release, and the geometry the probe uses is the geometry this port carries. The probe's
numbers are for reading, not for a threshold.
