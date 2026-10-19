# MIDIEventListInit and MIDIEventListAdd: the packet rules, measured

A MIDIEventList is a header of its protocol and its packet count, eight bytes, then packets. A packet is its time stamp
(eight bytes), its word count (four bytes) and its words (four bytes each). The next packet begins after the last word of
this one, which is what `MIDIEventPacketNext` computes. `MIDIEventListInit` sets the protocol, makes the count zero and
returns the first packet's place. `MIDIEventListAdd` takes the list's last packet as `curPacket` (the place `MIDIEventListInit`
returned while the list is empty) and returns the packet it wrote or merged into, which the caller passes to the next add; it
returns NULL when the words do not fit in the buffer the caller gave it, and the list is then as it was. The end of the list is
found from `curPacket` (its place plus 12 bytes plus 4 for each of its words), so a list built add by add is linear: 4.2 times
the time for 4 times the packets (2000 and 8000 packets, 2026-10-10). An earlier version of this file, and the library, took
the end as `curPacket` and returned the end; that was not measured, and made the public add walk the list (16 times the time
for 4 times the packets).

Measured on macOS on 2026-10-09 (probe2 and probe3 in `tests/backports/host/coremidi/oracle/`, recorded in probe2-macos.txt and
probe3-macos.txt; the results are also written in `tests/backports/host/coremidi/differential.m` beside each check):

- Two adds with one time stamp make one packet, with the words of both in order (2 + 2 words make a packet of 4).
- An add with a time stamp different from the last packet's starts a new packet (time stamps 7, 8, 8 make two packets, of
  1 and 2 words).
- An add of zero words writes nothing: the count stays zero and the place is returned unchanged.
- A word count above 64 is kept whole: 65, 70 and 80 words in one packet are accepted. The 64 of the structure's own array
  is not a limit of the builder.
- The buffer is counted in bytes. A list of 40 bytes holds two one-word packets of different times, and five one-word
  words of one time: 8 for the header, 16 for a one-word packet, 4 for each word added to a packet already there. A list of
  64 bytes holds three one-word packets.
- The protocol the caller gives is kept in the header, whatever the words are; the builder does not check them.

Measured on macOS on 2026-10-10 (`eventlistadd.m` in the same folder, recorded in `eventlistadd-macos.txt`; the scenario is
`eventlistadd.h`, and `differential.m` runs it against the library and requires the same lines):

- The first add to an empty list returns the place `MIDIEventListInit` returned (offset 8), the second packet's add returns
  the second packet's place (offset 24), and an add merged into a packet returns that packet.
- An add of zero words returns `curPacket`.
- `curPacket` is trusted as the last packet: an add with the first packet of a two-packet list as `curPacket` and a new time
  stamp writes after the first packet, over the second, and counts three packets. The library refuses a `curPacket` outside
  the buffer or whose word count runs past it (NULL); that case is not measured on macOS.
- On an empty list a packet is written at `curPacket`, wherever that is (offset 40 was written, offset 8 left alone).
- A refused add (a merge or a new packet that does not fit) returns NULL and leaves the count and the last packet's words as
  they were. The sizes are in bytes: a merge needs 28 for one word added to a one-word packet (8 + 12 + 4 + 4), and 27 refuses.

`RevenantCoreMIDI.c`'s `RevenantMIDIEventListAdd` implements these rules, and the two API functions of
`MIDIEventList14.m` call it. The packets it writes are the ones `MIDISendEventList` and the protocol-aware ports read.
