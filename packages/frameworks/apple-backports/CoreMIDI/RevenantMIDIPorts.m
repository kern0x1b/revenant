#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

#import "RevenantCoreMIDI.h"

#include <dispatch/dispatch.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#ifndef REVENANT_REFUSED_REASONS
#define REVENANT_REFUSED_REASONS 16
#endif
static const char *revenant_refused_seen[REVENANT_REFUSED_REASONS];
static size_t revenant_refused_count;
static int revenant_refused_full;
static pthread_mutex_t revenant_refused_lock = PTHREAD_MUTEX_INITIALIZER;

static void revenant_refused_once(const char *reason)
{
    int write = 0;
    int full = 0;
    pthread_mutex_lock(&revenant_refused_lock);
    int seen = 0;
    for (size_t i = 0; i < revenant_refused_count && !seen; i++)
        seen = strcmp(revenant_refused_seen[i], reason) == 0;
    if (!seen) {
        if (revenant_refused_count < REVENANT_REFUSED_REASONS) {
            revenant_refused_seen[revenant_refused_count++] = reason;
            write = 1;
        } else if (!revenant_refused_full) {
            revenant_refused_full = 1;
            full = 1;
        }
    }
    pthread_mutex_unlock(&revenant_refused_lock);
    if (write)
        NSLog(@"revenant: CoreMIDI refused %s (written once for this reason; later refusals of it are not written)", reason);
    if (full)
        NSLog(@"revenant: CoreMIDI refused more than %d different things; the refusals of the others are not written", REVENANT_REFUSED_REASONS);
}
#define revenant_refused(reason) revenant_refused_once("" reason)

#define REVENANT_STACK_LIST_WORDS 128
#define REVENANT_STACK_WORDS 32
#define REVENANT_STACK_BYTES 128

typedef struct revenant_source {
    void *refCon;
    RevenantMIDIParser parser;
} revenant_source;

typedef struct revenant_port {
    void *block;
    int protocol;
    int references;
    pthread_mutex_t lock;
    revenant_source *sources;
    size_t sourceCount;
    size_t sourceCapacity;
} revenant_port;

static void revenant_free_port(revenant_port *port);

static void revenant_port_retain(revenant_port *port)
{
    __atomic_add_fetch(&port->references, 1, __ATOMIC_RELAXED);
}

static void revenant_port_release(revenant_port *port)
{
    if (__atomic_sub_fetch(&port->references, 1, __ATOMIC_ACQ_REL) == 0)
        revenant_free_port(port);
}

static void revenant_port_call(revenant_port *port, const MIDIEventList *list, void *srcConnRefCon)
{
    __unsafe_unretained MIDIReceiveBlock block = (__bridge MIDIReceiveBlock)port->block;
    block(list, srcConnRefCon);
}

static size_t revenant_bound(const void *table, size_t count, size_t stride, MIDIObjectRef key, int after)
{
    const char *base = table;
    size_t low = 0;
    size_t high = count;
    while (low < high) {
        size_t middle = low + ((high - low) >> 1);
        MIDIObjectRef at = *(const MIDIObjectRef *)(base + middle * stride);
        if (at < key || (after && at == key))
            low = middle + 1;
        else
            high = middle;
    }
    return low;
}

typedef struct revenant_route {
    int references;
    pthread_mutex_t lock;
    RevenantMIDIRPN rpn[16];
} revenant_route;

typedef struct revenant_route_entry {
    MIDIEndpointRef endpoint;
    revenant_route *route;
} revenant_route_entry;

static revenant_route_entry *revenant_routes;
static size_t revenant_route_count;
static size_t revenant_route_capacity;
static pthread_mutex_t revenant_lock = PTHREAD_MUTEX_INITIALIZER;

typedef struct revenant_owned {
    MIDIObjectRef object;
    int destination;
    revenant_port *port;
    void *refCon;
    int stamped;
    SInt32 stamp;
} revenant_owned;
static revenant_owned *revenant_owned_rows;
static size_t revenant_owned_count;
static size_t revenant_owned_capacity;
static pthread_mutex_t revenant_owned_lock = PTHREAD_MUTEX_INITIALIZER;

