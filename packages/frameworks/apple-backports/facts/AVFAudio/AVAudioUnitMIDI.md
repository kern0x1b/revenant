# AVAudioUnitMIDIInstrument, and a correction

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), over the release's own MusicDevice
send API. Thirteen methods, 15 registry entries.

## The correction

An earlier report of this band said the release "exports no function that sends a MIDI event to an
audio unit" and refused the class. **That was wrong**, and the way it was wrong is the useful part: the
check that produced it grepped the `AudioUnit*` prefix and read the head of a truncated `_AU*` listing.
The coordinator's challenge — "on iOS the AudioUnit functions live in AudioToolbox's exports, not under
an `AudioUnit*` prefix; grep for `_MusicDevice`" — is what found it.

The measurement, over the **whole** of AudioToolbox in the 6.1.3 armv7 cache and then over all 580
libraries of it:

```
$ python3 -c "
import json
d = json.load(open('/tmp/all6.json'))
at = [v for k, v in d.items() if k.endswith('AudioToolbox.framework/AudioToolbox')][0]
print('AudioToolbox exports:', len(at))
print([e for e in at if e.startswith('_MusicDevice')])"

AudioToolbox exports: 337
['_MusicDeviceMIDIEvent', '_MusicDeviceStartNote', '_MusicDeviceStopNote', '_MusicDeviceSysEx']
```

and the same file shows the whole of the 37 `_AU*` exports is `AUGraph*` (29) and `AUPB*` (8) — no
`AUEventDispatcher*`, which is a separate thing and is not needed here.

`MusicDevice.h` of SDK 16.4 documents them as send functions, all `API_AVAILABLE(ios(5.0))`:

- `MusicDeviceMIDIEvent(inUnit, inStatus, inData1, inData2, inOffsetSampleFrame)` — "Used to sent
  MIDI channel messages to an audio unit", `inUnit` "The audio unit", the data bytes "exactly as
  described by the MIDI specification, including the combination of channel and command in the status
  byte".
- `MusicDeviceSysEx(inUnit, inData, inLength)` — "used to send any non-channel MIDI event to an audio
  unit… the complete MIDI SysEx message including the F0 and F7 start and termination bytes".
- `MusicDeviceStartNote(inUnit, inInstrument, inGroupID, outNoteInstanceID, inOffsetSampleFrame, inParams)`
  and `MusicDeviceStopNote(inUnit, inGroupID, inNoteInstanceID, inOffsetSampleFrame)` — the extended
  note API. The header's own rule: "To stop a note it must be stopped with the same API group as was
  used to start it."

## What each method calls

