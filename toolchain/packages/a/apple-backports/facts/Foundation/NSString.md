# NSString, the validated format of iOS 11.0

Introduced in iOS 11.0: a format string checked against the specifiers it is
allowed to use, so a format that arrives from outside the application cannot ask
for arguments that were never passed.

Source: Foundation of the arm64 shared cache of iOS 11.0
(`+[NSString stringWithValidatedFormat:validFormatSpecifiers:error:]` at
`0x1815863e0`, `+localizedStringWithValidatedFormat:…` at `0x181586350`, and the
real work in `-[NSPlaceholderString initWithValidatedFormat:validFormatSpecifiers:locale:arguments:error:]`
at `0x1815891ac`, which checks both arguments for `nil` and then hands the work
to CoreFoundation at `0x180b578fc`). Two more sources:
- The shape of the check follows the specifier parser of CoreFoundation's open
  source (`CFString.c` of swift-corelibs-foundation).
- The rule itself was read off the host's Foundation, which is newer than any
  release this package reads. Where the two sources disagree, the host wins:
  its `*` takes an argument, and it compares kinds through the relation below
  rather than by equality.

How it was checked: a fuzzer put random pairs of format and allowed specifiers
to the host's Foundation and to the port, called directly. It covered
positionals, `*` and `*N$`, flags, widths, precisions, every length, unknown
conversions, `%%`, external specifiers, a `%` left unfinished, text outside
ASCII and the localized form. The integer and float arguments are drawn per pair
too: 0, bytes above 0x7F, characters outside Latin 1, -1, the largest 32-bit
value and one past 32 bits. Over 180,000 pairs the two agreed on every verdict
and message. For the roughly half of them whose arguments are the ones the
allowed string describes, they also agreed on every character of the output.

The fuzzer was checked in turn against twelve ports broken on purpose, one rule
each (`tests/backports/host/validatedformat/mutants.txt`), and caught every one.

Until the arguments were drawn at random, every integer the fuzzer passed was 7,
and the port printed wrong strings that no check saw: a `%c` of 0 as a NUL
character, `%hhD` of 0x2603 as `9731`, and a `%c` above 0x7F in Latin 1 where
the string needed MacRoman. The section on the string below is what the port
does since.

An earlier version of these facts described a different rule. That comparison
never ran the port: the host test reached the port only through its public
entry point, which then called the host's own method. The table it gave is
wrong in four places:
- `%s` and `%S` are one kind in it;
- a width `*` is refused;
- `%0$@` is a specifier;
- `%P` is missing.

## The rule

Each string is read as a list of specifiers.
- `%%`, and any `%` followed by a conversion that is not one, are text.
- A `%` still unfinished at the end of the string is a specifier of its own
  kind, "unfinished". Only an unfinished specifier in the same place of the
  allowed string matches it.
- A specifier's value takes slot `N` when written `%N$…`, otherwise the next
  sequential slot. A positional does **not** move the sequential count, so in
  `%1$d %f` both specifiers ask for slot one.
- A width or precision written `*` takes a sequential integer slot of its own,
  before the value; written `*N$`, it takes slot `N`.
- `%0$…` is not a positional: it is text.
- A specifier written `%#@key@` or `%[key]@` asks for an object slot like `%@`.

For every slot the format asks for, the allowed string must have a specifier in
that slot. Only the **first** specifier the allowed string puts in that slot
counts. Every specifier of the format in that slot must accept it:

| the format asks for | the allowed slot may hold |
|---|---|
| `%@` | `%@` |
| an integer: `d D i o O u U x X c`, any length but `L` | an integer |
| `%C` | an integer or `%C` |
| `%Ld` and the other integers with `L` | the same |
| a float: `f F e E g G a A`, any length but `L` | a float |
| `%Lf` and the other floats with `L` | the same |
| `%s` | `%s`, `%P` or `%p` |
| `%P` | `%P`, `%s` or `%p` |
| `%S` | `%S` or `%p` |
| `%p` | `%p`, `%@`, an integer, `%s`, `%S` or `%P` |
| `%n` | `%n` |

Some consequences:
- `%d` matches `%ld` and `%hhd`, since lengths other than `L` do not matter.
- `%C` against `%d` passes, while `%d` against `%C` does not.
- `%*d` against `%d` is refused, since the width is a slot of its own; against
  `%d%d` it passes.
- `%1$d %f` is refused even against itself: slot one is an integer, and the
  float asks for the same slot.
- `%U%1$C%i` against itself passes, because `%C` accepts the integer that came
  first.
- An allowed string's own conflicts do not matter: `%d` against `%1$d %1$f`
  passes.
- `%5$@` against `%@` is refused, as is `%@ %` against `%@`.
- An empty format, or one with no specifiers, passes against anything,
  including an empty allowed string.