static RevenantMIDIParser *revenant_source_parser(revenant_port *port, void *refCon)
{
    for (size_t i = 0; i < port->sourceCount; i++)
        if (port->sources[i].refCon == refCon)
            return &port->sources[i].parser;
    if (port->sourceCount == port->sourceCapacity) {
        size_t capacity = port->sourceCapacity ? revenant_grown_capacity(port->sourceCapacity, sizeof(revenant_source)) : 4;
        revenant_source *grown = capacity ? realloc(port->sources, capacity * sizeof(revenant_source)) : NULL;
        if (!grown)
            return NULL;
        port->sources = grown;
        port->sourceCapacity = capacity;
    }
    revenant_source *source = &port->sources[port->sourceCount++];
    source->refCon = refCon;
    memset(&source->parser, 0, sizeof(source->parser));
    return &source->parser;
}

static void revenant_read_held(revenant_port *port, const MIDIPacketList *packets, void *srcConnRefCon)
{
    if (!port->block)
        return;
    size_t capacity = 8;
    const MIDIPacket *packet = &packets->packet[0];
    for (UInt32 i = 0; i < packets->numPackets; i++) {
        size_t piece = 0;
        if (!revenant_size_mul(&piece, 8, packet->length) || !revenant_size_add(&piece, 12) || !revenant_size_add(&capacity, piece)) {
            revenant_refused("a list whose events do not fit the address space");
            return;
        }
        packet = MIDIPacketNext(packet);
    }
    uint32_t stackList[REVENANT_STACK_LIST_WORDS] __attribute__((aligned(8)));
    MIDIEventList *list = (MIDIEventList *)stackList;
    MIDIEventList *heapList = NULL;
    if (capacity > sizeof(stackList)) {
        heapList = malloc(capacity);
        if (!heapList) {
            revenant_refused("a list the allocator would not give");
            return;
        }
        list = heapList;
    }
    list->protocol = port->protocol;
    list->numPackets = 0;
    MIDIEventPacket *end = &list->packet[0];
    MIDIEventPacket *last = NULL;
    UInt32 stackWords[REVENANT_STACK_WORDS];
    RevenantMIDIWords words;
    RevenantMIDIWordsUseStorage(&words, stackWords, REVENANT_STACK_WORDS);
    pthread_mutex_lock(&port->lock);
    RevenantMIDIParser *parser = revenant_source_parser(port, srcConnRefCon);
    if (!parser)
        revenant_refused("a source whose parser cannot be made");
    packet = &packets->packet[0];
    for (UInt32 i = 0; parser && i < packets->numPackets; i++) {
        words.count = 0;
        RevenantMIDIParseBytes(parser, packet->data, packet->length, port->protocol, 0, &words);
        if (i + 1 == packets->numPackets)
            RevenantMIDIParseFlush(parser, 0, &words);
        if (words.failed) {
            revenant_refused("the words of a packet, which could not be allocated");
        } else if (words.count > 0) {
            MIDIEventPacket *next = RevenantMIDIEventListAppend(list, capacity, end, &last, packet->timeStamp, words.count, words.words);
            if (next)
                end = next;
            else
                revenant_refused("an event that does not fit the list it was sized for");
        }
        packet = MIDIPacketNext(packet);
    }
    pthread_mutex_unlock(&port->lock);
    RevenantMIDIWordsRelease(&words);
    if (list->numPackets > 0) {
        revenant_port_call(port, list, srcConnRefCon);
    }
    free(heapList);
}

static void revenant_protocol_read(const MIDIPacketList *packets, void *refCon, void *srcConnRefCon)
{
    revenant_port *port = refCon;
    revenant_port_retain(port);
    revenant_read_held(port, packets, srcConnRefCon);
    revenant_port_release(port);
}

static OSStatus revenant_set_protocol(MIDIEndpointRef endpoint, MIDIProtocolID protocol)
{
    return MIDIObjectSetIntegerProperty(endpoint, REVENANT_PROTOCOL_KEY, (SInt32)protocol);
}

static revenant_port *revenant_new_port(MIDIProtocolID protocol, MIDIReceiveBlock block)
{
    revenant_port *port = calloc(1, sizeof(revenant_port));
    if (!port)
        return NULL;
    port->protocol = (int)protocol;
    port->references = 1;
    port->block = block ? (__bridge_retained void *)[block copy] : NULL;
    pthread_mutex_init(&port->lock, NULL);
    return port;
}

static void revenant_free_port(revenant_port *port)
{
    if (port->block)
        (void)(__bridge_transfer id)port->block;
    pthread_mutex_destroy(&port->lock);
    free(port->sources);
    free(port);
}

