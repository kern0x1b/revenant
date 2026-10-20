#import <CoreMIDI/CoreMIDI.h>

#import "RevenantCoreMIDI.h"

const CFStringRef kMIDIPropertyProtocolID = REVENANT_PROTOCOL_KEY;

OSStatus MIDIInputPortCreateWithProtocol(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol,
                                         MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock)
{
    return RevenantMIDIInputPort(client, portName, protocol, outPort, receiveBlock);
}

OSStatus MIDIDestinationCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol,
                                           MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock)
{
    return RevenantMIDIDestination(client, name, protocol, outDest, readBlock);
}

OSStatus MIDISourceCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc)
{
    return RevenantMIDISource(client, name, protocol, outSrc);
}

OSStatus MIDISendEventList(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist)
{
    return RevenantMIDISend(port, dest, evtlist);
}

OSStatus MIDIReceivedEventList(MIDIEndpointRef src, const MIDIEventList *evtlist)
{
    return RevenantMIDIReceive(src, evtlist);
}
