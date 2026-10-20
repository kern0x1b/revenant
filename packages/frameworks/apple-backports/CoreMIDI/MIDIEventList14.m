#import <CoreMIDI/CoreMIDI.h>

#import "RevenantCoreMIDI.h"

MIDIEventPacket *MIDIEventListInit(MIDIEventList *evtlist, MIDIProtocolID protocol)
{
    evtlist->protocol = protocol;
    evtlist->numPackets = 0;
    return &evtlist->packet[0];
}

MIDIEventPacket *MIDIEventListAdd(MIDIEventList *evtlist, ByteCount listSize, MIDIEventPacket *curPacket,
                                  MIDITimeStamp time, ByteCount wordCount, const UInt32 *words)
{
    return RevenantMIDIEventListAdd(evtlist, listSize, curPacket, time, wordCount, words);
}