static int revenant_gone(MIDIObjectRef object)
{
    SInt32 uniqueID = 0;
    return MIDIObjectGetIntegerProperty(object, kMIDIPropertyUniqueID, &uniqueID) == revenant_paramErr;
}

typedef enum {
    revenant_object_live,
    revenant_object_gone,
    revenant_object_replaced
} revenant_object_state;

static revenant_object_state revenant_object_check(MIDIObjectRef object, int stamped, SInt32 stamp)
{
    SInt32 value = 0;
    OSStatus status = MIDIObjectGetIntegerProperty(object, REVENANT_OWNER_KEY, &value);
    if (status == revenant_paramErr)
        return revenant_object_gone;
    if (!stamped)
        return revenant_object_live;
    if (status == noErr)
        return value == stamp ? revenant_object_live : revenant_object_replaced;
    return status == kMIDIUnknownProperty ? revenant_object_replaced : revenant_object_live;
}

static int revenant_row_stale(const revenant_owned *row)
{
    return revenant_object_check(row->object, row->stamped, row->stamp) != revenant_object_live;
}

static void revenant_free_owned(revenant_owned *row)
{
    if (row->port)
        revenant_port_release(row->port);
    if (row->refCon)
        (void)(__bridge_transfer id)row->refCon;
}

#define REVENANT_SWEEP_ROWS 8
static int revenant_sweeping;
static size_t revenant_owned_cursor;
static size_t revenant_route_cursor;

static void revenant_sweep_owned_window(void)
{
    struct revenant_window {
        revenant_owned row;
        int stale;
    } window[REVENANT_SWEEP_ROWS];
    size_t first = 0;
    size_t count = 0;
    pthread_mutex_lock(&revenant_owned_lock);
    if (revenant_owned_cursor >= revenant_owned_count)
        revenant_owned_cursor = 0;
    first = revenant_owned_cursor;
    if (revenant_owned_count - first < REVENANT_SWEEP_ROWS)
        first = revenant_owned_count > REVENANT_SWEEP_ROWS ? revenant_owned_count - REVENANT_SWEEP_ROWS : 0;
    while (count < REVENANT_SWEEP_ROWS && first + count < revenant_owned_count) {
        window[count].row = revenant_owned_rows[first + count];
        window[count].stale = 0;
        count++;
    }
    pthread_mutex_unlock(&revenant_owned_lock);
    size_t stale = 0;
    for (size_t i = 0; i < count; i++) {
        window[i].stale = revenant_row_stale(&window[i].row);
        stale += window[i].stale ? 1 : 0;
    }
    revenant_owned freed[REVENANT_SWEEP_ROWS];
    size_t freedCount = 0;
    pthread_mutex_lock(&revenant_owned_lock);
    if (stale) {
        size_t kept = 0;
        size_t i = 0;
        for (; i < count && first + i < revenant_owned_count; i++) {
            const revenant_owned *row = &revenant_owned_rows[first + i];
            if (window[i].stale && row->object == window[i].row.object && row->port == window[i].row.port &&
                row->refCon == window[i].row.refCon)
                freed[freedCount++] = *row;
            else
                revenant_owned_rows[first + kept++] = *row;
        }
        if (freedCount) {
            size_t tail = revenant_owned_count - (first + i);
            memmove(&revenant_owned_rows[first + kept], &revenant_owned_rows[first + i], tail * sizeof(revenant_owned));
            revenant_owned_count -= freedCount;
        }
        revenant_owned_cursor = first + kept;
    } else {
        revenant_owned_cursor = first + count;
    }
    pthread_mutex_unlock(&revenant_owned_lock);
    for (size_t i = 0; i < freedCount; i++)
        revenant_free_owned(&freed[i]);
}

static void revenant_route_release(revenant_route *route)
{
    if (__atomic_sub_fetch(&route->references, 1, __ATOMIC_ACQ_REL) == 0) {
        pthread_mutex_destroy(&route->lock);
        free(route);
    }
}

