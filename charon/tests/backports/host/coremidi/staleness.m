// The rows of CharonMIDIPorts.m go stale when the release no longer knows the object (a property read answers paramErr) and when
// the release has given the reference to a new object (the stamp the library wrote is not on it). A row of a live object keeps
// what it holds whatever its creator does to the object's UniqueID, which is the creator's to set (MIDIServices.h,
// kMIDIPropertyUniqueID). Each row's retained block is released when its row goes, and a row of a live object keeps its block.
//
// The host release cannot be made to reuse a reference, so this test stands in for the two release calls the rows make,
// MIDIObjectGetIntegerProperty and MIDIObjectSetIntegerProperty (run.sh renames them in CharonMIDIPorts.m and here to
// charon_test_...); nothing is linked from the release for them. The stand-in answers what the release was measured to answer
// (oracle/stamp-macos.txt, and the 6.1.3 application's lines in facts/CoreMIDI/CoreMIDI.md): a disposed or never-made reference
// answers paramErr, a live object answers -10835 for a key it does not hold and noErr with the value for one it does, and the
// owner's write of the UniqueID changes the UniqueID alone.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#import "CharonCoreMIDI.h"

static int gLive;
static int gFailures;

// A block stand-in whose release is counted: CharonMIDIOwnBlock takes a retained reference, as MIDIBlocks9.m gives it.
@interface Token : NSObject
@end
@implementation Token
- (void)dealloc
{
    gLive--;
}
@end

#define OBJECTS 128
typedef struct {
    int exists;          // the release knows the reference
    int hasUniqueID;     // a client and a port have none (-10835)
    SInt32 uniqueID;
    int hasStamp;
    SInt32 stamp;
    OSStatus refused;    // a status that every read answers instead (the release is not answering, say)
    OSStatus setStatus;  // the status of the write of the library's stamp (noErr unless the test makes it refuse)
} StubObject;
static StubObject gObject[OBJECTS];

// The key is the library's or it is the UniqueID, the one other key the rows read or an owner sets. (The host's property name
// constants are NULL until the release is first used, which this test never does, so the UniqueID is not compared by name.)
static int is_owner_key(CFStringRef propertyID)
{
    return propertyID && CFEqual(propertyID, CHARON_OWNER_KEY);
}

// A read of this object (the stamp, as the library makes it) is held inside the stand-in until the test lets it go: the thread that is
// in the call announces it, and then waits. The library must not hold a lock another thread needs while it is there.
static MIDIObjectRef gHeldObject = (MIDIObjectRef)-1;
static dispatch_semaphore_t gHeldEntered;
static dispatch_semaphore_t gHeldRelease;
static int gReads;
// The same hold for the one thread that sets it: its next read of this object (or of any, for kAnyObject) is held.
#define kNoObject ((MIDIObjectRef)0xFFFFFFFFu)
#define kAnyObject ((MIDIObjectRef)0xFFFFFFFEu)
static __thread MIDIObjectRef tHoldObject = kNoObject;

OSStatus charon_test_MIDIObjectGetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 *outValue)
{
    __atomic_add_fetch(&gReads, 1, __ATOMIC_RELAXED);
    if (tHoldObject != kNoObject && (tHoldObject == kAnyObject || tHoldObject == object)) {
        tHoldObject = kNoObject;
        dispatch_semaphore_signal(gHeldEntered);
        dispatch_semaphore_wait(gHeldRelease, DISPATCH_TIME_FOREVER);
    }
    if (object == gHeldObject) {
        gHeldObject = (MIDIObjectRef)-1;
        dispatch_semaphore_signal(gHeldEntered);
        dispatch_semaphore_wait(gHeldRelease, DISPATCH_TIME_FOREVER);
    }
    if (object >= OBJECTS || !gObject[object].exists)
        return charon_paramErr;
    StubObject *held = &gObject[object];
    if (held->refused != noErr)
        return held->refused;
    if (is_owner_key(propertyID)) {
        if (!held->hasStamp)
            return kMIDIUnknownProperty;
        *outValue = held->stamp;
        return noErr;
    }
    if (!held->hasUniqueID)
        return kMIDIUnknownProperty;
    *outValue = held->uniqueID;
    return noErr;
}

