// The in-process deliveries of this library's destinations against the dispose of their endpoint, on the host's own CoreMIDI
// (process-lifetime virtual endpoints; nothing persists, which prefs-bracket.sh checks). The release's destinations run nothing
// after their dispose has returned; a destination this library made must not either, and the library checks each delivery's object
// right before its call, so a delivery whose check begins after the dispose returned is not called. Three cases:
//   - test E: one call held inside its block, two deliveries queued behind it, the dispose issued and returned while the call is
//     held, then the call released. The queued deliveries must not be called. The release's destination is the control: its dispose
//     waits for the held read.
//   - the hold rounds: test E repeated over 200 rounds with 31 deliveries queued behind the held call. Asserted: no call after its dispose.
//   - the race: 200 trials of 32 fast messages, the dispose issued once the first call has begun, nothing held. A dispose can land
//     between a delivery's check and its call, the gap the code does not bound. The count and the latest lateness are recorded, not
//     asserted: the code gives no bound to assert.
//   - the drain cost: 20000 messages to a live destination, the pipeline's ns per message, median of five runs (recorded, not asserted).
// A wait for the queue to be served uses a sentinel: a live destination of the library whose delivery is queued last, so its call
// means every earlier delivery has been served. A wait that times out fails the run.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#import "CharonCoreMIDI.h"

static int gFailures;
static MIDIClientRef gClient;
static MIDIPortRef gOut;
static double gNsPerTick;
static MIDIEndpointRef gSentinel;
static MIDIEventList *gSentinelList;
static uint8_t gSentinelStorage[64] __attribute__((aligned(8)));
static dispatch_semaphore_t gSentinelSeen;

static void expect(int passed, const char *what, long value)
{
    printf("%s %s (%ld)\n", passed ? "ok" : "FAIL", what, value);
    if (!passed)
        gFailures++;
}

// What the receive procedures record: the calls begun, the calls begun after the dispose returned, and how long after it the latest
// such call began. The dispose time is set by the disposing thread when its dispose has returned (0 before that). A call that is armed
// (the first call of a round) signals that it is inside its block, and waits to be released.
typedef struct {
    dispatch_semaphore_t entered;
    dispatch_semaphore_t go;
    long started;
    long afterDispose;
    uint64_t lateMax;
    uint64_t disposed;
    int armed;
} probe_state;
static probe_state gP;

static void record_call(void)
{
    uint64_t now = mach_absolute_time();
    __atomic_add_fetch(&gP.started, 1, __ATOMIC_ACQ_REL);
    uint64_t disposed = __atomic_load_n(&gP.disposed, __ATOMIC_ACQUIRE);
    if (disposed && now > disposed) {
        __atomic_add_fetch(&gP.afterDispose, 1, __ATOMIC_ACQ_REL);
        uint64_t late = now - disposed;
        uint64_t seen = __atomic_load_n(&gP.lateMax, __ATOMIC_ACQUIRE);
        while (late > seen && !__atomic_compare_exchange_n(&gP.lateMax, &seen, late, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE))
            ;
    }
    if (__atomic_exchange_n(&gP.armed, 0, __ATOMIC_ACQ_REL)) {
        dispatch_semaphore_signal(gP.entered);
        dispatch_semaphore_wait(gP.go, DISPATCH_TIME_FOREVER);
    }
}

static void library_receive(const MIDIEventList *list, void *refCon)
{
    (void)list;
    (void)refCon;
    record_call();
}

static void release_read(const MIDIPacketList *packets, void *refCon, void *srcConnRefCon)
{
    (void)packets;
    (void)refCon;
    (void)srcConnRefCon;
    record_call();
}

// The disposing thread: it disposes, records when the dispose returned, and signals `done` when it has one (NULL for a dispose made
// on the calling thread).
typedef struct {
    MIDIEndpointRef endpoint;
    OSStatus status;
    dispatch_semaphore_t done;
    int *entered;
} disposer;

static void *dispose_thread(void *argument)
{
    disposer *d = argument;
    if (d->entered)
        __atomic_store_n(d->entered, 1, __ATOMIC_RELEASE);
    d->status = MIDIEndpointDispose(d->endpoint);
    __atomic_store_n(&gP.disposed, mach_absolute_time(), __ATOMIC_RELEASE);
    if (d->done)
        dispatch_semaphore_signal(d->done);
    return NULL;
}

