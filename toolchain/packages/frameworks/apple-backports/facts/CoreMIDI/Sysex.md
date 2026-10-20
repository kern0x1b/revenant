# SysEx of Universal MIDI Packets, as MIDI 1.0 bytes and as sends (iOS 17)

## MIDIEventPacketSysexBytesForGroup

The function returns the MIDI 1.0 bytes of the SysEx a packet holds on one group. Measured on macOS on 2026-10-09 by
`tests/backports/host/coremidi/oracle/sysexbytes.m` (recorded in `sysexbytes-macos.txt`), and held to the port by
differential.m (check_sysex_bytes_for_group, 8 answers, and check_sysex_long, 2):

- A complete message (status 0) is `F0`, the data and `F7`: `30030102 03000000` gives `F0 01 02 03 F7`.
- A start (status 1) is `F0` and its data, with no `F7`: `30160102 03040506` gives `F0 01 02 03 04 05 06`.
- A continue (status 2) is its data alone: `30260708 090A0B0C` gives `07 08 09 0A 0B 0C`.
- An end (status 3) is its data and `F7`: `30310D00` gives `0D F7`; an end of no data is `F7`.
- A group other than the packet's answers paramErr (-50) and no data. A word that is not SysEx does the same, and so does
  a group of 15 when the packet is on group 0.
- A packet of twelve complete messages of six bytes gives 96 bytes, and a start, ten continues and an end of six bytes each
  give 74 bytes, `F0`, the data 01 to 48 and `F7`: the whole SysEx, not the first 63 bytes. The buffer the port fills is
  sized from the packet's word count, so a packet of any length is answered in full.
- The result is a new CFData, which the caller releases.

The port reads the packet's first word and the SysEx messages that follow it on the same group, and stops at the first word
that is not a SysEx on that group. The measured packets are single messages, twelve complete messages, and one SysEx of 66
bytes spread over twelve words; a packet mixing a SysEx with another message type is not measured.

## MIDISendUMPSysex and MIDISendUMPSysex8

Measured on macOS on 2026-10-09 (`tests/backports/host/coremidi/oracle/umpsysend.m`, recorded in `umpsysend-macos.txt`):

- The words of the request reach the destination unchanged, for a SysEx7 and for a SysEx8, to a 1.0 destination and to a 2.0
  destination alike: `30030102 03000000` and `50010102 03040506 07080000 00000000` arrive as they were sent.
- After the call the request's word count is 0 and it is complete; its completion procedure runs once.
- The answer is noErr for every destination, including 0 (no destination): the completion still runs, and nothing arrives.
- A word count of 0 delivers nothing and completes.
- A word that is not SysEx is sent as it is (a note word reached a 2.0 destination verbatim).

What the port does: a destination this process made gets the words verbatim, in its own protocol, delivered on the calling
thread (macOS delivers on its own thread: the one difference). Any other destination is the release's, which carries MIDI
1.0 bytes: a SysEx7 is converted to its bytes (F0 and F7 as the message has them) and sent through the release's
MIDISendSysex, and its completion completes the request. A SysEx8 has no 1.0 form, so it is not sent to a release
destination, and the request completes at once: the one case where the port's answer to a destination differs from macOS,
which sends a SysEx8 to a 1.0 destination verbatim. Facts for the release's own endpoints in another process depend on the
virtual endpoint question in CoreMIDI.md.
