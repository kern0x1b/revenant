#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/CoreMIDI.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <stdlib.h>

int revenant_roundtrip_run(void);

#ifdef REVENANT_6_1_3_PROBE
#include "../../../host/coremidi/oracle/stamp.h"
#include "../../../host/coremidi/oracle/disposewait.h"

static void revenant_probe_read(const MIDIPacketList *packets, void *readRefCon, void *srcConnRefCon)
{
}

static int gProbeRemovals;

static void revenant_probe_notify(const MIDINotification *message, void *refCon)
{
    if (message->messageID != kMIDIMsgObjectRemoved)
        return;
    gProbeRemovals++;
    const MIDIObjectAddRemoveNotification *note = (const MIDIObjectAddRemoveNotification *)message;
    printf("probe 6.1.3: removal notification: childType %d, child ref %u\n", (int)note->childType, (unsigned)note->child);
    fflush(stdout);
}

static void revenant_probe_unique(const char *label, MIDIObjectRef object)
{
    SInt32 value = -1;
    OSStatus status = MIDIObjectGetIntegerProperty(object, kMIDIPropertyUniqueID, &value);
    printf("probe 6.1.3: %s, ref %u: UniqueID read status %d, value %d\n", label, (unsigned)object, (int)status, (int)value);
    fflush(stdout);
}

static void revenant_probe_umpkey(const char *label, MIDIObjectRef object, CFStringRef key)
{
    SInt32 value = -1;
    OSStatus status = MIDIObjectGetIntegerProperty(object, key, &value);
    printf("probe 6.1.3: %s: status %d, value %d\n", label, (int)status, (int)value);
    fflush(stdout);
}

static void revenant_probe_selectors(void)
{
    void *handle = dlopen("/System/Library/Frameworks/CoreBluetooth.framework/CoreBluetooth", RTLD_NOW);
    Class peripheral = NSClassFromString(@"CBPeripheral");
    printf("probe 6.1.3: CoreBluetooth loaded %d, CBPeripheral %s\n", handle != NULL, peripheral ? "present" : "absent");
    if (peripheral) {
        printf("probe 6.1.3: CBPeripheral responds to identifier %d, to UUID %d\n",
               (int)[peripheral instancesRespondToSelector:@selector(identifier)],
               (int)[peripheral instancesRespondToSelector:@selector(UUID)]);
    }
    fflush(stdout);
}

