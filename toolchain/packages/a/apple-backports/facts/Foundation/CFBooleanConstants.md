# `__kCFBooleanTrue`, `__kCFBooleanFalse`

Source: two LOAD-FAIL C symbols (corpus rows 24 and 151, `undecided-for-verdict.tsv`), imported
strong by `provenance` and `utm`. Measured directly against `dyld_shared_cache_armv7` for iOS
6.1.3 (`$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7`), reading `CoreFoundation`'s own
`LC_SYMTAB` and disassembling three of its functions (armv7 Thumb, capstone) - nothing here is
inferred from a header or from the modern SDK's behaviour.

## What the release actually exports

`CoreFoundation`'s `LC_SYMTAB` on 6.1.3 has exactly two boolean-related data symbols:
`kCFBooleanTrue` at `0x3950313c` and `kCFBooleanFalse` at `0x39503140` (single underscore at the
C level - the ordinary public pointer variables `CFBase.h` already declares). Reading through
them: each holds a 32-bit pointer to a private struct - `0x39505530` for true, `0x39505538` for
false, 8 bytes apart - and both structs are byte-for-byte identical: `00 00 00 00 80 00 00 00`, a
bare `CFRuntimeBase` (`isa = 0`, `info = 0x00000080`) with no value field at all. The private
struct symbols themselves (`__kCFBooleanTrue`/`__kCFBooleanFalse`, double underscore at the C
level - what a recent SDK compiles an app to bind directly, the way it binds `NSConstantArray`'s
`isa`) are **not present** in this `LC_SYMTAB` at all, under any visibility - not found searching
all 6161 entries for `Boolean`. That absence is the whole of the LOAD-FAIL: the release never
gave that particular symbol a home, public or private.

## Where the value actually comes from

`_CFBooleanGetValue` (`0x310b0378`) was disassembled. After a generic type-check preamble that
this object's `isa == 0` skips, the entire answer is:

```
movw r2, #0x5152
movt r2, #0x845
add  r2, pc          ; r2 = 0x39505530, the release's own private kCFBooleanTrue struct
cmp  r0, r2
it   eq
moveq r1, #1
```

`return cf == 0x39505530;` - literally the release's own fixed address, nothing read out of the
object's bytes. Since a carried object cannot occupy the release's own address (that memory is
inside the dyld shared cache, mapped read-only, and belongs to a different struct instance
anyway), **calling the release's real `CFBooleanGetValue` on this backport's own
`__kCFBooleanTrue`/`__kCFBooleanFalse` will not report the correct value** - measured, not
guessed, and true regardless of how the carried object is built. No caller was found doing this:
the corpus's 13-site audit of `provenance` and `utm` found every use is a literal array/dictionary
element, a default value, or a call argument - never a value read back through
`CFBooleanGetValue`, and never a pointer comparison against the release's own singleton either
(`delta` does not even demand the symbol). If a caller doing either of those ever turns up, this is
where it will read wrong, not crash - `_CFBooleanGetValue` returns `false` for an address it does
not recognise, it never dereferences past the check.

## What the backport does instead

`_CFGetTypeID` (`0x311391d4`) was disassembled as well, to check whether it has the same kind of
address-special-casing. It does not: for a legacy (`isa == 0`) object, the whole function is
`ubfx r1, r3, #8, #10` (`r3` is the object's second word, the info word) followed by `return r1;`
- a pure decode of the object's own bytes, no comparison against any fixed address. That means a
genuinely new CF object, minted with its own type, reports its own `CFGetTypeID()` correctly and
self-consistently, with nothing to fake.

So the backport registers a real CF class - `_CFRuntimeRegisterClass` and
`_CFRuntimeCreateInstance`, both exported by this same release (`0x310d2d40` and `0x310a2640`,
confirmed the same way) and the ordinary, documented mechanism every CF type uses, not private API
this backport invented. `_CFRuntimeRegisterClass`'s own preamble was disassembled to check the
`CharonCFRuntimeClass` struct's field layout before trusting it: it reads a flag out of
`version`'s low byte and, only if that flag is set, reads a function pointer at struct offset
`0x28` - exactly where the `refcount` field lands in the eleven 4-byte-field layout used here
(`version, className, init, copy, finalize, equal, hash, copyFormattingDesc, copyDebugDesc,
reclaim, refcount`), which confirms the struct's shape rather than assuming it from memory of the
public header. `version` is `0` here, so that flag is never set and `refcount` is never read.

`CFEqual` has no custom `equal` registered for this class, so it falls back to CF's own pointer
identity default - exactly correct for a type with exactly two possible values. `CFRetain`/
`CFRelease` operate on a real, ordinary refcount; each singleton is retained once more at
construction (`CFRetain` in the constructor, matching `CFEmptyCollections.m`'s own technique for
the host's empty singletons) so a caller's unbalanced `CFRelease` does not reach zero and free it.

## What is not known

The exact release this ABI first appeared in is not pinned down, same caveat as
`NSConstantLiterals.md` - the corpus tags it `13-16`. Whether the release's own `CFBoolean` type
registers a custom `hash` was not checked (this backport's own class does not, and CF's untyped
pointer-based default is safe either way for a two-valued type). Whether any real call site
anywhere compares `CFGetTypeID()` against `CFBooleanGetTypeID()` was not found in the corpus, but
was not exhaustively ruled out either - unlike the `CFBooleanGetValue` gap above, this one is
believed harmless rather than measured harmless.
