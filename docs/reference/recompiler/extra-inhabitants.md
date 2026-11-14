# Extra inhabitants of a pointer

arm64 Darwin reserves the low 4 GB of the address space, so the Swift compiler for it treats every value below
`0xFFFFFFFF` in the place of a pointer as an *extra inhabitant* (XI): the empty cases of an enumeration with a class
payload, the `nil` of an optional struct with a class field. The code it emits tells the two apart by one compare with
4 GB. A translated program runs as 32-bit ARM code, whose pointers all lie below 4 GB, so every valid pointer looks like
an extra inhabitant to that code. This page is what that costs, where the compare is, how it is dealt with, and what the
contract of an extra inhabitant is on this port.

## What went wrong

`Optional<URL>` is a resilient type of the Foundation overlay: its copy, its destroy and its tag go through the value
witnesses of `URL`, which the overlay compiled. `getEnumTagSinglePayload` of `URL` clamps the word it reads to
`0xFFFFFFFF` and adds one, so a pointer below 4 GB gave the tag of an empty case: `url.query` of a `URL?` from `URL(string:)`
read the optional as `nil` or copied it without a retain and released it later (use after free). The same happens for
every enumeration or optional that holds a class reference and that code reads through a value witness (a generic
function, a resilient type, the runtime's own copies).

## The contract

Three things must agree for a pointer type, and they now do:

| Part | What it is | Where | On this port |
| --- | --- | --- | --- |
| **get** | the index of the extra inhabitant a word holds, or "not one" | the runtime's `swift_getHeapObjectExtraInhabitantIndex` and the compiled `Vwet`/`Owxx`/`WOe` witnesses and outlined copies | a word below 0x1000 (the first page) is an extra inhabitant, anything else is a pointer |
| **store** | writes the index of an extra inhabitant | the runtime's `swift_storeHeapObjectExtraInhabitant`, the compiled `Vwst` | the index itself, as the word; it has no threshold, so it is as the compiler wrote it |
| **count** | how many extra inhabitants the type has | `numExtraInhabitants` of the value witness table, `swift_getHeapObjectExtraInhabitantCount` | the compiler wrote `0x7FFFFFFF` for a pointer; the runtime derives `LeastValidPointerValue` |

- The runtime is built with `LeastValidPointerValue = 0x1000`
  (`packages/s/swift-runtime/patches/the-least-valid-pointer-of-the-arm64-guest-is-the-first-page.patch`, the value the
  runtime has for every 32-bit platform). That changes the XI test of the runtime's own witnesses
  (`swift_getHeapObjectExtraInhabitantIndex`, the function-pointer variant, the witnesses of the built-in pointer types) and
  `_isValidAddress` of the standard library; the runtime reports 4096 as the count of a heap object pointer.
- The lift (`xlate`) rewrites the compare of the *compiled* code from `0xFFFFFFFF` to `0x1000`, below.
- Only the first 4096 indices are told from a pointer: a word of 4096 or more is a pointer. **An enumeration with a class
  payload and more than 4095 empty cases (4096 with the `nil` of its optional) is outside the contract**: the compiler
  writes `0x7FFFFFFF` as its count and stores the index as the word, so the index 4096 would be read as a pointer. No type
  of the standard library, the overlays, CryptoKit, Network or the SDK is near it (the largest enumerations of an
  XI-pointer payload have tens of cases), and the test `stepExtraInhabitantsBig` keeps the boundary: 4095 empty cases and
  the `nil` of the optional as the 4096th.

## The idiom

A compare of a value with 4 GB, in the code the compiler generates for the witnesses:

```
ldr   x8, [x0]              ; the word
mov   w9, #-1               ; 0xFFFFFFFF
cmp   x8, x9
csel  x8, x8, x9, lo        ; the index, clamped: min(word, 0xFFFFFFFF)
add   w0, w8, #1            ; the tag: index + 1, 0 for a pointer (the payload)
```

and a second shape in the copy, destroy and take witnesses of an enumeration (`Owxx`, `Owcp`, `Owca`, `OwCP`, `Owta`) and
the outlined copies (`WOe`, `WOy`, `WOh`):

```
ldr   x8, [x0]
mov   w9, #-1
cmp   x8, x9
b.lo  not_a_pointer
```

A valid pointer of the host is below 4 GB, so both treat it as an extra inhabitant.

### What the lift does

`xlate` reads the code of the guest through `ReadCode` (the hook that feeds rellume). A `cmp xN, xM` whose `xM` was just set
by `mov wM, #-1` and that the idiom's csel, `add`/`sub` of one or `b.lo`/`b.hs` follows is replaced by
`cmp xN, #1, lsl #12`, a word of the same size. The else value of the csel stays `0xFFFFFFFF`, so a pointer still gives the
tag of the payload. The rewrite is at the word, so it takes effect for every lift path (function lifts, entries of jump tables,
the retries of the lift of a function) in the same way.

The same two instructions clamp an integer in other code (`SmallVectorBase::grow_pod`, the size of a signature in
BoringSSL's `EVP_SignFinal`), and those must keep their meaning, so a compare is rewritten only when

- its function has a name and the name is a witness: `$s…Vwet`, `…Vwst`, `…Owxx`, `…Owcp`, `…Owca`, `…OwCP`, `…Owta`,
  `…Owug`, `…WOe`, with the suffix `Tm` of a merged function, or
- its function has no name (a stripped image) and the compare is the whole idiom: the `csel` is followed by the `add` or
  `sub` of one that turns the clamped value into the tag, or the branch is preceded by a 64-bit load of the compared
  register in the function.

`--xi-threshold` (`XL_XI_THRESHOLD`) sets the value, `0` leaves the compares; `--xi-except` (`XL_XI_EXCEPT`) leaves the
functions whose name has a given text, for a negative control. Every rewritten compare is listed in `report.txt` of the
translation, one `xi-compare:` line each: image, address, function, shape and how it was recognised.

## Inventory

Every use of the constants of the 4 GB rule in the guest images of the port, by a scan of the disassembly (`mov wN, #-1` or
`mov xN, #0xFFFFFFFF`/`#0x100000000` followed by a 64-bit compare, a `csel`, `lsr xN, xM, #32` followed by a test, a mask),
not by a guess:

| Image | Value witnesses `get` (Vwet, Owet) | Enumeration copy/destroy/take (Ow..) | Struct witnesses (Vw..) | Outlined copy/destroy (WO.) | Other functions |
| --- | ---: | ---: | ---: | ---: | --- |
| reCAPTCHA SDK | 24 | 0 | 0 | 3 | none |
| libswiftCore | 31 | 9 (8 `b.lo`) | 0 | 1 | 3 (merged `wetTm` and `Owug`, they are witnesses; the 2 `SmallVectorBase` clamps of the runtime are not) |
| libswiftFoundation | 21 | 17 (15 `b.lo`) | 0 | 0 | none |
| libswiftCryptoKit | 20 | 0 | 0 | 0 | 2 (`SwiftASN1.BitString._validate`, `EVP_SignFinal`: integer clamps) |
| libswiftNetwork | 6 | 0 | 0 | 0 | none |
| libswift_Concurrency | 14 | 0 | 20 (`b.lo`) | 0 | 2 (merged `wetTm`) |
| libswiftDispatch | 3 | 8 (7 `b.lo`) | 0 | 0 | none |
| libswiftObjectiveC | 1 | 0 | 0 | 0 | none |
| libswiftDarwin, CoreFoundation, CoreGraphics | 0 | 0 | 0 | 0 | none |

- **The SDK has 27 sites, all inside value witnesses and outlined copies.** There is no inline extra-inhabitant test in code
  that is not a witness, which is why a rewrite of the compare in the witnesses is enough and the compiler need not change.
  Inline code of a type the compiler knows compares with the number of its empty cases (`cmp x8, #10`), a value that is
  below 4096 for every enumeration that is inside the contract.
- Not extra inhabitants and left alone: 8 checks "the `Int` fits in `UInt32`" in the SDK (`lsr x8, x24, #32` and `cbnz`),
  57 constants of `0xFFFFFFFF` as a mask or a value, the integer clamps named above, `$sSbwetTm` (the extra inhabitants of a
  `Bool`, a 32-bit value: `cmp w8, #2`).
- The runtime C++ of libswiftCore uses the constant through `System.h`, which the runtime patch changes: in the
  disassembly of the arm64 `libswiftCore` the compare `cmp xN, #1, lsl #12` occurs 5 times with the patch and once without it.

A third shape appears only in code built without optimisation (the fixture of the check is one):

```
mov   x10, #0x100000000     ; 4 GB
subs  x9, x9, x10           ; the word minus 4 GB
b.hs  a_pointer
```

It is rewritten to `mov x10, #0x1000` under the same gate (a witness name, or a 64-bit load of the compared register).

## Measurements

Measured on the iPhone 4S, 2026-11-14. The steps and their names are in [corpus.md](corpus.md), check `libgenerics`.

| Build | Result |
| --- | --- |
| runtime patched, lift on | every `xi.*` step `ok` |
| runtime patched, lift on, `XL_XI_EXCEPT="Plain AnyHashable"` | `xi.control.struct`, `xi.control.enum`, `xi.control.stdlib` FAIL (the lift negative control) |
| runtime of main, lift on | only `xi.class.released` FAILs: an `Optional` of a class that generic guest code consumes is never released (the runtime negative control) |

The lift rewrote 40 sites in the translation of the check and 149 in a translation with the Foundation overlay (libswiftCore 39,
libswiftFoundation 38, libswift_Concurrency 35, libswiftCryptoKit 20, libswiftDispatch 11, libswiftNetwork 6).

The reCAPTCHA fixture (`ABFixture`, real Foundation overlay types, runtime patched, lift on) gives `ok url.query`,
`ok url.absolute` and the rest of `stepUrlAscii`, `stepRequest`, `stepJsonOut`, `stepJsonIn`, `stepData`, and the new
`stepXiResilient` (an array of `Optional<URL>` with every fifth `nil`, read after a copy and `removeAll()`; an array of
`Optional<URLRequest>` with a `nil`; an array of `Optional<CharacterSet>`), also under `MallocScribble=1`, with no release
too many. Three steps fail the same way without the runtime patch and the lift and are not an effect of this change:
`components.create` and `components.items` (`URLComponents(string:)`) and `string.format` (`String(format:)`).
