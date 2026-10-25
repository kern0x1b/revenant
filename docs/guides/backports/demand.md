# Demand: the SDK API an app needs, against iOS 6.1.3

`frameworks/Backports/tools/demand.lua` lists the SDK API that an application references, and classifies each item
against the iOS 6.1.3 system, against what the Backports implement, and against what a Swift runtime or a revenant
component provides. It works on any application: its input is a source tree (Swift, Objective-C, C, C++) and/or its
build products (objects, archives, Mach-O images), and nothing in it is specific to one app.

## Run it

```sh
./xmakew f -P . -p iphoneos -a armv7 --component=Backports -y
./xmakew build -P .
./xmakew l -P . frameworks/Backports/tools/demand.lua --report DIR --source SRC [--source SRC2] [--files LIST] \
    [--product PATH] [--runtime PATH] [--component PATH] [--objects build/.objs] [--ios 6.1.3]
```

`--source` may be given more than once, and so may `--files`, `--product`, `--runtime` and `--component`. `--files` names
a list of source files, one path per line; a source tree is walked for its files, and a list names exactly the files to
scan. A product is a `.o`, a `.a`, a Mach-O image, or a folder of them. `--objects` is the folder of the Backports
objects, `build/.objs` by default, which the build above writes. `--runtime` names the libraries of a Swift runtime an
iOS 6.1.3 device does not ship, and `--component` the libraries of a revenant component that implements API for it. A
provider library supplies the types of the module its file name names (`libCombine.a` supplies `Combine`, and
`libswiftFoundation.dylib` supplies `Foundation`), so a definition that a library makes for another module's type is not
counted. The report goes to `DIR`:

- `summary.txt`: the totals, the totals per framework, the missing items by kind, and the top 50 missing items;
- `frameworks.tsv`: referenced, present, backported, runtime, missing, and the counts by evidence level, per framework;
- `items.tsv`: every referenced item, with its framework, availability, status, evidence level, file count, bridge and
  the source of its status (`via`);
- `missing.tsv`: the missing items, most files first;
- `missing_files.tsv`: each missing item with each file that references it, for a build-graph overlay;
- `item_files.tsv`: every item with every file that references it, for a precision sample;
- `candidates.tsv`: member names that might be API, counted apart from the totals.

The bridge column names the Objective-C class that a Swift type bridges to (`NSURL` for `URL`), when that class is present
on iOS 6.1.3. A Swift type with a bridge is still a Swift overlay type, and it is provided by the runtime when the runtime
ships it.

## What the classes mean

Every referenced item gets one status, in this order. `present` means iOS 6.1.3 has it. `backported` means iOS 6.1.3 does
not have it, and a Backports object or a `--component` library implements it. `runtime` means iOS 6.1.3 does not have it,
and a `--runtime` library provides it: the Swift overlay types that revenant's Swift runtime ships. `missing` means none
of these holds. An item absent from the SDK is not counted: it is the app's own code or a private API, and the summary
counts those apart. `items.tsv` names the source of each status in its `via` column.

The iOS 6.1.3 system is the dyld shared cache under `.cache/dyld/6.1.3`, read through `apple.dyld`. Classes, C
functions and global variables are checked there, by the cache's export table, which holds the exports of every library
in it: a symbol counts as present when some library on iOS 6.1.3 exports it, whichever framework the SDK names as its
owner. The cache wins over the SDK's annotation: a class the cache exports is present even when its SDK declaration says
a later iOS introduced it. The summary counts those cases.

A member (an instance or class method, or a property) is checked by the availability its SDK declares, and its class
must also be present in the cache. Enum constants, protocols and Swift types are checked by their availability only. A
declaration with no availability annotation counts as present, and the summary says how many there are.

Where one name is declared by several SDK frameworks, the declaration that the SDK annotates explicitly, and that
was introduced first, is the one that counts. A framework's own Swift module owns its Swift types.