OSStatus charon_test_MIDIObjectSetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 value)
{
    if (object >= OBJECTS || !gObject[object].exists)
        return charon_paramErr;
    StubObject *held = &gObject[object];
    if (is_owner_key(propertyID)) {
        if (held->setStatus != noErr)
            return held->setStatus;
        held->hasStamp = 1;
        held->stamp = value;
        return noErr;
    }
    held->hasUniqueID = 1;
    held->uniqueID = value;
    return noErr;
}

// A destination the library makes: the stand-in of the release's call hands out one reference (an object the stand-in knows) and keeps the
// read procedure, so that a test can call it as the release's thread does.
static MIDIReadProc gDestinationProc;
static void *gDestinationRefCon;
static MIDIObjectRef gNextDestination = 20;

OSStatus charon_test_MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon,
                                           MIDIEndpointRef *outDest)
{
    gDestinationProc = readProc;
    gDestinationRefCon = refCon;
    MIDIObjectRef object = gNextDestination++;
    gObject[object].exists = 1;
    gObject[object].hasUniqueID = 1;
    gObject[object].uniqueID = (SInt32)(2000 + object);
    *outDest = object;
    return noErr;
}

static void expect(int passed, const char *name)
{
    printf("%s %s\n", passed ? "ok" : "FAIL", name);
    if (!passed)
        gFailures++;
}

// Makes an object the stand-in answers for, and owns a token for it (what MIDIBlocks9.m does for a client or a port).
static void own(MIDIObjectRef object, SInt32 uniqueID)
{
    gObject[object].exists = 1;
    gObject[object].hasUniqueID = 1;
    gObject[object].uniqueID = uniqueID;
    Token *token = [[Token alloc] init];
    gLive++;
    CharonMIDIOwnBlock(object, (__bridge_retained void *)token);
}

// The same for an object that has no UniqueID (a client, a port). A helper, so that no local keeps the token alive.
static void own_without_uniqueid(MIDIObjectRef object)
{
    gObject[object].exists = 1;
    Token *token = [[Token alloc] init];
    gLive++;
    CharonMIDIOwnBlock(object, (__bridge_retained void *)token);
}

// Creations that do nothing but walk the table: each makes a row of an object the stand-in always answers for (63), whose
// stamp is the last one written, so the filler before it is a replaced reference and is released by a later window. The sweep
// is incremental (a window of rows a creation), so a stale row is released within a pass of the table, not at the next creation.
static void creations(int count)
{
    gObject[63].exists = 1;
    for (int i = 0; i < count; i++)
        CharonMIDIOwnBlock(63, (__bridge_retained void *)[[NSObject alloc] init]);
}

// The reference given to a new object: it answers, with a UniqueID of its own and no stamp.
static void reuse(MIDIObjectRef object, SInt32 uniqueID)
{
    memset(&gObject[object], 0, sizeof(gObject[object]));
    gObject[object].exists = 1;
    gObject[object].hasUniqueID = 1;
    gObject[object].uniqueID = uniqueID;
}

// A destination of the library whose block holds a counted token and, in its first call, announces itself and waits.
static MIDIEndpointRef make_destination_holding_a_token(dispatch_semaphore_t entered, dispatch_semaphore_t release)
{
    Token *token = [[Token alloc] init];
    gLive++;
    MIDIEndpointRef destination = 0;
    OSStatus status = CharonMIDIDestination(0, CFSTR("holding"), kMIDIProtocol_2_0, &destination,
                                            ^(const MIDIEventList *list, void *ref) {
        (void)token;
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
    });
    return status == noErr ? destination : 0;
}