static void revenant_probe_objects(void)
{
    MIDIClientRef client = 0;
    OSStatus clientStatus = MIDIClientCreate(CFSTR("revenant-probe"), NULL, NULL, &client);
    printf("probe 6.1.3: client create status %d\n", (int)clientStatus);
    fflush(stdout);
    if (clientStatus != noErr)
        return;
    revenant_probe_unique("client live", client);

    MIDIEndpointRef dest = 0;
    OSStatus created = MIDIDestinationCreate(client, CFSTR("revenant-probe-dest"), revenant_probe_read, NULL, &dest);
    printf("probe 6.1.3: destination create status %d\n", (int)created);
    fflush(stdout);
    if (created == noErr) {
        revenant_probe_unique("destination live", dest);
        revenant_probe_umpkey("destination UMP key 'active group bitmap'", dest, CFSTR("active group bitmap"));
        revenant_probe_umpkey("destination UMP key 'ump endpoint'", dest, CFSTR("ump endpoint"));
        revenant_probe_umpkey("destination UMP key 'associated endpoint'", dest, CFSTR("associated endpoint"));
        MIDIEndpointDispose(dest);
        revenant_probe_unique("destination disposed", dest);
    }

    MIDIEndpointRef src = 0;
    OSStatus srcStatus = MIDISourceCreate(client, CFSTR("revenant-probe-src"), &src);
    printf("probe 6.1.3: source create status %d\n", (int)srcStatus);
    fflush(stdout);
    if (srcStatus == noErr) {
        revenant_probe_unique("source live", src);
        MIDIEndpointDispose(src);
        revenant_probe_unique("source disposed", src);
    }

    MIDIPortRef port = 0;
    OSStatus portStatus = MIDIInputPortCreate(client, CFSTR("revenant-probe-in"), revenant_probe_read, NULL, &port);
    printf("probe 6.1.3: input port create status %d\n", (int)portStatus);
    fflush(stdout);
    if (portStatus == noErr) {
        revenant_probe_unique("input port live", port);
        MIDIPortDispose(port);
        revenant_probe_unique("input port disposed", port);
    }

    ItemCount devices = MIDIGetNumberOfDevices();
    printf("probe 6.1.3: setup devices %lu\n", (unsigned long)devices);
    fflush(stdout);
    if (devices > 0) {
        MIDIDeviceRef device = MIDIGetDevice(0);
        MIDIEntityRef entity = 0;
        OSStatus entityStatus = MIDIDeviceNewEntity(device, CFSTR("revenant-probe-entity"), kMIDIProtocol_2_0, false, 0, 0, &entity);
        printf("probe 6.1.3: MIDIDeviceNewEntity (protocol 2.0) status %d, entity ref %u\n", (int)entityStatus, (unsigned)entity);
        fflush(stdout);
        if (entityStatus == noErr) {
            revenant_probe_umpkey("entity protocol read back", entity, CFSTR("protocol"));
            OSStatus removed = MIDIDeviceRemoveEntity(device, entity);
            printf("probe 6.1.3: MIDIDeviceRemoveEntity status %d\n", (int)removed);
            fflush(stdout);
        }
    }
    MIDIClientDispose(client);
    revenant_probe_unique("client disposed", client);

    MIDIClientRef notifying = 0;
    if (MIDIClientCreate(CFSTR("revenant-probe-notify"), revenant_probe_notify, NULL, &notifying) == noErr) {
        MIDIEndpointRef first = 0, second = 0;
        MIDIDestinationCreate(notifying, CFSTR("revenant-probe-first"), revenant_probe_read, NULL, &first);
        MIDIEndpointDispose(first);
        MIDIDestinationCreate(notifying, CFSTR("revenant-probe-second"), revenant_probe_read, NULL, &second);
        printf("probe 6.1.3: destination ref after a dispose: first %u, second %u\n", (unsigned)first, (unsigned)second);
        fflush(stdout);
        MIDIEndpointDispose(second);
        MIDIEndpointRef noted = 0;
        if (MIDISourceCreate(notifying, CFSTR("revenant-probe-noted-src"), &noted) == noErr)
            MIDIEndpointDispose(noted);
        for (int i = 0; i < 200 && gProbeRemovals < 3; i++)
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
        printf("probe 6.1.3: removal notifications received: %d (this block disposed two destinations and a source; the release also posts the removals of the objects disposed before it to a client made after them)\n", gProbeRemovals);
        fflush(stdout);
        MIDIClientDispose(notifying);
    }
}

static void revenant_probe_list_keys(const char *label, MIDIObjectRef object)
{
    CFPropertyListRef properties = NULL;
    OSStatus status = MIDIObjectGetProperties(object, &properties, true);
    if (status != noErr || !properties || CFGetTypeID(properties) != CFDictionaryGetTypeID()) {
        printf("probe 6.1.3: %s: properties status %d\n", label, (int)status);
        fflush(stdout);
        if (properties)
            CFRelease(properties);
        return;
    }
    CFDictionaryRef dictionary = (CFDictionaryRef)properties;
    CFIndex count = CFDictionaryGetCount(dictionary);
    const void **keys = malloc((size_t)count * sizeof(void *));
    CFDictionaryGetKeysAndValues(dictionary, keys, NULL);
    printf("probe 6.1.3: %s: properties status %d, %ld keys:", label, (int)status, (long)count);
    for (CFIndex i = 0; i < count; i++) {
        char name[128];
        if (CFGetTypeID(keys[i]) == CFStringGetTypeID() && CFStringGetCString(keys[i], name, sizeof(name), kCFStringEncodingUTF8))
            printf(" '%s'", name);
    }
    printf("\n");
    fflush(stdout);
    free(keys);
    CFRelease(properties);
}

static dispatch_semaphore_t gProbeArrival;
static UInt32 gProbeWords[8];
static int gProbeWordCount = -1;
static int gProbeProtocol = -1;

