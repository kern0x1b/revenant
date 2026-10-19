#import "CharonAVAudioUnit.h"
#import <AudioToolbox/MusicDevice.h>
#import <AudioToolbox/AudioUnitParameters.h>
#import "CharonMIDIEventList.h"

// AVAudioUnitMIDIInstrument over the release's own MusicDevice send API.
//
// A previous report of this family said the release "exports no function that sends a MIDI event to an
// audio unit". That was wrong, and the mistake is worth recording: the check that produced it grepped
// the AudioUnit* prefix and read the head of a truncated _AU* listing. The right measurement is over
// the whole of AudioToolbox, and it is:
//
//   a listing of AudioToolbox's exported symbols, filtered to the MusicDevice prefix:
//   AudioToolbox exports matching _MusicDevice: ['_MusicDeviceMIDIEvent', '_MusicDeviceStartNote',
//   '_MusicDeviceStopNote', '_MusicDeviceSysEx']
//
// MusicDevice.h of SDK 16.4 (:185-186) documents MusicDeviceMIDIEvent as the call that sends MIDI channel
// messages sent to the audio unit: inUnit is the unit, inStatus the MIDI status byte, and inData1 and inData2 are read
// as the MIDI specification reads them, the channel and the command both in the status byte. All of it is
// API_AVAILABLE(ios(5.0)). MusicDeviceSysEx is the non-channel form, and
// MusicDeviceStartNote/MusicDeviceStopNote are the extended note API that returns the note instance
// the same API group stops. So every channel message, the system-exclusive message and the note pair
// are the release's own calls.
//
// MusicDeviceMIDIEventList is NOT among the four exports, so -[AVAudioUnitMIDIInstrument
// sendMIDIEventList:] (iOS 16) cannot be the release's list call. It decodes the list message by message
// to MusicDeviceMIDIEvent, and a complete system-exclusive message to MusicDeviceSysEx (CharonMIDIEventList.h).

@implementation AVAudioUnitMIDIInstrument {
    NSMutableDictionary<NSNumber *, NSNumber *> *_charon_notes;   // (channel << 8 | note) -> note instance
    NoteInstanceID _charon_nextInstance;
}

// The instrument is a music device: the release's own description of one, asked for the
// kAudioUnitType_MusicDevice family. An application may pass its own description instead, which is
// what the header's initializer is for.
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description
{
    if (description.componentType == 0) {
        description.componentType = kAudioUnitType_MusicDevice;
    }
    if (description.componentManufacturer == 0) {
        description.componentManufacturer = kAudioUnitManufacturer_Apple;
    }
    self = [super initWithCharonComponentDescription:description name:nil manufacturerName:nil version:0];
    if (self) {
        _charon_notes = [NSMutableDictionary dictionary];
    }
    return self;
}

// The unit's own component, which is what the MusicDevice calls take. A unit that is not attached to a
// graph has one anyway: AudioComponentInstanceGetComponent answers it from the instance.
- (MusicDeviceComponent)charon_musicDevice
{
    return (MusicDeviceComponent)self.audioUnit;
}

// A note, started with the extended API when the release has it, so that the note instance it returns
// is what stops it. The header (MusicDevice.h:32-33) requires a note to stop through the API group that started it.
// A release that answers the note instance is used that way; one that does not
// falls back to the MIDI note-on event, which the same header documents as the other legal way and
// which is stopped with the note-off event.
- (void)startNote:(uint8_t)note withVelocity:(uint8_t)velocity onChannel:(uint8_t)channel
{
    MusicDeviceComponent unit = [self charon_musicDevice];
    if (unit == NULL) {
        return;
    }
    if (_charon_notes == nil) {
        _charon_notes = [NSMutableDictionary dictionary];
    }
    // MusicDeviceStdNoteParams is the two-argument form the header calls "the common usage for
    // MusicDeviceStartNote": a Float32 pitch, which is a MIDI note number with an optional fractional
    // part, and a Float32 velocity. The struct is the release's own and its field types are its own.
    MusicDeviceStdNoteParams params;
    memset(&params, 0, sizeof(params));
    params.argCount = 2;
    params.mPitch = (Float32)note;
    params.mVelocity = (Float32)velocity;
    NoteInstanceID instance = 0;
    if (MusicDeviceStartNote(unit, 0 /* the instrument of a group-0 channel */, 0, &instance, 0,
                             (const MusicDeviceNoteParams *)&params) == noErr) {
        _charon_notes[@((channel << 8) | note)] = @(instance);
        return;
    }
    MusicDeviceMIDIEvent(unit, 0x90 | (channel & 0x0F), note, velocity, 0);
}

