# Function stitching: the graph objects the port carries

Stitching is how several Metal functions are compiled into one. The objects that DESCRIBE a stitch — a
graph, its nodes, an attribute, the descriptor that carries the graphs — are plain data, and this port
carries all of them. They are in `Metal/MTLFunctionStitching15.m`, one object, which `release-split`
measures at **16.0 and no other release**.

## What the header says, as facts

Every type is `API_AVAILABLE(macos(12.0), ios(15.0))` in `MTLFunctionStitching.h`. The **cache
ladder puts this object in the 16.0 band**, and it says so in its own words:

```
release-split: clean, every object file's symbols first-appear in one release (1 files, 12 symbols, 50 releases checked)
```

with a note that **no release is held between 12.0 and 16.0**, so 16.0 here means **"after 12.0, by
16.0, not a measured first release"** — a band, not a measurement. So the rows carry that wording, and nothing here claims the symbols were first exported at
16.0. The object's name carries 15 because the family is the 15.0 API, and the rows say 16.0 because
that is the band the ladder chose.

The shapes, from the header's own declarations:

| type | members |
| --- | --- |
| `MTLFunctionStitchingAttribute` | protocol, no members of its own |
| `MTLFunctionStitchingNode` | protocol, `<NSObject, NSCopying>` |
| `MTLFunctionStitchingAttributeAlwaysInline` | class, no members of its own |
| `MTLFunctionStitchingInputNode` | `argumentIndex` (readwrite), `-initWithArgumentIndex:` |
| `MTLFunctionStitchingFunctionNode` | `name`, `arguments`, `controlDependencies` (all readwrite), `-initWithName:arguments:controlDependencies:` |
| `MTLFunctionStitchingGraph` | `functionName`, `nodes`, `outputNode` (**nullable**), `attributes`, `-initWithFunctionName:nodes:outputNode:attributes:` |
| `MTLStitchedLibraryDescriptor` | `functionGraphs`, `functions` |
| `MTLRenderPipelineFunctionsDescriptor` | `vertexAdditionalBinaryFunctions`, `fragmentAdditionalBinaryFunctions`, `tileAdditionalBinaryFunctions` - three nullable lists |

## Why these are carried and not absent

**A descriptor is a data object and works on every device, including one with no such hardware.** An
input node is an argument index; a function node is a name and two lists; a graph is a name, a node
list, an optional output node and an attribute list. None of them asks the device anything, so none of
them is absent, and that is the same distinction the owner drew for the hardware rows.

**What the port cannot do is STITCH, and that is a different thing.** `air2cpu` translates each kernel
to its own object and `CharonMetalLibrary` holds a dictionary of them, so a graph handed to this port
describes a function it will never produce. That is a limit on the port's **output**, not on these
**objects**, and the rows say so in those words.

`MTLLinkedFunctions` is **not** in this object: it is 14.0, and an object carrying 14.0 and 16.0 would
be placed in neither band. `release-split` decides that, and it is why this slice is 8 rows and not the
11 the group table counted.

## The round trip, and the three mutants

`tests/backports/host/metal-census/stitch.sh` builds the test **together with** the port's source in one
clang line — `arm64-apple-ios15.0-macabi`, the EAGL stub `metalblit/run.sh` already uses, the pattern
`tests/backports/host/security/run-cases.sh` uses. It must be one line: two objects cannot be linked
when one is built for the device and one for the host, and `ld` ignores the mismatched one with
"building for macOS but attempting to link with file built for iOS", which surfaces as an undefined
`_main` and looks like a missing test rather than a mismatched object.

It builds a graph from two input nodes and a function node with its arguments and control
dependencies, sets an output node and an attribute list, and reads **every** value back through the
header's own accessors. It checks that a copy of the graph, of an input node, of a function node, of the
`MTLStitchedLibraryDescriptor` and of the `MTLRenderPipelineFunctionsDescriptor` is a **new** object
with equal values, and that the header's **nullable** `outputNode` stays `nil` when it is not set.

**The port's classes are proved DEFINED in the binary, not resolved to a dylib.** `Metal.framework` has
the same API on the host, so a test could pass by calling Apple's implementation and every assertion
would then be a statement about it. `otool -L` on the built binary shows **no MetalKit linked at
all** — that is a link-time fact, not a reading of the run's wording. The check counts the six `_OBJC_CLASS_$_MTL*` symbols the port itself defines
and fails on a count of zero or a count that differs from six. `SELF_TEST=1` exercises that function
against a symbol list with one class missing, and requires both halves: the missing class is named, and
the full list passes.

Three mutants, each red, and each named by the assertion that caught it:

| mutation | caught by |
| --- | --- |
| a graph that forgets its nodes | `FAIL a graph reads its node list back` |
| a copy that returns `self` instead of a copy | `FAIL a graph's copy is a different object with the same values` |
| a binary-functions descriptor that forgets the vertex list | `FAIL two of the three lists round-trip and the one left unset stays nil` |

```
stitch: the round trip is green and all three mutants are red
```

## Owed, and not part of this delivery

**The pre-export tooling is parked** on branch `band-api-metal/owed` at `bb688396a`, with the reviewers'
open findings B1..B5 of the `metal-owed-r7` round, and it is **not** part of `metal-stitch`.

What is parked: `tests/backports/host/metal-census/pre-export.sh`, `check-split-control.sh` and
`failure-matrix.sh`. They guard the release-split and the link, and two holes in them are open and are
recorded here rather than fixed in this delivery. A stub in the matrix cannot find `work-guard.sh`, so
six of its rows pass on a missing file, and the FAIL-noise filters can be defeated. Separately,
`pre-export.sh:207` lost its `fail`, so a non-compiling source on the `SYMBOL_DIR` path exits 0 with an
OK line. The branch is `band-api-metal/owed` at `bb688396a` and the reviewer's findings are the
`metal-owed-r7` round.

This delivery carries the stitching objects, their rows, this file, and the host test that proves the
port's own classes are defined rather than Apple's — which is the part that cannot be re-derived from
the gate alone.
