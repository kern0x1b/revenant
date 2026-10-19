// MIDIClientCreateWithBlock, MIDIInputPortCreateWithBlock and MIDIDestinationCreateWithBlock, of iOS 9: the
// block forms of the client, the input port and the virtual destination. The release has the function forms
// (MIDIClientCreate, MIDIInputPortCreate, MIDIDestinationCreate), and each block is carried through the
// function form's refCon: the block is copied once. A client's, port's or destination's copy is released when the object
// is gone (CharonMIDIOwnBlock; the rows are swept when the next object is made, CharonMIDIPorts.m). A disposed object
// answers paramErr to a UniqueID read, measured on macOS and on 6.1.3 (facts/CoreMIDI/CoreMIDI.md, "Disposed objects").
#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

// A NULL block is accepted, as macOS accepts it: the object is made and its notifications or packets go nowhere.
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

// The reference constant the release keeps for a block: a copy of the block, or NULL for no block.
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
