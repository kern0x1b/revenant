#include <CoreMIDI/CoreMIDI.h>
#include <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <stdio.h>

static dispatch_semaphore_t gDwEntered;
static dispatch_semaphore_t gDwGo;
static volatile int gDwReturned;

static void charon_dw_read_proc(const MIDIPacketList *packets, void *readRefCon, void *srcConnRefCon)
{
    dispatch_semaphore_signal(gDwEntered);
    dispatch_semaphore_wait(gDwGo, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    gDwReturned = 1;
}

typedef struct {
    const char *kind;
    MIDIObjectRef object;
    int isPort;
    dispatch_semaphore_t done;
    volatile double milliseconds;
    volatile OSStatus status;
} charon_dw_dispose;

static double charon_dw_now(void)
{
    return (double)CFAbsoluteTimeGetCurrent() * 1000.0;
}

static void charon_dw_run(const char *kind, MIDIObjectRef object, int isPort, MIDIEndpointRef sender)
{
    Byte buffer[64];
    MIDIPacketList *list = (MIDIPacketList *)buffer;
    MIDIPacket *packet = MIDIPacketListInit(list);
    MIDIPacketListAdd(list, sizeof(buffer), packet, 0, 3, (const Byte[]){0x90, 0x3C, 0x7F});
    gDwReturned = 0;
    __block charon_dw_dispose job = {kind, object, isPort, dispatch_semaphore_create(0), -1, 0};
    OSStatus sent = isPort ? MIDIReceived(sender, list) : MIDISend((MIDIPortRef)sender, object, list);
    int entered = dispatch_semaphore_wait(gDwEntered, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
    printf("disposewait: %s: list sent status %d, read procedure entered %d\n", kind, (int)sent, entered);
    fflush(stdout);
    if (!entered) {
        printf("disposewait: %s: not measured (the procedure was not entered)\n", kind);
        fflush(stdout);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        double start = charon_dw_now();
        OSStatus status = job.isPort ? MIDIPortDispose((MIDIPortRef)job.object) : MIDIEndpointDispose((MIDIEndpointRef)job.object);
        job.milliseconds = charon_dw_now() - start;
        job.status = status;
        dispatch_semaphore_signal(job.done);
    });
    int disposed = dispatch_semaphore_wait(job.done, dispatch_time(DISPATCH_TIME_NOW, 1500 * NSEC_PER_MSEC)) == 0;
    int returnedBefore = gDwReturned;
    printf("disposewait: %s: dispose came back within 1.5 s while the read procedure was still running: %s (procedure returned: %d)\n",
           kind, disposed ? "yes" : "no", returnedBefore);
    fflush(stdout);
    dispatch_semaphore_signal(gDwGo);
    if (!disposed)
        dispatch_semaphore_wait(job.done, dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC));
    printf("disposewait: %s: dispose status %d, took %s, procedure returned %d\n", kind, (int)job.status,
           job.milliseconds < 1500 ? "under 1.5 s" : "1.5 s or more (it waited for the procedure)", gDwReturned);
    fflush(stdout);
}

static void charon_dispose_wait_probe(void)
{
    gDwEntered = dispatch_semaphore_create(0);
    gDwGo = dispatch_semaphore_create(0);
    MIDIClientRef client = 0;
    OSStatus status = MIDIClientCreate(CFSTR("charon-disposewait"), NULL, NULL, &client);
    printf("disposewait: client create status %d\n", (int)status);
    fflush(stdout);
    if (status != noErr)
        return;
    MIDIPortRef output = 0;
    MIDIOutputPortCreate(client, CFSTR("charon-dw-out"), &output);
    MIDIEndpointRef dest = 0;
    status = MIDIDestinationCreate(client, CFSTR("charon-dw-dest"), charon_dw_read_proc, NULL, &dest);
    printf("disposewait: destination create status %d\n", (int)status);
    fflush(stdout);
    if (status == noErr)
        charon_dw_run("destination", dest, 0, output);
    MIDIEndpointRef source = 0;
    MIDIPortRef input = 0;
    OSStatus sourceStatus = MIDISourceCreate(client, CFSTR("charon-dw-src"), &source);
    OSStatus portStatus = MIDIInputPortCreate(client, CFSTR("charon-dw-in"), charon_dw_read_proc, NULL, &input);
    OSStatus connect = sourceStatus == noErr && portStatus == noErr ? MIDIPortConnectSource(input, source, NULL) : -1;
    printf("disposewait: source create status %d, input port create status %d, connect status %d\n", (int)sourceStatus,
           (int)portStatus, (int)connect);
    fflush(stdout);
    if (connect == noErr)
        charon_dw_run("input port", input, 1, source);
    if (sourceStatus == noErr)
        MIDIEndpointDispose(source);
    MIDIClientDispose(client);
}