static void revenant_prune_routes_window(void)
{
    MIDIEndpointRef window[REVENANT_SWEEP_ROWS];
    revenant_route *routes[REVENANT_SWEEP_ROWS];
    int gone[REVENANT_SWEEP_ROWS];
    size_t first = 0;
    size_t count = 0;
    pthread_mutex_lock(&revenant_lock);
    if (revenant_route_cursor >= revenant_route_count)
        revenant_route_cursor = 0;
    first = revenant_route_cursor;
    if (revenant_route_count - first < REVENANT_SWEEP_ROWS)
        first = revenant_route_count > REVENANT_SWEEP_ROWS ? revenant_route_count - REVENANT_SWEEP_ROWS : 0;
    while (count < REVENANT_SWEEP_ROWS && first + count < revenant_route_count) {
        window[count] = revenant_routes[first + count].endpoint;
        routes[count] = revenant_routes[first + count].route;
        count++;
    }
    pthread_mutex_unlock(&revenant_lock);
    size_t goneCount = 0;
    for (size_t i = 0; i < count; i++) {
        gone[i] = revenant_gone(window[i]);
        goneCount += gone[i] ? 1 : 0;
    }
    revenant_route *freed[REVENANT_SWEEP_ROWS];
    size_t freedCount = 0;
    pthread_mutex_lock(&revenant_lock);
    if (goneCount) {
        size_t kept = 0;
        size_t i = 0;
        for (; i < count && first + i < revenant_route_count; i++) {
            const revenant_route_entry *entry = &revenant_routes[first + i];
            if (gone[i] && entry->endpoint == window[i] && entry->route == routes[i]) {
                freed[freedCount++] = entry->route;
                continue;
            }
            revenant_routes[first + kept++] = *entry;
        }
        size_t tail = revenant_route_count - (first + i);
        memmove(&revenant_routes[first + kept], &revenant_routes[first + i], tail * sizeof(revenant_route_entry));
        revenant_route_count -= i - kept;
        revenant_route_cursor = first + kept;
    } else {
        revenant_route_cursor = first + count;
    }
    pthread_mutex_unlock(&revenant_lock);
    for (size_t i = 0; i < freedCount; i++)
        revenant_route_release(freed[i]);
}

static void revenant_sweep(void)
{
    if (__atomic_exchange_n(&revenant_sweeping, 1, __ATOMIC_ACQUIRE))
        return;
    revenant_sweep_owned_window();
    revenant_prune_routes_window();
    __atomic_store_n(&revenant_sweeping, 0, __ATOMIC_RELEASE);
}

static void revenant_route_forget(MIDIObjectRef object)
{
    revenant_route *dropped = NULL;
    pthread_mutex_lock(&revenant_lock);
    size_t i = revenant_bound(revenant_routes, revenant_route_count, sizeof(revenant_route_entry), object, 0);
    if (i < revenant_route_count && revenant_routes[i].endpoint == object) {
        dropped = revenant_routes[i].route;
        memmove(&revenant_routes[i], &revenant_routes[i + 1], (revenant_route_count - i - 1) * sizeof(revenant_route_entry));
        revenant_route_count--;
    }
    pthread_mutex_unlock(&revenant_lock);
    if (dropped)
        revenant_route_release(dropped);
}

static void revenant_own(MIDIObjectRef object, int destination, revenant_port *port, void *refCon)
{
    revenant_owned row;
    memset(&row, 0, sizeof(row));
    row.object = object;
    row.destination = destination;
    row.port = port;
    row.refCon = refCon;
    row.stamp = (SInt32)arc4random();
    row.stamped = MIDIObjectSetIntegerProperty(object, REVENANT_OWNER_KEY, row.stamp) == noErr;
    revenant_sweep();
    revenant_route_forget(object);
    pthread_mutex_lock(&revenant_owned_lock);
    if (revenant_owned_count == revenant_owned_capacity) {
        size_t capacity = revenant_grown_capacity(revenant_owned_capacity, sizeof(revenant_owned));
        revenant_owned *grown = capacity ? realloc(revenant_owned_rows, capacity * sizeof(revenant_owned)) : NULL;
        if (grown) {
            revenant_owned_rows = grown;
            revenant_owned_capacity = capacity;
        }
    }
    if (revenant_owned_count < revenant_owned_capacity) {
        size_t i = revenant_bound(revenant_owned_rows, revenant_owned_count, sizeof(revenant_owned), object, 1);
        memmove(&revenant_owned_rows[i + 1], &revenant_owned_rows[i], (revenant_owned_count - i) * sizeof(revenant_owned));
        revenant_owned_rows[i] = row;
        revenant_owned_count++;
    }
    pthread_mutex_unlock(&revenant_owned_lock);
}

