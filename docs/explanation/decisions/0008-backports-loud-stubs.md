# 0008: Backports live in `frameworks/Backports`; a gap is a loud stub

Status: accepted

## Context

The backports are iOS frameworks and members newer than the iOS 6 target, provided as libraries an app links
against. A member we have not yet written must not silently resolve to an empty symbol: an app would load and
then misbehave on a device.

## Decision

Backport code lives in one component, `frameworks/Backports`, and the Swift packages (`revenant@appintents`,
`revenant@activitykit`, `revenant@tipkit`, `revenant@widgetkit`, and the others) are wrappers of its `Swift`
component. A member that is not yet backported is an open gap, declared with `open_gap(name, cause)`
(`frameworks/Backports/src/Swift/xmake.lua`). Its target raises at build time, naming the framework, the
deployment target and the cause, and pointing at the open gaps in `frameworks/Backports/README.md`.

## Consequences

- Building a target that has an open gap fails, on purpose; the cause says what is missing.
- The README's "Open gaps" section is where a reader finds the gap and its reason.

## Enforced by

The build: `open_gap` raises in `before_build`, so an open gap stops the build that reaches it. `repository/open_gaps`
reads every gap name in `frameworks/Backports/src/Swift/xmake.lua` and fails when the README does not name it in
backticks.

## Not enforced

That the README lists no gap that is closed: a name in its open-gaps section that no `open_gap` declares is not
checked, because the README also names partial members, which are not gaps.
