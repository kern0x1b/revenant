# PDFKit's constants

Every constant here is the host's own value, read out of the host's PDFKit with `dladdr` naming the
image it came from, and compared name by name against the committed object by
`tests/backports/host/pdfkit-constants/run.sh`:

    the port's objects carry 125 string constants and 1 numeric constants
    COMPARED 126 MISMATCHES 0

## Why the differential does not link the port's object

Linking it was the mistake, and it cost a run: the port's objects import `<PDFKit/PDFKit.h>`, and
compiling the differential against the same headers as the host framework collides on `NSString`
before either side answers a question. The port's values are the string literals in the committed
object, so the runner reads the name-to-literal map out of that file and compares it with the host's
map. Nothing has to agree with the port's headers, and the collision cannot come back.

## Why each name is read in its own fork

Reading a symbol's pointer and messaging it kills the process that does it, and in the parent that
takes the whole run with it. That happened twice: 69 names, then a segfault; then zero names, after
`objc_opt_class` — which expects a pointer that may be a `Class`, not an arbitrary symbol address —
turned out to be the wrong probe. One `fork()`ed child per name with the result on a pipe makes a
name that cannot be read cost its own row.

## The image proof, and why it is the only one

The host framework has no file on disk:

    $ ls /System/Library/Frameworks/PDFKit.framework/PDFKit
    ls: /System/Library/Frameworks/PDFKit.framework/PDFKit: No such file or directory

It lives in the dyld shared cache, so `nm` cannot be pointed at it and `dladdr`'s image pointer is
the only proof there is. The run fails if any name's image does not contain `PDFKit`.

## The one numeric name, and what it took to check it

`kPDFDestinationUnspecifiedValue` is `PDFKIT_EXTERN const CGFloat` — the sentinel for an unspecified
x or y in a point, which the header's own comment describes as "no position is specified". Two things
were wrong in the first version of this work, and the review caught the first:

1. it claimed "the value the header gives". **The header gives no value at all**: PDFDestination.h:17
   declares the symbol with no initializer, so there was nothing to give.
2. it wrote `CGFLOAT_MAX`, which is `DBL_MAX` on this target — 1.7976931348623157e+308. The host's own
   value, read through `dlsym` as a double with `dladdr` naming the image, is
   **3.4028234663852886e+38**, which is `FLT_MAX`.

So the row is host-checked now, not header-only, and the differential compares the numeric names the
way it compares the strings: `read-host-numeric.m` reads the host's double, the runner compares it
with what the port's literal evaluates to, and a mismatch fails the run.

That comparison needed a fix of its own before it meant anything. A control that planted
`(CGFloat)DBL_MAX` — a different number from the host's — still passed, because the port's literal
arrives with a cast in front of it and the runner looked the name up without it. With the cast
stripped:

    kPDFDestinationUnspecifiedValue	(CGFloat)DBL_MAX
  MISMATCH        kPDFDestinationUnspecifiedValue  port=DBL_MAX -> 1.7976931348623157e+308  host=3.4028234663852886e+38
  COMPARED 125 MISMATCHES 1

A check that reads nothing looks exactly like a check that passes, so the control is what made the
number mean something.

## Bands

One object per release the names' availability names, which is the port's own rule: 11.0 carries 119,
15.0 carries 3, 16.0 carries 2 and 16.4 carries 2.
