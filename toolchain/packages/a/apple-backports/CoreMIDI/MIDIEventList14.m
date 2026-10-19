#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

MIDIEventPacket *MIDIEventListInit(MIDIEventList *evtlist, MIDIProtocolID protocol)
{
    evtlist->protocol = protocol;
    evtlist->numPackets = 0;
    return &evtlist->packet[0];
}

MIDIEventPacket *MIDIEventListAdd(MIDIEventList *evtlist, ByteCount listSize, MIDIEventPacket *curPacket,
                                  MIDITimeStamp time, ByteCount wordCount, const UInt32 *words)
{
    return CharonMIDIEventListAdd(evtlist, listSize, curPacket, time, wordCount, words);
}