static revenant_port *revenant_destination_port(MIDIEndpointRef endpoint, int twoOnly, int *stamped, SInt32 *stamp)
{
    revenant_port *port = NULL;
    pthread_mutex_lock(&revenant_owned_lock);
    size_t i = revenant_bound(revenant_owned_rows, revenant_owned_count, sizeof(revenant_owned), endpoint, 1);
    while (i > 0 && revenant_owned_rows[i - 1].object == endpoint) {
        const revenant_owned *row = &revenant_owned_rows[--i];
        if (row->destination && row->port) {
            if (twoOnly && row->port->protocol != kMIDIProtocol_2_0)
                break;
            port = row->port;
            *stamped = row->stamped;
            *stamp = row->stamp;
            revenant_port_retain(port);
            break;
        }
    }
    pthread_mutex_unlock(&revenant_owned_lock);
    return port;
}

static dispatch_queue_t revenant_delivery_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("revenant.in-process-delivery", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

typedef struct revenant_delivery {
    struct revenant_delivery *next;
    revenant_port *port;
    MIDIEndpointRef endpoint;
    int stamped;
    SInt32 stamp;
    MIDIPortRef out;
    int ump;
    MIDIEventList list;
} revenant_delivery;

static revenant_delivery *revenant_delivery_new(size_t bytes)
{
    size_t total = offsetof(revenant_delivery, list);
    if (!revenant_size_add(&total, bytes))
        return NULL;
    return malloc(total);
}

static pthread_mutex_t revenant_pending_lock = PTHREAD_MUTEX_INITIALIZER;
static revenant_delivery *revenant_pending_head;
static revenant_delivery *revenant_pending_tail;
static int revenant_pending_scheduled;

#define REVENANT_DRAIN_MESSAGES 16

static uint64_t revenant_drain_ticks(void)
{
    static uint64_t ticks;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        ticks = 1000000ull * timebase.denom / timebase.numer;
    });
    return ticks;
}

static void revenant_drain(void *context);

static void revenant_enqueue(revenant_delivery *delivery)
{
    int schedule = 0;
    delivery->next = NULL;
    pthread_mutex_lock(&revenant_pending_lock);
    if (revenant_pending_tail)
        revenant_pending_tail->next = delivery;
    else
        revenant_pending_head = delivery;
    revenant_pending_tail = delivery;
    if (!revenant_pending_scheduled) {
        revenant_pending_scheduled = 1;
        schedule = 1;
    }
    pthread_mutex_unlock(&revenant_pending_lock);
    if (schedule)
        dispatch_async_f(revenant_delivery_queue(), NULL, revenant_drain);
}

typedef struct revenant_ump_send {
    MIDISysexSendRequest request;
    MIDISysexSendRequestUMP *umpRequest;
} revenant_ump_send;

static void revenant_ump_send_done(MIDISysexSendRequest *request)
{
    revenant_ump_send *send = request->completionRefCon;
    MIDISysexSendRequestUMP *umpRequest = send->umpRequest;
    free(send);
    if (umpRequest) {
        umpRequest->complete = YES;
        if (umpRequest->completionProc)
            umpRequest->completionProc(umpRequest);
    }
}

int RevenantMIDIUMPReleaseSend(MIDISysexSendRequestUMP *umpRequest, MIDIEndpointRef dest, const UInt32 *words, UInt32 count)
{
    RevenantMIDIRPN rpn[16];
    memset(rpn, 0, sizeof(rpn));
    uint8_t stackBytes[REVENANT_STACK_BYTES];
    RevenantMIDIBytes bytes;
    RevenantMIDIBytesUseStorage(&bytes, stackBytes, REVENANT_STACK_BYTES);
    RevenantMIDIUMPToBytes(words, count, rpn, &bytes);
    int queued = 0;
    if (bytes.count > 0 && !bytes.failed) {
        size_t total = sizeof(revenant_ump_send);
        revenant_ump_send *send = revenant_size_add(&total, bytes.count) ? calloc(1, total) : NULL;
        if (send) {
            UInt8 *data = (UInt8 *)(send + 1);
            memcpy(data, bytes.bytes, bytes.count);
            send->umpRequest = umpRequest;
            send->request.destination = dest;
            send->request.data = data;
            send->request.bytesToSend = (UInt32)bytes.count;
            send->request.completionProc = revenant_ump_send_done;
            send->request.completionRefCon = send;
            if (MIDISendSysex(&send->request) == noErr) {
                queued = 1;
            } else {
                revenant_refused("a UMP sysex the release refused");
                free(send);
            }
        }
    }
    RevenantMIDIBytesRelease(&bytes);
    return queued;
}

