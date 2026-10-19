# AudioToolbox's functions, iOS 7 to 26: 24 implemented, 2 owed

Carried in `libAVFAudioBackports.dylib`. The registry is `registry/AVFAudio/iosaudiotoolboxfunctions.json`. The sources are
`AVFAudio/AudioToolboxFunctions{7,9,10,11,14,15,16,17,18,26}.m`, named by the release that introduced each function. The release this port runs on (iOS 6.1.3, armv7) exports none of them
(`tools/image-exports.lua 6.1.3 armv7`).

The oracle is the host's own function of the same name, called through `dlsym` with the same inputs. The host test is
`tests/backports/host/audiotoolbox-functions/functions.m`, and `functions.sh` runs it. Its last line is
`checks=audiotoolbox-functions failures=0`. Each port definition is compiled under a `RevenantTest` name, so the host's symbol and the
port's sit in one process. Two mutations were run on purpose: the last-active time as 1 and the unknown-extension status as 0. The
test failed on both (5 FAIL lines), and the sources were reverted. The drum bank's MSB changed to 119 fails two checks (2 FAIL lines), and the source was restored.

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
(`RevenantAudioComponentNoComponentStatus`; the iOS SDK names no constant for it). The options choose out-of-process loading on the
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
with `RevenantForEachMIDIMessage` (`AVFAudio/RevenantMIDIEventList.h`), the walk the instrument's `sendMIDIEventList:` already uses.

The host test renders the sampler after each list, from a fresh engine with the General MIDI bank, and compares the port's render with
the host's bit for bit, and their statuses. Five lists: a MIDI 1.0 note on, a MIDI 2.0 note on at velocity16 0x8000 and at 0xFFFF,
a MIDI 1.0 note on followed by a MIDI 2.0 control change 7 at 0xFFFFFFFF, and the same note followed by a MIDI 2.0 pitch bend at
0xFFFFFFFF. Each host render is not silent. The conversions the sampler cannot hear (note off velocity, the pressures, the program
change, the system and sysex messages) follow the UMP definition, as `facts/AVFAudio/AVAudioUnitMIDI.md` says.

## iOS 10: `AudioQueueNewOutputWithDispatchQueue`, `AudioQueueNewInputWithDispatchQueue`

The release's queue calls a C function with a user-data pointer. The port's C callback hands the block to the dispatch queue
(`AudioToolboxFunctions10.m`). The output block runs on the queue it was given, off the main thread, when a buffer has played: the
host's answer, measured with a 2048-byte silent buffer (`functions.m`, `checkQueueDispatch`). The port's callback is a
`dispatch_async`, so the block runs after the callback returns. The input callback's timestamp and packet descriptions are copied
before the block is queued, since the release's pointers are only valid during the callback.

A NULL dispatch queue is `kAudio_ParamError` (-50), the host's answer for the output form (measured). A NULL block is also -50 in
the port; the host's answer for it is not measured. The input form is not run by the test (it needs a microphone), so its block's
thread and timing are not measured.

Each queue made this way keeps one small object for the life of the process: the release holds the callback's user-data pointer
for the queue's life, and the port has no hook for the dispose.

## iOS 16: `AudioComponentValidate`, `AudioComponentValidateWithResults`

The host's answer for the generic output component is passed (result 1), and its `AudioComponentValidateWithResults` dictionary
holds `Result` (1), `WasCached`, `Output` (the auval report, as an array of strings) and `Tests`. The host's answer for a NULL
component is -50 (measured). The port passes a component when an instance of it can be made and disposed at once, and fails it when
the instance cannot be made. The host validates out of process, so its failed answer is not measured here. The port's dictionary
carries `Result` and `WasCached` (NO: the port keeps no cache), and empty `Output` and `Tests`, because the auval report the host
produces is not run by this port. The block runs on a background queue (measured: not the main thread).

## iOS 17: `AudioFileGetUserDataSize64`, `AudioFileGetUserDataAtOffset`