## Failure

A format that does not fit answers `nil` and fills in `NSCocoaErrorDomain`
`2048` (`NSFormattingError`) with

    Format '<format>' does not match expected '<allowed>'

in `NSDebugDescription`. A `nil` format or a `nil` list of allowed specifiers
raises `NSInvalidArgumentException` with `%@: nil argument`, before anything
else happens.

## The string that is built

What the method answers when the format fits is whatever Apple's formatter makes
of it. The formatter of iOS 6 makes something else of formats the check lets
through. On iOS 6.0 (in the emulator):
- `%0$@` prints `0@`, where Apple prints `0$@`;
- a positional past the specifiers before it prints nothing at all: `%9$@`
  alone gives an empty string, and so does `%12$@ %1$@`;
- `%1$@ %10$@ %2$@` gives `A C B`, where Apple gives `A J B`;
- `%[k]@` prints `[k]@`, where Apple prints it whole;
- `%#@key@` ends the process with a segmentation fault.

So the port does not hand the format to the release. It builds the string
itself, the way Apple's formatter does, and asks the release only for single
specifiers it formats the same way:
- The arguments are read in slot order. Each has the kind and size of the first
  specifier the **allowed** string puts in its slot, since that string is the
  caller's statement of what was passed. On armv7 this is the only reading that
  keeps the arguments in step: a `%d` there is four bytes and a `%lld` eight.
  Apple's releases of this API are 64-bit, where every argument fills eight
  bytes and the question does not arise.
- A slot the allowed string leaves empty is read as a pointer.
- Each slot's value is then cut to the size CoreFoundation reads it at: that
  of the **last** specifier the format puts in the slot, as its formatter keeps
  one size per argument and each specifier overwrites it.
  - `hh` and `%c` keep 8 bits, `h` and `%C` 16, `l`, `z` and `t` a `long`,
    `ll`, `q` and `j` 64 bits, and anything else 32 bits, all with their sign.
  - A slot used as a width or precision after that is 32 bits.
  - So `%hhD` of 0x2603 is `3`, `%1$x %c` of 0x1f641 is `41 A`, and `%u%1$c`
    of 0xb0 is `4294967216`.
- Each specifier is then formatted on its own with its positional numbers taken
  out.
  - Integers, floats and pointers go through `snprintf` with the text of the
    specifier, as CoreFoundation does. An integer is passed as 64 bits when the
    specifier's own size is 64 bits, and otherwise as its 32 bits, widened with
    their sign to a `long`: that is what `%D`, `%U` and `%O` read, and it is what
    the host's formatter passes them. On armv7 a `long` is 32 bits, so there
    `%hU` of 0x1f600 prints `4294964736` where the host prints
    `18446744073709549056`.
  - As CoreFoundation appends the result as a C string, it ends at the first
    NUL byte: `%c` of 0 prints nothing.
  - Only `%c` and `%lc` make bytes above 0x7F. `%lc` of one prints nothing,
    since `snprintf` refuses it in the C locale. A byte from `%c` stays ISO
    Latin 1 while everything else in the string is ASCII. When anything else
    in the string is not - the text of the format, a `%C`, an object, a `%S` -
    CoreFoundation's string is widened to 16 bits, and the bytes are read in
    the system's encoding instead, wherever they stand. The system's encoding
    is MacRoman on the host, and on an iPhone 4S and an iPad 2 with 6.1.3 its own
    `+stringWithFormat:` does the same: `%c|%C|%c` of 0xe9, 0x2603 and 0xb0 is
    `È|☃|∞` there as on the host. The port asks the release for its
    system encoding rather than assuming it.
  - `%c` goes this way with a locale too, since CoreFoundation localizes only
    `d i u D U` and the floats.
  - With a locale, as `+localizedStringWithValidatedFormat:` passes one, they go
    through the release's formatter with that locale instead.
  - Objects, `%s`, `%S`, `%P` and `%C` always go through the release's
    formatter, one specifier at a time.
- Text specifiers print their text without the `%`: `%k` prints `k`, `%0$@`
  prints `0$@`, and `%'10f` prints `'10f`.
- External specifiers print themselves whole and take no argument:
  `%#@key@ %@` prints `%#@key@ A`.
- `%n` takes its argument and prints nothing.
- An unfinished `%` prints nothing.

The device cases (`tests/backports/device/foundation11-cases.m`) hold the port
on iOS 6 to the host's answers for every one of the formats above, and for
stars, positional stars, `%s %S %P %C %c`, every length, the integer and float
conversions with flags, `%n` and the localized form, and for the bytes, sizes
and shared slots above. One of those cases asks the release's own
`+stringWithFormat:` for the MacRoman bytes, so the device answers for itself.
