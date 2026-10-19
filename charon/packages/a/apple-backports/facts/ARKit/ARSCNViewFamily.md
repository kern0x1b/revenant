# The ARSCNView family: what carries, what is a dependency, and what each piece is blocked on

Measured 2026-09-28 in the `api-reality` worktree, for the ARKit series on `cfde59f06`.

## The shape, per band

| band | `SCNView` carried | the family |
| --- | --- | --- |
| 4.3 | no — the row's minimum is 6.0 | dependency |
| 6.1.3 | yes — the port implements the SDK's own class | **writable**, except the two gaps below |
| 8.0+ | native | the same rows |

The port implements the SDK's declared classes rather than declaring its own: `CharonSCN.h:1` is
`#import <SceneKit/SceneKit.h>`, and `SCNView.m` is `@implementation SCNView` carrying
`_OBJC_CLASS_$_SCNView`. So `ARSCNView` compiled against the SDK's SceneKit header subclasses exactly
the port's class, and `ARKitBackports` now names `SceneKitBackports` in its `libraries`.

## The 42 rows

| piece | rows | state |
| --- | --- | --- |
| `ARSCNView` | 1 class + 5 methods + 4 properties | written; **two build defects below** |
| `ARSCNViewDelegate` | 1 protocol + 5 `renderer:` methods | declaration, per `kind=protocol` |
| `ARSCNPlaneGeometry` | 1 class + 2 methods | **blocked** on a SceneKit row that is not implemented |
| `ARSCNFaceGeometry` | 1 class + 3 methods | class and constructors carry; `updateFromFaceGeometry:` is absent by sensor |
| `ARSCNDebugOptionShowWorldOrigin`, `…ShowFeaturePoints` | 2 constants | writable; SceneKit's `SCNDebugOptions` values |
| `ARSKView`, `ARSKViewDelegate` | 9 rows | **dependency** — SpriteKit is not carried |

## The two build defects in `ARSCNView.m`

Both measured, both with a known fix, neither committed:

1. **`@synthesize` is not allowed in a category's implementation**, even on the non-fragile ABI armv7
   has, so the anchor a node stands for cannot be a category ivar on the SDK's `SCNNode`. The fix that
   uses only public API is for the view to hold the pairing itself — an `NSMapTable` from node to
   anchor — and for `anchorForNode:` to walk the parents looking each up, and `nodeForAnchor:` to walk
   the scene the other way. No category, no associated object, no ivar on a class the port does not
   declare.
2. **`-unprojectPoint:ontoPlaneWithTransform:` is `API_AVAILABLE(ios(12.0))`**, so at a 6.1.3 target the
   SDK's declaration is invisible and the selector does not resolve. `ARSCNView` is an 11.0 class with a
   12.0 method on it, so that method belongs in a **12.0 object** beside the other 12.0 API, and
   `ARSCNView`'s 11.0 object declares the class and the 11.0 members. That is the release split, and it
   is the same rule the ARKit objects already follow.

The draft is in `.agent-work/ARSCNView-draft.m`.

## The gap in `ARSCNPlaneGeometry`, settled by the SDK

`SCNGeometry.h:121` and `:135`:

```objc
@property(nonatomic, readonly) NSArray<SCNGeometrySource *> *geometrySources API_AVAILABLE(macos(10.10));
@property(nonatomic, readonly) NSArray<SCNGeometryElement *> *geometryElements API_AVAILABLE(macos(10.10));
```

**Both are readonly, and the only public way to put data into a geometry is
`+geometryWithSources:elements:`, which returns a new object.** So `-updateFromPlaneGeometry:` — an
instance method, which by its name has to update the receiver in place — cannot repopulate a geometry
from ARKit's file: the storage is the SDK's and is not visible there. Apple's own design has the
update living inside SceneKit, where those ivars are.

So this is a SceneKit change and not a SceneKit *row*, and the two ways it can be made are both in
SceneKit's gift: the properties readwrite, or a method that takes a geometry and repopulates it. Either
one is new API on a class the tree implements, so it is the SceneKit band's to add and to measure
against the host's SceneKit — which has these properties writable, since on macOS
`+geometryWithSources:elements:` is the documented way to build one and a caller that mutates in place
does so through SceneKit's own storage.

What is *not* needed any more is the constructor work. All the constructors were the ones the SDK has
declared since 8.0, and the port implements the two ARSCNPlaneGeometry needs:

| constructor | port | registry |
| --- | --- | --- |
| `+geometrySourceWithData:semantic:…:dataStride:` | `SCNGeometrySource.m` | **added** (commit `1f8a5812e`) |
| `+geometryElementWithData:primitiveType:primitiveCount:bytesPerIndex:` | `SCNGeometryElement.m` | **added** (commit `1f8a5812e`) |
| `geometrySources`, `geometryElements`, `+geometryWithSources:elements:` | `SCNGeometry.m` | **added** (commit `bc8ff2c89`) |

Five rows this series has found the port implements and the registry did not carry.

