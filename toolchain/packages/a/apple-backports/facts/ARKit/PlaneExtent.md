# ARPlaneExtent: the plane's size, read out of ARKitCore of the 16.0 cache

`ARPlaneExtent` arrived in 16.0. Every value and every string the port's `ARKit/ARPlaneExtent16.m`
carries was read out of the release, not chosen, and this page is where the read is recorded so that
it can be taken again.

## There is no host oracle for this class, and the control that says so

This Mac (macOS 27.0, build 26A428) has `ARKit.framework` and it loads: `dlopen` by path answers a
handle, and 24 677 classes are in the runtime. Its `ARKit` has **`ARSkeletonDefinition` and no
`ARPlaneExtent`**:

```
$ .agent-work/runs/arkit-planeextent-host/oracle
handle=0x36c5c0b48
  ARPlaneExtent                ABSENT
  ARWorldTrackingConfiguration ABSENT
  ARReferenceObject            ABSENT
  ARSkeletonDefinition         present
  ARSession                    ABSENT
classes=24677
```

The control is the third and fifth lines against the fourth: the same `dlopen` of the same framework
brings `ARSkeletonDefinition` in, so the three `ABSENT` lines are the host's answer and not an
unloaded framework. (The coordinator measured the same three absences on 2026-10-03; this run repeats
it rather than taking it.)

So nothing in this family may be described as "the host agrees". What stands in for a differential is
`tests/backports/host/arkit-planeextent/run.sh`, which measures the port's own object against the
release's own code, listed below, and which has to go red when any one of those readings is changed.

## The class's own method lists

`tools/corpus/skeleton-table.lua <cache> ARKitCore impls ARPlaneExtent` reads both lists of the class
and prints each one with its header:

```
#instance list=0x1af218598
#  entsize_and_flags=0xc000000f count=11 entsize=12 small=true selector_base=0x182329184 relative=true
setHeight:            0x1af14f4f4
init                  0x1af14f268
encodeWithCoder:      0x1af14f2c0
initWithCoder:        0x1af14f348
setWidth:             0x1af14f4e4
height                0x1af14f4ec
width                 0x1af14f4dc
isEqual:              0x1af14f3bc
copyWithZone:         0x1af14f470
rotationOnYAxis       0x1af14f4cc
setRotationOnYAxis:   0x1af14f4d4
#class list=0x1af2183e8
#  entsize_and_flags=0xc000000f count=1 entsize=12 small=true selector_base=0x182329184 relative=true
supportsSecureCoding   0x1af14f2b8
```

Eleven instance methods and one class method. Three facts come out of this that the port needed:

- **`+supportsSecureCoding` is the class's own**, not an inherited answer. The instance list says
  nothing about a class method, and it would have been easy to record a YES on the strength of the
  header's `<NSSecureCoding>` alone. The class list has exactly one entry and this is it.
- **The three setters exist** (`-setRotationOnYAxis:` at 0x1af14f4d4, `-setWidth:` at 0x1af14f4e4,
  `-setHeight:` at 0x1af14f4f4) while the release's public header declares the three properties
  `readonly` and does not declare the setters. So the object has to be fillable from inside and not
  from a caller, and the port's setters are the release's own methods rather than API this package
  claims.
- **`-isEqual:` and `-copyWithZone:` exist** and both are reachable from the SDK's own `NSObject`
  declarations, so what the port answers for them is a caller's answer.

Each implementation address is inside a span the image's own `LC_FUNCTION_STARTS` declares
(`functions 1af14f200 1af14f520` prints fourteen starts, `0x1af14f2c0 +0x88` for the encoder), which
is the control that a read which found nothing found nothing.

## +supportsSecureCoding answers YES, unconditionally

```
$ sh tools/corpus/disasm.sh ~/.charon/dyld/16.0/dyld_shared_cache_arm64e ARKitCore 1af14f2b8 1af14f2c0
0x1af14f2b8:	 52800020     	mov	w0, #0x1                ; =1
0x1af14f2bc:	 d65f03c0     	ret
```

Two instructions, the constant 1 in the return register. The release does not consult the protocol
list, so the port's `return YES` is the same answer and not an inference from the header.

## The coder keys: origin, width, height

`-encodeWithCoder:` at 0x1af14f2c0, span `+0x88`:

```
0x1af14f2d8:	 aa0003f3     	mov	x19, x0
0x1af14f2dc:	 bd400808     	ldr	s8, [x0, #8]
0x1af14f2e0:	 956513d0     	bl	0x1b4a94220      ; branch stub
0x1af14f2e4:	 f90007e0     	str	x0, [sp, #0x8]
0x1af14f2e8:	 d018d462     	adrp	x2, 0x31a8e000
	; adrp page 0x1e0bdd000
0x1af14f2ec:	 9138c042     	add	x2, x2, #0xe30
0x1af14f2f0:	 1e204100     	fmov	s0, s8
0x1af14f2f4:	 94063ee3     	bl	0x1af2dee80      ; [coder encodeFloat:forKey:]
0x1af14f2f8:	 bd400e60     	ldr	s0, [x19, #0xc]
0x1af14f2fc:	 f018d422     	adrp	x2, 0x31a87000
	; adrp page 0x1e0bd6000
0x1af14f300:	 9139c042     	add	x2, x2, #0xe70
0x1af14f304:	 f94007e0     	ldr	x0, [sp, #0x8]
0x1af14f308:	 94063ede     	bl	0x1af2dee80
0x1af14f30c:	 bd401260     	ldr	s0, [x19, #0x10]
0x1af14f310:	 f018d422     	adrp	x2, 0x31a87000
	; adrp page 0x1e0bd6000
0x1af14f314:	 913a4042     	add	x2, x2, #0xe90
0x1af14f318:	 f94007e0     	ldr	x0, [sp, #0x8]
0x1af14f31c:	 94063ed9     	bl	0x1af2dee80
0x1af14f320:	 f94007e0     	ldr	x0, [sp, #0x8]
```

Three `adrp`/`add` pairs, three `__cfstring` constants, and three stores of `s0` out of the object at
offsets 8, `0xc` and `0x10`. The constants and their strings:

| constant | chars | length | string | image |
| --- | --- | --- | --- | --- |
| `0x1e0bdeb30` | `0x1af285058` | 6 | `origin` | ARKitCore `__cstring` |
| `0x1e0bd6e70` | `0x1af27e6d2` | 5 | `width` | ARKitCore `__cstring` |
| `0x1e0bd6e90` | `0x1af27e6d8` | 6 | `height` | ARKitCore `__cstring` |

**`origin` is not `rotationOnYAxis`.** That is the one thing a reader would have got wrong by
carrying the property name over, and it is why the property each float belongs to was established a
second way. The three accessors are one `ldr` each, so each property names its own offset:

```
0x1af14f4cc:	 bd400800     	ldr	s0, [x0, #8]     ; -rotationOnYAxis
0x1af14f4dc:	 bd400c00     	ldr	s0, [x0, #0xc]   ; -width
0x1af14f4ec:	 bd401000     	ldr	s0, [x0, #0x10]  ; -height
```

So: `origin` is written from offset 8, which is `-rotationOnYAxis`'s own offset; `width` from `0xc`,
which is `-width`'s; `height` from `0x10`, which is `-height`'s. Three identifications, three
independent reads, and they agree. The three `bl 0x1af2dee80` are all in ARKitCore's `__objc_stubs`
(0x1af2d7ca0 .. 0x1af2f1fff), so the three calls are one message and not three different encoders.

**Two methods, one table.** `-initWithCoder:` at 0x1af14f348 reads the same three constants, in the
same order, into the same three offsets:

```
0x1af14f36c:	 9138c042     	add	x2, x2, #0xe30    ; origin  (page 0x1e0bdd000)
0x1af14f374:	 bd000a60     	str	s0, [x19, #0x8]
0x1af14f37c:	 9139c042     	add	x2, x2, #0xe70    ; width   (page 0x1e0bd6000)
0x1af14f388:	 bd000e60     	str	s0, [x19, #0xc]
0x1af14f394:	 913a4042     	add	x2, x2, #0xe90    ; height  (page 0x1e0bd6000)
0x1af14f3a4:	 bd001268     	str	s8, [x19, #0x10]
```

Encode and decode are different functions at different addresses and they were read separately; that
they agree on all three keys and all three offsets is the check, and it is the reason no key here was
guessed from a header.

## -init: no plane is this big

```
0x1af14f29c:	 fd431100     	ldr	d0, [x8, #0x620]   ; page 0x1af24c000 + 0x620
0x1af14f2a0:	 fd000400     	str	d0, [x0, #8]
0x1af14f2a4:	 52b7f008     	mov	w8, #-0x40800000    ; =-1082130432
0x1af14f2a8:	 b9001008     	str	w8, [x0, #0x10]
```

One 64-bit constant across the rotation and the width, and a second value into the height. The
constant at `0x1af24c620` is inside ARKitCore's `__const` (0x1af220b00 .. 0x1af252903) and reads:

```
00000000000080bf   ->  double -1.0   ->  low word 0x00000000, high word 0xbf800000
```

