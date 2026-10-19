#import "RevenantAVAudioUnit.h"
#import <AudioToolbox/MusicDevice.h>
#import <AudioToolbox/AudioUnitParameters.h>
#import "RevenantMIDIEventList.h"

@implementation AVAudioUnitMIDIInstrument {
    NSMutableDictionary<NSNumber *, NSNumber *> *_revenant_notes;
    NoteInstanceID _revenant_nextInstance;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description
{
    if (description.componentType == 0) {
        description.componentType = kAudioUnitType_MusicDevice;
    }
    if (description.componentManufacturer == 0) {
        description.componentManufacturer = kAudioUnitManufacturer_Apple;
    }
    self = [super initWithRevenantComponentDescription:description name:nil manufacturerName:nil version:0];
    if (self) {
        _revenant_notes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (MusicDeviceComponent)revenant_musicDevice
{
    return (MusicDeviceComponent)self.audioUnit;
}

- (void)startNote:(uint8_t)note withVelocity:(uint8_t)velocity onChannel:(uint8_t)channel
{
    MusicDeviceComponent unit = [self revenant_musicDevice];
    if (unit == NULL) {
        return;
    }
    if (_revenant_notes == nil) {
        _revenant_notes = [NSMutableDictionary dictionary];
    }
    MusicDeviceStdNoteParams params;
    memset(&params, 0, sizeof(params));
    params.argCount = 2;
    params.mPitch = (Float32)note;
    params.mVelocity = (Float32)velocity;
    NoteInstanceID instance = 0;
    if (MusicDeviceStartNote(unit, 0 , 0, &instance, 0,
                             (const MusicDeviceNoteParams *)&params) == noErr) {
        _revenant_notes[@((channel << 8) | note)] = @(instance);
        return;
    }
    MusicDeviceMIDIEvent(unit, 0x90 | (channel & 0x0F), note, velocity, 0);
}

- (void)stopNote:(uint8_t)note onChannel:(uint8_t)channel
{
    MusicDeviceComponent unit = [self revenant_musicDevice];
    if (unit == NULL) {
        return;
    }
    NSNumber *key = @((channel << 8) | note);
    NSNumber *instance = _revenant_notes[key];
    if (instance != nil) {
        if (MusicDeviceStopNote(unit, 0, (NoteInstanceID)instance.unsignedIntValue, 0) == noErr) {
            [_revenant_notes removeObjectForKey:key];
            return;
        }
    }
    MusicDeviceMIDIEvent(unit, 0x80 | (channel & 0x0F), note, 0, 0);
}

- (void)sendController:(uint8_t)controller withValue:(uint8_t)value onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], 0xB0 | (channel & 0x0F), controller, value, 0);
}

- (void)sendPitchBend:(uint16_t)pitchbend onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], 0xE0 | (channel & 0x0F),
                         (UInt32)(pitchbend & 0x7F), (UInt32)((pitchbend >> 7) & 0x7F), 0);
}

- (void)sendPressure:(uint8_t)pressure onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], 0xD0 | (channel & 0x0F), pressure, 0, 0);
}

- (void)sendPressureForKey:(uint8_t)key withValue:(uint8_t)value onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], 0xA0 | (channel & 0x0F), key, value, 0);
}

- (void)sendProgramChange:(uint8_t)program onChannel:(uint8_t)channel
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], 0xC0 | (channel & 0x0F), program, 0, 0);
}

- (void)sendProgramChange:(uint8_t)program bankMSB:(uint8_t)bankMSB bankLSB:(uint8_t)bankLSB onChannel:(uint8_t)channel
{
    MusicDeviceComponent unit = [self revenant_musicDevice];
    MusicDeviceMIDIEvent(unit, 0xB0 | (channel & 0x0F), 0, bankMSB, 0);
    MusicDeviceMIDIEvent(unit, 0xB0 | (channel & 0x0F), 32, bankLSB, 0);
    MusicDeviceMIDIEvent(unit, 0xC0 | (channel & 0x0F), program, 0, 0);
}

- (void)sendMIDIEvent:(uint8_t)midiStatus data1:(uint8_t)data1
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], midiStatus, data1, 0, 0);
}

- (void)sendMIDIEvent:(uint8_t)midiStatus data1:(uint8_t)data1 data2:(uint8_t)data2
{
    MusicDeviceMIDIEvent([self revenant_musicDevice], midiStatus, data1, data2, 0);
}

- (void)sendMIDISysExEvent:(NSData *)midiData
{
    if (midiData.length == 0) {
        return;
    }
    MusicDeviceSysEx([self revenant_musicDevice], midiData.bytes, (UInt32)midiData.length);
}

- (BOOL)playing
{
    return _revenant_notes.count > 0;
}


- (void)sendMIDIEventList:(const MIDIEventList *)eventList
{
    MusicDeviceComponent unit = [self revenant_musicDevice];
    if (unit == NULL) {
        return;
    }
    RevenantForEachMIDIMessage(eventList, ^(const uint8_t *bytes, UInt32 length) {
        if (bytes[0] == 0xF0) {
            MusicDeviceSysEx(unit, bytes, length);
        } else {
            MusicDeviceMIDIEvent(unit, bytes[0], length > 1 ? bytes[1] : 0, length > 2 ? bytes[2] : 0, 0);
        }
    });
}

@end
