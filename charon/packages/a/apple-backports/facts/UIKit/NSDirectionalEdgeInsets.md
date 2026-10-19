# NSDirectionalEdgeInsets

Introduced in iOS 11.0: insets named by writing direction — leading and
trailing instead of left and right.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`NSStringFromDirectionalEdgeInsets` at `0x18a2450cc`,
`NSDirectionalEdgeInsetsFromString` at `0x18a2452e8`,
`NSDirectionalEdgeInsetsZero` at `0x18ad10568`); the observable behaviour from
the differential test against the host's UIKit through Mac Catalyst
(`tests/backports/host/directionaledges`).

## The string form

`NSStringFromDirectionalEdgeInsets` formats with `{%.*g, %.*g, %.*g, %.*g}`,
the precision passed in, which is the same text `NSStringFromUIEdgeInsets`
writes for the same four numbers: `{1.5, 2, 3.25, 4}`.

`NSDirectionalEdgeInsetsFromString` accepts exactly what
`UIEdgeInsetsFromString` accepts, and refuses the same way — every refusal is
four zeroes, never a partial read:

| string | result |
|---|---|
| `{1, 2, 3, 4}` | `1 2 3 4` |
| `{ 1 , 2 , 3 , 4 }` | `1 2 3 4`: spaces do not matter |
| `{1, 2, 3, 4, 5}` | `1 2 3 4`: the extra is dropped |
| `{-1.5, 0, 2e2, .5}` | `-1.5 0 200 0.5` |
| `{1, 2}`, `{1}` | zeroes: fewer than four is a refusal, not a partial read |
| `1, 2, 3, 4` | zeroes: the braces are required |
| `nonsense`, `` | zeroes |

Both functions therefore stand on the iOS 6 ones, which makes the port's text
and its tolerance identical by construction, including the precision, which
differs between a 32-bit and a 64-bit `CGFloat`.

## The value and the coder

`+[NSValue valueWithDirectionalEdgeInsets:]` is `+valueWithBytes:objCType:`
with `@encode(NSDirectionalEdgeInsets)`: the value it makes is `-isEqual:` to
one made that way, and its `objCType` is `{NSDirectionalEdgeInsets=dddd}` where
`CGFloat` is a double and `{NSDirectionalEdgeInsets=ffff}` where it is a float.

`-[NSCoder encodeDirectionalEdgeInsets:forKey:]` writes the **string form** as
an object under the key — the archive holds `{1.5, 2, 3.25, 4}` as text, and
the port's archive is byte for byte the same, with secure coding on and off.
`-decodeDirectionalEdgeInsetsForKey:` reads that string back, and a key that is
not there reads as zeroes, since an absent string parses to zeroes.

## Asking a value for insets it does not hold

`-directionalEdgeInsetsValue` on a value that holds something else raises
`NSInvalidArgumentException`, and the reason names three things: the size asked
for, the encoding the value really holds and the size of that encoding -
`Cannot get value with size 32. The type encoded as {CGPoint=dd} is expected to
be 16 bytes` on a 64-bit host, with the same sentence and its own numbers
elsewhere. That refusal comes from `-getValue:size:`, which iOS 11 added
alongside these insets; where the release has it the port calls it, and where
it does not the port measures the encoding with `NSGetSizeAndAlignment` and
raises the same exception itself rather than reading a struct of the wrong size
off the end of the value. The first version of the port did read it, and
answered a point's two numbers as the first two insets; the second pass against
the current implementation found that too.

