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

The three functions of this section are declared in `AVFAudio/CharonAudioToolboxDeclarations.h`, with the types the 16.4 SDK does not
have (`AudioStreamPacketDependencyDescription`, `AudioConverterOptions`, `AudioConverterComplexInputDataProcRealtimeSafe`). The header
is guarded on `CA_REALTIME_API`, which the iOS 26 SDK defines, so a 26 SDK build does not see the types twice.

## Not yet in this file

`AudioComponentGetIcon`, `AudioComponentCopyIcon`, `AudioComponentCopyConfigurationInfo`, `AudioOutputUnitPublish`, the two sound bank
functions and `AudioWorkIntervalCreate` are the rest of the round's functions. They are written in their own sections, with their own
measurements, when they are in.