- `startNote:withVelocity:onChannel:` calls `MusicDeviceStartNote` and **keeps the note instance it
  returns**, so `stopNote:onChannel:` calls `MusicDeviceStopNote` with the same instance, as the
  header requires. A release that answers the extended call gets the extended pair; one that does not
  falls back to the MIDI note-on and note-off events, which the same header documents as the other
  legal way ("(1) the MIDI Note on event (MusicDeviceMIDIEvent) — notes must be stopped with the MIDI
  note off event").
- The four channel messages, both `sendMIDIEvent:` forms, and the two program-change forms are
  `MusicDeviceMIDIEvent` with the status byte the MIDI specification gives each message, channel in
  the low nibble. A 14-bit pitch bend is the low seven bits in `inData1` and the high seven in
  `inData2`. A banked program change is the two bank-select controller events and then the program
  change.
- `sendMIDISysExEvent:` is `MusicDeviceSysEx` with the whole block, F0 and F7 included.
- `inOffsetSampleFrame` is `0` throughout, which is what the header says to pass when not scheduling
  from the unit's render thread: these methods are called from the host's thread, not from a render
  callback.

## The initializer

`-initWithAudioComponentDescription:` (`introduced` 8.0) is declared on both SDKs the same way:
nonnull, under `AVAUDIOUNIT_HAVE_AUDIOUNIT` (`AVAudioUnitMIDIInstrument.h:36` of iOS SDK 26.2 and of
macOS SDK 27.0). The header says the description is for an AUv2 unit of type
`kAudioUnitType_MusicDevice` or `kAudioUnitType_RemoteInstrument`, and that an AUv3 unit goes through
`instantiateWithComponentDescription:options:completionHandler:`. The header says nothing about a zero
type or manufacturer.

**Port choice, not Apple behaviour:** when `componentType` is 0 the port uses `kAudioUnitType_MusicDevice`,
and when `componentManufacturer` is 0 it uses `kAudioUnitManufacturer_Apple`. The override calls the
AVAudioUnit hook (see `RevenantAVAudioUnit.h`), and never returns nil: `NSObject`'s `init` does not fail,
so the nonnull declaration holds for every description.

## The list form

`-[AVAudioUnitMIDIInstrument sendMIDIEventList:]` (iOS 16) is **implemented**, and it is not
`MusicDeviceMIDIEventList`, which this release does not export. The list is walked in order by
`RevenantForEachMIDIMessage` (`AVFAudio/RevenantMIDIEventList.h`), and each message goes to the release's own call:
a MIDI 1.0 message to `MusicDeviceMIDIEvent`, a complete system-exclusive message to `MusicDeviceSysEx`.

- **Type 1** (system common and realtime): the status and the data bytes its status takes. Not observed on the host's
  sampler, which ignores system messages (the reset, `0xFF`, is not seen either, with type 1 or type 2).
- **Type 2** (MIDI 1.0 channel voice): the bytes as written.
- **Type 3** (SysEx7): packets are joined (start, continue, end; complete alone) into one `F0 ... F7` message, which goes
  to `MusicDeviceSysEx`. A message not complete within the list is not sent. Not observed on the host's sampler, which
  ignores the universal sysex it was given (master volume, master tuning, GM on, GS reset).
- **Type 4** (MIDI 2.0 channel voice, two words), converted to MIDI 1.0. Measured bit for bit on the host's sampler
  (`tests/backports/host/avfaudio/midi-host.m`, `checks=host-midi-equivalence failures=0`), each against the type-2
  message the rule gives:
  - note on: velocity = max(1, velocity16 >> 9). Measured at 0xFFFF (127), 0x8000 (64), 0x7FFF (63), 0x0100 (1),
    0x0001 (1), 0xFE00 (127), 0x3F00 (31), 0xC000 (96) and 0 (1, so a velocity of 0 is not a note off);
  - control change: value = value32 >> 25. Measured on controller 7 at 0xFFFFFFFF (127), 0x80000000 (64), 0x40000000 (32),
    0x7FFFFFFF (63) and 1 (0). Other controllers are the same rule, not measured;
  - pitch bend: 14-bit value = value32 >> 18, low seven bits then high seven. Measured at 0xFFFFFFFF (16383), 0 (0),
    0xC0000000 (12288) and 0x80000001 (8192).
  - Not observable on the sampler, so the UMP rule is what the port sends: note off velocity (velocity16 >> 9, no
    minimum); poly pressure and channel pressure (value32 >> 25). The sampler ignores MIDI program changes, type 2 or
    type 4, so the program change (bank MSB and LSB as controls 0 and 32 when the bank-valid bit is set, then the program
    from bits 31-24 of the second word) is the UMP rule too.
  - Dropped, with no MIDI 1.0 single-message form: the registered and assignable controllers, the per-note forms and the
    relative forms (opcodes 0, 1, 2, 3, 4, 5, 6, 7, and 0xF).
- Types 0 and 5 to 15 are not sent.
- A `NULL` list sends nothing.

`tests/backports/host/avfaudio/midilist.sh` runs the walk over one list per case (26 checks: type 2, the type 1 system
messages, the type 4 scalings and program change, the type 3 joins and the cases that must send nothing), against bytes
written out by hand from the UMP definition. Its one-to-one check with the host is `midi-host.m`, which renders the
host's sampler for each type-4 message and its type-2 equivalent and compares the renders bit for bit.

## What is still not carried

The note-control half of the sampler (`startNote:velocity:channel:` and its kin on `AVAudioUnitSampler`) is the
sampler's own instrument interface, and it is not in this file's scope; `AVAudioUnitSampler.md` says what the
sampler carries.