The SDK is the one `toolchain/modules/workspace.lua` names. `REVENANT_GEN_SDK` names another iPhoneOS SDK folder, and
the run reads that one.

## How exact it is

Each item carries the weakest evidence it rests on.

| Level | Source of the reference | Exact? |
| --- | --- | --- |
| `exact` | the undefined symbols of a product (`nm -u`), and the frameworks a source imports (`#import`, `#include`, `@import`, `import`) | yes, for what the product or the source names |
| `syntax` | an Objective-C message `[Receiver selector:]` and an `@selector(...)`, read from `.m`, `.mm` and headers | the selector is exact. The receiver is a class name, a cast, or a variable or property whose declared type is in the same file or unambiguous across the tree. A receiver of an application class is not an SDK API. A message to self whose selector the same file declares is the file's own method. Any other receiver is a selector-level item |
| `text` | an identifier in the source that is not after a `.` and is not in an import directive, or a selector string in a product, matched by name against the SDK | approximate: an app name that matches an SDK name counts, unless the scanned sources declare it. A name is declared by an interface, implementation or protocol with a body, by a Swift class, struct, enum, protocol or actor, or by an enum case with associated values. A forward declaration, a category and a typealias declare nothing |
| candidate | a member name after `.` in Swift or Objective-C | not counted; listed only in `candidates.tsv` |

Swift is not type checked. Its references are the names it spells: imported frameworks, type names matched against the
SDK's Swift and Objective-C class names, and member names as candidates. A message to a receiver of unknown type is a
selector-level item: the selector exists in the SDK, but not on which class. Its status is an estimate.

### Measured precision

A random sample of the items of the library map was judged against the source, by reading one sampled occurrence per
item. The first sample was taken before the fixes described above, and the second after them, from the same tree, with a
different seed.

| Tier | Sample | Before | After |
| --- | --- | --- | --- |
| `syntax` | 50 items | 4 false, 8% | 1 false, 2% |
| `text` | 50 items | 1 false, 2% | 0 false, 0% |
| `exact` | not sampled | | |

With 50 items per tier, a rate of 0 or 1 out of 50 leaves a 95% interval that reaches about 10%. The `exact` tier is the
product symbols and the framework imports, which are syntax facts, and it was not judged. Where a sampled item had both
a true occurrence and a `super` call to an application class in its first lines, it was judged by the true occurrence.

## What it cannot see yet

- Macros and generated code. A header or a source the scan does not get (a build step's output, a Swift-generated
  header) leaves its references unseen.
- Types that are not classes, protocols, C functions, global variables, enum constants or members: typedefs, structs,
  enums as types, and macros.
- Swift member resolution by type. A Swift call `x.frame` is a candidate, not a reference to `UIView.frame`.
- Method presence on iOS 6.1.3 measured by the cache. It is taken from the SDK's annotation. The cache holds the
  classes and the functions, not each class's method list.
- Versions below the minor release: 6.1.3 and 6.1.4 are both `6.1`.
- Products built for an architecture other than the one `nm` reads: a fat binary is read through all its slices.
- A message whose receiver is a property typed in a header that is not in the scanned files: its type is not known, so it
  is a selector-level item.
- Selector-level items with a receiver of unknown type are counted when the SDK has the selector on any class. A method
  that the app declares itself, sent to a receiver of unknown type, is counted the same way.
- A framework counts as present when the cache has a library under its own install name. A framework whose iOS 6.1.3
  code sits in another library is reported missing. A framework is provided by a component or the runtime only when the
  library is given with `--component` or `--runtime`.
- A component that is not built or installed on the machine is not measured, and its items are reported missing.
- Text matches to names the scanned sources do not declare. A name that is declared outside the scanned trees (a
  generated file, a folder not given with `--source` or `--files`) is counted as the SDK's name.

## Cost

The SDK facts are extracted once per SDK and cached under `build/generated/backports`. The source scan is linear in the
bytes read, at roughly a megabyte a second. The classification reads the iOS 6.1.3 cache once, in a few seconds.
