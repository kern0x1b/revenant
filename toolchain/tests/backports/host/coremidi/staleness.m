#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#import "CharonCoreMIDI.h"

static int gLive;
static int gFailures;

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
    int exists;
    int hasUniqueID;
    SInt32 uniqueID;
    int hasStamp;
    SInt32 stamp;
    OSStatus refused;
    OSStatus setStatus;
} StubObject;
static StubObject gObject[OBJECTS];

static int is_owner_key(CFStringRef propertyID)
{
    return propertyID && CFEqual(propertyID, CHARON_OWNER_KEY);
}

static MIDIObjectRef gHeldObject = (MIDIObjectRef)-1;
static dispatch_semaphore_t gHeldEntered;
static dispatch_semaphore_t gHeldRelease;
static int gReads;
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

static void own(MIDIObjectRef object, SInt32 uniqueID)
{
    gObject[object].exists = 1;
    gObject[object].hasUniqueID = 1;
    gObject[object].uniqueID = uniqueID;
    Token *token = [[Token alloc] init];
    gLive++;
    CharonMIDIOwnBlock(object, (__bridge_retained void *)token);
}

static void own_without_uniqueid(MIDIObjectRef object)
{
    gObject[object].exists = 1;
    Token *token = [[Token alloc] init];
    gLive++;
    CharonMIDIOwnBlock(object, (__bridge_retained void *)token);
}

static void creations(int count)
{
    gObject[63].exists = 1;
    for (int i = 0; i < count; i++)
        CharonMIDIOwnBlock(63, (__bridge_retained void *)[[NSObject alloc] init]);
}

static void reuse(MIDIObjectRef object, SInt32 uniqueID)
{
    memset(&gObject[object], 0, sizeof(gObject[object]));
    gObject[object].exists = 1;
    gObject[object].hasUniqueID = 1;
    gObject[object].uniqueID = uniqueID;
}

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
        charon_test_MIDIObjectSetIntegerProperty(1, CFSTR("uniqueID"), 99);
        own(3, 33);
        expect(gLive == 3, "an object whose creator set its UniqueID is the same object: its row is kept");
        gObject[2].exists = 0;
        own(4, 44);
        creations(4);
        expect(gLive == 3, "an object that answers paramErr is released within a pass of the table");
        reuse(3, 77);
        own(5, 55);
        creations(4);
        expect(gLive == 3, "a reference given to a new object (no stamp) is released, and the live ones are kept");
        gObject[5].stamp ^= 0x5A5A5A5A;
        own(6, 66);
        creations(4);
        expect(gLive == 3, "a reference that answers another stamp is released");
        gObject[1].refused = -10842;
        own(7, 77);
        creations(4);
        expect(gLive == 4, "an object whose read fails with another status is kept");
        gObject[1].refused = noErr;
        own_without_uniqueid(8);
        own(9, 99);
        expect(gLive == 6, "an object with no UniqueID is kept while it answers its stamp");
        gObject[8].exists = 0;
        own(10, 100);
        creations(4);
        expect(gLive == 6, "and released when it is gone");
        gObject[11].setStatus = -10844;
        own(11, 111);
        own(12, 112);
        int before = gLive;
        gObject[11].exists = 0;
        own(13, 113);
        creations(4);
        expect(gLive == before, "an object whose stamp was refused is released when it is gone");

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

        static const UInt32 voice[2] = {0x40903C00u, 0x12340000u};
        Byte listBuffer[64];
        MIDIEventList *voiceList = (MIDIEventList *)listBuffer;
        MIDIEventPacket *voiceEnd = MIDIEventListInit(voiceList, kMIDIProtocol_2_0);
        CharonMIDIEventListAdd(voiceList, sizeof(listBuffer), voiceEnd, 0, 2, voice);
        gObject[70].exists = 1;
        gObject[70].hasUniqueID = 1;
        (void)CharonMIDIReceive(70, voiceList);
        for (int step = 0; step < 2; step++) {
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
