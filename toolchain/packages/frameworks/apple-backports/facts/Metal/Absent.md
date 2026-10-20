# What the absent rows say, and which of those reasons is a reason

Every `absent` row in this package's Metal and MetalKit registries, grouped by the reason it gives.
Counted from the rows themselves, not from a summary: the command is below, and it names the six
buckets by the words the rows use.

```
python3 - <<'PY'
import json, os, collections
root = "packages/a/apple-backports/registry"
counts = collections.Counter()
for framework in ("Metal", "MetalKit"):
    for name in sorted(os.listdir(os.path.join(root, framework))):
        document = json.load(open(os.path.join(root, framework, name)))
        for entry in document["entries"]:
            if entry["status"] != "absent":
                continue
            reason = (entry.get("reason", "") + " " + entry.get("effect", "")).lower()
            if "no ray tracing" in reason:
                bucket = "hardware: no ray tracing"
            elif "counter heap" in reason:
                bucket = "hardware: no counter heaps"
            elif "arrived in ios" in reason or "arrived with the sdk" in reason:
                bucket = "iOS arrival"
            elif "no sdk header declares" in reason:
                bucket = "port-own name"
            elif "cannot find protocol declaration" in reason:
                bucket = "build error: MTLAllocation"
            elif "not corpus-demanded" in reason:
                bucket = "corpus non-demand"
            else:
                bucket = "other"
            counts[(framework, bucket)] += 1
for key in sorted(counts):
    print(key, counts[key])
PY
```

| reason the row gives | Metal | MetalKit | total |
| --- | ---: | ---: | ---: |
| iOS arrival | 106 | 0 | 106 |
| corpus non-demand | 20 | 18 | 38 |
| port-own name | 19 | 0 | 19 |
| build error: MTLAllocation | 15 | 0 | 15 |
| hardware: no ray tracing | 6 | 0 | 6 |
| hardware: no counter heaps | 2 | 0 | 2 |
| **total** | **168** | **18** | **186** |

## Which of these is an answer, and which is a backlog

**Two of the six are hardware, and they are the only two that answer.** Six rows are ray tracing -
"an acceleration structure is a ray tracing resource, and this device has no ray tracing" - and two
are counter heaps, whose "entry size is a property of the counter hardware". Those eight keep their
absent status, and the answer stays the documented one rather than a missing method.

**The other 178 were not reasons, and this file is the record of that.** A correction, because the
earlier version of this table was wrong in the direction that mattered: it read the 186 rows as
"absent for a hardware reason", and they are not. iOS arrival is not hardware - an API that did not
exist yet is a thing to carry, not a thing to omit, and the port's job is to carry it. Corpus
non-demand is not hardware either; a Tier 2 verdict that nobody asked for is a measure of interest,
not of capability. A port-own name is not hardware at all - it is a class of the port's own under a
name no header declares, and the row is about that name, not about the device. And the fifteen
`MTLAllocation` rows are a build error in the port's own header, quoted at line and column, which is
a thing to fix rather than a thing to be absent about.

So the honest reading of the table is: **eight rows answer as Apple documents, and 178 are work.**
That is the backlog this file exists to name, and it is larger than the work the registry claimed to
have already answered.

## What was done about it

**MetalKit is carried, all 18.** `MTKTextureLoader`'s eleven option and origin constants, the three
classes `MTKMesh` needs - `MTKMeshBuffer`, `MTKMeshBufferAllocator`, `MTKSubmesh` - and the four
single-value model-bridge functions. What each does, and what it deliberately does not claim, is in
`TextureLoader.md` next door; the two places the port says no - a cube layout offered with one image,
and the mipmap levels its descriptor does not build - answer with an `NSError` or with a stated
limit rather than with a silent success.

### update 2026-09-29: the fifteen protocol rows, re-derived from what the port carries

The rows this file counted as "a build error: MTLAllocation, 15" were **stale**, and the correction
is the point of this entry. Each of the fifteen carried the reason:

