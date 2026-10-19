# MIDI 1.0 and 2.0 translation, as macOS CoreMIDI does it

The release has MIDI 1.0 bytes only, so a port that is made for Universal MIDI Packets converts both ways. Each rule
below is one macOS CoreMIDI was measured to apply, through virtual endpoints on this host (macOS, arm64) on 2026-10-09;
the measurements are the lines of the oracle's output, `tests/backports/host/coremidi/oracle/batch.m`, and the probes
recorded beside them. `CharonCoreMIDI.c` implements the rules and `tests/backports/host/coremidi/run.sh` holds it to
them: every one of the 896 recorded 1.0 to 2.0 answers and of the 106 880 recorded 2.0 to 1.0 answers (the 65 536 velocities,
the 32-bit values and the rest of that batch), read from the recorded files at run time, and the probes. Nothing here is taken from the 26.2 headers, which say what a value means and not how a
conversion rounds.

## 1.0 to 2.0 (a 2.0 port receiving a 1.0 packet)

- Each source connected to a port has its own parser: the SysEx and the running status of one source's bytes do not carry into
  another source's (CharonMIDIPorts.m, keyed by the source's connection reference). The measured fact behind it is the
  legacy input port's: each source's bytes come out as their own packets, unchanged (oracle/inputport-sources.m,
  inputport-sources-macos.txt). The UMP input port's state is not measured. The per-source parser is the reading that two byte
  streams are two streams; differential-ports.m checks that a SysEx open on one source is ended by that source's own F7, with
  the expectation written as each source's own translation, not as a measured UMP answer.
- A channel message keeps its status and channel and gains a 64-bit form. The value is scaled up:
  - velocity (note on and note off), 7 to 16 bits: `x << 9` up to 64; above 64, `(x << 9) + 8d + (d >> 3)` with
    `d = x - 64`. Measured for all 128 values.
  - controller, poly pressure and channel pressure, 7 to 32 bits: `x << 25` up to 64; above 64,
    `2^31 + round(d * (2^31 - 1) / 63)`. Measured for all 128 values.
  - pitch bend, 14 to 32 bits (data1 is the least significant byte, data2 the most): `x << 18` up to 8192; above it,
    `(x << 18) + 32d + (d >> 8)` with `d = x - 8192`. Measured at 255 points: the 128 values of data2 with data1 zero
    (which crosses the centre), and the 128 values of data1 with data2 zero. The formula is not measured for every
    14-bit value; it is the one that fits all 255.
  - program change: the program is the top byte of the second word, and no bank is sent.
