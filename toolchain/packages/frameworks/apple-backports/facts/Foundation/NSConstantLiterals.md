# `NSConstantArray`, `NSConstantDictionary`, `NSConstantIntegerNumber` and `NSConstantDoubleNumber`

Source: a real strong import, read directly out of a shipped binary rather than out of a header
- none of the four classes appears in any SDK header, because the compiler emits them itself and
an application never spells their names. The first three were read with `nm -u`, `dyld_info
-fixups` and raw file reads against `UTM.app/UTM` (arm64, from the corpus scratchpad's extracted
Payload; the same symbols are imported by Delta and Provenance from the same corpus, one or two
classes each). `NSConstantDoubleNumber` (`provenance`, one strong import, `crash-demand-top.tsv`
rank 65) was not read the same way - see its own section below.

## What the compiler does

When every element of an `@[...]` array literal, every pair of an `@{...}` dictionary literal, or
the argument of an `@(...)` boxed integer literal is itself a compile-time constant, clang does not
build the object at process start. It emits a static instance directly into `__DATA_CONST`, gives
its `isa` slot a bind to the class by name (`NSConstantArray`, `NSConstantDictionary`,
`NSConstantIntegerNumber`), and lets dyld resolve that bind against whichever image exports the
class - `CoreFoundation`/`Foundation` on the releases that carry it. iOS 6 does not, so an
application built this way cannot even launch there without it: the class is the whole of the
requirement, since the compiler already built the object.

## The layout, read from `UTM.app/UTM`

`__objc_intobj` (six 24-byte entries), `__objc_arrayobj` (six 24-byte entries) and
`__objc_dictobj` (one 40-byte entry) each hold instances back to back. Past the bound `isa`:

- `NSConstantArray`: a `uint64_t` count, then a pointer to a contiguous, immortal `id const *` of
  that many objects. Two array instances (count 1 and count 3) point at
  `0x1006dba68`/`0x1006dba80`, forty bytes apart, exactly `3 * 8` - the pointers are read off
  consecutively out of one shared pool, not individually owned.
- `NSConstantDictionary`: a `uint64_t` at offset 8 (seen only as `1` in the one instance found -
  unused by the backport, since a 30-pair dictionary already exercises `count`, `keys` and
  `objects`), a `uint64_t` count at offset 16, then a keys pointer and an objects pointer, each
  into the same kind of shared pool. The one instance carries count `30`; its keys pointer and its
  objects pointer are exactly `30 * 8` bytes apart in the pool, which is what tied `count` to the
  two pointers rather than to some other field.
- `NSConstantIntegerNumber`: a `const char *` at offset 8 and an `int64_t` at offset 16. The
  pointer was followed to two distinct addresses in `__TEXT,__cstring`; each holds a single
  Objective-C type-encoding character - `"i"` at one, `"q"` at the other - so the field is
  `-objCType`, and the trailing eight bytes are the literal's own value, stored whole regardless of
  the encoded width (`0`, `2`, `3`, `12` were the values actually seen).

## `NSConstantDoubleNumber`, reasoned rather than read

No shipped binary that strongly imports `NSConstantDoubleNumber` was available to this band to
disassemble - `provenance`'s own binary, the one the demand row names, was not on hand either.
The layout carried (`isa`, `const char *objCType`, `double value`) is not invented: it is the same
`isa`-then-`objCType`-then-`value` shape measured for `NSConstantIntegerNumber` above, on the
reasoning that both classes come from the same clang codegen path - a boxed literal, `@(expr)`,
that clang can fold at compile time because `expr` is itself a compile-time constant - and clang
does not invent a second struct shape for a second numeric flavour of the same optimisation. What
changed from the measured class is only the trailing field's width and the type-encoding character
`objCType` points at: `"d"` for a `double` expression, presumably `"f"` for a `float` one, in place
of `"i"`/`"q"`. Confirming the exact byte offsets against a real binary - and finding out whether a
boxed `float` literal really does widen to an 8-byte `double` in storage the way this class assumes,
matching how the integer class stores every width in a full 8 bytes - is future work for whichever
band next holds a binary that imports this class strongly.

## What the backport does

Each class reads its own bound instance through a fixed-offset struct overlay, the way
`CFEmptyCollections.m`'s `__NSArray0__`/`__NSDictionary0__` read the host's singletons - no ivars
are declared, so nothing depends on how this compiler's non-fragile layout would place them.
`NSConstantArray` and `NSConstantDictionary` implement the minimum NSArray/NSDictionary primitives
(`-count`, `-objectAtIndex:`, `-objectForKey:`, `-keyEnumerator`) that the class clusters build the
rest of their behaviour on. `NSConstantIntegerNumber` and `NSConstantDoubleNumber` each implement
every `NSNumber` accessor directly against their own stored value, rather than leaning on an
inherited default that real `NSNumber` does not guarantee for a subclass it never expects.
`NSConstantDoubleNumber`'s `-stringValue` picks the shortest decimal that reads back to the same
`double`, the property a real `NSNumber`'s description promises, rather than reproducing
`CFNumber`'s own formatter byte for byte; this was not held against a host oracle, since no
UIKit/Foundation host test can construct a compile-time-constant literal the way a real binary's
`isa`-bound instance is built.

## What is not known

The exact iOS release this ABI first appeared in is not pinned down - the corpus tags it `13-16`,
and the binary read here (UTM, built mid-2024) only proves it existed by whatever SDK that build
used. The registry's `introduced: 13.0` is the demand data's own lower bound, not a release
measured directly; unlike the layout above, it is reasoned, not read. The dictionary's offset-8
field is carried in the layout for completeness but not interpreted - no second instance was
available to test what varies it, and the backport does not depend on its value.