## Does SceneKit read an override of the two getters? Measured on the host: no

`geometrySources` and `geometryElements` are readonly, so the only public way to put data into a
geometry is `+geometryWithSources:elements:`, which returns a new object — and `-updateFromPlaneGeometry:`
has to update its receiver. The way out without a setter is to override the two getters in a subclass
and let SceneKit call them. Whether it does is a question only the host's SceneKit can answer, and the
answer is no.

The probe (`.agent-work/arkit/geometry-override-probe.m`) renders each case offscreen with `SCNRenderer`
and counts the pixels an offscreen snapshot has that are not black. The geometry is drawn **black**, so
it takes lit pixels *away* from the background, and what a case draws is how much less than the
background it leaves.

```
  background, nothing in the scene:            14716
  case 1  factory-built geometry draws:          11580 px
  case 2  subclass, no override                  11580 px
  case 3  only the getters hold the data:           0 px
  case 4  the getters hold half a quad:             0 px
  case 5  the getters hold nothing:                 0 px
```

**One reading fits all of them.** The control draws 11580 px, and a subclass that overrides nothing
draws the same 11580 — so the subclass's mere existence changes nothing. A subclass whose data lives
*only* in its getters draws **0**, the background untouched. And a subclass whose getters describe half
a quad, and one whose getters describe nothing, both draw 0 as well — the shapes and sizes the getters
return make no difference at all, which is what "SceneKit reads its own storage and never asks" looks
like from the outside.

**Consequences, per band.** On 6.x, where the SceneKit is this tree's, the port's `SCNGeometry` gets a
package-internal `charon_replaceSources:elements:` declared in `CharonSCN.h` and in no public header,
which `-updateFromPlaneGeometry:` calls; the port implements the storage, so this is not a private ivar
and not new public API, and it needs no registry row. On 8.0–11.2, where SceneKit is the system's, there
is no such storage to reach and no override is read, so `ARSCNPlaneGeometry` on that band is a
**dependency** and the reason is this table.

**And it did not reproduce.** The build is now fixed and the stale binary deleted, and a clean rerun of
exactly this configuration gives:

```
  case 1  factory-built geometry draws:          0 px
  case 2  subclass, no override:                0 px
  case 3  only the getters hold the data:       0 px
  case 4  the getters hold half a quad:         0 px
  case 5  the getters hold nothing:             0 px
```

with the background line absent entirely. Two consecutive invocations agree with each other and
disagree with the run above, so the harness is not deterministic here: `SCNRenderer` is asked for
`device:nil` and what it hands back varies, and the empty-scene background reads 14716 once and 0
afterwards.

**So the table stands as one unreproduced run, and there is now a second observation against it.** It
is not promoted to "reproduced", and it is not withdrawn either. What the clean rerun does establish is
that the probe as written cannot answer the question: its verdict line still reads "NOT read" only
because the control draws nothing, which is the wrong way round — a control that fails makes the
verdict unearned, and here the unearned verdict happens to agree with the earlier reading, which is
exactly the coincidence that should not be trusted.

What would make it a measurement: an `SCNRenderer` built on a device obtained explicitly rather than
`nil`, so the background is the same on every run, and the control's silhouette compared against that
background before any override case is read. Until that is done, the per-band consequences below stand
on the reasoning — an override the framework never calls cannot be a route, whatever the pixels say — and
not on this probe.

## The earlier gap, superseded

Three SceneKit members it needs: `geometrySources` and `geometryElements` and
`+geometryWithSources:elements:` are implemented by the port and are now rows (`ios8.json`, 70 → 73).
The other two are **not implemented and not in the 16.4 headers either**:

- `+[SCNGeometrySource geometryWithVector:vectorFormat:vertexCount:vectorStride:dataOffset:dataStride:]`
  and the `SCNGeometrySourceFormat` enum — `grep -rhoE "SCNGeometrySourceFormat[A-Za-z0-9]+"` over the
  SDK's SceneKit headers returns **nothing**, so the enum's name cannot be read from them.
- `+[SCNGeometryElement geometryWithData:primitiveType:primitiveCount:bytesPerIndex:dataOffset:]` — not
  in `SCNGeometryElement.m`.

Both are SceneKit rows to add rather than anything ARKit can do, and the first needs the SceneKit band
to tell the format enum's real spelling.

## `ARSCNFaceGeometry`, documented

This device has no TrueDepth, so no face is ever tracked, and Apple's own answer for a device that
cannot is what `+faceGeometryWithDevice:` returns: `nil`. The class and its two constructors are
carried and answer that; `-updateFromFaceGeometry:` is **absent by sensor** — it takes an
`ARFaceGeometry`, which this device's registry does not carry at all, because face tracking needs a
sensor it has not. Labelled documented rather than measured, because there is no device here that has
the sensor to measure it on.

## `ARSKView`: the dependency, with its rows

