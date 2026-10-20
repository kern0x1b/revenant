# The UMP and MIDI-CI constants of CoreMIDI, iOS 17 and 18

The constants of iOS 17 (`kMIDIPropertyUMPActiveGroupBitmap`, `kMIDIPropertyUMPCanTransmitGroupless`) and iOS 18
(`kMIDIPropertyAssociatedEndpoint`, the MIDI-CI and MIDI-UMP object keys and notification names) are read from the
host's own CoreMIDI by `tests/backports/host/coremidi/oracle/constants.m`, and the differential
(`tests/backports/host/coremidi/differential.m`, check_constants) holds the port's copies to those readings.

Measured on macOS, 2026-10-10 (`oracle/constants-macos.txt`):

- The three property constants read NULL in a process that has not made a MIDI client, through the linked symbol. After
  `MIDIClientCreate` they are the keys the framework holds:
  - `kMIDIPropertyUMPActiveGroupBitmap` is `active group bitmap`;
  - `kMIDIPropertyUMPCanTransmitGroupless` is `ump endpoint`;
  - `kMIDIPropertyAssociatedEndpoint` is `associated endpoint`.
- The `ump endpoint` value is the framework's key, not a symbol mix-up: a virtual source of this process reads
  `kMIDIPropertyUMPCanTransmitGroupless` back after `MIDIObjectSetIntegerProperty` with the constant as 1 and through the
  literal `"ump endpoint"` as 1; the literal `"UMPCanTransmitGroupless"` finds nothing (-10835). So an application that
  passes the constant gets the key macOS uses, and the port's constant holds the same string. What an endpoint answers for
  these keys is the release's own (MIDIObjectGetIntegerProperty is not replaced): on the emulated 6.1.3 an endpoint answers
  -10835 for each of the three (UMPClasses.md), as a virtual endpoint on macOS does until the key is set.
- A virtual endpoint reports -10835 (property not present) for each of the three until it is set.
- The twelve keys and notifications are their own names: `MIDICIDeviceObjectKey` is `MIDICIDeviceObjectKey`, and so on.

Release: `MIDIConstants17.m` holds the two UMP property constants, `MIDIConstants18.m` the rest, so each file defines the
API of one release. The earlier facts (commit 408967c66) recorded the NULL reads of a process that had made no client as
the answer; that reading is kept above as the "before" value and is not what an application gets after it makes one.
