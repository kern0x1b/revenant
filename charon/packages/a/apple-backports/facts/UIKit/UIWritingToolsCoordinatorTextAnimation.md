# `UIWritingToolsCoordinatorTextAnimationDebugDescription()`, iOS 18.2

`UIWritingToolsCoordinatorTextAnimationDebugDescription(UIKit/UIWritingToolsCoordinatorTextAnimation18.m)`.

## What was measured, and how

The four answers were **measured by calling the Mac Catalyst UIKit's own function** on macOS 27
(build 26A428), not read from a header and not inferred from the case names. The probe runs inside
this repository's own windowed harness (`tests/backports/host/uikit2/windowed.m`), `dlsym`s the
function out of the process and calls it for every value; the source is
`.agent-work/runs/uikit-c/catalyst-probe-body.m` and its output `.agent-work/runs/uikit-c/probe.out`:

```
#catalyst	Version 27.0 (Build 26A428)
value	UIWritingToolsCoordinatorTextAnimationDebugDescription(0)	Awaiting-new-text animation	-
value	UIWritingToolsCoordinatorTextAnimationDebugDescription(1)	Text removal animation	-
value	UIWritingToolsCoordinatorTextAnimationDebugDescription(2)	Text insertion animation	-
value	UIWritingToolsCoordinatorTextAnimationDebugDescription(99)	Unknown text animation	-
```

A Mac Catalyst process is the only Mac Catalyst UIKit that starts on this machine, and that is
measured too, three ways: a plain command line binary built for `arm64-apple-ios15.0-macabi` dies in
the ObjC runtime's `realizeClassWithoutSwift` (SIGBUS, exit 138); a bundle with no scene manifest
traps in `___UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` (SIGTRAP, exit 133); and
the harness's own `colors` group reaches its first check here, so the harness itself is sound.

## The case numbers

The header (`UIWritingToolsCoordinator.h:431-447`) declares three cases with no explicit values, so
they are 0, 1 and 2 in the order it declares them - which the probe's answers confirm: the value the
function returns for 0 is the one the header documents for the animation "while waiting to receive
results from the large language model", for 1 the removal, for 2 the insertion. `99` is none of them,
and the release names that case too rather than answering nil.