int main(void)
{
    @autoreleasepool {
        own(1, 11);
        own(2, 22);
        expect(gLive == 2, "two live objects own two tokens");
        // The creator sets the UniqueID of its own object: the documented use of the property.
        charon_test_MIDIObjectSetIntegerProperty(1, CFSTR("uniqueID"), 99);
        own(3, 33);
        expect(gLive == 3, "an object whose creator set its UniqueID is the same object: its row is kept");
        gObject[2].exists = 0;
        own(4, 44);
        creations(4);
        expect(gLive == 3, "an object that answers paramErr is released within a pass of the table");
        // The release gives the reference of a disposed object to a new object, which has no stamp.
        reuse(3, 77);
        own(5, 55);
        creations(4);
        expect(gLive == 3, "a reference given to a new object (no stamp) is released, and the live ones are kept");
        // The new object is another library instance's, with a stamp of its own.
        gObject[5].stamp ^= 0x5A5A5A5A;
        own(6, 66);
        creations(4);
        expect(gLive == 3, "a reference that answers another stamp is released");
        // A read that fails with another status is no evidence either way.
        gObject[1].refused = -10842;
        own(7, 77);
        creations(4);
        expect(gLive == 4, "an object whose read fails with another status is kept");
        gObject[1].refused = noErr;
        // A client or a port has no UniqueID: its identity is the stamp alone.
        own_without_uniqueid(8);
        own(9, 99);
        expect(gLive == 6, "an object with no UniqueID is kept while it answers its stamp");
        gObject[8].exists = 0;
        own(10, 100);
        creations(4);
        expect(gLive == 6, "and released when it is gone");
        // The stamp could not be written: the row is kept while the object is known and released when it is gone.
        gObject[11].setStatus = -10844;
        own(11, 111);
        own(12, 112);
        int before = gLive;
        gObject[11].exists = 0;
        own(13, 113);
        creations(4);
        expect(gLive == before, "an object whose stamp was refused is released when it is gone");

        // The sweep is bounded: a creation reads at most a window of rows however many the process holds, and a table of stale rows
        // is released within a pass of the table (ceil(rows / window) creations).
        int held = gLive;
        for (int i = 0; i < 40; i++)
            own(64 + i, 6400 + i);
        expect(gLive == held + 40, "forty more live objects are owned");
        for (int i = 0; i < 40; i++)
            gObject[64 + i].exists = 0;
        gReads = 0;
        own(63, 6300);
        int readsOfOne = gReads;
        expect(readsOfOne > 0 && readsOfOne <= 16, "one creation reads at most a window of the table, not all of it");
        int passes = 1;
        while (gLive > held + 1 && passes < 40) {
            own(63, 6300);
            passes++;
        }
        expect(gLive == held + 1 && passes <= 8, "and every stale row is released within a pass of the table");

        // The delivery reads the object (is the destination still there?) on the drain thread, right before its block is called, with
        // no lock held that another thread needs: while the drain thread is inside that read, another thread's send to an endpoint
        // that is not the library's returns. The sender reads nothing; its send only queues the delivery.
        static const UInt32 words[2] = {0x40903C00u, 0x12340000u};
        gHeldEntered = dispatch_semaphore_create(0);
        gHeldRelease = dispatch_semaphore_create(0);
        dispatch_semaphore_t delivered = dispatch_semaphore_create(0);
        __block int deliveries = 0;
        MIDIEndpointRef destination = 0;
        OSStatus made = CharonMIDIDestination(0, CFSTR("destination"), kMIDIProtocol_2_0, &destination,
                                              ^(const MIDIEventList *list, void *ref) {
            deliveries++;
            dispatch_semaphore_signal(delivered);
        });
        expect(made == noErr && destination != 0, "a destination of the library is made over the stand-in");
        gHeldObject = destination;
        __block Boolean firstResult = false;
        dispatch_semaphore_t firstDone = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            firstResult = CharonMIDIDeliverInProcess(destination, words, 2);
            dispatch_semaphore_signal(firstDone);
        });
        int inRead = dispatch_semaphore_wait(gHeldEntered, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        __block Boolean otherResult = true;
        dispatch_semaphore_t otherDone = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            otherResult = CharonMIDIDeliverInProcess(50, words, 2);
            dispatch_semaphore_signal(otherDone);
        });
        int otherReturned = dispatch_semaphore_wait(otherDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        expect(inRead && otherReturned && !otherResult,
               "a send to another endpoint returns while the drain thread is inside its check of the object");
        dispatch_semaphore_signal(gHeldRelease);
        int firstReturned = dispatch_semaphore_wait(firstDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        int arrived = dispatch_semaphore_wait(delivered, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        expect(firstReturned && firstResult && arrived && deliveries == 1, "and the delivery of that destination reaches its block once");
        if (!otherReturned)
            dispatch_semaphore_wait(otherDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));

        // A queued delivery holds the destination's port: the object goes and its row is swept while the block is running, and
        // the block (with what it captured) is released only after the call returns.
        int baseline = gLive;
        dispatch_semaphore_t blockEntered = dispatch_semaphore_create(0);
        dispatch_semaphore_t blockRelease = dispatch_semaphore_create(0);
        MIDIEndpointRef second = make_destination_holding_a_token(blockEntered, blockRelease);
        expect(second != 0 && gLive == baseline + 1, "a destination whose block holds a token is made");
        Boolean sent = CharonMIDIDeliverInProcess(second, words, 2);
        int running = dispatch_semaphore_wait(blockEntered, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        gObject[second].exists = 0;
        for (int i = 0; i < 24; i++)
            own(30 + i, 3000 + i);
        expect(sent && running && gLive == baseline + 1 + 24, "the object is gone and its row swept while the block runs: the token is alive");
        dispatch_semaphore_signal(blockRelease);
        for (int i = 0; i < 200 && gLive != baseline + 24; i++)
            usleep(10000);
        expect(gLive == baseline + 24, "and it is released once the call has returned");

        // The sweep reads objects with no lock held that a send needs. A creation whose sweep is inside the read of a row (an
        // object of the owned table, then the endpoint of a selection state) does not stop a send or another creation.
        static const UInt32 voice[2] = {0x40903C00u, 0x12340000u};
        Byte listBuffer[64];
        MIDIEventList *voiceList = (MIDIEventList *)listBuffer;
        MIDIEventPacket *voiceEnd = MIDIEventListInit(voiceList, kMIDIProtocol_2_0);
        CharonMIDIEventListAdd(voiceList, sizeof(listBuffer), voiceEnd, 0, 2, voice);
        // A route (a selection state) for endpoint 70, which the stand-in knows; the owned table is made small and live.
        gObject[70].exists = 1;
        gObject[70].hasUniqueID = 1;
        (void)CharonMIDIReceive(70, voiceList);
        for (int step = 0; step < 2; step++) {
            // step 0 holds a read of an owned row; step 1 holds the read of the route's endpoint.
            own(100, 1000 + step);
            MIDIObjectRef heldObject = step == 0 ? kAnyObject : 70;
            dispatch_semaphore_t creatorDone = dispatch_semaphore_create(0);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                tHoldObject = heldObject;
                own(101, 1010);
                dispatch_semaphore_signal(creatorDone);
            });
            int sweeping = dispatch_semaphore_wait(gHeldEntered, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
            __block int sendOK = 0;
            __block int creationOK = 0;
            dispatch_semaphore_t othersDone = dispatch_semaphore_create(0);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                Boolean ours = CharonMIDIDeliverInProcess(90, voice, 2);
                (void)CharonMIDIReceive(71, voiceList);
                sendOK = !ours;
                own(102, 1020);
                creationOK = 1;
                dispatch_semaphore_signal(othersDone);
            });
            int returned = dispatch_semaphore_wait(othersDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
            expect(sweeping && returned && sendOK && creationOK,
                   step == 0 ? "a send and another creation return while a sweep is inside the read of an owned row"
                             : "a send and another creation return while a sweep is inside the read of a selection state's endpoint");
            dispatch_semaphore_signal(gHeldRelease);
            dispatch_semaphore_wait(creatorDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
            if (!returned)
                dispatch_semaphore_wait(othersDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
        }
    }

    printf("staleness: %d failures\n", gFailures);
    return gFailures ? 1 : 0;
}