- A note on with velocity 0 stays a 1.0 word. Measured: `20903C00` goes out as `20903C00`.
- A system common or real-time message is a 32-bit word of message type 1, unchanged.
- A SysEx is a SysEx7 packet of 6 bytes, as the 1.0 stream gives it (see SysEx below).
- Running status: the release never gives a packet with running status (CoreMIDI's documentation: "Running status is not
  allowed" in a MIDIPacket). The parser reads it as a running status; macOS, given such a packet to send, reads a stray data
  byte as a continuation of a SysEx. That difference is in a case the release does not produce, and is not reproduced.
- Measured (probe2, recorded in oracle/probe2-macos.txt), not built: the 2.0 port's answer to a 1.0 RPN sequence (CC 101, 100, 6, 38). macOS combines it into one
  2.0 RPN event (`20B06500 20B06400 20B00600` into `40200000 18000000`); this library sends each controller as its own
  message and does not combine them. A crutch in coordination/crutches.md.

## 2.0 to 1.0 (a list sent or received through a 1.0 endpoint)

- A list sent to a 2.0 destination this process made is not converted: each packet's time stamp and words reach its block as
  they were sent (CharonMIDISend, CharonMIDIPorts.m), so a 2.0 velocity of 0x1234 arrives as 0x1234, which is what macOS's
  own 2.0 destination gives for the same list (differential-ports.m). A 1.0 destination of the library, and a source, still
  take the 1.0 route below.
- A disposed destination of the library takes nothing: its block is not called, from a send or from in-process delivery,
  as macOS gives nothing to a destination after MIDIEndpointDispose (oracle/removal-notify-macos.txt).
- Note on: velocity `max(1, v16 >> 9)`, so a note on of velocity 0 goes out as velocity 1. Note off: `v16 >> 9`.
  Measured for all 65 536 values of note on.
- Controller, poly pressure, channel pressure: `v32 >> 25`. Measured for every 2^19th value of 32 bits and all 128 poly
  pressures.
- Pitch bend: the 14-bit value `v32 >> 18`, sent LSB then MSB (data1, data2). Measured for every 2^18th value.
- Program change: `(word1 >> 24) & 0x7F`. When the bank bit (bit 0 of the first word) is set, bank select goes first, as
  controller 0 with the MSB from bits 15 to 8 of the second word and controller 32 with the LSB from bits 7 to 0, then the
  program change. Measured: `40C00001 05000A03` goes out as `B0 00 0A`, `B0 20 03`, `C0 05`.
- Registered and non-registered parameters (opcodes 2 and 3): the controllers that select the parameter, 101 and 100 for
  RPN, 99 and 98 for NRPN, are sent only when the parameter differs from the last one this endpoint sent on the channel.
  Then controller 6 carries `v32 >> 25`, and controller 38 carries `(v32 >> 18) & 0x7F` only when that is not zero.
  Measured in one sequence on one destination (probe2 and probe4, recorded in oracle/probe2-macos.txt and probe4-macos.txt): RPN 0,0, then NRPN 1,35, then RPN 0,0 again, then the
  same RPN with a new value, and the values 0, 0x00800000, 0x02000000, 0x02000001, 0x00000001, 0x01000000, 0x04000000,
  0x3F000000, 0x40000000. Whether the state is kept per destination or per port is not measured; it is kept per
  endpoint here.
- Messages with no 1.0 form produce nothing: per-note pitch bend (opcode 6), per-note management (15), the assignable
  per-note controller (1), the per-note registered controller (0), relative RPN (4) and relative NRPN (5). Measured for
  each of them: no packet at all. The attribute type of a note (bits 7 to 0 of the first word) is ignored: a note on with
  attribute type 1 or 2 goes out the same as one without.
- System common and real-time messages are sent as their bytes, and a type 1 word that is not one of them is not sent: measured
  on macOS (oracle/ump-invalid-system.m, ump-invalid-system-macos.txt), F0, F4, F5, F7, a bare data byte and a channel status
  with no data (10900000) are sent as nothing, and F1, F2, F6, F8 and FE as their bytes (F3 and F9 to FF follow the same rule,
  not measured). A SysEx is sent from its SysEx7 packets: F0 before a start
  or a complete message, F7 after an end or a complete message, and the data bytes of each packet.
- Not sent: SysEx8 and mixed data (types 5 and 13 to 15), flex data, the UMP stream and utility messages. The 1.0 side
  cannot carry them. Their handling in macOS was not measured.

## 2.0 sources and the 2.0 input ports connected to them (a measured gap)

A 2.0 list sent to a 2.0 DESTINATION this process made reaches the destination's block as it was sent (CharonMIDIPorts.m,
charon_deliver_2_0; checked against the release's own 2.0 destination in differential-ports.m). The same is not true of a 2.0
SOURCE and the 2.0 input port connected to it: `MIDIReceivedEventList` on a source converts the list to MIDI 1.0 bytes and hands
them to the release's `MIDIReceived`, and the port's read procedure converts them back, so a 16-bit velocity is cut to 7 bits and
spread again.

Measured, with a note on of velocity 0x1234 (`40903C00 12340000`) sent from a 2.0 source to a 2.0 input port connected to it:

- macOS, the release's own source and port (differential-ports.m, "the release's own 2.0 source gives its 2.0 input port the
  0x1234 velocity as sent"): `40903C00 12340000`, as sent.
- the library's source and port, on the host (the same run, the line it prints beginning "known gap"): velocity 0x1200.
- the library's source and port on the emulated 6.1.3 (tests/backports/emulate/coremidi/app/main.m, built with
  CHARCOREMIDI_PROBE=1; `MIDIReceivedEventList status 0, arrived 1, protocol 2, 2 words: 40903C00 12000000`): velocity 0x1200.