- (void)stopNote:(uint8_t)note onChannel:(uint8_t)channel
{
    MusicDeviceComponent unit = [self charon_musicDevice];
    if (unit == NULL) {
        return;
    }
    NSNumber *key = @((channel << 8) | note);
    NSNumber *instance = _charon_notes[key];
    if (instance != nil) {
        // The note was started with the extended API, so it is stopped with it.
        if (MusicDeviceStopNote(unit, 0, (NoteInstanceID)instance.unsignedIntValue, 0) == noErr) {
            [_charon_notes removeObjectForKey:key];
            return;
        }
    }
    MusicDeviceMIDIEvent(unit, 0x80 | (channel & 0x0F), note, 0, 0);
}

- (void)sendController:(uint8_t)controller withValue:(uint8_t)value onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self charon_musicDevice], 0xB0 | (channel & 0x0F), controller, value, 0);
}

- (void)sendPitchBend:(uint16_t)pitchbend onChannel:(uint8_t)channel
{
    // A 14-bit pitch bend is the low seven bits first, which is what the MIDI specification says and
    // what MusicDeviceMIDIEvent's inData1 then inData2 order takes.
    MusicDeviceMIDIEvent([self charon_musicDevice], 0xE0 | (channel & 0x0F),
                         (UInt32)(pitchbend & 0x7F), (UInt32)((pitchbend >> 7) & 0x7F), 0);
}

- (void)sendPressure:(uint8_t)pressure onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self charon_musicDevice], 0xD0 | (channel & 0x0F), pressure, 0, 0);
}

- (void)sendPressureForKey:(uint8_t)key withValue:(uint8_t)value onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self charon_musicDevice], 0xA0 | (channel & 0x0F), key, value, 0);
}

- (void)sendProgramChange:(uint8_t)program onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self charon_musicDevice], 0xC0 | (channel & 0x0F), program, 0, 0);
}

- (void)sendProgramChange:(uint8_t)program bankMSB:(uint8_t)bankMSB bankLSB:(uint8_t)bankLSB onChannel:(uint8_t)channel
{
    // A banked program change is two bank-select controller events and then the program change, which
    // is what the MIDI specification's bank select and program change are and what the release's unit
    // reads them as. The header (MusicDevice.h:188-191) makes the same point about the channel and the command
    // sharing the status byte.
    MusicDeviceComponent unit = [self charon_musicDevice];
    MusicDeviceMIDIEvent(unit, 0xB0 | (channel & 0x0F), 0, bankMSB, 0);
    MusicDeviceMIDIEvent(unit, 0xB0 | (channel & 0x0F), 32, bankLSB, 0);
    MusicDeviceMIDIEvent(unit, 0xC0 | (channel & 0x0F), program, 0, 0);
}

- (void)sendMIDIEvent:(uint8_t)midiStatus data1:(uint8_t)data1
{
    MusicDeviceMIDIEvent([self charon_musicDevice], midiStatus, data1, 0, 0);
}

- (void)sendMIDIEvent:(uint8_t)midiStatus data1:(uint8_t)data1 data2:(uint8_t)data2
{
    MusicDeviceMIDIEvent([self charon_musicDevice], midiStatus, data1, data2, 0);
}

// A system-exclusive block is the release's own call, and its length is the whole message, F0 and F7
// bracketing bytes included (MusicDevice.h:227-232).
- (void)sendMIDISysExEvent:(NSData *)midiData
{
    if (midiData.length == 0) {
        return;
    }
    MusicDeviceSysEx([self charon_musicDevice], midiData.bytes, (UInt32)midiData.length);
}

- (BOOL)playing
{
    return _charon_notes.count > 0;
}


// The list form. The packets are decoded to MIDI 1.0 channel messages and each is one MusicDeviceMIDIEvent;
// a word that is not a channel message is skipped, which facts/AVFAudio/AVAudioUnitMIDI.md records.
- (void)sendMIDIEventList:(const MIDIEventList *)eventList
{
    MusicDeviceComponent unit = [self charon_musicDevice];
    if (unit == NULL) {
        return;
    }
    CharonForEachMIDIMessage(eventList, ^(const uint8_t *bytes, UInt32 length) {
        if (bytes[0] == 0xF0) {
            MusicDeviceSysEx(unit, bytes, length);
        } else {
            MusicDeviceMIDIEvent(unit, bytes[0], length > 1 ? bytes[1] : 0, length > 2 ? bytes[2] : 0, 0);
        }
    });
}

@end
