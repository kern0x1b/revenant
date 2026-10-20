# MIDIEventListForEachEvent, as macOS hands the visitor each message

MIDIEventListForEachEvent (iOS 15) calls a visitor with each Universal MIDI Packet of an event list, as a
MIDIUniversalMessage of 28 bytes. The header fixes the fields; the measurements below fix what macOS CoreMIDI puts in
them where the header is silent. Measured 2026-10-09 on this host by `tests/backports/host/coremidi/oracle/visit.m` and
`visit-jr.txt`; the bytes are in `visit-expectations.h`, which run.sh generates into its build folder from those recordings with
`oracle/visit-expectations.lua` (no copy is committed), and differential.m (check_visitor)
holds MIDIUniversalMessage's defined bytes to them: 38 messages, all equal.

Measured:

- Channel voice 1.0, system common, SysEx7 and channel voice 2.0 messages are parsed to the header's fields, at the offsets
  `offsetof` gives on macOS (type 0, group 4, status 8, channel 12, data from 16). The one exception is 14-bit pitch bend,
  which is stored in the 16-bit field at 16, LSB first.
- A program change's bank is the 14-bit value `(MSB << 7) | LSB`: `programChange.bank` of `40C00001 05000A03` is 0x0503.
- A utility message (type 0 in the header, status 1 or 2) has group 0xFF, not its word's group. The jitter clock is the low
  byte of the word's 16-bit field: `00100ABC` gives 0xBC, `0010FFFF` gives 0xFF, `00100001` gives 1 (visit-jr.txt).
- A utility NOOP (`00000000`) is not a utility message: it arrives as type 0xFF, group 0xFF, its word at offset 8.
- A real-time system message (F8 to FF) arrives as type 0xFF with its group from the word and its word at offset 8.
- A word of a type the header does not name (6 and 7, 8 to 0xC, 0xD and 0xF) arrives as type 0xFF, group 0xFF, its words at
  offset 8. Measured for 0x60 (type 6), 0xD0 (flex data) and 0xF0 (UMP stream) as the bytes of one event.
- The word sizes the visitor and the translation use (RevenantMIDIUMPWordCount): 1 for types 6 and 7, 2 for 8, 9 and A, 3 for B
  and C, 4 for D, E and F. Measured on macOS 27.0.1 (oracle/visit-sizes.m, visit-sizes-macos.txt) by where the next
  recognisable word begins: a packet of a type's word then a NOOP, a system clock and a note on gives 4, 4, 3, 3, 3, 2, 2 and
  1 events for types 6, 7, 8, 9, A, B, C and E. The lone-word probe of types 8 to 0xE overran the packet and was killed (the
  visitor reads past the packet end on macOS); the library's visitor checks the remaining words instead.
- A SysEx8 stream (type 5) arrives with type 5, its status at 8, byte count at 12, stream ID at 13, and its data at 14
  copied from byte 3 of the first word: the data is the bytes of the words from there, not the bytes the header's layout
  puts first. Measured on one stream (`50010102 03040506 07080000`); it is reproduced as measured, and a second stream is not
  measured.

Not measured, so not claimed: a SysEx8 stream of more than one packet, and the mixed data set (status 8 and 9 of type 5),
which takes the SysEx8 rule as written here.

`MIDIVisitor15.m` implements these rules. It parses a word only where the word is complete in its packet, and a packet
whose words end short stops there, as CoreMIDI's own visitor stops on a short message.
