# NFCNDEFPayload and NFCNDEFMessage, the NDEF value classes of iOS 11.0

Two value classes and no radio: a payload is a type, an identifier and bytes, a message is a list of
payloads, and both are made, encoded and parsed without a tag anywhere near them. That is why they are
carried whole while the sessions of the framework are not.

## The decision this revises, and why it was wrong

`registry/CoreNFC/ios11.json` carried both classes as **`absent`**, with the reason

> "a message read from a tag has no tag to come from on a release with no NFC hardware"

**That reason does not reach these two classes.** A 4S and an iPad 2 have no NFC radio — that is
true, and it is why `NFCNDEFReaderSession` and its delegate are what the framework does not carry, and
those two rows are untouched. But a `NFCNDEFMessage` is not *read from a tag*: it is a value, and
`+ndefMessageWithData:` reads the bytes an application already has (a test vector, a file, a payload it
built), while `-initWithNDEFRecords:` and `-initWithFormat:…` make one. Neither direction touches a
radio, so the hardware wall stops at the session and the values are carried, and the twenty rows of
`registry/CoreNFC/ndef.json` are the code that makes the revision true.

The same shape as the CoreData iCloud rows: a true statement about the release, applied to an API it
does not reach.

## The record shape is the specification's, written out

`RevenantNDEF.h` and `RevenantNDEF.m` in this directory are the NFC Forum NDEF Technical Specification's
record, not a description of it: the header byte with MB, ME, SR, IL, TNF and CF; a one-byte type
length; a payload length of one byte when SR is set and of four when it is not; **the ID length byte
exactly when the header's IL says the field is there**, whatever length that byte names; then the type,
the ID and the payload. `RevenantNDEFRecordLength` answers **0** when a field is wider than the
one-byte length fields can say, so a record that cannot be written is refused rather than truncated,
and `RevenantNDEFRecordDecode` answers 0 for bytes that are not a whole record of the length they claim.
The URI RTD's 36-entry prefix table and the text RTD's status byte (its top bit the encoding, its low
six the length of the language code) are the same source's.

Three things were got wrong the first time and are worth writing down, because all three are the
specification being *read* rather than assumed:

1. **IL is a header bit, not a consequence of the identifier's length.** A record with no ID carries no
   ID length field, and the parser has to answer **nil**, not an empty `NSData` — an empty one makes the
   encoder write the field back and the round trip weigh a byte more than the bytes it was given. That
   was the cause of two of the three defects the differential found.

   The encoder follows the same rule from the other side: it writes the ID field **only when the identifier
   has bytes**. The host's CoreNFC writes a record whose identifier is an empty `NSData` with IL clear, three
   bytes for the empty record (the default message of an NSUserActivity, tests/backports/host/nfc-activity),
   and a one-byte identifier with the field, five bytes. The port wrote the field for any non-nil identifier,
   four bytes for that record, until the fix that this paragraph records; `tests/backports/host/corenfc` checks
   the three-byte record.
2. **The long path's four payload-length bytes come straight after the type length**, and the ID length
   follows them, not the type. A record whose IL is clear and whose type then begins with a zero reads
   as one record with the wrong type: the reader lands one byte early and the next record's type comes
   back as the first record's own type with a leading NUL.
3. **The chunk marker is written in one place.** The payload object carries the bytes of a chunk and
   never the marker; the renderer puts the marker as the first byte of the payload; the parser reads
   that byte back, opening a group on `0x00` in a well-known record and continuing on the number that
   follows. A payload object that also carried the marker would mark every chunk twice.

## What the differential is, and what it found

`tests/backports/host/corenfc` compiles the port's own sources and asks them. **There is no host
framework to compare with**: macOS has no CoreNFC — every declaration of `NFCNDEFPayload.h` and
`NFCNDEFMessage.h` is `API_UNAVAILABLE(macos)` — so the test's include path carries a transcription of
the SDK 16.4 declarations (`tests/backports/host/corenfc/CoreNFC/CoreNFC.h`) and the oracle is the
record shape above, written out as byte vectors.

    checks=39 failures=0

Green: the text vector `E2 01 08 54 02 65 6E 48 65 6C 6C 6F` reads back field by field with its
language and its length; the well-known URI vector `E2 01 0C 55 01 "example.com"` reads back as
`http://www.example.com` through the prefix table; a 300-byte media record with the four-byte length
field and the ID field present and empty parses into itself and the record after it; a message the
port builds weighs exactly what the vector weighs and reads back as the same payload; a ten-byte
payload chunked by four is three records of 4, 4 and 2 bytes, each numbered by the marker its payload
begins with, the continuations carrying no type and no ID of their own, and the group reads back as the
ten bytes it was; a record that does not add up ends the message and is not repaired; both classes
survive secure coding with their records.

**The mutation is demonstrated**: `sh tests/backports/host/corenfc/run.sh --mutated` flips one byte of
the text vector's payload length and the run reports a different set of failures (4), so the test is
able to fail and is not guarding a constant.

The vectors are the specification's own worked example (the text RTD's "Hello" in English) and a
well-known URI, written out from the field rules; **libndef's vectors were not used** — the URLs
available to this band returned 404, and a vector nobody has read is not a vector. That makes the
oracle the specification and this test's own arithmetic, which is a weaker second source than a second
implementation, and it is said here rather than implied.

## What it does not do

It reads and writes NDEF. It does not talk to a tag, open a session or find one, and nothing on this
port ever does: `+NFCNDEFReaderSession readingAvailable` is NO and a session that is begun is
invalidated with `NFCReaderErrorUnsupportedFeature`, which is the framework's own wording for "Core NFC
is not supported on the current platform". The sessions of the framework are the next delivery
(`registry/CoreNFC/ios11.json` keeps the rows for the session and its delegate as they are).