static OSStatus revenant_send(MIDIPortRef port, MIDIEndpointRef endpoint, const MIDIEventList *list, int received);

static void revenant_fallback(revenant_delivery *delivery)
{
    if (delivery->ump) {
        const MIDIEventPacket *packet = &delivery->list.packet[0];
        (void)RevenantMIDIUMPReleaseSend(NULL, delivery->endpoint, packet->words, packet->wordCount);
        return;
    }
    if (revenant_send(delivery->out, delivery->endpoint, &delivery->list, 0) != noErr)
        revenant_refused("a send to a reference given to another object, which the release refused");
}

static void revenant_deliver_checked(revenant_delivery *delivery, revenant_object_state state)
{
    switch (state) {
    case revenant_object_live:
        revenant_port_call(delivery->port, &delivery->list, NULL);
        break;
    case revenant_object_gone:
        break;
    case revenant_object_replaced:
        revenant_fallback(delivery);
        break;
    }
    revenant_port_release(delivery->port);
    free(delivery);
}

static void revenant_drain(void *context)
{
    (void)context;
    uint64_t start = mach_absolute_time();
    uint64_t limit = revenant_drain_ticks();
    size_t done = 0;
    for (;;) {
        pthread_mutex_lock(&revenant_pending_lock);
        revenant_delivery *delivery = revenant_pending_head;
        if (delivery) {
            revenant_pending_head = delivery->next;
            if (!revenant_pending_head)
                revenant_pending_tail = NULL;
        } else {
            revenant_pending_scheduled = 0;
        }
        pthread_mutex_unlock(&revenant_pending_lock);
        if (!delivery)
            return;
        revenant_object_state state = revenant_object_check(delivery->endpoint, delivery->stamped, delivery->stamp);
        revenant_deliver_checked(delivery, state);
        done++;
        if (done == REVENANT_DRAIN_MESSAGES || mach_absolute_time() - start >= limit) {
            pthread_mutex_lock(&revenant_pending_lock);
            int more = revenant_pending_head != NULL;
            if (!more)
                revenant_pending_scheduled = 0;
            pthread_mutex_unlock(&revenant_pending_lock);
            if (more)
                dispatch_async_f(revenant_delivery_queue(), NULL, revenant_drain);
            return;
        }
    }
}

OSStatus RevenantMIDIInputPort(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol,
                                         MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock)
{
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0)
        return revenant_paramErr;
    revenant_port *port = revenant_new_port(protocol, receiveBlock);
    if (!port)
        return revenant_memFullErr;
    OSStatus status = MIDIInputPortCreate(client, portName, revenant_protocol_read, port, outPort);
    if (status != noErr)
        revenant_port_release(port);
    else
        revenant_own(*outPort, 0, port, NULL);
    return status;
}

Boolean RevenantMIDIDeliverInProcess(MIDIEndpointRef endpoint, const UInt32 *words, UInt32 count)
{
    int stamped = 0;
    SInt32 stamp = 0;
    revenant_port *port = revenant_destination_port(endpoint, 0, &stamped, &stamp);
    if (!port)
        return false;
    if (!port->block) {
        revenant_port_release(port);
        return true;
    }
    size_t bytes = 0;
    if (!revenant_size_mul(&bytes, 4, count) || !revenant_size_add(&bytes, 8 + sizeof(MIDITimeStamp) + sizeof(UInt32))) {
        revenant_refused("a UMP send of this many words");
        revenant_port_release(port);
        return true;
    }
    revenant_delivery *delivery = revenant_delivery_new(bytes);
    if (!delivery) {
        revenant_port_release(port);
        return true;
    }
    delivery->port = port;
    delivery->endpoint = endpoint;
    delivery->stamped = stamped;
    delivery->stamp = stamp;
    delivery->out = 0;
    delivery->ump = 1;
    MIDIEventList *list = &delivery->list;
    list->protocol = (MIDIProtocolID)port->protocol;
    list->numPackets = 0;
    MIDIEventPacket *last = NULL;
    if (RevenantMIDIEventListAppend(list, bytes, &list->packet[0], &last, 0, count, words)) {
        revenant_enqueue(delivery);
    } else {
        free(delivery);
        revenant_port_release(port);
    }
    return true;
}