// One 2.0 note, as a list of one packet, for the library's sends.
static MIDIEventList *note(uint8_t *storage, size_t size)
{
    MIDIEventList *list = (MIDIEventList *)storage;
    MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
    UInt32 words[2] = {0x40903C00u, 0xFFFF0000u};
    CharonMIDIEventListAdd(list, size, end, 0, 2, words);
    return list;
}

static void reset_probe(void)
{
    gP.started = 0;
    gP.afterDispose = 0;
    gP.lateMax = 0;
    gP.disposed = 0;
    gP.armed = 0;
}

// Waits until the library's queue has served every delivery queued before this call: the sentinel is queued last, and its call is the
// answer. A wait that times out fails the run.
static int drain_queue(void)
{
    CharonMIDISend(gOut, gSentinel, gSentinelList);
    if (dispatch_semaphore_wait(gSentinelSeen, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC)) == 0)
        return 1;
    expect(0, "the queue is served: the sentinel is called within five seconds", 0);
    return 0;
}

// Waits until a call has begun (the first of a burst), so that the dispose is issued while the deliveries behind it are queued.
// Gives up after three seconds; the caller counts the begun calls, so a give-up is a failed count.
static int wait_started(void)
{
    for (int i = 0; i < 30000; i++) {
        if (__atomic_load_n(&gP.started, __ATOMIC_ACQUIRE) > 0)
            return 1;
        usleep(100);
    }
    return 0;
}

// One round of the hold: the first delivery is blocked inside its call, `queued` more are sent behind it, and the dispose is issued
// from another thread. The library's dispose returns while the call is blocked (it does not wait for a call it did not make); the
// blocked call is released after that; the queue is then served. Adds the calls begun and those begun after the dispose returned.
// Returns 0 when the round could not be run (the failure is printed).
static int hold_round(int queued, long *started, long *afterDispose)
{
    reset_probe();
    gP.entered = dispatch_semaphore_create(0);
    gP.go = dispatch_semaphore_create(0);
    gP.armed = 1;
    MIDIEndpointRef dest = 0;
    OSStatus made = CharonMIDIDestination(gClient, CFSTR("delivery-hold"), kMIDIProtocol_2_0, &dest, ^(const MIDIEventList *list, void *refCon) {
        library_receive(list, refCon);
    });
    if (made != noErr) {
        expect(0, "hold: the library's destination is made", made);
        return 0;
    }
    uint8_t storage[64] __attribute__((aligned(8)));
    MIDIEventList *list = note(storage, sizeof(storage));
    for (int i = 0; i < 1 + queued; i++)
        CharonMIDISend(gOut, dest, list);
    if (dispatch_semaphore_wait(gP.entered, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC)) != 0) {
        expect(0, "hold: the first delivery is inside its call", 0);
        return 0;
    }
    disposer d = {dest, noErr, dispatch_semaphore_create(0)};
    pthread_t thread;
    pthread_create(&thread, NULL, dispose_thread, &d);
    if (dispatch_semaphore_wait(d.done, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC)) != 0) {
        expect(0, "hold: the library's dispose returns while its call is blocked", 0);
        return 0;
    }
    dispatch_semaphore_signal(gP.go);
    pthread_join(thread, NULL);
    if (!drain_queue())
        return 0;
    *started += gP.started;
    *afterDispose += gP.afterDispose;
    return d.status == noErr;
}

// Test E: one round with two deliveries queued behind the blocked call. Only the blocked call is made, and none after the dispose.
static void test_e(void)
{
    long started = 0;
    long afterDispose = 0;
    if (!hold_round(2, &started, &afterDispose))
        return;
    printf("E library: calls begun %ld; begun after the dispose returned %ld\n", started, afterDispose);
    expect(afterDispose == 0, "E library: no delivery begins after its dispose returned", afterDispose);
    expect(started == 1, "E library: the two queued deliveries are not called (the one blocked call is)", started);
}

