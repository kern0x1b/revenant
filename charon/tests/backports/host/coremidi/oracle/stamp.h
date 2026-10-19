// Probe, shared by the host program (stamp.m) and the 6.1.3 application (emulate/coremidi/app/main.m): can an object of the release
// carry a private integer property, does it survive the owner changing the object's UniqueID, what does the read answer after the
// object is disposed, and is a reference ever given to a second object. This decides how the library tells "the same object" from
// "a reference the release gave to a new object" (CharonMIDIPorts.m). Every line names the status of the call and the value
// apart: the value is meaningful only with a noErr status.
#include <CoreMIDI/CoreMIDI.h>
#include <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

#define STAMP_KEY CFSTR("charon.owner")
#define STAMP_VALUE 0x5A5A1234

static void charon_stamp_read_proc(const MIDIPacketList *packets, void *readRefCon, void *srcConnRefCon)
{
}

// The notifications the stamp causes: a property written on an object is announced to the clients as a property change.
static int gStampChanges;

static void charon_stamp_notify(const MIDINotification *message, void *refCon)
{
    if (message->messageID != kMIDIMsgPropertyChanged)
        return;
    const MIDIObjectPropertyChangeNotification *change = (const MIDIObjectPropertyChangeNotification *)message;
    char name[64] = "";
    CFStringGetCString(change->propertyName, name, sizeof(name), kCFStringEncodingUTF8);
    gStampChanges++;
    printf("stamp: notification: property changed, object type %d, property '%s'\n", (int)change->objectType, name);
    fflush(stdout);
}

static void charon_stamp_read(const char *what, MIDIObjectRef object, CFStringRef key)
{
    SInt32 value = -1;
    OSStatus status = MIDIObjectGetIntegerProperty(object, key, &value);
    printf("stamp: %s: read status %d, value %d\n", what, (int)status, (int)value);
    fflush(stdout);
}

// Whether the object's property dictionary lists the stamp key, and how many keys it has.
static void charon_stamp_keys(const char *what, MIDIObjectRef object)
{
    CFPropertyListRef properties = NULL;
    OSStatus status = MIDIObjectGetProperties(object, &properties, false);
    int listed = 0;
    long count = 0;
    if (status == noErr && properties && CFGetTypeID(properties) == CFDictionaryGetTypeID()) {
        count = (long)CFDictionaryGetCount((CFDictionaryRef)properties);
        listed = CFDictionaryContainsKey((CFDictionaryRef)properties, STAMP_KEY);
    }
    printf("stamp: %s: properties status %d, %ld keys, stamp key listed %d\n", what, (int)status, count, listed);
    fflush(stdout);
    if (properties)
        CFRelease(properties);
}

// One object kind through its life: stamp, read back, (a destination or source: the owner sets the UniqueID), dispose, read.
static void charon_stamp_life(const char *kind, MIDIObjectRef object, int ownerSetsUniqueID, void (*dispose)(MIDIObjectRef))
{
    char what[96];
    snprintf(what, sizeof(what), "%s before the stamp", kind);
    charon_stamp_read(what, object, STAMP_KEY);
    OSStatus status = MIDIObjectSetIntegerProperty(object, STAMP_KEY, STAMP_VALUE);
    printf("stamp: %s: set status %d\n", kind, (int)status);
    fflush(stdout);
    snprintf(what, sizeof(what), "%s after the stamp", kind);
    charon_stamp_read(what, object, STAMP_KEY);
    charon_stamp_keys(kind, object);
    if (ownerSetsUniqueID) {
        OSStatus set = MIDIObjectSetIntegerProperty(object, kMIDIPropertyUniqueID, 0x1234ABC);
        printf("stamp: %s: owner sets UniqueID 0x1234ABC, status %d\n", kind, (int)set);
        fflush(stdout);
        snprintf(what, sizeof(what), "%s UniqueID after the owner set it", kind);
        charon_stamp_read(what, object, kMIDIPropertyUniqueID);
        snprintf(what, sizeof(what), "%s stamp after the owner set the UniqueID", kind);
        charon_stamp_read(what, object, STAMP_KEY);
    }
    dispose(object);
    snprintf(what, sizeof(what), "%s stamp after the dispose", kind);
    charon_stamp_read(what, object, STAMP_KEY);
}

static void charon_stamp_dispose_client(MIDIObjectRef object) { MIDIClientDispose((MIDIClientRef)object); }
static void charon_stamp_dispose_port(MIDIObjectRef object) { MIDIPortDispose((MIDIPortRef)object); }
static void charon_stamp_dispose_endpoint(MIDIObjectRef object) { MIDIEndpointDispose((MIDIEndpointRef)object); }

