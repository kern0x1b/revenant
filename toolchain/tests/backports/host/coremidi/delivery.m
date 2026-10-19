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

static int drain_queue(void)
{
    CharonMIDISend(gOut, gSentinel, gSentinelList);
    if (dispatch_semaphore_wait(gSentinelSeen, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC)) == 0)
        return 1;
    expect(0, "the queue is served: the sentinel is called within five seconds", 0);
    return 0;
}

static int wait_started(void)
{
    for (int i = 0; i < 30000; i++) {
        if (__atomic_load_n(&gP.started, __ATOMIC_ACQUIRE) > 0)
            return 1;
        usleep(100);
    }
    return 0;
}

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
