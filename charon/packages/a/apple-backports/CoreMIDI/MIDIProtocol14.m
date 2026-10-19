#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

const CFStringRef kMIDIPropertyProtocolID = CHARON_PROTOCOL_KEY;

OSStatus MIDIInputPortCreateWithProtocol(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol,
                                         MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock)
{
    return CharonMIDIInputPort(client, portName, protocol, outPort, receiveBlock);
}

OSStatus MIDIDestinationCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol,
                                           MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock)
{
    return CharonMIDIDestination(client, name, protocol, outDest, readBlock);
}

OSStatus MIDISourceCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc)
{
    return CharonMIDISource(client, name, protocol, outSrc);
}

OSStatus MIDISendEventList(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist)
{
    return CharonMIDISend(port, dest, evtlist);
}

OSStatus MIDIReceivedEventList(MIDIEndpointRef src, const MIDIEventList *evtlist)
{
    return CharonMIDIReceive(src, evtlist);
}
