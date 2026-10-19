#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

static void charon_notify(const MIDINotification *message, void *refCon)
{
    MIDINotifyBlock block = (__bridge MIDINotifyBlock)refCon;
    if (block)
        block(message);
}

static void charon_read(const MIDIPacketList *packets, void *readRefCon, void *srcConnRefCon)
{
    MIDIReadBlock block = (__bridge MIDIReadBlock)readRefCon;
    if (block)
        block(packets, srcConnRefCon);
}

static void *charon_retain_block(id block)
{
    return block ? (__bridge_retained void *)[block copy] : NULL;
}

static void charon_release_block(void *refCon)
{
    if (refCon)
        (void)(__bridge_transfer id)refCon;
}

OSStatus MIDIClientCreateWithBlock(CFStringRef name, MIDIClientRef *outClient, MIDINotifyBlock notifyBlock)
{
    void *refCon = charon_retain_block(notifyBlock);
    OSStatus status = MIDIClientCreate(name, charon_notify, refCon, outClient);
    if (status != noErr)
        charon_release_block(refCon);
    else if (refCon)
        CharonMIDIOwnBlock(*outClient, refCon);
    return status;
}

OSStatus MIDIInputPortCreateWithBlock(MIDIClientRef client, CFStringRef portName, MIDIPortRef *outPort, MIDIReadBlock readBlock)
{
    void *refCon = charon_retain_block(readBlock);
    OSStatus status = MIDIInputPortCreate(client, portName, charon_read, refCon, outPort);
    if (status != noErr)
        charon_release_block(refCon);
    else if (refCon)
        CharonMIDIOwnBlock(*outPort, refCon);
    return status;
}

OSStatus MIDIDestinationCreateWithBlock(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outDest, MIDIReadBlock readBlock)
{
    void *refCon = charon_retain_block(readBlock);
    OSStatus status = MIDIDestinationCreate(client, name, charon_read, refCon, outDest);
    if (status != noErr)
        charon_release_block(refCon);
    else if (refCon)
        CharonMIDIOwnBlock(*outDest, refCon);
    return status;
}