// The release's destination, the control of test E: its dispose waits for the blocked read, and no read begins after it returns. The
// release's reads are not visible to a sentinel, so the wait after the dispose is a fixed bound of this control, not a timing of the
// release. Its assertions: the dispose was entered, it was still running at the check while the read was held (the wait), and the
// count after the dispose is zero. A mutant that releases the read before the check (DELIVERY_MUTANT_NO_WAIT) must fail the wait.
static void test_release_control(void)
{
    reset_probe();
    gP.entered = dispatch_semaphore_create(0);
    gP.go = dispatch_semaphore_create(0);
    gP.armed = 1;
    MIDIEndpointRef dest = 0;
    OSStatus made = MIDIDestinationCreate(gClient, CFSTR("delivery-e-release"), release_read, NULL, &dest);
    if (made != noErr) {
        expect(0, "E release: the release's destination is made", made);
        return;
    }
    uint8_t packetStorage[64] __attribute__((aligned(8)));
    MIDIPacketList *packets = (MIDIPacketList *)packetStorage;
    Byte bytes[3] = {0x90, 60, 100};
    MIDIPacketListAdd(packets, sizeof(packetStorage), MIDIPacketListInit(packets), 0, 3, bytes);
    for (int i = 0; i < 3; i++)
        MIDISend(gOut, dest, packets);
    if (dispatch_semaphore_wait(gP.entered, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC)) != 0) {
        expect(0, "E release: the first read is inside its call", 0);
        return;
    }
    // The dispose thread sets `entered` before it calls the release's dispose. The wait is evidenced, not assumed: the dispose was
    // entered (the flag is seen, polled for up to five seconds), and it had not returned when the check ran, 20 ms later, while the
    // read was still held. A dispose that did not wait would have returned by then, and the mutant below (the read released and
    // the dispose joined before the check) is the red for that case.
    int entered = 0;
    disposer d = {dest, noErr, NULL, &entered};
    pthread_t thread;
    pthread_create(&thread, NULL, dispose_thread, &d);
#ifdef DELIVERY_MUTANT_NO_WAIT
    dispatch_semaphore_signal(gP.go);
    pthread_join(thread, NULL);
#endif
    for (int i = 0; i < 5000 && !__atomic_load_n(&entered, __ATOMIC_ACQUIRE); i++)
        usleep(1000);
    usleep(20000);
    int wasEntered = __atomic_load_n(&entered, __ATOMIC_ACQUIRE);
    int waiting = wasEntered && __atomic_load_n(&gP.disposed, __ATOMIC_ACQUIRE) == 0;
#ifndef DELIVERY_MUTANT_NO_WAIT
    dispatch_semaphore_signal(gP.go);
    pthread_join(thread, NULL);
#endif
    usleep(200000);
    printf("E release (control): dispose entered %d; reads begun %ld; begun after the dispose returned %ld; dispose status %d\n",
           wasEntered, gP.started, gP.afterDispose, (int)d.status);
    expect(wasEntered, "E release (control): the dispose is entered", wasEntered);
    expect(waiting, "E release (control): its dispose is still running at the check, while the read is held (it waits)", 0);
    expect(gP.afterDispose == 0, "E release (control): no read begins after the dispose returned", gP.afterDispose);
}

// The hold rounds: test E repeated over 200 rounds, each with 31 deliveries queued behind the blocked call.
static void test_hold_rounds(void)
{
    long started = 0;
    long afterDispose = 0;
    int rounds = 0;
    for (int round = 0; round < 200; round++) {
        if (!hold_round(31, &started, &afterDispose))
            break;
        rounds++;
    }
    printf("hold: %d rounds of one blocked call and 31 queued deliveries; calls begun %ld; begun after the dispose returned %ld\n",
           rounds, started, afterDispose);
    expect(rounds == 200, "hold: every round runs to the end", rounds);
    expect(started == rounds, "hold: only the blocked call of each round is called", started);
    expect(afterDispose == 0, "hold: no queued delivery begins after its dispose returned, in 200 rounds", afterDispose);
}

// The race: fast calls and the dispose issued once the first call of a trial has begun. Recorded, not asserted (the code gives no bound).
static void test_race(void)
{
    long began = 0;
    long started = 0;
    long afterDispose = 0;
    uint64_t late = 0;
    for (int trial = 0; trial < 200; trial++) {
        reset_probe();
        MIDIEndpointRef dest = 0;
        if (CharonMIDIDestination(gClient, CFSTR("delivery-race"), kMIDIProtocol_2_0, &dest, ^(const MIDIEventList *list, void *refCon) {
                library_receive(list, refCon);
            }) != noErr) {
            expect(0, "race: the library's destination is made", trial);
            return;
        }
        uint8_t storage[64] __attribute__((aligned(8)));
        MIDIEventList *list = note(storage, sizeof(storage));
        for (int i = 0; i < 32; i++)
            CharonMIDISend(gOut, dest, list);
        began += wait_started();
        disposer d = {dest, noErr, NULL};
        dispose_thread(&d);
        if (!drain_queue())
            return;
        started += gP.started;
        afterDispose += gP.afterDispose;
        if (gP.lateMax > late)
            late = gP.lateMax;
    }
    double lateMs = (double)late * gNsPerTick / 1000000.0;
    printf("race: 200 trials of 32 fast messages; first calls begun %ld; calls begun %ld; begun after the dispose returned %ld; latest such call %.3f ms after it\n",
           began, started, afterDispose, lateMs);
    expect(began == 200, "race: the first call of every trial begins before its dispose (so the race is measured)", began);
}

