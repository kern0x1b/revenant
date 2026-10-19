#import <AudioToolbox/MusicDevice.h>
#import "CharonMIDIEventList.h"

// MusicDeviceMIDIEventList, iOS 15: the list form of MusicDeviceMIDIEvent and MusicDeviceSysEx. The release has neither the
// list call nor a selector for it, so the list is walked here, one message at a time, in the order the list gives them
// (CharonForEachMIDIMessage: the same conversion the instrument's sendMIDIEventList: makes). Each MIDI 1.0 message goes to
// MusicDeviceMIDIEvent at the offset given, and each complete system-exclusive message to MusicDeviceSysEx.
//
// The conversions the host's own MusicDeviceMIDIEventList is measured on, bit for bit on a sampler, in
// tests/backports/host/audiotoolbox-functions: a MIDI 1.0 note on, a MIDI 2.0 note on at two velocities, a MIDI 2.0 control
// change, and a MIDI 2.0 pitch bend. The other conversions CharonForEachMIDIMessage makes follow the UMP definition
// (facts/AVFAudio/AudioToolboxFunctions.md says which). The status is noErr when every message is sent; a failing message's
// status is returned, and the host's status for that case is not measured.
OSStatus MusicDeviceMIDIEventList(MusicDeviceComponent inUnit, UInt32 inOffsetSampleFrame, const MIDIEventList *evtList)
{
    __block OSStatus status = noErr;
    CharonForEachMIDIMessage(evtList, ^(const uint8_t *bytes, UInt32 length) {
        OSStatus result = (bytes[0] == 0xF0)
            ? MusicDeviceSysEx(inUnit, bytes, length)
            : MusicDeviceMIDIEvent(inUnit, bytes[0], length > 1 ? bytes[1] : 0, length > 2 ? bytes[2] : 0, inOffsetSampleFrame);
        if (result != noErr) {
            status = result;
        }
    });
    return status;
}
