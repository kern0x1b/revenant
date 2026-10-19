# NSData: base64, byte ranges and a buffer that is not copied, iOS 7

Source: the host's own Foundation, asked case by case, and the differential run of
`tests/backports/host/foundation2/run.sh`, which encodes every length from 0 to 80 bytes under eighteen
combinations of options, decodes a corpus of well formed and malformed input, and compares every answer
with the system's.

## Encoding

`-base64EncodedStringWithOptions:` and `-base64EncodedDataWithOptions:` answer the same text, one as a
string and one as its ASCII bytes. Empty data answers an empty result, not nil.

A line length option wraps the output, and the line ending is `\r\n` unless it is asked to be otherwise:
`64CharacterLineLength` alone already ends its lines with a carriage return and a line feed.
`EndLineWithCarriageReturn` on its own makes them `\r`, and asking for both endings gives `\r\n` again.
A line ending option without a line length does nothing at all - there are no lines to end. Asking for
both lengths at once also does nothing: neither wrapping happens. No line ending is added after the last
line.

## Decoding

`-initWithBase64EncodedString:options:` and `-initWithBase64EncodedData:options:` answer nil for anything
that is not base64: a space or a newline in the middle is enough. An empty string answers empty data rather
than nil. `NSDataBase64DecodingIgnoreUnknownCharacters` drops everything outside the alphabet and the
padding before reading, so `QU JD` becomes the three bytes `41 42 43`.

What they do with the padding sign is Foundation's own decoder, the Objective-C method
`-[NSData(NSData) _decodeBase64EncodedCharacterBuffer:length:options:buffer:bufferLength:state:]` that
`-_initWithBase64EncodedObject:options:` hands every range to - a selector the Foundation of iOS 7.0, 9.0,
12.0 and 18.0 all carry. It is not the decoder of Swift's `Data`, which the same host answers differently
with: `QQ==QQ==` is `41` there and `41 00 00 41` here. Read from its instructions:

- the characters are taken four at a time, `=` counting as a character whose value is 0, into an
  accumulator that is shifted by six and never cleared; a group gives the low eight bits of the
  accumulator shifted right by 16, by 8 and by nothing;
- a group with three `=` in it fails the whole string, and the characters left over at the end must make
  no incomplete group;
- a group with no `=` gives three bytes. A group with `=` gives three bytes too, unless nothing but `=`
  (and, when unknown characters are ignored, characters outside the alphabet) follows it anywhere in the
  string: then it gives two for one `=` and one for more;
- without the option a character after a `=` inside a group fails, and after the first group with `=` in
  it the decoder stops, so the rest may be `=` and nothing else: `QQQ==` is `41 04` and `QQQ=A` is nil;
- with the option the count of `=` starts again at every group, so `QUJD==RA` is `41 42 43 00`,
  `QUI=QUI=` is `41 42 00 41 42` and `=A/A====` is `00 0F 00`.

The backport decodes the same way, and every string of up to eight characters over `Q`, `/`, `=` and an
unknown `!`, with and without the option - 174762 of them - answers as the host's Foundation does.

## The other two

`-enumerateByteRangesUsingBlock:` hands the bytes over in as few ranges as the data is stored in: a
hundred thousand contiguous bytes arrive as one range covering the whole length. Setting the block's
`stop` ends the walk.

`-initWithBytesNoCopy:length:deallocator:` takes the buffer as it is and calls the block when the data is
deallocated, with the same pointer and length it was given - it is the block, and not the data, that
frees anything. The block is called even when the buffer is NULL and the length is zero, and that call
happens at deallocation, not before: a data object still alive has not called it.
