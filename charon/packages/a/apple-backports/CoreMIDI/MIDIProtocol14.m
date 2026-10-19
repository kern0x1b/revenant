// The protocol-aware ports and endpoints and the list sends of iOS 14, and the property that names an endpoint's protocol.
// Each function is the API's name over CharonMIDIPorts.m's internal one: the release has MIDI 1.0 CoreMIDI only, and the
// conversion, the endpoints and the routes are described there and in facts/CoreMIDI/Translation.md.
#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

// The property's key is the one string the library names (CharonCoreMIDI.h), so the three files that use it agree.
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