Built on the release's `AudioFileGetUserDataSize` and `AudioFileGetUserData` (`AudioToolboxFunctions17.m`). The host's answers, on a
WAV file with a 10-byte chunk, are the port's, for offsets -1, 0, 2, 6, 8, 10 and 12 and sizes 0, 4 and 32 (the test compares the status,
the size written and the bytes): an offset below 0 is `kAudioFilePositionError` (-40); a size of 0 is `kAudioFileBadPropertySizeError`
('!siz'); an offset at or past the end (10 and 12) is -40. Each of those leaves the size as it was. Otherwise the bytes from the offset
are copied, up to the size asked and the bytes left (offsets 0, 2, 6 and 8). A missing chunk, or index 3, is `kAudioFileInvalidChunkError`
('chk?'), the release's status. The release can read only the whole chunk, so the port reads it in full and copies the part asked for.

`AudioFileGetUserDataSize64` gives the release's size as 64 bits: the host's value for the 10-byte chunk is 10 both ways.

## iOS 18: `AudioConverterNewWithOptions`, `AudioConverterPrepare`

`AudioConverterNewWithOptions` makes the converter `AudioConverterNew` makes, for the same formats. The host gives noErr with no
options and with `kAudioConverterOption_Unbuffered` (measured), and the converters convert the same frames to the same bytes. The
unbuffered option is not enforced, and this is a divergence: the host refuses `AudioConverterFillComplexBuffer` on an unbuffered
converter with `'op??'` (measured). The port's converter is buffered and does not refuse. The test prints the host's refusal and
does not count it.

`AudioConverterPrepare` calls its completion once, with noErr, off the main thread, for flags 0 and 1 (measured). The host prepares its
converter machinery for later creations; the release has nothing to prepare, so the port's preparation is empty. That is the host's
speed-up, which is not reproduced; the status and the thread are the host's.

## iOS 26: the realtime-safe conversion, the dependency conversion, the dependency write

`AudioConverterFillComplexBufferRealtimeSafe` gives the release's conversion for linear PCM on both sides. The host's answer for PCM to
float is noErr, and the port's output is the host's, bit for bit. The host's answer for PCM to ALAC (a non-PCM output) is
`kAudioConverterErr_OperationNotSupported` (`'op??'`, measured), and the port refuses the same conversion with the same status, without
calling the release. Other non-PCM conversions are not measured.

`AudioConverterFillComplexBufferWithPacketDependencies` takes two arrays the release has no use for. The host answers -50 when the
packet-description array is NULL (measured), and -50 when both arrays are NULL (measured); with the descriptions given and the
dependencies NULL it is not measured on its own. With both given, the host's output for PCM is the same bytes, and the host leaves the
dependency array as it was (0x5A sentinel, measured). The host's `kAudioFormatProperty_FormatEmploysDependentPackets` is 0 for PCM and
for AAC (measured), so the host has no dependencies to fill for either. A format that does employ dependent packets is not measured, and
the release has no dependency to fill for such a format either, so the port leaves the array as it was for every format.

`AudioFileWritePacketsWithDependencies` is the release's packet write, with the dependencies ignored. The host's answer for PCM is noErr
and the packet count, with the dependency array NULL and given (measured on a WAV file). A format that employs dependent packets is not
measured.

The three functions of this section are declared in `AVFAudio/RevenantAudioToolboxDeclarations.h`, with the types the 16.4 SDK does not
have (`AudioStreamPacketDependencyDescription`, `AudioConverterOptions`, `AudioConverterComplexInputDataProcRealtimeSafe`). The header
is guarded on `CA_REALTIME_API`, which the iOS 26 SDK defines, so a 26 SDK build does not see the types twice.

## iOS 7: `AudioComponentGetIcon`

The host answers nil for NULL. For the generic output it answers an image of 32 by 32 points at every size asked: 0, 16, 32,
64 and 128 (measured on the macOS host; `functions.m`, `printIcons`). The port returns a blank image of that size for any
component, and nil for NULL. The host's image is the component's own artwork, which the port does not carry, so the pixels
differ. The iOS host's answer for a size is not measured, since the host test runs on macOS. The port's definition is
iOS-only (its return type is UIImage), so the host test prints the host's answers and does not compile the port's
definition. The SDK deprecates the function at iOS 14, in favour of `AudioComponentCopyIcon`.

## iOS 14: `AudioComponentCopyIcon`

The host answers an image for the generic output and nil for NULL (measured, `printIcons`). The port answers the same
way: a blank 32 by 32 image, and nil for NULL. The pixels differ, as above. A component the macOS host does not find (the
sampler, which `AudioComponentFindNext` answers NULL for in that process) was not measured, so the answer for it is not
claimed.

