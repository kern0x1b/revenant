# The name of a gesture recognizer, iOS 11.0

Introduced in iOS 11.0: a name a recognizer carries so it can be told apart in
a log.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`-[UIGestureRecognizer setName:]` at `0x18a63db60`,
`-[UIGestureRecognizer name]` at `0x18a63db50`) and the differential test
against the host's UIKit (`tests/backports/host/gesturename`).

## Behaviour

The setter is `objc_setProperty_nonatomic_copy` on the field at offset `0xc8`,
so the string is **copied**: a mutable string handed over and then changed does
not change the recognizer's name, and the name is not the same object that was
passed. The getter reads the field. The name starts out `nil` and can be set
back to `nil`. Each recognizer keeps its own.

Nothing in the release acts on the name — it is carried for the reader, which is
why the port can carry it in full, in an associated object, and be the real
implementation rather than a stand-in.

## What the port cannot do

`-description` of a recognizer prints the name in parentheses after the address:
`<UITapGestureRecognizer: 0x… (tap); id = 1; state = Possible; view = (nil)>`.
The port does not reproduce that: `-description` belongs to the release, and the
port replaces no system method. So a name set through the backport is readable
through `-name` but does not show up when a recognizer is printed. The host test
prints that as a note beside its checks.
