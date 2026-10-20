# Builder typechecks

`Tests/TypeChecks/` holds snippets the result builders must accept or refuse, each one a test of the
`SwiftUITypeChecks` target: `./xmakew test -P . SwiftUITypeChecks/*` from the top of revenant, after the `SwiftUI`
target is built. A positive snippet passes when it compiles with nothing said; a negative one passes when the
compiler refuses it and its first error names the reason the snippet exists. Each test's compiler output is in
the target's autogen folder, `<name>.log`.

| test | snippet | refused for |
| --- | --- | --- |
| `tables-positive` | `tables/positive.swift` | compiles: a table over a collection of rows, the row value reaching through `ForEach` and `Group` as the element's own type |
| `tables-negative` | `tables/negative.swift` | `conform to 'TableRowContent'`: a `Text` is not table content |
| `tables-negative-widget-bundle` | `tables/negative-widget-bundle.swift` | `could not be inferred`: a bare `if` in a widget bundle |
| `tables-negative-widget-concrete` | `tables/negative-widget-concrete.swift` | `could not be inferred`: the same with a named widget type |
| `tabs-positive` | `tabs/positive.swift` | compiles |
| `tabs-negative` | `tabs/negative.swift` | `conform to specified type 'TabContent'` |

The two widget-bundle runs that guard the bundle were taken with the earlier `tabletests/run.sh` and are **run
output**, so they are not in this tree: the clean one (exit 0: the bare `if` in a bundle is refused, with a
concrete widget type and with `any Widget`) and the mutant one (exit 1: the same two cases compile once an
overload is added that takes what a bare `if` is).

The mutant is `static func buildOptional(_ widget: (any Widget)?) -> some Widget` in
`Sources/Widgets.swift`, which 26.2 does not have. Add it, build the module, run the two widget-bundle tests,
and they turn red; that is what the case is for.