static int revenant_deliver_2_0(MIDIPortRef out, MIDIEndpointRef endpoint, const MIDIEventList *source, OSStatus *status)
{
    int stamped = 0;
    SInt32 stamp = 0;
    revenant_port *port = revenant_destination_port(endpoint, 1, &stamped, &stamp);
    if (!port)
        return 0;
    *status = noErr;
    if (!port->block) {
        revenant_port_release(port);
        return 1;
    }
    size_t bytes = 16;
    const MIDIEventPacket *event = &source->packet[0];
    for (UInt32 i = 0; i < source->numPackets; i++) {
        size_t piece = 0;
        if (!revenant_size_mul(&piece, 4, event->wordCount) || !revenant_size_add(&piece, 16) || !revenant_size_add(&bytes, piece)) {
            *status = revenant_memFullErr;
            revenant_refused("a 2.0 list of this many words");
            revenant_port_release(port);
            return 1;
        }
        event = MIDIEventPacketNext(event);
    }
    revenant_delivery *delivery = revenant_delivery_new(bytes);
    if (!delivery) {
        *status = revenant_memFullErr;
        revenant_port_release(port);
        return 1;
    }
    delivery->port = port;
    delivery->endpoint = endpoint;
    delivery->stamped = stamped;
    delivery->stamp = stamp;
    delivery->out = out;
    delivery->ump = 0;
    MIDIEventList *list = &delivery->list;
    list->protocol = kMIDIProtocol_2_0;
    list->numPackets = 0;
    MIDIEventPacket *end = &list->packet[0];
    MIDIEventPacket *last = NULL;
    event = &source->packet[0];
    for (UInt32 i = 0; i < source->numPackets && end; i++) {
        end = RevenantMIDIEventListAppend(list, bytes, end, &last, event->timeStamp, event->wordCount, event->words);
        event = MIDIEventPacketNext(event);
    }
    if (end) {
        revenant_enqueue(delivery);
    } else {
        *status = revenant_memFullErr;
        free(delivery);
        revenant_port_release(port);
    }
    return 1;
}

OSStatus RevenantMIDIDestination(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol,
                                           MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock)
{
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0)
        return revenant_paramErr;
    revenant_port *port = revenant_new_port(protocol, readBlock);
    if (!port)
        return revenant_memFullErr;
    OSStatus status = MIDIDestinationCreate(client, name, revenant_protocol_read, port, outDest);
    if (status != noErr) {
        revenant_port_release(port);
        return status;
    }
    status = revenant_set_protocol(*outDest, protocol);
    if (status != noErr) {
        if (MIDIEndpointDispose(*outDest) != noErr)
            revenant_refused("the dispose of a destination whose protocol was refused");
        revenant_port_release(port);
        return status;
    }
    revenant_own(*outDest, 1, port, NULL);
    return noErr;
}

void RevenantMIDIOwnBlock(MIDIObjectRef object, void *retainedBlock)
{
    revenant_own(object, 0, NULL, retainedBlock);
}

void RevenantMIDIForgetRoute(MIDIObjectRef object)
{
    revenant_route_forget(object);
}

OSStatus RevenantMIDISource(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc)
{
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0)
        return revenant_paramErr;
    OSStatus status = MIDISourceCreate(client, name, outSrc);
    if (status != noErr)
        return status;
    status = revenant_set_protocol(*outSrc, protocol);
    if (status != noErr) {
        if (MIDIEndpointDispose(*outSrc) != noErr)
            revenant_refused("the dispose of a source whose protocol was refused");
        return status;
    }
    revenant_route_forget(*outSrc);
    return noErr;
}

