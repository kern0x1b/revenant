// MIDIEventListInit and MIDIEventListAdd, of iOS 14: the builders of a Universal MIDI Packet list. The release
// has no event list at all, so the list is a plain buffer this file fills, and its packet rules are the ones
// macOS CoreMIDI was measured to keep (facts/CoreMIDI/EventList.md).
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
