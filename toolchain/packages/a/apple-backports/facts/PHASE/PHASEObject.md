# PHASEObject

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `PHASEObject15.m`: a 3D object in
the engine, organised into a hierarchy with relative transforms. Fourteen registry entries.

`AVAudioEnvironmentNode`'s `rootObject` and `PHASEEngine`'s both answer one of these, so it is carried
here rather than the property being `absent`: the SDK declares `@property(readonly, strong)
PHASEObject *rootObject`, and the declared type is what an application sees. The host's concrete class
is a `PHASERootObject` — a framework-internal subclass with no row in the corpus — which is an
implementation detail and not the declared surface.

## The identity is a literal, and the gate is why

`PHASEObject`'s transform is a `simd_float4x4` and both transforms start at the identity, which the
header's own note requires — *"The transform must have orthogonal basis vectors and uniform scale"* — and
which a zeroed allocation is not.

It is written out as a **literal**, not taken from the SDK's `matrix_identity_float4x4`, because the
6.1.3 gate names that as a weak import the release does not export:

```
libAVFAudioBackports.dylib weakly imports 1 symbol the armv7 release it is
checked against does not export, each of which is NULL there and must be
called only behind a check for it: _matrix_identity_float4x4
```

A weak import of a symbol the release lacks is a call through NULL, so the object depends on no symbol
to stand at one.

## The hierarchy

- `initWithEngine:` is the header's `NS_DESIGNATED_INITIALIZER`; `-init` and `+new` are
  `NS_UNAVAILABLE`, and both rows are `absent` with that reason.
- **`addChild:error:` refuses a child that already has a parent**, which is what the header says it
  does: *"Returns an error if the child already has a parent."* An object already in the hierarchy
  cannot be added here without the hierarchy becoming a graph.
- `removeChild:` and `removeChildren` clear the link from both sides, and a child's world transform is
  recomputed.
- **`worldTransform` is the object's own transform composed with every ancestor's** — one matrix
  product, and the whole of what a hierarchy of relative transforms is. A parent's move moves the
  subtree, because the subtree's world transform is derived from it.
- `right`, `up` and `forward` are the class properties the header declares, and the right-handed frame
  it names: right along +x, up along +y, forward along −z.
- `NSCopying`, which the header declares: a copy takes the transform and starts with no children of its
  own, because two objects sharing a children array would both claim the same children.

## The host differential

`tests/backports/host/phase/run.sh` compares the **declared behaviour** and not the class name: that
the port's root is a `PHASEObject`, that it has no parent and no children, and that its transform is
the identity — and that the host agrees about the two of those that are declared behaviour.

## The bug, and what the disassembly said

`rootObject` answered nil while the root was made, kept, and alive in its slot. The disassembly named it in
one instruction:

```
-[charon_host_PHASEEngine rootObject]:
  mov x0, #0x0        <- a constant nil, no load at all
```

and the source said why. A rewrite of that method had replaced the **comment above it and left the
body**, so the accessor was still

```objc
- (PHASEObject *)rootObject { return nil; }
```

Three measurements had been consistent with that and none had said it outright, because each was
answering a question about the *class* — the answering method was the port's own (`dladdr`:
`-[charon_host_PHASEEngine rootObject]`), the ivar was strong and assigned in the only initializer, and
the slot at offset 72 held a live object. `@synthesize rootObject = _charon_rootObject;` changed
nothing because **a hand-written accessor wins over a synthesised one**, and the one it won with
returned nil. The tenth ivar was never a clue: the SDK's own 26.0 `lastRenderTime` property is
auto-synthesised into `_lastRenderTime`, which is ordinary and one class.

The getter returns the ivar, there is exactly one definition of the method again, and:

```
stage a fresh engine's root object: port charon_host_PHASEObject, host PHASERootObject
checks=37 failures=0
```

Two mutants, both red:

| mutant | result |
| --- | --- |
| the getter returns a different ivar | `FAIL the port's root object is a PHASEObject, which is the property's declared type` |
| the root not kept — a `__weak` ivar | the same FAIL |
| restored (`cp` from a saved copy) | `checks=37 failures=0` |

The lesson worth keeping, and it is the one the review could not have told me: a hand-written accessor
and a `@synthesize` for the same property are two definitions, and the compiler keeps one without
saying which. The disassembly is what named it; three higher-level measurements all pointed somewhere
else and were all true.
