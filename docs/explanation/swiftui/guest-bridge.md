# The SwiftUI surface an app needs, and how to reproduce it

Question: what exactly does an app built against the real SwiftUI require from the framework, and can our implementation
hand it the same thing? The answer is checked by building and linking, not by reasoning.

## The test app

`app.swift` is an ordinary SwiftUI app: `@main App`, `WindowGroup`, `NavigationView`, `List`, `ForEach` over
`Identifiable`, `NavigationLink`, `Toggle`, `Button`, `Text` with string interpolation, `@State`, `@StateObject`,
`ObservableObject` with `@Published`, `navigationTitle`.

Build: `swiftc -target arm64-apple-ios14.0 -sdk <SDK 16.4> -F fw -O -wmo -parse-as-library`, where `app.swift` is
`frameworks/SwiftUI/tests/data/api/app.swift`.
`fw/SwiftUI.framework` is a local copy of the framework from the SDK, which `tools/api_surface.lua prepare` makes in the
run's folder, with one line of `swiftinterface` changed (`os_log` with string interpolation does not rebuild with the
6.4 compiler). The copy is needed only to compile the test app on this machine; nothing from Apple is distributed.

## What turned out

The app requires **127 symbols**: 64 from SwiftUI, 12 from Combine, 14 from the stdlib, and the rest C and ObjC.

Of the 64 SwiftUI symbols, 35 are functions, initializers and accessors, and 29 are metadata records (13 nominal type
descriptors, 6 method descriptors, 3 protocol descriptors, 4 associated type descriptors, 2 witness tables, 1 metadata
accessor).

The app contains neither a type layout nor the framework's code. SwiftUI is resilient, so the app builds the metadata of
its own types at run time through the framework's value witnesses, and the whole graph and drawing go through three
entry points: `View._makeView`, `View._makeViewList` and `View._viewListCount`. The app does not import the
`_ViewInputs`, `_GraphValue` or `_ViewOutputs` symbols at all: those types are opaque to it, and it only passes them on.

## The protocol shapes (from the firmware cache)

`View` is the same in iOS 16.0 and 18.0: six requirements, in this order.

| slot | requirement |
|---|---|
| 0 | access to the associated conformance `Body: View` |
| 1 | access to the associated type `Body` |
| 2 | `static _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs` (with a default implementation) |
| 3 | `static _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs` (with an implementation) |
| 4 | `static _viewListCount(inputs: _ViewListCountInputs) -> Int?` (with an implementation) |
| 5 | the getter `body` |

`App`: the conformance, the associated type, the getter `body`, and `init()`. `Scene`: the conformance, the associated
type, the getter `body`, and one static method with a default implementation.

## Reproducing it with our implementation

For this experiment `frameworks/SwiftUI/src/` was built for `arm64-apple-ios14.0` against the real SDK. `-DREV_SYSTEM_COMBINE` took the
system's Combine instead of ours, and that flag is gone from the sources, which take our Combine now. `-D REV_NO_FIELD_REFLECTION` stands in for `_forEachField`, which the prebuilt stdlib
does not have; the port has that SPI, because its runtime is built from source.

| step | matched, of 64 |
|---|---|
| as first written | 36 |
| after aligning the shapes (`LocalizedStringKey`, the `View` entry points, `List<SelectionValue, Content>`, `ForEach` without the `Content: View` constraint on the type, `ObservedObject.Wrapper`, alignment and builders as structs) | 58 |
| plus `-enable-library-evolution` (without it the compiler emits no method descriptors) | **64** |

Then the app is linked against our implementation:

```
swiftc -target arm64-apple-ios14.0 -sdk $SDK -o demo-arm64 app-nc.o arm64/SwiftUI-evo-nc.o \
  -framework UIKit -framework Foundation -framework Combine
```

The link succeeds, and **zero** SwiftUI symbols are unresolved.

## What this means, and what it does not

It means that the app does not need Apple's code. It needs the interface, and that interface can be reproduced in full.
For the recompiler pipeline it removes the need to touch `SwiftUI.framework` at all: the guest side is built as "the
app, our SwiftUI (arm64) and the guest's libswiftCore".

It does not mean that the app works. Linking checks names and shapes, not behaviour. Our `_makeView` semantics are our
own (our engine builds the nodes itself and does not use these entry points). The match of resilient type layouts has
not been checked at run time, and nothing has been run. The first real answer comes from the recompiler's probe: this
same app, translated to armv7, on the emulator's screen.

## Requirements that follow for our implementation

1. The module must be named `SwiftUI`, because the manglings depend on it.
2. For the guest build, the module is built with `-enable-library-evolution`.
3. Names and argument labels must match Apple's word for word, including `LocalizedStringKey`, the number of generic
   parameters of the generic types, and the level at which each constraint sits. `ForEach` is declared without
   `Content: View`, and the constraint is added in an extension with the `View` conformance.
4. The order of the protocol requirements must match slot for slot (the table above).

## Commands

The scripts that extracted the protocol shapes and the slot table from the firmware cache were exploratory, and they did
not go into the repository. The rest of the command is repeated here:

```
nm -u app.o | sort > undef.txt
```
