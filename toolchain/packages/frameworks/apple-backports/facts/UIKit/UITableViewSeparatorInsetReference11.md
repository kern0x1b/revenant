# UITableView.separatorInsetReference, iOS 11.0

One row, and it stays `absent`. What changed here is the row's **reason**: the version this page
replaces said the port "does not draw the table's separators, so there is no drawing for a reference
to steer", and that is false about this tree's own code. `packages/frameworks/apple-backports/UIKit/UITableView+Separators7.m`
takes a table's separators over - it sets `separatorStyle` to None for that table, which is the
release's own answer for a table with no separator, remembers what the style was, and draws the line
itself in a view of its own inside each cell (`RevenantTableSeparatorView`, `-revenant_layoutSeparator`).
So the port draws them, and it draws them at one of exactly two positions:

- at the cell's own edges, at `separatorInset` - `-revenant_layoutSeparator:147-150`;
- narrowed by the table's `layoutMargins`, which is what `cellLayoutMarginsFollowReadableWidth` asks
  for - `-revenant_layoutSeparator:153-157`, and the flag is the port's own member on these bands
  (`UITableView+Separators7.m:226-236`).

`separatorInsetReference` is the iOS 11 name for choosing between those two insets. So the question is
not whether the port has a drawing for it to steer - it has - but whether carrying the newer name would
answer what the system answers. It would not, and that is measured, below.

## The release carries neither name on the bands this port builds

```
$ xmake l tools/cache-index/first-rung.lua separatorInset separatorInsetReference \
      setSeparatorInsetReference: cellLayoutMarginsFollowReadableWidth zzzBackportProbeXYZ
separatorInset	7.0
separatorInsetReference	11.0
setSeparatorInsetReference:	11.0
cellLayoutMarginsFollowReadableWidth	9.0
zzzBackportProbeXYZ	NONE
```

Both band ends are below all three: the property is a later name than the flag that steers the port's
one drawing, and later than `-separatorInset` itself. The class-scoped reading is the row's `source`:
`xmake l tools/corpus/objc-inventory.lua` over `~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7` and
`~/.revenant/dyld/4.3/dyld_shared_cache_armv7`, where `UITableView` is in both dumps and its own selector
table holds no `-separatorInsetReference`, with `-setSeparatorStyle:` present on it in the same two
dumps.

**A selector-list index that cannot be used here, so nobody uses it again.** The obvious cheap check -
`grep -cxF separatorInsetReference ~/.revenant/dyld/6.1.3/selectors_armv7.txt` - answers 0 for 6.1.3 and
for 4.3, and so does the control it needs: the same file answers 0 for plain `separatorInset`, which
first-rung places at **7.0**, and 1 for `reloadData`. So `selectors_armv7.txt` is a partial list, a zero
in it says nothing about the release, and the only reader that has a self-test is `first-rung.lua`.
Measured 2026-10-03.

## The two names are not one switch on the system, and that is what settles it

The obvious implementation - a category that stores the reference and steers the drawing the way
`cellLayoutMarginsFollowReadableWidth` does - assumes the newer name is the older one under a new
spelling. The system does not treat them that way. Measured on the host's own UIKit under Mac Catalyst,
which is the release this tree measures against wherever a host answer exists:

```
$ xcrun clang -fobjc-arc -target arm64-apple-ios15.0-macabi -isysroot $(xcrun --show-sdk-path) \
    -iframework $(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks \
    -framework UIKit probe.m -o probe && ./probe
fresh table, nothing set                       separatorInsetReference=0 cellLayoutMarginsFollowReadableWidth=0
set separatorInsetReference = FromAutomaticInsets separatorInsetReference=1 cellLayoutMarginsFollowReadableWidth=0
set separatorInsetReference = FromCellEdges    separatorInsetReference=0 cellLayoutMarginsFollowReadableWidth=0
set cellLayoutMarginsFollowReadableWidth = YES separatorInsetReference=0 cellLayoutMarginsFollowReadableWidth=1
set cellLayoutMarginsFollowReadableWidth = NO  separatorInsetReference=0 cellLayoutMarginsFollowReadableWidth=0
controls                                       FromCellEdges=0 FromAutomaticInsets=1 followsReadableDefault=0
```

The probe is `.agent-work/runs/separator-inset/probe.m` in the worktree this landed from; each of the
four lines is a fresh table so no setting is inherited. Read the two middle pairs against each other:
setting the reference to `FromAutomaticInsets` leaves the flag answering **NO**, and setting the flag to
YES leaves the reference answering **FromCellEdges**. Each reads back exactly what was set and moves
nothing else. The controls in the last line are what make the zeros readable - both enum values and the
flag's default are in the same run.

So on a real release the two names are two settings over one separator, not one setting under two
names. The port has one drawing and therefore one switch, and the flag is the name **the release
carries** on every band this port builds.

Carrying the newer name here would have to do one of three things, and each is a lie about one of the
two names above: answer the reference and change nothing, which is a value nothing consults (the flag
still steers); or take the drawing away from the flag, so an application that sets the flag the release
has sees it stop working; or accept both names for one switch, which is the equivalence the run above
refutes. Hence `absent`, stated as what a caller gets rather than as a queue entry: the property is not
declared, `respondsToSelector:` answers honestly, and an unchecked call raises.

## The spelling, for whoever tries this again

The type is `UITableViewSeparatorInsetReference` and the two cases are
`UITableViewSeparatorInsetFromCellEdges` and `UITableViewSeparatorInsetFromAutomaticInsets`
(SDK 16.4 `UITableView.h:317`, and the property at :370 with "The default value is
UITableViewSeparatorInsetFromCellEdges"). There is **no** `UITableViewCellSeparatorInsetReference` and
no `...FromCellLayoutMargins`: `grep -rl` over the 16.4 SDK's `UIKit.framework/Headers` names no file
for `UITableViewCellSeparatorInsetReference` and does name `UITableView.h` for each of the other four.
An earlier attempt at this row spelled the type `UITableViewCellSeparatorInsetReference` and the case
`UITableViewCellSeparatorInsetReferenceAutomatic`, which is why it did not compile.

The header's default and the flag's default agree, which is the one thing the two names do share:
`FromCellEdges` is 0 and a fresh table answers 0 for both (the probe's first line).

**Not claimed:** that the host's behaviour on 26.2 under Mac Catalyst is what a 6.1.3 table would have
done had it carried the property. It does not carry it - that is the first section - and the question
asked here is what carrying the name would have to answer, which the host answers for itself.