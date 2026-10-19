# NSAttributedStringMarkdownSourcePosition

Introduced in iOS 16.0. Where a run of characters in a Markdown-parsed attributed string came
from in the source: four 1-based line and column numbers, the value of the
`NSMarkdownSourcePositionAttributeName` attribute.

Source: the host's own class on macOS 27.0, held against the port by
`tests/backports/host/markdownsourceposition`.

The whole class is carried, because no release this package is built for has any part of it.

## The four numbers

`-initWithStartLine:startColumn:endLine:endColumn:` keeps the four it is given and the four
properties read them back. `-init` is **not** carried: the SDK's header declares only the
four-number initialiser, and the host's class has no `-init` of its own - its own method list is
seventeen methods and `-init` is not among them (measured with `class_copyMethodList`) - so
`[[... alloc] init]` answers NSObject's, which is four zeroes, on both sides.

`-isEqual:` is by all four, `-copyWithZone:` makes a new object of the same class with all four,
and `+supportsSecureCoding` is `YES`.

`-hash` is the one member whose value is not held equal to the host's: the host's is a private
mixing of its own fields (`0` for 2/3/4/5, `3` for 2/3/4/6) and no API fixes the number. What
`-hash` owes is one thing and the port keeps it: two equal positions hash alike. The
differential checks that on both sides and prints the two numbers.

`-description` is

```
<NSAttributedStringMarkdownSourcePosition: 0xADDRESS>{startLine=2, startColumn=3, endLine=4, endColumn=5}
```

and it writes the four **unsigned**, as the host does: a position built with `-2` reads back `-2`
from every property and describes itself as `18446744073709551614`. The port prints them the same
way, which is a `%lu` of the stored value and not a change of type.

## What a column is, and what a range is measured in

Two different units, and the host's own archive says so in keys side by side: the four numbers are
**UTF-8 byte offsets**, and the range `-rangeInString:` answers is in **UTF-16 units**, because a
range into an `NSString` is.

Measured on the host's own archive of a position its Markdown parser put in an attributed string
(`NSStartUTF8Offset`, `NSEndUTF8Offset`, `NSStartUTF16Offset`, `NSEndUTF16Offset` and the two code
point lengths are all keys of that archive):

| the position | the document | byte keys | UTF-16 keys | `-rangeInString:` |
| --- | --- | --- | --- | --- |
| 1/1..1/24 | `a éé two-byte run here\n` (23 characters, 25 bytes) | start 0, end 23 | start 0, end 21, end code point length 1 | `{0, 22}` |
| 1/1..1/7 | `# Title\n` | start 2, end 6 | start 2, end 6, length 1 | `{2, 5}` |
| 1/1..1/26 | `and a face at the end 😀\n` | end names the face's last byte | end offset 22, end code point length 2 | `{0, 24}` |

So a line is one-based and its first byte is the one after the newline before it; a column is
one-based and a byte offset within the line, and for a multi-byte character it is the character's
first byte; the range is `{ the start place in UTF-16, the end place plus that character's width,
minus the start place }`, which is the last character and not the place after it.

The byte a column names is turned into a UTF-16 place by walking the document's bytes, and a byte
**inside** a character is that character's place and that character's width - 2 for a character
above the BMP and 1 for every other. That is the third row of the table, and it is the case a
byte-offset answer gets wrong: `and a face at the end 😀` is 26 bytes and 24 UTF-16 units, so an
answer in bytes is `{0, 25}` where the host answers `{0, 24}`.

## What the host's own answer rests on, and where it does not hold

The host's `-rangeInString:` answers out of a cache of offsets its parser filled when it marked the
run, and the string it cached is the one **its parser read**, which is not always the string handed
to the method. Over twelve documents and the 29 runs the host's parser marks, the two answers are
the same range on 28 and differ on one:

* the CRLF document (`    indented code\r\n    second line\r\n`), where the system's range is
  `{4, 13}` and the backport's is `{4, 30}`: the buffer the system's parser read did not have the
  CRs in it, so its cached offsets count a document seventeen bytes shorter than the one it was
  asked about.

This is measured over the whole corpus of the differential, which prints both numbers for every
case they differ on, and it is why the entry in `coordination/crutches.md` says what it says. The
backport has no cache at all - the eight keys are read and dropped, below - so its answer comes
from the four numbers, and it is the answer the host gives for the twenty-eight positions its own
cache describes correctly.

A position the document does not reach - a line past the last, a column past the line, a column of
zero, a line below one, an end before the start - answers `{NSNotFound, NSNotFound}` on the host
and `{NSNotFound, 0}` in the backport: the backport refuses rather than point into the middle of
the string, which is the one difference in this family that is a decision and not a consequence.
Both answers are printed for twelve such positions by the differential.

The host's own `-startOffsets` and `-endOffsets` - the two private accessors for the six numbers of
a cache - **hang** on a position with no cache, so what the host computes there cannot be read out
of it; the range section above is measured through the positions the host's parser marks, which is
where its cache is real.

## Archiving

`+supportsSecureCoding` is `YES` and the keys are the host's own, twelve of them, so an archive
this class writes is one the host's class reads and the other way round.

| key | value | written with |
| --- | --- | --- |
| `NSStartLine` | the start line | `-encodeInteger:forKey:` |
| `NSStartColumn` | the start column | `-encodeInteger:forKey:` |
| `NSEndLine` | the end line | `-encodeInteger:forKey:` |
| `NSEndColumn` | the end column | `-encodeInteger:forKey:` |
| `NSStartUTF8Offset` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSEndUTF8Offset` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSStartUTF16Offset` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSEndUTF16Offset` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSStartUTF8NextCodePoint` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSEndUTF8NextCodePoint` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSStartUTF16CurrentCodePointLength` | `NSIntegerMax` | `-encodeInteger:forKey:` |
| `NSEndUTF16CurrentCodePointLength` | `NSIntegerMax` | `-encodeInteger:forKey:` |

The last eight are the UTF-8 and UTF-16 places the host works out for itself and caches, the code
point each end starts at and the length of the code point at each end in UTF-16 - the numbers the
range section above reads. It writes them in the state that means "not worked out" -
`NSIntegerMax` - and an archive written from a position nobody has asked for a range of carries all
eight that way. **The host's own Markdown parser does not: it asks for the ranges, fills the cache,
and an archive of one of its positions carries real offsets** (the second and third rows of the
table above). So the eight are a cache with a value in it, and a `0` among them is a real offset
that some other string must never see. The port writes them in the same "not worked out" state so an
archive is the same shape whichever of the two wrote it, and reads them in the same state as the
host does; what it does with them is nothing, because they are offsets into one particular
Markdown string and an archive carries neither that string nor any key naming it, so a decoded
offset has nothing to be checked against. That is why `-rangeInString:` derives the range from the
four line and column numbers.

A position of 2/3/4/5 is 706 bytes in the host's archive (measured).

## The key beside the class

`NSMarkdownSourcePositionAttributeName` is the string `NSMarkdownSourcePosition`, read out of the
running class and held against it by the same differential.