## iOS 7: `AudioOutputUnitPublish`

The host answers noErr (0) for every input measured: a description with a unit, a NULL unit, a NULL name, version 0, and a
NULL description (`checkPublish` compares each with the port's answer). After the call the host does not make the published
description findable in its own process: `AudioComponentFindNext` answers NULL for it. The port does nothing and returns noErr,
so an application in this process finds the same components before and after the call, as it does on the host.
The release publishes the unit to other processes, which may find it through the audio component manager. This port hosts
each unit in its own process, so there is no other process for the publication to reach; that is not reproduced.

## iOS 7: `CopyNameFromSoundBank`, `CopyInstrumentInfoFromSoundBank`

A DLS bank is a RIFF form `DLS ` with an `INFO` list holding the bank's name (its `INAM`) and a `lins` list holding one
`ins ` list per instrument. The instrument's `insh` chunk gives its bank word and its program; its own `INFO` list gives its name.
The port reads those chunks (`AudioToolboxFunctions7.m`).

The host's name for `gs_instruments.dls` is "QuickTime Music Synthesizer  " (29 characters, with two trailing spaces),
status 0. The host's instrument list has 235 entries, and the port's is equal to it entry for entry (`isEqualToArray`). Each
entry's keys are `LSB`, `MSB`, `program` and `name`, and the mapping is:

- `LSB` is the second byte of the bank word (`(bank >> 8) & 0x7f`). Bits 0 to 7 of the bank word are zero in this file, and
  their use is not measured.
- `MSB` is 120 when the bank word's top bit is set (the 12 drum entries) and 121 otherwise (`probe16`, `dls_expect.py`
  against the host's output, all 235 lines).
- `program` is the instrument's number, and `name` its `INAM`, with the trailing spaces the file has.

The host reads a DLS bank whose name ends in `.sf2` by its content, and the port does too: the same bytes under the name
`copy.sf2` give the same 235 entries from both (`checkSoundBanks`).

The host's answers for the other files, measured on the macOS host:

- A missing file: name -10871, with the URL's last path component as the name (for `absent.dls`); the instrument list is
  fnfErr (-43). Both the port and the host are checked for these.
- A directory: name -10871 with its last path component, and the list -10871. Both are checked.
- A text file (the host's name call is not made, see below): the list is -10871. The port's answer is checked against it.
- A bank cut to its first 100 bytes: the host's list status is 0 with 1 entry, and the port's is 0 with 0 entries (printed,
  not counted). The host reads part of the instrument it cannot finish; the port reads only the instruments that are whole.
- The host traps (exit 133) on the name call for an empty file, a text file and an `Info.plist`, and hangs on a truncated bank
  (the 100-byte copy; no answer within four seconds). The host's answers for those names are not measured, so the port's
  answer there is -10871 with the component, and the test does not call the host for them.

A SoundFont bank (`sfbk`) is not read: no `.sf2` file was on the machine the host was measured on
(`find /System/Library /Library -iname '*.sf2'` finds none). The port answers -10871 for a SoundFont, and that answer is not
measured against the host's.

## Owed in this file

`AudioComponentCopyConfigurationInfo` (iOS 16) and `AudioWorkIntervalCreate` (iOS 14) are owed: the rows say so, and no
port definition exists for either.

`AudioComponentCopyConfigurationInfo` answers, for the generic output component, status 0 and a dictionary with
`AvailableArchitectures`, `BusCountWritable`, `ChannelConfigurations`, `HasCustomView`, `IconURL`, `InitialInputs`,
`InitialOutputs`, `MIDIProtocol`, `SupportedChannelLayoutTags` and `ValidationResult` (measured on the macOS host, `probe17`).
It answers -3000 for NULL and for a component the process does not find. The dictionary is the component's own configuration,
read from its bundle, which the port has no bundle to read, so the function stays owed until that is decided.

`AudioWorkIntervalCreate` returns an `os_workgroup_interval_t` (`AudioWorkInterval.h`, iOS 14), and the port has no
`os_workgroup` to return. The host returns a non-NULL interval for a name and for a NULL name, with a clock of 0 and NULL attributes
(`probe19`, macOS host). The function stays owed until the port has a workgroup to return.

