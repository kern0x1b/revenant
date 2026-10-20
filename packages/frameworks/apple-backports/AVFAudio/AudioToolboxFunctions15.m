#import <AudioToolbox/MusicDevice.h>
#import "RevenantMIDIEventList.h"

OSStatus MusicDeviceMIDIEventList(MusicDeviceComponent inUnit, UInt32 inOffsetSampleFrame, const MIDIEventList *evtList)
{
    __block OSStatus status = noErr;
    RevenantForEachMIDIMessage(evtList, ^(const uint8_t *bytes, UInt32 length) {
        OSStatus result = (bytes[0] == 0xF0)
            ? MusicDeviceSysEx(inUnit, bytes, length)
            : MusicDeviceMIDIEvent(inUnit, bytes[0], length > 1 ? bytes[1] : 0, length > 2 ? bytes[2] : 0, inOffsetSampleFrame);
        if (result != noErr) {
            status = result;
        }
    });
    return status;
}