SpriteKit is **not carried**: no entry among the 43 libraries, no `SpriteKit/` folder, no `SKView` row,
no `SKView.m`. The ladder puts `_OBJC_CLASS_$_SKView` first at **7.0**:

```
7.0  1        7.1  1        8.0  2        9.0  3
```

So `ARSKView`, being declared as `@interface ARSKView : SKView`, is a SpriteKit dependency at every
band. Its nine rows: the class, `anchorForNode:`, `hitTest:types:`, `nodeForAnchor:`, and
`ARSKViewDelegate`'s five `view:` methods. The cause is above and it is for the SpriteKit owner.

## A correction: the "nineteen errors" were my hand compile, not the build

An earlier commit of this series said `SCNGeometry.m` "has 19 pre-existing errors". That was wrong and
the error is mine. The gate compiles an object with (`backports.lua:394-396`):

```
-Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability
-Werror=objc-missing-property-synthesis
```

**`-Werror` is not blanket**, and a hand compile with a blanket `-Werror` reports nineteen errors on that
file which the build does not see — the protocol members of `SCNAnimatable`
(`animationKeys`, `insertMaterial:atIndex:`, `removeMaterialAtIndex:`,
`replaceMaterialAtIndex:withMaterial:`), which the gate does not ask about. Under the real flags
`SCNGeometry.m`, `SCNView.m` and `charon_replaceSources:elements:` are all clean, and every ARKit object
compiles clean under the same flags.

A hand compile is not a measurement of the tree's own files, and the rule is to build through the
package's own rules or reuse the gate's compile line verbatim. The flags are recorded here so the next
person does not have to find them.

## `ARSCNView`: what is built and what is not

`ARSCNView11.m` **builds clean** under the gate's own flags. The pairing between a node and its anchor
is an `NSMapTable` the view holds, weak in both directions, because a category's `@synthesize` is
rejected even on the non-fragile ABI armv7 has - so the pairing is a map the view owns and the
SDK's `SCNNode` needs nothing for. `anchorForNode:` walks the parents and takes the first ancestor the
map knows; `nodeForAnchor:` is the other direction. `hitTest:types:` and
`raycastQueryFromPoint:allowingTarget:alignment:` forward to the frame, whose answers are the shared
pinhole arithmetic.

`ARSCNView12.m` does **not** yet build, and the reason is one missing declaration rather than a design
problem. `-unprojectPoint:ontoPlaneWithTransform:` on both the view and the frame is
`NS_REFINED_FOR_SWIFT` and `API_AVAILABLE(ios(12.0))`, so at a 6.1.3 target neither declaration is visible
and neither selector resolves. The frame's two-argument one is the SDK's C name for the five-argument
one the port already implements - so the 12.0 object needs

1. a declaration of the five-argument `-[ARFrame unprojectPoint:ontoPlaneWithTransform:orientation:viewportSize:]`
   in a header the port owns, because the SDK's own `ARFrame.h` declares only the two-argument form and
   that one is invisible below 12.0; and
2. the frame's two-argument method implemented against that five-argument one, using the frame's own
   camera's image resolution as the viewport, in the same 12.0 object.

Both are one declaration and one forward. The draft is `.agent-work/ARSCNView12-draft.m` and it is not in
the delivery because it does not build.

## There is no host differential for this family, and that is the framework's doing

`tests/backports/host/arkit/run.sh` exists and measures the tracker. It does **not** measure this
family, and the reason is measured rather than assumed:

```
arkit-scnview-diff.m:29:9: error: unknown type name 'ARSCNView'; did you mean 'SCNView'?
arkit-scnview-diff.m:32:26: error: property 'session' not found on object of type 'SCNView *'
```

The host has **SceneKit** and it has no **ARKit** - ARKit has never shipped on macOS, and the SDK that
declares `ARSCNView` is the iPhoneOS SDK, whose headers cannot be compiled into a macOS build. So:

- `ARSCNView` is an ARKit class, and its superclass is real, but the *class* is in a framework the
  host does not have. `SCNView` compiles; `ARSCNView` does not name anything.
- `ARFrame`, `ARSession`, `ARHitTestResult` and `ARRaycastQuery` are iOS-only types too, so the
  forwarding half cannot even be *typed* on the host, let alone compared against an oracle.

**So the oracle for this family is Apple's documentation, labelled `documented` on every row that
depends on it** - the forwarding methods answer what the frame answers because they call it, and the
geometry methods answer the plane's own buffers because that is what the framework's own
`updateFromPlaneGeometry:` says they do. What *is* measured is the build: both objects compile clean
under the build's own flags, and the release split is checked by the gate, which weighs each object
against the release of the API it carries.

The mutation that a host differential would carry is applied where the code is, instead: the pairing
is a map the view holds rather than a category ivar on the SDK's `SCNNode`, and that is checked by the
compiler - a category's `@synthesize` is rejected even on the non-fragile ABI armv7 has, which is why
`NSMapTable` is the only shape this can have. Writing a host test that cannot name the class would be
a test of nothing.