static revenant_route *revenant_route_retain(MIDIEndpointRef endpoint)
{
    pthread_mutex_lock(&revenant_lock);
    size_t i = revenant_bound(revenant_routes, revenant_route_count, sizeof(revenant_route_entry), endpoint, 0);
    if (i < revenant_route_count && revenant_routes[i].endpoint == endpoint) {
        revenant_route *route = revenant_routes[i].route;
        __atomic_add_fetch(&route->references, 1, __ATOMIC_RELAXED);
        pthread_mutex_unlock(&revenant_lock);
        return route;
    }
    pthread_mutex_unlock(&revenant_lock);
    revenant_route *made = calloc(1, sizeof(revenant_route));
    if (!made)
        return NULL;
    made->references = 1;
    pthread_mutex_init(&made->lock, NULL);
    revenant_route *route = NULL;
    pthread_mutex_lock(&revenant_lock);
    i = revenant_bound(revenant_routes, revenant_route_count, sizeof(revenant_route_entry), endpoint, 0);
    if (i < revenant_route_count && revenant_routes[i].endpoint == endpoint) {
        route = revenant_routes[i].route;
        __atomic_add_fetch(&route->references, 1, __ATOMIC_RELAXED);
    } else {
        if (revenant_route_count == revenant_route_capacity) {
            size_t capacity = revenant_route_capacity ? revenant_grown_capacity(revenant_route_capacity, sizeof(revenant_route_entry)) : 16;
            revenant_route_entry *grown = capacity ? realloc(revenant_routes, capacity * sizeof(revenant_route_entry)) : NULL;
            if (grown) {
                revenant_routes = grown;
                revenant_route_capacity = capacity;
            }
        }
        if (revenant_route_count < revenant_route_capacity) {
            memmove(&revenant_routes[i + 1], &revenant_routes[i], (revenant_route_count - i) * sizeof(revenant_route_entry));
            revenant_routes[i].endpoint = endpoint;
            revenant_routes[i].route = made;
            revenant_route_count++;
            made->references++;
            route = made;
        }
    }
    pthread_mutex_unlock(&revenant_lock);
    if (route != made) {
        pthread_mutex_destroy(&made->lock);
        free(made);
    }
    return route;
}

static OSStatus revenant_send(MIDIPortRef port, MIDIEndpointRef endpoint, const MIDIEventList *list, int received)
{
    size_t capacity = 16;
    const MIDIEventPacket *event = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; i++) {
        size_t piece = 0;
        if (!revenant_size_mul(&piece, 8, event->wordCount) || !revenant_size_add(&piece, 10) || !revenant_size_add(&capacity, piece))
            return revenant_memFullErr;
        event = MIDIEventPacketNext(event);
    }
    uint32_t stackPackets[REVENANT_STACK_LIST_WORDS] __attribute__((aligned(8)));
    MIDIPacketList *packets = (MIDIPacketList *)stackPackets;
    MIDIPacketList *heapPackets = NULL;
    if (capacity > sizeof(stackPackets)) {
        heapPackets = malloc(capacity);
        if (!heapPackets)
            return revenant_memFullErr;
        packets = heapPackets;
    }
    uint8_t stackBytes[REVENANT_STACK_BYTES];
    RevenantMIDIBytes bytes;
    RevenantMIDIBytesUseStorage(&bytes, stackBytes, REVENANT_STACK_BYTES);
    OSStatus status = noErr;
    revenant_route *route = revenant_route_retain(endpoint);
    if (!route) {
        status = revenant_memFullErr;
    } else {
        int failed = 0;
        pthread_mutex_lock(&route->lock);
        MIDIPacket *packet = MIDIPacketListInit(packets);
        event = &list->packet[0];
        for (UInt32 i = 0; i < list->numPackets && !failed; i++) {
            bytes.count = 0;
            RevenantMIDIUMPToBytes(event->words, event->wordCount, route->rpn, &bytes);
            if (bytes.failed) {
                failed = 1;
            } else if (bytes.count > 0) {
                MIDIPacket *next = MIDIPacketListAdd(packets, capacity, packet, event->timeStamp, bytes.count, bytes.bytes);
                if (next)
                    packet = next;
                else
                    failed = 1;
            }
            event = MIDIEventPacketNext(event);
        }
        pthread_mutex_unlock(&route->lock);
        revenant_route_release(route);
        if (failed)
            status = revenant_memFullErr;
    }
    RevenantMIDIBytesRelease(&bytes);
    if (status == noErr && packets->numPackets > 0)
        status = received ? MIDIReceived(endpoint, packets) : MIDISend(port, endpoint, packets);
    free(heapPackets);
    return status;
}

OSStatus RevenantMIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist)
{
    OSStatus status = noErr;
    if (revenant_deliver_2_0(port, dest, evtlist, &status))
        return status;
    return revenant_send(port, dest, evtlist, 0);
}

OSStatus RevenantMIDIReceive(MIDIEndpointRef src, const MIDIEventList *evtlist)
{
    return revenant_send(0, src, evtlist, 1);
}