The low word lands at offset 8 and the high word at `0xc`, because the store is a 64-bit store at the
rotation's own offset and the bytes are little-endian. So a fresh extent reads **rotation 0.0,
width -1.0**, and `0xBF800000` as a float is **-1.0** for the height. Checked with `struct.unpack`,
and `fd000400` is byte-for-byte what `clang -arch arm64e` assembles `str d0, [x0, #0x8]` to.

A plane is not this big, which is the point: an extent nobody has measured yet says so in its own
three floats rather than in a flag.

## -isEqual: compares the three floats, within FLT_EPSILON

```
0x1af14f3f4:	 bd400a80     	ldr	s0, [x20, #8]
0x1af14f3f8:	 bd400801     	ldr	s1, [x0, #8]
0x1af14f3fc:	 7ea1d400     	fabd	s0, s0, s1
0x1af14f400:	 52a68008     	mov	w8, #0x34000000     ; =872415232
0x1af14f404:	 1e270101     	fmov	s1, w8
0x1af14f408:	 1e212000     	fcmp	s0, s1
0x1af14f40c:	 54000245     	b.pl	<return NO>
```

`fabd` is the difference made positive, and the constant it is compared against is
`0x34000000`, which as a `float` is `1.1920928955078125e-07` -- `FLT_EPSILON`. A difference below it
passes. The same three lines repeat for offsets `0xc` and `0x10`, and the class is checked first:
`cbz w0` after the `isKindOfClass:` stub returns NO for anything else. The port keeps the tolerance
because a comparison without it answers NO for two extents the release answers YES for, which is an
invented answer in the same way a wrong value is.

## -copyWithZone: allocates the same class and copies the three floats

```
0x1af14f48c:	 aa13e3e2 / mov x2, x19; bl 0x1af2dab20    ; [cls allocWithZone: zone]
0x1af14f4a0:	 bd000a60     	str	s0, [x19, #8]
0x1af14f4ac:	 bd000e60     	str	s0, [x19, #0xc]
0x1af14f4b8:	 bd001260     	str	s0, [x19, #0x10]
```

Three getters called on `self` and three stores into the new object: no other state exists to copy.

## The harness

`tests/backports/host/arkit-planeextent/run.sh` compiles the port's object with the class renamed and
asks it twenty-six things, of which the load-bearing ones are: a fresh extent's three defaults; that the
class carries `+supportsSecureCoding` itself and answers YES; that the archive the port writes
contains the three literal key strings `origin`, `width` and `height` **and not** the property name;
that the archive round-trips, including for three floats whose bits are not short decimals; that two
extents with the same values are equal and are not the same object; that a rotation below the
release's tolerance is equal and one above it is not; and that a copy is a different object that
equals the original.

Six mutants, each of which has to turn the run red:

| mutant | what only it can see |
| --- | --- |
| the rotation written under `rotationOnYAxis` instead of `origin` | the key list, and the round trip |
| `width` and `height` written under each other's keys | the round trip -- every key is still present |
| a fresh extent whose width is zero | the defaults |
| an extent that declines secure coding | `+supportsSecureCoding`, and the archive as well, because a secure-coding archiver refuses a class that declines |
| `isEqual:` answering identity only | the value equality and the copy |
| `isEqual:` demanding bit equality | the tolerance, and nothing else |

## What is left, and why

The class's own method list is eleven instance methods and one class method, and every one of the
twelve has been read here: `-init`, `-initWithCoder:`, `-encodeWithCoder:`, `-isEqual:`,
`-copyWithZone:`, the three getters, the three setters and `+supportsSecureCoding`. There is nothing
else the release has, so there is nothing else this class owes. `-isEqual:`'s span is `+0xb4`, which
runs to `0x1af14f470` and stops exactly at `-copyWithZone:`'s own start, so the two `mov w20, #0`
arms and the two `bl` tails inside that span belong to `-isEqual:` and not to a method of their own.

Not carried here, and not claimed here: **`ARPlaneAnchor.planeExtent`**, which is the one member of
this class a caller would reach in practice. `grep planeExtent` over
`coordination/corpus/ledger-2026-10-03/ARKit.tsv` answers nothing -- it is not one of this ledger's
rows -- and `ARKit/ARAnchor.m` does not implement it. The anchor's own state here is the tracker's
`simd_float3` extent (`-[ARPlaneAnchor initWithPlaneValue:]` in `ARKit/ARAnchor.m`), which carries no
rotation about the vertical, so an extent built from it would carry a `rotationOnYAxis` of zero
because there was nothing to measure, which is the fake this package does not ship. It is a row about
the anchor, and it is owed until the detector produces the rotation that belongs in it.