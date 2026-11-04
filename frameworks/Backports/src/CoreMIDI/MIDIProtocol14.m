#include "../revenant_impl.h"
#import <CoreMIDI/CoreMIDI.h>

#import "RevenantCoreMIDI.h"

const CFStringRef BACKPORT_IMPL(kMIDIPropertyProtocolID) = REVENANT_PROTOCOL_KEY;

OSStatus BACKPORT_IMPL(MIDIInputPortCreateWithProtocol)(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol,
                                         MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock)
{
    return RevenantMIDIInputPort(client, portName, protocol, outPort, receiveBlock);
}

OSStatus BACKPORT_IMPL(MIDIDestinationCreateWithProtocol)(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol,
                                           MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock)
{
    return RevenantMIDIDestination(client, name, protocol, outDest, readBlock);
}

OSStatus BACKPORT_IMPL(MIDISourceCreateWithProtocol)(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc)
{
    return RevenantMIDISource(client, name, protocol, outSrc);
}

OSStatus BACKPORT_IMPL(MIDISendEventList)(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist)
{
    return RevenantMIDISend(port, dest, evtlist);
}

OSStatus BACKPORT_IMPL(MIDIReceivedEventList)(MIDIEndpointRef src, const MIDIEventList *evtlist)
{
    return RevenantMIDIReceive(src, evtlist);
}