// Makes and disposes `count` objects while `live` of them are kept, and counts the references the release gave twice. The
// objects of the kind are made by make(client, out); a reference seen again is a reuse.
typedef OSStatus (*charon_stamp_make)(MIDIClientRef client, MIDIObjectRef *out);

static OSStatus charon_stamp_make_destination(MIDIClientRef client, MIDIObjectRef *out)
{
    return MIDIDestinationCreate(client, CFSTR("charon-stamp-dest"), charon_stamp_read_proc, NULL, out);
}

static OSStatus charon_stamp_make_source(MIDIClientRef client, MIDIObjectRef *out)
{
    return MIDISourceCreate(client, CFSTR("charon-stamp-src"), out);
}

static OSStatus charon_stamp_make_port(MIDIClientRef client, MIDIObjectRef *out)
{
    return MIDIInputPortCreate(client, CFSTR("charon-stamp-in"), charon_stamp_read_proc, NULL, out);
}

static OSStatus charon_stamp_make_client(MIDIClientRef client, MIDIObjectRef *out)
{
    return MIDIClientCreate(CFSTR("charon-stamp-client"), NULL, NULL, out);
}

static void charon_stamp_churn(const char *kind, charon_stamp_make make, MIDIClientRef client,
                               void (*dispose)(MIDIObjectRef), int count)
{
    MIDIObjectRef *seen = calloc((size_t)count, sizeof(MIDIObjectRef));
    int reused = 0, failed = 0, ascending = 0;
    MIDIObjectRef held[8] = {0};
    for (int i = 0; i < count; i++) {
        MIDIObjectRef object = 0;
        if (make(client, &object) != noErr) {
            failed++;
            continue;
        }
        for (int j = 0; j < i; j++)
            if (seen[j] == object)
                reused++;
        if (i > 0 && object > seen[i - 1])
            ascending++;
        seen[i] = object;
        // A few objects stay alive across the churn: a reference that is live must not be given again.
        if (i % 50 == 0 && i / 50 < 8)
            held[i / 50] = object;
        else
            dispose(object);
    }
    int heldReused = 0;
    for (int k = 0; k < 8; k++)
        if (held[k])
            for (int j = 0; j < count; j++)
                if (seen[j] == held[k] && j != k * 50)
                    heldReused++;
    printf("stamp: %s churn: %d made, %d failed, %d references seen again, %d ascending, %d of the live ones given twice\n",
           kind, count, failed, reused, ascending, heldReused);
    fflush(stdout);
    for (int k = 0; k < 8; k++)
        if (held[k])
            dispose(held[k]);
    free(seen);
}

static void charon_stamp_probe(void)
{
    MIDIClientRef client = 0;
    OSStatus status = MIDIClientCreate(CFSTR("charon-stamp"), charon_stamp_notify, NULL, &client);
    printf("stamp: client create status %d\n", (int)status);
    fflush(stdout);
    if (status != noErr)
        return;
    MIDIEndpointRef dest = 0, src = 0;
    MIDIPortRef input = 0, output = 0;
    MIDIClientRef other = 0;
    if (MIDIDestinationCreate(client, CFSTR("charon-stamp-d"), charon_stamp_read_proc, NULL, &dest) == noErr)
        charon_stamp_life("destination", dest, 1, charon_stamp_dispose_endpoint);
    if (MIDISourceCreate(client, CFSTR("charon-stamp-s"), &src) == noErr)
        charon_stamp_life("source", src, 1, charon_stamp_dispose_endpoint);
    if (MIDIInputPortCreate(client, CFSTR("charon-stamp-i"), charon_stamp_read_proc, NULL, &input) == noErr)
        charon_stamp_life("input port", input, 0, charon_stamp_dispose_port);
    if (MIDIOutputPortCreate(client, CFSTR("charon-stamp-o"), &output) == noErr)
        charon_stamp_life("output port", output, 0, charon_stamp_dispose_port);
    if (MIDIClientCreate(CFSTR("charon-stamp-c"), NULL, NULL, &other) == noErr)
        charon_stamp_life("client", other, 0, charon_stamp_dispose_client);
    // Notifications are delivered on this thread's run loop: let the ones queued so far arrive, then count them.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, false);
    printf("stamp: %d property change notification(s) in all\n", gStampChanges);
    fflush(stdout);
    charon_stamp_churn("destination", charon_stamp_make_destination, client, charon_stamp_dispose_endpoint, 300);
    charon_stamp_churn("source", charon_stamp_make_source, client, charon_stamp_dispose_endpoint, 300);
    charon_stamp_churn("input port", charon_stamp_make_port, client, charon_stamp_dispose_port, 300);
    charon_stamp_churn("client", charon_stamp_make_client, client, charon_stamp_dispose_client, 100);
    MIDIClientDispose(client);
}
