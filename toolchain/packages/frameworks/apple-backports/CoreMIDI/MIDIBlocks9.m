#import <CoreMIDI/CoreMIDI.h>

#import "RevenantCoreMIDI.h"

static void revenant_notify(const MIDINotification *message, void *refCon)
{
    MIDINotifyBlock block = (__bridge MIDINotifyBlock)refCon;
    if (block)
        block(message);
}

static void revenant_read(const MIDIPacketList *packets, void *readRefCon, void *srcConnRefCon)
{
    MIDIReadBlock block = (__bridge MIDIReadBlock)readRefCon;
    if (block)
        block(packets, srcConnRefCon);
}

static void *revenant_retain_block(id block)
{
    return block ? (__bridge_retained void *)[block copy] : NULL;
}

static void revenant_release_block(void *refCon)
{
    if (refCon)
        (void)(__bridge_transfer id)refCon;
}

OSStatus MIDIClientCreateWithBlock(CFStringRef name, MIDIClientRef *outClient, MIDINotifyBlock notifyBlock)
{
    void *refCon = revenant_retain_block(notifyBlock);
    OSStatus status = MIDIClientCreate(name, revenant_notify, refCon, outClient);
    if (status != noErr)
        revenant_release_block(refCon);
    else if (refCon)
        RevenantMIDIOwnBlock(*outClient, refCon);
    return status;
}

OSStatus MIDIInputPortCreateWithBlock(MIDIClientRef client, CFStringRef portName, MIDIPortRef *outPort, MIDIReadBlock readBlock)
{
    void *refCon = revenant_retain_block(readBlock);
    OSStatus status = MIDIInputPortCreate(client, portName, revenant_read, refCon, outPort);
    if (status != noErr)
        revenant_release_block(refCon);
    else if (refCon)
        RevenantMIDIOwnBlock(*outPort, refCon);
    return status;
}

OSStatus MIDIDestinationCreateWithBlock(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outDest, MIDIReadBlock readBlock)
{
    void *refCon = revenant_retain_block(readBlock);
    OSStatus status = MIDIDestinationCreate(client, name, revenant_read, refCon, outDest);
    if (status != noErr)
        revenant_release_block(refCon);
    else if (refCon)
        RevenantMIDIOwnBlock(*outDest, refCon);
    return status;
}