static void revenant_probe_connection(void)
{
    MIDIClientRef client = 0;
    if (MIDIClientCreate(CFSTR("revenant-probe-conn"), NULL, NULL, &client) != noErr)
        return;
    gProbeArrival = dispatch_semaphore_create(0);
    MIDIEndpointRef src = 0;
    MIDIPortRef port = 0;
    OSStatus srcStatus = MIDISourceCreateWithProtocol(client, CFSTR("revenant-probe-src2"), kMIDIProtocol_2_0, &src);
    OSStatus portStatus = MIDIInputPortCreateWithProtocol(client, CFSTR("revenant-probe-in2"), kMIDIProtocol_2_0, &port,
        ^(const MIDIEventList *list, void *srcConnRefCon) {
            if (list->numPackets > 0 && gProbeWordCount < 0) {
                const MIDIEventPacket *packet = &list->packet[0];
                gProbeProtocol = (int)list->protocol;
                gProbeWordCount = packet->wordCount < 8 ? (int)packet->wordCount : 8;
                for (int i = 0; i < gProbeWordCount; i++)
                    gProbeWords[i] = packet->words[i];
            }
            dispatch_semaphore_signal(gProbeArrival);
        });
    printf("probe 6.1.3: 2.0 source status %d, 2.0 input port status %d\n", (int)srcStatus, (int)portStatus);
    fflush(stdout);
    if (srcStatus == noErr && portStatus == noErr) {
        revenant_probe_list_keys("source before connect", src);
        revenant_probe_list_keys("port before connect", port);
        OSStatus connected = MIDIPortConnectSource(port, src, NULL);
        printf("probe 6.1.3: MIDIPortConnectSource status %d\n", (int)connected);
        fflush(stdout);
        revenant_probe_list_keys("source after connect", src);
        revenant_probe_list_keys("port after connect", port);
        Byte buffer[64];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 words[2] = {0x40903C00u, 0x12340000u};
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        MIDIEventListAdd(list, sizeof(buffer), end, 0, 2, words);
        OSStatus received = MIDIReceivedEventList(src, list);
        int arrived = dispatch_semaphore_wait(gProbeArrival, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) == 0;
        printf("probe 6.1.3: MIDIReceivedEventList status %d, arrived %d, protocol %d, %d words:", (int)received, arrived, gProbeProtocol, gProbeWordCount);
        for (int i = 0; i < gProbeWordCount; i++)
            printf(" %08X", (unsigned)gProbeWords[i]);
        printf("\n");
        fflush(stdout);
        MIDIPortDisconnectSource(port, src);
    }
    if (portStatus == noErr)
        MIDIPortDispose(port);
    if (srcStatus == noErr)
        MIDIEndpointDispose(src);
    MIDIClientDispose(client);
}

#endif

static void revenant_probe_wrap_send(void)
{
    Byte buffer[64];
    MIDIEventList *list = (MIDIEventList *)buffer;
    list->protocol = kMIDIProtocol_2_0;
    list->numPackets = 1;
    list->packet[0].timeStamp = 0;
    list->packet[0].wordCount = 536870913;
    printf("probe 6.1.3 wrap: MIDISendEventList, one packet of wordCount 536870913, list of 64 bytes\n");
    fflush(stdout);
    OSStatus status = MIDISendEventList(0, 0, list);
    printf("probe 6.1.3 wrap: MIDISendEventList status %d\n", (int)status);
    fflush(stdout);
}

static void revenant_probe_wrap_add(void)
{
    Byte buffer[64];
    MIDIEventList *list = (MIDIEventList *)buffer;
    list->protocol = kMIDIProtocol_2_0;
    list->numPackets = 0;
    UInt32 word = 0;
    printf("probe 6.1.3 wrap: MIDIEventListAdd, wordCount 1073741819, into 64 bytes\n");
    fflush(stdout);
    MIDIEventPacket *next = MIDIEventListAdd(list, sizeof(buffer), &list->packet[0], 0, 1073741819, &word);
    printf("probe 6.1.3 wrap: MIDIEventListAdd %s, numPackets %u\n", next ? "accepted" : "refused", (unsigned)list->numPackets);
    fflush(stdout);
}

@interface RevenantAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
#ifndef REVENANT_NO_AUDIO_SESSION
    OSStatus session = AudioSessionInitialize(NULL, NULL, NULL, NULL);
    UInt32 category = kAudioSessionCategory_MediaPlayback;
    OSStatus category_status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    OSStatus active = AudioSessionSetActive(true);
    printf("audio session: initialize %d, category %d, active %d\n", (int)session, (int)category_status, (int)active);
    fflush(stdout);
#else
    printf("audio session: not activated (REVENANT_NO_AUDIO_SESSION)\n");
    fflush(stdout);
#endif
#ifdef REVENANT_6_1_3_PROBE
    revenant_probe_selectors();
#endif
    revenant_probe_wrap_send();
    revenant_probe_wrap_add();
#ifdef REVENANT_6_1_3_PROBE
    revenant_probe_objects();
    revenant_probe_connection();
    revenant_stamp_probe();
    revenant_dispose_wait_probe();
#endif
    int failures = revenant_roundtrip_run();
    printf("application exit: %d\n", failures);
    fflush(stdout);
    exit(failures);
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantAppDelegate class]));
    }
}