// The drain's cost per message: a live destination of the library gets BENCH_MESSAGES fast messages, and the sentinel is queued last.
// The pipeline time is the first block call to the last one, divided by the messages after the first. Each delivery reads the owner
// stamp on the drain thread (charon_drain), so the figure includes that read. Recorded as the median of BENCH_RUNS runs, not asserted
// (the count of calls per run is asserted).
#define BENCH_MESSAGES 20000
#define BENCH_RUNS 5
static uint64_t gBenchFirst;
static uint64_t gBenchLast;
static long gBenchCount;

static void bench_receive(void)
{
    uint64_t now = mach_absolute_time();
    if (gBenchCount++ == 0)
        gBenchFirst = now;
    gBenchLast = now;
}

static int compare_double(const void *a, const void *b)
{
    double x = *(const double *)a;
    double y = *(const double *)b;
    return (x > y) - (x < y);
}

static void test_drain_cost(void)
{
    MIDIEndpointRef dest = 0;
    if (CharonMIDIDestination(gClient, CFSTR("delivery-bench"), kMIDIProtocol_2_0, &dest, ^(const MIDIEventList *list, void *refCon) {
            (void)list;
            (void)refCon;
            bench_receive();
        }) != noErr) {
        expect(0, "bench: the library's destination is made", 0);
        return;
    }
    uint8_t storage[64] __attribute__((aligned(8)));
    MIDIEventList *list = note(storage, sizeof(storage));
    double ns[BENCH_RUNS];
    for (int run = 0; run < BENCH_RUNS; run++) {
        gBenchCount = 0;
        for (int i = 0; i < BENCH_MESSAGES; i++)
            CharonMIDISend(gOut, dest, list);
        if (!drain_queue())
            return;
        expect(gBenchCount == BENCH_MESSAGES, "bench: every message of the run is called", gBenchCount);
        ns[run] = (double)(gBenchLast - gBenchFirst) * gNsPerTick / (BENCH_MESSAGES - 1);
    }
    printf("bench: drain pipeline, %d messages per run, ns per message over %d runs:", BENCH_MESSAGES, BENCH_RUNS);
    for (int run = 0; run < BENCH_RUNS; run++)
        printf(" %.0f", ns[run]);
    qsort(ns, BENCH_RUNS, sizeof(double), compare_double);
    printf("; median %.0f\n", ns[BENCH_RUNS / 2]);
}

int main(void)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    gNsPerTick = (double)timebase.numer / (double)timebase.denom;
    OSStatus clientStatus = MIDIClientCreate(CFSTR("delivery"), NULL, NULL, &gClient);
    OSStatus portStatus = clientStatus == noErr ? MIDIOutputPortCreate(gClient, CFSTR("delivery-out"), &gOut) : noErr;
    if (clientStatus != noErr || portStatus != noErr) {
        printf("FAIL the client and its output port are made: MIDIClientCreate status %d, MIDIOutputPortCreate status %d\n",
               (int)clientStatus, (int)portStatus);
        return 1;
    }
    gSentinelSeen = dispatch_semaphore_create(0);
    OSStatus sentinelStatus = CharonMIDIDestination(gClient, CFSTR("delivery-sentinel"), kMIDIProtocol_2_0, &gSentinel,
                                                    ^(const MIDIEventList *list, void *refCon) {
        dispatch_semaphore_signal(gSentinelSeen);
    });
    if (sentinelStatus != noErr) {
        printf("FAIL the sentinel destination is made: status %d\n", (int)sentinelStatus);
        return 1;
    }
    gSentinelList = note(gSentinelStorage, sizeof(gSentinelStorage));
    test_e();
    test_release_control();
    test_hold_rounds();
    test_race();
    test_drain_cost();
    printf("delivery: %d failures\n", gFailures);
    return gFailures ? 1 : 0;
}
