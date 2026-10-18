# AudioToolbox's functions, first batch: eight functions, iOS 7 to 15

Carried in `libAVFAudioBackports.dylib`. The registry is `registry/AVFAudio/iosaudiotoolboxfunctions.json`. The sources are
`AVFAudio/AudioToolboxFunctions7.m`, `AudioToolboxFunctions9.m`, `AudioToolboxFunctions11.m` and `AudioToolboxFunctions15.m`, named by
the release that introduced each function. The release this port runs on (iOS 6.1.3, armv7) exports none of them
(`tools/image-exports.lua 6.1.3 armv7`).

The oracle is the host's own function of the same name, called through `dlsym` with the same inputs. The host test is
`tests/backports/host/audiotoolbox-functions/functions.m`, and `functions.sh` runs it. Its last line is
`checks=audiotoolbox-functions failures=0`. Each port definition is compiled under a `CharonTest` name, so the host's symbol and the
port's sit in one process. Two mutations were run on purpose: the last-active time as 1 and the unknown-extension status as 0. The
test failed on both (5 FAIL lines), and the sources were reverted.

## iOS 7: `AudioComponentGetLastActiveTime`, `AudioOutputUnitGetHostIcon`

`AudioComponentGetLastActiveTime(comp)` answers the host's time for the component. The host answers 0 for the generic output
component before it is used, and still 0 after it is instantiated and initialized (`probe2.m`, and the test's
`checkLastActive`). The port answers 0 for every component, since it keeps no record of use. Not measured: the answer after a
render has run, and the answer for a `NULL` component.

`AudioOutputUnitGetHostIcon(au, size)` answers the icon of the application hosting the unit. The host answers nil for the generic
output instance at size 32. The port hosts every unit in its own process, so it has no host application icon to return: nil for
every unit. The function's return type is `UIImage *`, which only iOS has, so the port's definition is compiled for iOS only. The host
test prints the host's answer and does not compile the port's definition.

## iOS 9: the sound completions, `AudioComponentInstantiate`

`AudioServicesPlaySystemSoundWithCompletion(sound, block)` and `AudioServicesPlayAlertSoundWithCompletion(sound, block)` call the
block after the sound. The release's way to know when a sound ends is `AudioServicesAddSystemSoundCompletion`, which calls back on
the run loop it is given. The host refuses that registration: it answers -1500 for valid sound IDs (1104) and for an invalid one
(0xFFFFFFFF), before and after the sound is played (`probe5.m`, `probe6.m`). For the host's own completions, the block runs once on a
background thread (not the main thread), 0.000 to 0.001 s after the play call returns, for a valid and an invalid sound ID and for
both the system and the alert form (`probe7.m`, and the test's `checkSoundCompletions`).

The port tries the release's registration first, and runs the block when the sound ends (on the main run loop, where the release
calls back). If the release refuses the registration, the block runs on the default-priority global queue at once, which is what
the host does. Both paths are in `AudioToolboxFunctions9.m`. On the host the refusal path is the one taken, so the host test
covers that path only. The release's path is not run here: on the device it is a behaviour the host does not reproduce, and it has
no host measurement.

`AudioComponentInstantiate(component, options, handler)` calls the handler with an instance and status 0 for a component. The host
calls it on the calling thread, before the call returns; the test measures that the handler runs on the main thread when the call is
made there, and before the call returns. For no component, the host answers no instance and status -3000
(`CharonAudioComponentNoComponentStatus`; the iOS SDK names no constant for it). The options choose out-of-process loading on the
host. The port loads every unit in its own process, so it does not use them. A `NULL` handler is not called: the host's answer to a
`NULL` handler is not measured.

## iOS 11: `AudioUnitExtensionCopyComponentList`, `AudioUnitExtensionSetComponentList`

The host answers `'bnd?'` (0x626E643F, 1651401791) for `AudioUnitExtensionSetComponentList` whatever the identifier and the list: an
unknown identifier with an empty list, the same identifier with one component description, and a `NULL` identifier all give that
status. `AudioUnitExtensionCopyComponentList` answers `NULL` for an unknown identifier, for a `NULL` identifier, and still after a set
(measured `probe2.m` and `probe7.m`). The port can register no app extension, so no identifier is known to it, and it gives the same
answers for every identifier.

## iOS 15: `MusicDeviceMIDIEventList`

`MusicDeviceMIDIEventList(unit, offset, list)` sends each Universal MIDI Packet message of the list to the unit, in order: a complete
system-exclusive message to `MusicDeviceSysEx`, and every other message to `MusicDeviceMIDIEvent` at the offset. The port walks the list
with `CharonForEachMIDIMessage` (`AVFAudio/CharonMIDIEventList.h`), the walk the instrument's `sendMIDIEventList:` already uses.

The host test renders the sampler after each list, from a fresh engine with the General MIDI bank, and compares the port's render with
the host's bit for bit, and their statuses. Five lists: a MIDI 1.0 note on, a MIDI 2.0 note on at velocity16 0x8000 and at 0xFFFF,
a MIDI 1.0 note on followed by a MIDI 2.0 control change 7 at 0xFFFFFFFF, and the same note followed by a MIDI 2.0 pitch bend at
0xFFFFFFFF. Each host render is not silent. The conversions the sampler cannot hear (note off velocity, the pressures, the program
change, the system and sysex messages) follow the UMP definition, as `facts/AVFAudio/AVAudioUnitMIDI.md` says.

## Not in this batch

`AudioComponentGetIcon`, `AudioComponentCopyIcon`, `AudioComponentCopyConfigurationInfo`, `AudioOutputUnitPublish`, the two sound bank
functions, `AudioWorkIntervalCreate`, the two `AudioQueue...WithDispatchQueue` functions, the `AudioConverter` functions, the
`AudioFile` functions, and the two `AudioComponentValidate` functions are the other rows of the round. They are in their own
batches with their own facts.
