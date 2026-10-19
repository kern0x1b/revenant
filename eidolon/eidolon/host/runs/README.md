# runs

The two runs of `eidolon/tools/tabletests/run.sh` that guard the widget bundle are **run output**, so
they live in `.agent-work/runs/` and not in this tree — `tabletests-clean.log` (exit 0: the bare `if` in a
bundle is refused, with a concrete widget type and with `any Widget`) and `tabletests-mutant.log` (exit 1:
the same two cases compile once an overload is added that takes what a bare `if` is).

The mutant is `static func buildOptional(_ widget: (any Widget)?) -> some Widget` in
`eidolon/Sources/SwiftUI/Widgets.swift`, which 26.2 does not have. Add it, build the module, run the
tabletests, and the two cases turn red; that is what the case is for.