> `RevenantMetalProtocols.h:51:35: error: cannot find protocol declaration for 'MTLAllocation'`

Two things about that are no longer true. **`RevenantMetalProtocols.h` does not name `MTLAllocation`
at all** — `grep -c MTLAllocation` on the file is 0 — and **line 51 is a bare forward declaration**,
not that diagnostic. The header compiles with the library's own flags and no `-I`, run from
`packages/a/apple-backports`, and the quoted `file:line:column` no longer resolves to anything.

So the fifteen were re-derived from what the port actually carries, and the evidence is a compiled
one. **`-Wprotocol` was silenced in every Metal class's own source** by a `#pragma clang diagnostic
ignored` at the top of the file, and a *suppressed* warning cannot be promoted to an error — so
`-Werror=protocol` had never been able to fire on any of them. Removing the two lines and compiling
with `-Werror=protocol -Werror=incomplete-implementation` names the missing required members, exactly:

```
Metal/RevenantMetalBuffer.m:4:17: error: method 'newTextureWithDescriptor:offset:bytesPerRow:' in protocol 'MTLBuffer' not implemented
Metal/RevenantMetalBuffer.m:4:17: error: method 'addDebugMarker:range:' in protocol 'MTLBuffer' not implemented
Metal/RevenantMetalBuffer.m:4:17: error: method 'removeAllDebugMarkers' in protocol 'MTLBuffer' not implemented
```

| protocol | the port's class | missing required members, measured |
| --- | --- | --- |
| MTLDevice | `RevenantMetalDevice` | debug markers, the offset texture constructor |
| MTLResource | `RevenantMetalBuffer`, `RevenantMetalTexture` **by inheritance** | the debug markers `MTLResource` declares |
| MTLBuffer | `RevenantMetalBuffer` | the offset texture constructor (the debug markers and `gpuAddress` are defined; `facts/Metal/Buffers.md`) |
| MTLTexture | `RevenantMetalTexture` | debug markers |
| MTLSamplerState | `RevenantMetalSampler` (RevenantMetal.h:186) | none |
| MTLFunction | `RevenantMetalFunction` | none |
| MTLLibrary | `RevenantMetalLibrary` | function constants, `-newFunctionWithConstantValues:` |
| MTLRenderPipelineState | `RevenantMetalPipeline` | the binary, the stage-input accessors |
| MTLCommandQueue | `RevenantMetalQueue` | `-insertDebugBoundary:`, the handler members |
| MTLCommandBuffer | `RevenantMetalCommandBuffer` | none |
| MTLCommandEncoder | `RevenantMetalEncoder`, `RevenantMetalComputeEncoder` **by inheritance** | none |
| MTLRenderCommandEncoder | `RevenantMetalEncoder` | `-setViewport`, debug marking |
| MTLDrawable | `RevenantMetalDrawable` **by inheritance** through `CAMetalDrawable` | none — the stripped compile is CLEAN |
| MTLDepthStencilState | `RevenantMetalDepthStencil` | none — the stripped compile is CLEAN |
| MTLCaptureScope | `RevenantMTLCaptureScope` | none |

**Three of them needed no class at all**, because 16.4's own headers make the conformance by
inheritance: `MTLBuffer.h:32` declares `@protocol MTLBuffer <MTLResource>` and `MTLTexture.h:264` the
same, `MTLRenderCommandEncoder.h:131` and `MTLComputeCommandEncoder.h:41` both declare
`<MTLCommandEncoder>`, and `CAMetalDrawable` is `<MTLDrawable>`. A class conforming to a protocol
conforms to everything it inherits.

**The pragmas are half removed, and the half that stays is measured.** Ten classes are fully
conformant and their pragmas are gone; thirteen are not, and their stripped compile says so in as many
words, so their pragmas stay — a build failure that says nothing is worse than a warning that names the
gap. **The remaining partial conformances are work owed, and this file now names every one of them.**

**The file floors do not move.** Every row in `ios8render.json` and `ios11capturemanager.json` is
`minimum: 6.0`, which is where the port's Metal starts, so flipping a protocol row to `implemented`
adds it to `bands[introduced]` (backports.lua:664) without raising any file's floor. `MTLCaptureScope`
is `introduced: 11.0`, so it lands in that band; every other one is `introduced: 8.0`.

### update 2026-09-29: r2 — ten of the fifteen are inert, not implemented, and the citations are corrected

A review of `metal-alloc` found the fifteen flipped to unqualified `implemented` while their classes
demonstrably miss required members, and it is right: `backports.lua:664` turns a protocol row with
`status == "implemented"` into a **band floor** through `bands[introduced]`, so claiming a conformance
that is not callable claims a floor this port cannot support. A missing required protocol method is a
callable gap — owed, not carried.

**The rule now applied: `implemented` only where the stripped compile is clean.** Ten rows are
`inert` — the class is carried and the members it does implement are callable, but these are not, and
each row names them:

| row | the port's class | the exact selectors owed |
| --- | --- | --- |
| MTLDevice | `RevenantMetalDevice` | `heapBufferSizeAndAlignWithLength:options:`, `heapTextureSizeAndAlignWithDescriptor:`, `minimumLinearTextureAlignmentForPixelFormat:`, `minimumTextureBufferAlignmentForPixelFormat:`, `newBufferWithBytesNoCopy:length:options:deallocator:`, `newComputePipelineStateWithDescriptor:options:completionHandler:` and 13 more |
| MTLResource | `RevenantMetalBuffer`, `RevenantMetalTexture` | `isAliasable`, `makeAliasable`, and the debug markers `MTLResource` declares |
| MTLBuffer | `RevenantMetalBuffer` | `newTextureWithDescriptor:offset:bytesPerRow:` (the debug markers and `gpuAddress` are defined; `facts/Metal/Buffers.md`) |
| MTLTexture | `RevenantMetalTexture` | `getBytes:bytesPerRow:bytesPerImage:fromRegion:mipmapLevel:slice:`, `newTextureViewWithPixelFormat:`, `newTextureViewWithPixelFormat:textureType:levels:slices:`, `newSharedTextureHandle`, the `MTLResource` pair |
| MTLFunction | `RevenantMetalLibrary` | `newArgumentEncoderWithBufferIndex:`, `newArgumentEncoderWithBufferIndex:reflection:` |
| MTLLibrary | `RevenantMetalLibrary` | `newFunctionWithDescriptor:error:` and the intersection-function and completion-handler forms |
| MTLRenderPipelineState | `RevenantMetalPipeline` | `imageblockMemoryLengthForDimensions:`, `functionHandleWithFunction:stage:`, `newIntersectionFunctionTableWithDescriptor:stage:`, `newVisibleFunctionTableWithDescriptor:stage:` |
| MTLCommandQueue | `RevenantMetalQueue` | `commandBufferWithDescriptor:` |
| MTLCommandBuffer | `RevenantMetalCommandBuffer` | `blitCommandEncoderWithDescriptor:`, `computeCommandEncoderWithDescriptor:`, `computeCommandEncoderWithDispatchType:`, `accelerationStructureCommandEncoder`, `encodeSignalEvent:value:`, `encodeWaitForEvent:value:` and more |
| MTLCommandEncoder, MTLRenderCommandEncoder | `RevenantMetalEncoder`, `RevenantMetalComputeEncoder` | `setVertexBufferOffset:atIndex:`, `setFragmentBufferOffset:atIndex:`, `setScissorRects:count:`, `setDepthClipMode:`, and on the compute side `setBufferOffset:atIndex:` and more |

**Four stay `implemented`, because the stripped compile is clean for their classes:**
`MTLSamplerState` (`RevenantMetalSampler`), `MTLDepthStencilState` (`RevenantMetalDepthStencil`),
`MTLDrawable` (`RevenantMetalDrawable`) and `MTLCaptureScope` (`RevenantMTLCaptureScope`).

**The floors, computed from the registry as it now stands.** `protocol_sources` (backports.lua:656)
reads every `implemented` protocol row and raises `floors_of[introduced]` to the row's `minimum`:

| file | implemented protocol rows | their `introduced` | floor raised |
| --- | --- | --- | --- |
| `ios8render.json` | `MTLSamplerState`, `MTLDrawable`, `MTLDepthStencilState` | 8.0 | **6.0** |
| `ios11capturemanager.json` | `MTLCaptureScope` | 11.0 | **6.0** |

Every row in both files is `minimum: 6.0`, and 6.0 is where the port's Metal starts, so **no floor
moves**: the ten `inert` rows contribute none, and the four that do would not raise a floor even if
they were higher.

**Three citations corrected, each verified by `grep -n` against the 16.4 SDK rather than recalled.**
`MTLResource` is forward-declared at **`MTLBuffer.h:17`**, and it is the base of `MTLBuffer` at
**`MTLBuffer.h:32`**. `MTLDrawable` is declared at **`MTLDrawable.h:26`** and forward-declared at
**`MTLCommandBuffer.h:20`**; `RevenantMetalDrawable` conforms to `CAMetalDrawable`, whose inheritance
from `MTLDrawable` is in **`QuartzCore/…/CAMetalLayer.h:28`** — QuartzCore, not a Metal header, which
is what the earlier entry implied by citing the Metal headers for it. `MTLCommandEncoder` is the base
of **`MTLRenderCommandEncoder.h:131`** and **`MTLComputeCommandEncoder.h:41`**.

**And the count was wrong: TWELVE classes keep the pragma, not thirteen.** Ten had it removed, and
twelve keep theirs — `RevenantMetalBuffer`, `RevenantMetalDevice`, `RevenantMetalEncoder`,
`RevenantMetalLibrary`, `RevenantMetalPipeline`, `RevenantMetalQueue`, `RevenantMetalTexture`,
`MTLBlitCommandEncoder8`, `MTLComputeCommandEncoder8`, `MTLComputePipeline8`, `MTLHeap10` and
`MTLSharedEvent12`. A reviewer's independent run measured the same twelve refusing with
`-Wprotocol` naming a member in each, and the control — the same tree with the pragmas in place —
compiles clean.

### update 2026-09-29: r3 — the acceptance test is BOTH diagnostics, and two rows are now honest

A review measured the stripped compile **with `-Wobjc-protocol-property-synthesis` as well as
`-Wprotocol`** and found two rows I had left `implemented` that are not: a protocol property nobody
implements is auto-synthesized to nothing and **raises unrecognized-selector when read**, so it is a
callable gap exactly as a missing method is. My r1 run checked `-Wprotocol` only, and the claim that
four rows were conformant was false for two of them.

**The two are now honest, by implementing rather than by demoting:**

- **`MTLFunction`** — the two argument encoders answer `nil`, because an argument encoder is a Metal 3
  *argument buffer* and this port dispatches a device pointer plus the three thread identifiers;
  `functionConstantsDictionary` is `@{}` because the plist carries no constants; `options` is
  `MTLFunctionOptionNone`, the enumeration's own zero and "Default usage" per
  `MTLFunctionDescriptor.h:17`; `patchType` is `MTLPatchTypeNone`, which `MTLLibrary.h:127` names for
  "not a post tessellation function"; `patchControlPointCount` is `-1`, the header's own value for a
  shader that specified none; and `vertexAttributes` and `stageInputAttributes` are the kernel's
  **real** argument list from the plist, each attribute built by the reader's own `MTLVertexAttribute`
  through one helper so the two cannot drift apart.
- **`MTLSamplerState`** — `gpuResourceID` answers a typed zero, because it is a "Handle of the GPU
  resource suitable for storing in an Argument Buffer" (`MTLTexture.h:424`) and this device is the
  port's own over OpenGL ES 2.0 with no GPU resource handle to hand out.

**The remaining six selectors on `MTLLibrary`** — `newFunctionWithDescriptor:error:`, its
completion-handler form, and the two intersection-function pairs -- were iOS 14.0 function-descriptor
forms the port did not carry. *Superseded: see the update at the end of this file.*

**And the citation corrected once more:** `MTLTexture.h` does not declare `<MTLResource>` at all — it
imports `MTLResource.h` at `MTLTexture.h:10` and `MTLTexture.h:32` reads `MTLTextureType3D = 7,`. The
base declaration is `MTLResource` in **`MTLResource.h`**, reached from `MTLTexture.h:10`'s import.

### update 2026-09-29: r4 — the criterion is an AST comparison, and every list is the tool's

Two reviews in a row caught the same class of mistake and the second one is the fix. The acceptance
test was built on two warnings, and **each is wrong in a different way**:

  - `-Wprotocol` does not inspect property ACCESSORS. It is about methods, so a property whose getter
    is on the wrong class produces nothing at all.
  - `-Wobjc-protocol-property-synthesis` cannot tell a HAND-WRITTEN getter from a missing one. It is
    emitted for any protocol property the `@implementation` does not `@synthesize`, so a tree with all
    six of `MTLFunction`'s getters written reports the same six warnings as one with none.

Both were clean while **two rows were not conformant at all**, and `backports.lua:664` turns an
`implemented` protocol row into a band floor. The six `MTLFunction` property getters were on
`RevenantMetalLibrary`, which declares `<MTLLibrary>`, instead of `RevenantMetalFunction`; and
`MTLSamplerState`'s `gpuResourceID` was on `RevenantMetalTexture` instead of `RevenantMetalSampler`.

**The criterion is now: an `implemented` row <=> for every protocol member — required and optional
instance and class methods, and every property's getter and, when readwrite, its setter — the class's
`@implementation`, its category implementations or its `@synthesize` bindings DEFINE that selector.**
`tests/backports/host/protocol-members.py` reads the SDK's members through the file's own import and
the class's definitions from the same translation unit, off `-Xclang -ast-dump=json`. No pragma is
stripped, because nothing there is a warning: a suppressed warning hides a message, and a declaration
is not a message. `-Wprotocol` is kept as a cross-check for methods, which the AST comparison would
otherwise accept if inherited.

**The fifteen rows, as the tool now measures them** — every list below is the tool's, not prose:

| row | class | missing | state |
| --- | --- | ---: | --- |
| MTLCaptureScope | `RevenantMTLCaptureScope` | 0 | **implemented** |
| MTLSamplerState | `RevenantMetalSampler` | 0 | **implemented** |
| MTLFunction | `RevenantMetalFunction` | 0 | **implemented** |
| MTLDrawable | `RevenantMetalDrawable` | 0 | **implemented** |
| MTLDepthStencilState | `RevenantMetalDepthStencil` | 0 | **implemented** |
| MTLCommandQueue | `RevenantMetalQueue` | 2 | inert |
| MTLResource | `RevenantMetalBuffer` | 4 | inert |
| MTLBuffer | `RevenantMetalBuffer` | 4 | inert |
| MTLLibrary | `RevenantMetalLibrary` | 6 | inert |
| MTLCommandEncoder | `RevenantMetalComputeEncoder` | 3 | inert |
| MTLRenderPipelineState | `RevenantMetalPipeline` | 15 | inert |
| MTLCommandBuffer | `RevenantMetalCommandBuffer` | 19 | inert |
| MTLTexture | `RevenantMetalTexture` | 25 | inert |
| MTLDevice | `RevenantMetalDevice` | 84 | inert |
| MTLRenderCommandEncoder | `RevenantMetalEncoder` | 104 | inert |

**Three of the ten need no class of their own and are still measured.** `MTLResource` is answered
through `RevenantMetalBuffer` (`MTLBuffer.h:32` makes `MTLBuffer` a `MTLResource`),
`MTLCommandEncoder` through `RevenantMetalComputeEncoder` (`MTLComputeCommandEncoder.h:41`), and
`MTLDrawable` through `RevenantMetalDrawable`, which adopts `CAMetalDrawable` and that is `<MTLDrawable>`
in QuartzCore's `CAMetalLayer.h:28`. The tool resolves each by asking which `@interface` adopts a
protocol inheriting the row's, so these are measured on a real class rather than asserted.

### update 2026-09-29: MTLResource is implemented — all four members were cheap

The criterion reported `RevenantMetalBuffer` missing four `MTLResource` members — `allocatedSize`,
`hazardTrackingMode`, `isAliasable`, `makeAliasable` — and **all four were cheap**, needing no
measurement, because each is a property of a CPU-resident buffer whose size the port already answers.

| member | answer | where it comes from |
| --- | --- | --- |
| `allocatedSize` | the window's own `length` | a buffer here is a window onto ONE `MTLBuffer`'s bytes, and that is the smallest allocation it can live in; a larger number is one nobody here can know |
| `hazardTrackingMode` | `MTLHazardTrackingModeUntracked` | the header's own case at `MTLResource.h:98` — the workgroup's threads are joined by a mutex and a condition variable before the dispatch is encoded (`facts/Metal/Compute.md`), so the hazard is resolved by the join, not by a tracked range |
| `isAliasable` | `NO` | two textures over one range of the memory this device has would be two names for bytes the shader then writes twice |
| `makeAliasable` | does nothing | and `isAliasable` says `NO` because nothing did — that is the pair the header gives |

**The header's own wording corrected the signatures twice**, and the criterion caught each: `makeAliasable`
is `-(void) makeAliasable` with **no argument** (`MTLResource.h:78`), not a `BOOL` taking a resource —
whether the call succeeded is what `isAliasable` answers. Reading the header before writing the
method would have saved a round trip.

`MTLResource` is therefore `implemented`, and the criterion reports every member of the protocol
defined for `RevenantMetalBuffer`.

### update: v-impl-metal-device -- the queue, the command buffer, the encoders, the buffer and the library

The device chain in the brief's order has moved these rows since the tables above were written. Each names
its facts, and the tables above are kept as the record of the state they describe.

- **MTLCommandQueue** (protocol, and the two selectors): implemented. `facts/Metal/CommandBuffer.md`.
- **MTLCommandBuffer** (protocol): 16 of its 19 members are defined; the three left are `encodeSignalEvent:value:`,
  `encodeWaitForEvent:value:` (need deferred command recording) and `parallelRenderCommandEncoderWithDescriptor:`
  (needs the parallel render encoder and pass-level load actions). `facts/Metal/CommandBuffer.md`.
- **MTLCommandEncoder** (protocol): implemented, the three debug members of the blit, compute and render encoders.
  `facts/Metal/EncoderDebugGroups.md`.
- **MTLBuffer** (protocol): one member left, `newTextureWithDescriptor:offset:bytesPerRow:`, which needs the texture
  storage of the MTLTexture tranche. `facts/Metal/Buffers.md`.
- **MTLLibrary** (protocol): implemented, `installName` included: the translator carries the metallib's install name
  into `library.json` and the port returns it. The two intersection-function pairs are answered nil by the device
  (no ray tracing), and the descriptor pair is implemented. `facts/Metal/LibraryDescriptors.md`.
- The rows for the buffer and the library members are in `registry/Metal/ios10buffer.json`, `ios16buffer.json`,
  `ios8buffer.json` and `ios14library.json`.