Why it is not built natively. The library would have to know which input ports are connected to a source, and nothing it can
read says so:

- The connection is made by the release's own `MIDIPortConnectSource`. The port cannot replace a function the release exports
  (`modules/apple/backports.lua`'s `band()` drops a port object whose symbols the release exports, and `attach.c` interposes
  Objective-C classes and categories only: facts/VideoToolbox/PixelRotationSession.md measures the same wall for
  `VTSessionSetProperty`). `MIDIPortConnectSource` and `MIDIPortDisconnectSource` are the release's own on every band.
- The release shows no connection. On the emulated 6.1.3, `MIDIObjectGetProperties` of a 2.0 source before and after
  `MIDIPortConnectSource` lists the same three keys (`uniqueID`, `protocol`, `name`), and that of the input port the same one
  (`name`), connected or not (the probe's "properties status 0" lines). MIDIServices.h has no call that lists a port's sources.
- The release calls a port's read procedure with the bytes and the connection reference the application gave; the call names no
  source, so a 1.0 packet cannot be matched to the 2.0 list it came from without a guess (the same bytes can come from two
  sources, and the port may not be connected to the one that sent them).

What it costs: a 2.0 source's values above 7 bits are cut on the way to a 2.0 input port; a 2.0 destination of the library is
not affected, and neither is a 1.0 port. A crutch (coordination/crutches.md, "CoreMIDI 2.0 source to 2.0 input port").

## SysEx

A SysEx of six data bytes or fewer is one complete packet (status 0). A longer one is a start of six, then continues of six,
then the end (status 3), with the last chunk held back until the next byte or the F7 arrives, so a SysEx of exactly six
bytes is complete, as measured: 6 bytes give `30060102 03040506`, 7 bytes give a start `30160102 03040506` and an end
`30310700 00000000`, 12 bytes give a start and an end of six `30360708 090A0B0C`. An empty SysEx is `30000000 00000000`.

- A SysEx split over two packets of one list is one message: `F0 01 02` and `03 04 F7` give `30040102 03040000` (complete).
- A real-time byte inside a SysEx sends the SysEx so far first. Measured: `F0 01 F8 02 F7` gives `30010100 00000000`
  (complete, one byte), then `10F80000`, then `30310200 00000000` (end). `F0 01 F8 F7` gives `30010100 00000000`,
  `10F80000`, `30300000 00000000`. A chunk after an earlier one is sent as a continue (status 2): that case is not measured.
- A SysEx still open at the end of a list sends what it holds as a start (`F0 01 02` gives `30120102 00000000`), and stays
  open for the next list, as the port's parser does across callbacks.
- Measured and not reproduced: a 13-byte SysEx (`F0` then 1 to 13, then `F7`) came back as a start of six, a continue of
  six and two zero words, with the thirteenth byte missing. The translation writes the end of it, as the spec does. This is
  a CoreMIDI behaviour on macOS, and the difference is not chosen for the port.

## Reproducing the measurements

`tests/backports/host/coremidi/run.sh` runs the differential against the recorded answers. The recording itself is
`tests/backports/host/coremidi/oracle/batch.m` (run it on macOS: `batch down` and `batch up`), and
the differential reads the two recorded files (`oracle/batch-up.txt`, `oracle/batch-down.txt`) itself: no header is generated from them.
