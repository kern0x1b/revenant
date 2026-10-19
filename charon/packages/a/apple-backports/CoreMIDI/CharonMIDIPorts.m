// The protocol-aware ports and endpoints, and the list sends, of the iOS 14 API, as internal functions: the
// functions MIDIProtocol14.m exports call these, and so do the iOS 18 classes (MIDIUMP18.m), which build on the
// same endpoints. This file exports no API name: every function is CharonMIDI..., so a band whose release has the
// protocol API still gets these, where MIDIProtocol14.m is left out.
#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

#include <dispatch/dispatch.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

// Logs the first refusal of each reason, once: a packet or an event the library cannot carry is not dropped silently, and the
// same refusal is not written again for every packet that meets it, nor does one reason's refusal hide another's. The reasons
// seen are a bounded table (CHARON_REFUSED_REASONS, 16: the file has nine); the refusals of a reason that does not fit it are
// not written, and the table's being full is written once. The reason is a string literal (the macro makes a variable a compile
// error), so the table holds the pointers.
#ifndef CHARON_REFUSED_REASONS
#define CHARON_REFUSED_REASONS 16
#endif
static const char *charon_refused_seen[CHARON_REFUSED_REASONS];
static size_t charon_refused_count;
static int charon_refused_full;
static pthread_mutex_t charon_refused_lock = PTHREAD_MUTEX_INITIALIZER;

static void charon_refused_once(const char *reason)
{
    int write = 0;
    int full = 0;
    pthread_mutex_lock(&charon_refused_lock);
    int seen = 0;
    for (size_t i = 0; i < charon_refused_count && !seen; i++)
        seen = strcmp(charon_refused_seen[i], reason) == 0;
    if (!seen) {
        if (charon_refused_count < CHARON_REFUSED_REASONS) {
            charon_refused_seen[charon_refused_count++] = reason;
            write = 1;
        } else if (!charon_refused_full) {
            charon_refused_full = 1;
            full = 1;
        }
    }
    pthread_mutex_unlock(&charon_refused_lock);
    if (write)
        NSLog(@"charon: CoreMIDI refused %s (written once for this reason; later refusals of it are not written)", reason);
    if (full)
        NSLog(@"charon: CoreMIDI refused more than %d different things; the refusals of the others are not written", CHARON_REFUSED_REASONS);
}
#define charon_refused(reason) charon_refused_once("" reason)

// Stack storage of the hot paths, in 32-bit words: the list a read callback builds (512 bytes: the header, and room for about
// ten short packets), the words of one packet, the packets a send builds (the same 512 bytes), and its bytes. What does not fit
// is built on the heap, so that no list is refused for its size.
#define CHARON_STACK_LIST_WORDS 128
#define CHARON_STACK_WORDS 32
#define CHARON_STACK_BYTES 128

// The MIDI 1.0 parser of one source of a port, keyed by the reference the source was connected with (srcConnRefCon). Two
// sources are two byte streams: the SysEx one source has open does not continue on the bytes of another.
typedef struct charon_source {
    void *refCon;
    CharonMIDIParser parser;
} charon_source;

// The receive side of one port or destination: the block it was given (copied once, kept until the last reference is gone), the
// protocol its events are delivered in, the parsers of its sources, and the lock that guards those parsers. References are
// counted: the row of the owned table holds one, and every read callback, send and queued delivery that calls the block holds
// one for as long as it does. That is the lifetime rule of the block: it is called with no retain of its own (no
// objc_retainBlock, no autorelease: the sender's thread may have no pool), because the port that holds it cannot be freed under the
// call, whichever thread frees the row.
typedef struct charon_port {
    void *block;
    int protocol;
    int references;
    pthread_mutex_t lock;
    charon_source *sources;
    size_t sourceCount;
    size_t sourceCapacity;
} charon_port;

static void charon_free_port(charon_port *port);

static void charon_port_retain(charon_port *port)
{
    __atomic_add_fetch(&port->references, 1, __ATOMIC_RELAXED);
}

// The last reference frees the port and its block: the acquire-release order makes what every holder did to the port visible to
// the thread that frees it.
static void charon_port_release(charon_port *port)
{
    if (__atomic_sub_fetch(&port->references, 1, __ATOMIC_ACQ_REL) == 0)
        charon_free_port(port);
}

// Calls the port's block with a list. The port holds the block and the caller holds a reference to the port, so the call makes no
// retain of the block of its own.
static void charon_port_call(charon_port *port, const MIDIEventList *list, void *srcConnRefCon)
{
    __unsafe_unretained MIDIReceiveBlock block = (__bridge MIDIReceiveBlock)port->block;
    block(list, srcConnRefCon);
}

// The index of the first entry of a table whose reference is not before the key (or, when `after` is set, the first one after
// it). Every entry of these tables starts with its reference, and the table is sorted by it, so one search serves the owned rows
// and the routes: a binary search, with no allocation, and a midpoint that is a shift (no divide on the 32-bit size_t of the 4S).
static size_t charon_bound(const void *table, size_t count, size_t stride, MIDIObjectRef key, int after)
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

// The 2.0 parameter selection an endpoint last sent on each channel: the state the 1.0 translation carries from one list to the
// next. A route is a heap object, so its address stays put while the table of routes moves. The table keeps one reference to it
// and each send that translates through it holds another; the route's lock is held for the translation (the table's lock is not).
typedef struct charon_route {
    int references;
    pthread_mutex_t lock;
    CharonMIDIRPN rpn[16];
} charon_route;

// One entry of the table of routes: the endpoint reference, and the route the table holds a reference to.
typedef struct charon_route_entry {
    MIDIEndpointRef endpoint;
    charon_route *route;
} charon_route_entry;

// The table is sorted by endpoint reference, and every access takes the lock. The lock is held for the search and the update
// alone.
static charon_route_entry *charon_routes;
static size_t charon_route_count;
static size_t charon_route_capacity;
static pthread_mutex_t charon_lock = PTHREAD_MUTEX_INITIALIZER;

// The objects this file made with a block, and what each owns: the receive side of an input port or a destination (port), or
// the retained block of a port, destination or client that MIDIBlocks9.m made (refCon). A destination row also lets this process
// deliver to the destination itself. The release does not tell the library that an object was disposed, so a window of the rows
// is swept whenever a new one is made (charon_sweep). An object the release no longer knows answers paramErr to a UniqueID read (a destination, a
// source, an input port and a client: oracle/removal-notify-macos.txt on macOS, and the 6.1.3 probe of
// tests/backports/emulate/coremidi/app/main.m). The release may give a disposed reference to a new object, so each row also
// carries the stamp the library wrote on the object (CHARON_OWNER_KEY) when it took it: a live object that answers another
// stamp, or none, is a reference that was given again. The stamp is the library's own key, so what an application does to the
// object's UniqueID (the creator's to set) does not change the row. The rows are sorted by the object's reference (charon_bound);
// a reference the release gave again has a row for each object, and the newest row is the one that counts.
typedef struct charon_owned {
    MIDIObjectRef object;
    int destination;
    charon_port *port;
    void *refCon;
    int stamped;
    SInt32 stamp;
} charon_owned;
static charon_owned *charon_owned_rows;
static size_t charon_owned_count;
static size_t charon_owned_capacity;
static pthread_mutex_t charon_owned_lock = PTHREAD_MUTEX_INITIALIZER;

// The parser of a source of a port, made on its first list. The caller holds the port's lock. NULL when the table cannot grow.
static CharonMIDIParser *charon_source_parser(charon_port *port, void *refCon)
{
    for (size_t i = 0; i < port->sourceCount; i++)
        if (port->sources[i].refCon == refCon)
            return &port->sources[i].parser;
    if (port->sourceCount == port->sourceCapacity) {
        size_t capacity = port->sourceCapacity ? charon_grown_capacity(port->sourceCapacity, sizeof(charon_source)) : 4;
        charon_source *grown = capacity ? realloc(port->sources, capacity * sizeof(charon_source)) : NULL;
        if (!grown)
            return NULL;
        port->sources = grown;
        port->sourceCapacity = capacity;
    }
    charon_source *source = &port->sources[port->sourceCount++];
    source->refCon = refCon;
    memset(&source->parser, 0, sizeof(source->parser));
    return &source->parser;
}

// The receive thread of the release calls this with a list of MIDI 1.0 packets. Each packet becomes one event packet of the
// same time stamp, in the port's protocol. The parser is the source's own, so a SysEx that is open at the end of one list is
// continued by the next, and the list's last packet sends whatever is still held.
static void charon_read_held(charon_port *port, const MIDIPacketList *packets, void *srcConnRefCon)
{
    if (!port->block)
        return;
    // Eight bytes of event per byte of input bounds every message's words, a SysEx's included. The sizes are summed with checks:
    // the release's counts are summed into a size_t that is 32 bits on armv7.
    size_t capacity = 8;
    const MIDIPacket *packet = &packets->packet[0];
    for (UInt32 i = 0; i < packets->numPackets; i++) {
        size_t piece = 0;
        if (!charon_size_mul(&piece, 8, packet->length) || !charon_size_add(&piece, 12) || !charon_size_add(&capacity, piece)) {
            charon_refused("a list whose events do not fit the address space");
            return;
        }
        packet = MIDIPacketNext(packet);
    }
    // A list of a few short packets is built in stack storage (the read thread of the release allocates nothing for it); a list
    // that does not fit that storage is built on the heap.
    uint32_t stackList[CHARON_STACK_LIST_WORDS] __attribute__((aligned(8)));
    MIDIEventList *list = (MIDIEventList *)stackList;
    MIDIEventList *heapList = NULL;
    if (capacity > sizeof(stackList)) {
        heapList = malloc(capacity);
        if (!heapList) {
            charon_refused("a list the allocator would not give");
            return;
        }
        list = heapList;
    }
    list->protocol = port->protocol;
    list->numPackets = 0;
    MIDIEventPacket *end = &list->packet[0];
    MIDIEventPacket *last = NULL;
    UInt32 stackWords[CHARON_STACK_WORDS];
    CharonMIDIWords words;
    CharonMIDIWordsUseStorage(&words, stackWords, CHARON_STACK_WORDS);
    pthread_mutex_lock(&port->lock);
    CharonMIDIParser *parser = charon_source_parser(port, srcConnRefCon);
    if (!parser)
        charon_refused("a source whose parser cannot be made");
    packet = &packets->packet[0];
    for (UInt32 i = 0; parser && i < packets->numPackets; i++) {
        words.count = 0;
        CharonMIDIParseBytes(parser, packet->data, packet->length, port->protocol, 0, &words);
        if (i + 1 == packets->numPackets)
            CharonMIDIParseFlush(parser, 0, &words);
        if (words.failed) {
            charon_refused("the words of a packet, which could not be allocated");
        } else if (words.count > 0) {
            MIDIEventPacket *next = CharonMIDIEventListAppend(list, capacity, end, &last, packet->timeStamp, words.count, words.words);
            if (next)
                end = next;
            else
                charon_refused("an event that does not fit the list it was sized for");
        }
        packet = MIDIPacketNext(packet);
    }
    pthread_mutex_unlock(&port->lock);
    CharonMIDIWordsRelease(&words);
    if (list->numPackets > 0) {
        charon_port_call(port, list, srcConnRefCon);
    }
    free(heapList);
}

// The release's read procedure of the port's source. The reference is taken for the whole call: the release does not tell the
// library about a dispose, and a row that is found stale on another thread frees its reference, not the port under this call.
static void charon_protocol_read(const MIDIPacketList *packets, void *refCon, void *srcConnRefCon)
{
    charon_port *port = refCon;
    charon_port_retain(port);
    charon_read_held(port, packets, srcConnRefCon);
    charon_port_release(port);
}

// The protocol of an endpoint, as the port sets it. The result is the release's; a caller that cannot set it disposes the endpoint.
static OSStatus charon_set_protocol(MIDIEndpointRef endpoint, MIDIProtocolID protocol)
{
    return MIDIObjectSetIntegerProperty(endpoint, CHARON_PROTOCOL_KEY, (SInt32)protocol);
}

static charon_port *charon_new_port(MIDIProtocolID protocol, MIDIReceiveBlock block)
{
    charon_port *port = calloc(1, sizeof(charon_port));
    if (!port)
        return NULL;
    port->protocol = (int)protocol;
    port->references = 1;
    port->block = block ? (__bridge_retained void *)[block copy] : NULL;
    pthread_mutex_init(&port->lock, NULL);
    return port;
}

// The port's block is released here when the last reference goes, on the thread that drops it: a read procedure of the release can
// be the one (a row swept while its read was running), and then the block's release runs on the release's read thread, as the block
// itself runs there.
static void charon_free_port(charon_port *port)
{
    if (port->block)
        (void)(__bridge_transfer id)port->block;
    pthread_mutex_destroy(&port->lock);
    free(port->sources);
    free(port);
}

// Whether the release no longer knows an object: a UniqueID read answers paramErr for one that was disposed (and for one that
// never existed), and a live object answers something else (noErr, or -10835 for an object with no UniqueID).
static int charon_gone(MIDIObjectRef object)
{
    SInt32 uniqueID = 0;
    return MIDIObjectGetIntegerProperty(object, kMIDIPropertyUniqueID, &uniqueID) == charon_paramErr;
}

typedef enum {
    charon_object_live,
    charon_object_gone,
    charon_object_replaced
} charon_object_state;

// What a reference answers now, for the object that was taken with the given stamp (stamped is 0 when the stamp could not be
// written). paramErr is an object the release no longer knows. For a stamped object the stamp read back is the evidence of
// identity: noErr with the same value is the object; noErr with another value, or kMIDIUnknownProperty on a live object, is a
// reference that was given to a new object. Any other status (the server not answering, say) is no evidence: the object is
// kept, because freeing the port of a live object leaves the release calling into freed memory.
static charon_object_state charon_object_check(MIDIObjectRef object, int stamped, SInt32 stamp)
{
    SInt32 value = 0;
    OSStatus status = MIDIObjectGetIntegerProperty(object, CHARON_OWNER_KEY, &value);
    if (status == charon_paramErr)
        return charon_object_gone;
    if (!stamped)
        return charon_object_live;
    if (status == noErr)
        return value == stamp ? charon_object_live : charon_object_replaced;
    return status == kMIDIUnknownProperty ? charon_object_replaced : charon_object_live;
}

// Whether an owned row is stale: its object is gone, or its reference now belongs to another object.
static int charon_row_stale(const charon_owned *row)
{
    return charon_object_check(row->object, row->stamped, row->stamp) != charon_object_live;
}

// Frees what an owned row holds: the port and its block, or the retained block alone.
static void charon_free_owned(charon_owned *row)
{
    if (row->port)
        charon_port_release(row->port);
    if (row->refCon)
        (void)(__bridge_transfer id)row->refCon;
}

// The sweep is incremental. Every creation of an object looks at a window of CHARON_SWEEP_ROWS rows of the owned table and of
// CHARON_SWEEP_ROWS routes, from where the last creation stopped, so the cost of a creation is bounded (at most
// 2 * CHARON_SWEEP_ROWS property reads) however many objects the process holds, and a table of N rows is walked once in N /
// CHARON_SWEEP_ROWS creations. A stale row is therefore freed within that many creations, not at the next one: the block it holds
// is kept until then, which is a bounded delay in memory and never a wrong answer, because a delivery checks its own destination
// before it calls the block (charon_drain) and does not rely on the sweep. A process that makes no more objects sweeps nothing,
// so its stale rows and their blocks are kept until the next creation. The reads are made with no lock held: a send on another
// thread takes the table's lock and must not wait for the release. Rows are appended and inserted by other threads and removed by
// the sweeper (one at a time: charon_sweeping), so a row's index may move between the window being copied and the removal; the
// removal checks the object and the port nevertheless. The freed blocks are released after the lock is let go: a block's
// destructor is application code.
#define CHARON_SWEEP_ROWS 8
static int charon_sweeping;
static size_t charon_owned_cursor;
static size_t charon_route_cursor;

static void charon_sweep_owned_window(void)
{
    struct charon_window {
        charon_owned row;
        int stale;
    } window[CHARON_SWEEP_ROWS];
    size_t first = 0;
    size_t count = 0;
    pthread_mutex_lock(&charon_owned_lock);
    if (charon_owned_cursor >= charon_owned_count)
        charon_owned_cursor = 0;
    first = charon_owned_cursor;
    // The end of the table is looked at with a whole window (the last rows, or the whole table when it is smaller than a
    // window), not a short one: a table that grows by a row a creation would otherwise keep the cursor at its end, looking at
    // the newest row alone.
    if (charon_owned_count - first < CHARON_SWEEP_ROWS)
        first = charon_owned_count > CHARON_SWEEP_ROWS ? charon_owned_count - CHARON_SWEEP_ROWS : 0;
    while (count < CHARON_SWEEP_ROWS && first + count < charon_owned_count) {
        window[count].row = charon_owned_rows[first + count];
        window[count].stale = 0;
        count++;
    }
    pthread_mutex_unlock(&charon_owned_lock);
    size_t stale = 0;
    for (size_t i = 0; i < count; i++) {
        window[i].stale = charon_row_stale(&window[i].row);
        stale += window[i].stale ? 1 : 0;
    }
    charon_owned freed[CHARON_SWEEP_ROWS];
    size_t freedCount = 0;
    pthread_mutex_lock(&charon_owned_lock);
    if (stale) {
        // The window's rows are where they were (only inserts and this sweeper's own removals move rows); one that is not the
        // row that was read is left for a later pass.
        size_t kept = 0;
        size_t i = 0;
        for (; i < count && first + i < charon_owned_count; i++) {
            const charon_owned *row = &charon_owned_rows[first + i];
            if (window[i].stale && row->object == window[i].row.object && row->port == window[i].row.port &&
                row->refCon == window[i].row.refCon)
                freed[freedCount++] = *row;
            else
                charon_owned_rows[first + kept++] = *row;
        }
        if (freedCount) {
            size_t tail = charon_owned_count - (first + i);
            memmove(&charon_owned_rows[first + kept], &charon_owned_rows[first + i], tail * sizeof(charon_owned));
            charon_owned_count -= freedCount;
        }
        charon_owned_cursor = first + kept;
    } else {
        charon_owned_cursor = first + count;
    }
    pthread_mutex_unlock(&charon_owned_lock);
    for (size_t i = 0; i < freedCount; i++)
        charon_free_owned(&freed[i]);
}

static void charon_route_release(charon_route *route)
{
    if (__atomic_sub_fetch(&route->references, 1, __ATOMIC_ACQ_REL) == 0) {
        pthread_mutex_destroy(&route->lock);
        free(route);
    }
}

// Forgets the routes of the endpoints that are gone, a window at a time as above: a disposed endpoint sends nothing again. The reads
// are made with no lock held, so a send is never held up by the release's answer.
static void charon_prune_routes_window(void)
{
    MIDIEndpointRef window[CHARON_SWEEP_ROWS];
    charon_route *routes[CHARON_SWEEP_ROWS];
    int gone[CHARON_SWEEP_ROWS];
    size_t first = 0;
    size_t count = 0;
    pthread_mutex_lock(&charon_lock);
    if (charon_route_cursor >= charon_route_count)
        charon_route_cursor = 0;
    first = charon_route_cursor;
    if (charon_route_count - first < CHARON_SWEEP_ROWS)
        first = charon_route_count > CHARON_SWEEP_ROWS ? charon_route_count - CHARON_SWEEP_ROWS : 0;
    while (count < CHARON_SWEEP_ROWS && first + count < charon_route_count) {
        window[count] = charon_routes[first + count].endpoint;
        routes[count] = charon_routes[first + count].route;
        count++;
    }
    pthread_mutex_unlock(&charon_lock);
    size_t goneCount = 0;
    for (size_t i = 0; i < count; i++) {
        gone[i] = charon_gone(window[i]);
        goneCount += gone[i] ? 1 : 0;
    }
    charon_route *freed[CHARON_SWEEP_ROWS];
    size_t freedCount = 0;
    pthread_mutex_lock(&charon_lock);
    if (goneCount) {
        size_t kept = 0;
        size_t i = 0;
        for (; i < count && first + i < charon_route_count; i++) {
            const charon_route_entry *entry = &charon_routes[first + i];
            if (gone[i] && entry->endpoint == window[i] && entry->route == routes[i]) {
                freed[freedCount++] = entry->route;
                continue;
            }
            charon_routes[first + kept++] = *entry;
        }
        size_t tail = charon_route_count - (first + i);
        memmove(&charon_routes[first + kept], &charon_routes[first + i], tail * sizeof(charon_route_entry));
        charon_route_count -= i - kept;
        charon_route_cursor = first + kept;
    } else {
        charon_route_cursor = first + count;
    }
    pthread_mutex_unlock(&charon_lock);
    for (size_t i = 0; i < freedCount; i++)
        charon_route_release(freed[i]);
}

// One incremental sweep of the owned rows and the routes. A creation that finds a sweep running on another thread leaves it the
// work: the window it would have looked at is looked at by the next creation.
static void charon_sweep(void)
{
    if (__atomic_exchange_n(&charon_sweeping, 1, __ATOMIC_ACQUIRE))
        return;
    charon_sweep_owned_window();
    charon_prune_routes_window();
    __atomic_store_n(&charon_sweeping, 0, __ATOMIC_RELEASE);
}

// The route of an endpoint is the selection state of a reference the release may have given to another object: a new object
// that takes the reference must not inherit the state of the old one. The route is dropped when the library makes an object for
// the reference: a row (charon_own), a source (CharonMIDISource) or the Bluetooth source (CharonMIDIForgetRoute).
static void charon_route_forget(MIDIObjectRef object)
{
    charon_route *dropped = NULL;
    pthread_mutex_lock(&charon_lock);
    size_t i = charon_bound(charon_routes, charon_route_count, sizeof(charon_route_entry), object, 0);
    if (i < charon_route_count && charon_routes[i].endpoint == object) {
        dropped = charon_routes[i].route;
        memmove(&charon_routes[i], &charon_routes[i + 1], (charon_route_count - i - 1) * sizeof(charon_route_entry));
        charon_route_count--;
    }
    pthread_mutex_unlock(&charon_lock);
    if (dropped)
        charon_route_release(dropped);
}

// Records an object the library made with a block, after a sweep. A row that cannot be added (the table cannot grow) leaves the
// object untracked: its port or block is then kept for as long as the process runs.
static void charon_own(MIDIObjectRef object, int destination, charon_port *port, void *refCon)
{
    charon_owned row;
    memset(&row, 0, sizeof(row));
    row.object = object;
    row.destination = destination;
    row.port = port;
    row.refCon = refCon;
    // The stamp is a value of this process's own choosing: a reused reference may carry another library instance's stamp, and a
    // random value makes a coincidence a 2^-32 event.
    row.stamp = (SInt32)arc4random();
    row.stamped = MIDIObjectSetIntegerProperty(object, CHARON_OWNER_KEY, row.stamp) == noErr;
    charon_sweep();
    charon_route_forget(object);
    pthread_mutex_lock(&charon_owned_lock);
    if (charon_owned_count == charon_owned_capacity) {
        size_t capacity = charon_grown_capacity(charon_owned_capacity, sizeof(charon_owned));
        charon_owned *grown = capacity ? realloc(charon_owned_rows, capacity * sizeof(charon_owned)) : NULL;
        if (grown) {
            charon_owned_rows = grown;
            charon_owned_capacity = capacity;
        }
    }
    if (charon_owned_count < charon_owned_capacity) {
        // After the rows of the same reference: the newest row of a reference is the last of them.
        size_t i = charon_bound(charon_owned_rows, charon_owned_count, sizeof(charon_owned), object, 1);
        memmove(&charon_owned_rows[i + 1], &charon_owned_rows[i], (charon_owned_count - i) * sizeof(charon_owned));
        charon_owned_rows[i] = row;
        charon_owned_count++;
    }
    pthread_mutex_unlock(&charon_owned_lock);
}

// The newest destination row this process made for an endpoint, with its port retained for the caller (who releases it), and the
// stamp the row was taken with. NULL when the endpoint is not one of this process's destinations. The search reads no property: the
// object is checked by the delivery, before the block is called (charon_drain). The table's lock is held for the search alone.
// With twoOnly (the 2.0 send), a row of a 1.0 destination answers NULL with nothing retained: the port's protocol is set once, when
// the port is made, and the row holds the port while it is in the table; a row leaves the table under the lock, and its port is
// released after the lock is dropped (charon_sweep_owned_window), so the protocol is read under the lock and no reference is needed.
static charon_port *charon_destination_port(MIDIEndpointRef endpoint, int twoOnly, int *stamped, SInt32 *stamp)
{
    charon_port *port = NULL;
    pthread_mutex_lock(&charon_owned_lock);
    size_t i = charon_bound(charon_owned_rows, charon_owned_count, sizeof(charon_owned), endpoint, 1);
    while (i > 0 && charon_owned_rows[i - 1].object == endpoint) {
        const charon_owned *row = &charon_owned_rows[--i];
        if (row->destination && row->port) {
            if (twoOnly && row->port->protocol != kMIDIProtocol_2_0)
                break;
            port = row->port;
            *stamped = row->stamped;
            *stamp = row->stamp;
            charon_port_retain(port);
            break;
        }
    }
    pthread_mutex_unlock(&charon_owned_lock);
    return port;
}

// The in-process deliveries: a queue of the sends to this process's destinations, drained on one serial queue of the process, in
// the order they were made. The order of the deliveries to different destinations is the order of the sends, as before, and the
// block runs after the send has returned (oracle/removal-notify-macos.txt: the block ran after the call), on a thread of its own.
static dispatch_queue_t charon_delivery_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("charon.in-process-delivery", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

// One queued delivery: the port whose block is called (the delivery holds a reference to it), the endpoint and the stamp of the row
// it was made for, and the list, in one allocation. The sender's output port is the one a list is sent through when the endpoint
// was given to another object before the delivery ran (the release route), and `ump` says the list holds a UMP request's words.
typedef struct charon_delivery {
    struct charon_delivery *next;
    charon_port *port;
    MIDIEndpointRef endpoint;
    int stamped;
    SInt32 stamp;
    MIDIPortRef out;
    int ump;
    MIDIEventList list;
} charon_delivery;

// An allocation for a delivery of a list of `bytes` bytes (a list header, packets and words, as the caller sized them).
static charon_delivery *charon_delivery_new(size_t bytes)
{
    size_t total = offsetof(charon_delivery, list);
    if (!charon_size_add(&total, bytes))
        return NULL;
    return malloc(total);
}

// The queue of deliveries, under its own lock: a sender appends, and the drain takes from the head. One drain is scheduled at a time.
static pthread_mutex_t charon_pending_lock = PTHREAD_MUTEX_INITIALIZER;
static charon_delivery *charon_pending_head;
static charon_delivery *charon_pending_tail;
static int charon_pending_scheduled;

// A drain pass delivers at most CHARON_DRAIN_MESSAGES deliveries and runs for at most one millisecond, and then schedules the next
// pass. Each delivery checks its object (charon_object_check) right before its block is called, with no check carried over from the
// delivery before it. The queue holds destinations only, and for a destination a dispose that has returned is seen by every check
// that begins after it: measured on macOS 27 (delivery.m, the hold rounds), not shown for any other object. The code does not bound
// the time between a check and the call that follows it (the check's reply, and the drain thread's scheduling): a dispose that
// returns in that gap is followed by the call. The gap is measured, not bounded (crutches.md, the window entry; delivery.m).
#define CHARON_DRAIN_MESSAGES 16

static uint64_t charon_drain_ticks(void)
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

static void charon_drain(void *context);

static void charon_enqueue(charon_delivery *delivery)
{
    int schedule = 0;
    delivery->next = NULL;
    pthread_mutex_lock(&charon_pending_lock);
    if (charon_pending_tail)
        charon_pending_tail->next = delivery;
    else
        charon_pending_head = delivery;
    charon_pending_tail = delivery;
    if (!charon_pending_scheduled) {
        charon_pending_scheduled = 1;
        schedule = 1;
    }
    pthread_mutex_unlock(&charon_pending_lock);
    if (schedule)
        dispatch_async_f(charon_delivery_queue(), NULL, charon_drain);
}

// The release's completion of a MIDISendSysex this file queued: the UMP request is completed (when there is one), and the block is
// freed. The block holds the request and its data, which the release reads until it completes. The request is one the sender still
// owns, or none: a delivery that is sent late has no request to complete.
typedef struct charon_ump_send {
    MIDISysexSendRequest request;
    MIDISysexSendRequestUMP *umpRequest;
    // The bytes the release sends follow the struct, in the same block.
} charon_ump_send;

static void charon_ump_send_done(MIDISysexSendRequest *request)
{
    charon_ump_send *send = request->completionRefCon;
    MIDISysexSendRequestUMP *umpRequest = send->umpRequest;
    free(send);
    if (umpRequest) {
        umpRequest->complete = YES;
        if (umpRequest->completionProc)
            umpRequest->completionProc(umpRequest);
    }
}

// Sends UMP words to a destination of the release as MIDI 1.0 bytes, through its sysex send. The words are converted in stack storage
// (a short list needs no allocation for the conversion), and the bytes are copied once into the block the release's completion frees:
// the release's sysex send is asynchronous and keeps its request and data until it completes, so that block is the one allocation the
// send makes (crutches.md, the UMP sysex entry). 1 when the release has the bytes (its completion then completes the request, if there
// is one), and 0 when it has not, in which case nothing is kept and the caller completes the request.
int CharonMIDIUMPReleaseSend(MIDISysexSendRequestUMP *umpRequest, MIDIEndpointRef dest, const UInt32 *words, UInt32 count)
{
    CharonMIDIRPN rpn[16];
    memset(rpn, 0, sizeof(rpn));
    uint8_t stackBytes[CHARON_STACK_BYTES];
    CharonMIDIBytes bytes;
    CharonMIDIBytesUseStorage(&bytes, stackBytes, CHARON_STACK_BYTES);
    CharonMIDIUMPToBytes(words, count, rpn, &bytes);
    int queued = 0;
    if (bytes.count > 0 && !bytes.failed) {
        size_t total = sizeof(charon_ump_send);
        charon_ump_send *send = charon_size_add(&total, bytes.count) ? calloc(1, total) : NULL;
        if (send) {
            UInt8 *data = (UInt8 *)(send + 1);
            memcpy(data, bytes.bytes, bytes.count);
            send->umpRequest = umpRequest;
            send->request.destination = dest;
            send->request.data = data;
            send->request.bytesToSend = (UInt32)bytes.count;
            send->request.completionProc = charon_ump_send_done;
            send->request.completionRefCon = send;
            if (MIDISendSysex(&send->request) == noErr) {
                queued = 1;
            } else {
                charon_refused("a UMP sysex the release refused");
                free(send);
            }
        }
    }
    CharonMIDIBytesRelease(&bytes);
    return queued;
}

// The forward declaration of the 1.0 route: a list sent through the release, which the fallback of a delivery takes.
static OSStatus charon_send(MIDIPortRef port, MIDIEndpointRef endpoint, const MIDIEventList *list, int received);

// The endpoint was given to another object (the release reused its reference) before the delivery ran: the list takes the route a
// send to any other endpoint takes, as it would have had the reference never been this library's. A UMP request's words take the
// release's sysex route, as a UMP send to any other destination does. A refusal of the release is logged where it is made.
static void charon_fallback(charon_delivery *delivery)
{
    if (delivery->ump) {
        const MIDIEventPacket *packet = &delivery->list.packet[0];
        (void)CharonMIDIUMPReleaseSend(NULL, delivery->endpoint, packet->words, packet->wordCount);
        return;
    }
    if (charon_send(delivery->out, delivery->endpoint, &delivery->list, 0) != noErr)
        charon_refused("a send to a reference given to another object, which the release refused");
}

// Delivers one queued list, once the object's state is known: the block is called for a live object, nothing is called for a
// disposed one (the release delivers nothing to a disposed destination), and a reference that was given to another object takes the
// release's route.
static void charon_deliver_checked(charon_delivery *delivery, charon_object_state state)
{
    switch (state) {
    case charon_object_live:
        charon_port_call(delivery->port, &delivery->list, NULL);
        break;
    case charon_object_gone:
        break;
    case charon_object_replaced:
        charon_fallback(delivery);
        break;
    }
    charon_port_release(delivery->port);
    free(delivery);
}

static void charon_drain(void *context)
{
    (void)context;
    uint64_t start = mach_absolute_time();
    uint64_t limit = charon_drain_ticks();
    size_t done = 0;
    for (;;) {
        pthread_mutex_lock(&charon_pending_lock);
        charon_delivery *delivery = charon_pending_head;
        if (delivery) {
            charon_pending_head = delivery->next;
            if (!charon_pending_head)
                charon_pending_tail = NULL;
        } else {
            charon_pending_scheduled = 0;
        }
        pthread_mutex_unlock(&charon_pending_lock);
        if (!delivery)
            return;
        // The object is checked for this delivery, right before its call (see above).
        charon_object_state state = charon_object_check(delivery->endpoint, delivery->stamped, delivery->stamp);
        charon_deliver_checked(delivery, state);
        done++;
        if (done == CHARON_DRAIN_MESSAGES || mach_absolute_time() - start >= limit) {
            pthread_mutex_lock(&charon_pending_lock);
            int more = charon_pending_head != NULL;
            if (!more)
                charon_pending_scheduled = 0;
            pthread_mutex_unlock(&charon_pending_lock);
            if (more)
                dispatch_async_f(charon_delivery_queue(), NULL, charon_drain);
            return;
        }
    }
}

OSStatus CharonMIDIInputPort(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol,
                                         MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock)
{
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0)
        return charon_paramErr;
    charon_port *port = charon_new_port(protocol, receiveBlock);
    if (!port)
        return charon_memFullErr;
    OSStatus status = MIDIInputPortCreate(client, portName, charon_protocol_read, port, outPort);
    if (status != noErr)
        charon_port_release(port);
    else
        charon_own(*outPort, 0, port, NULL);
    return status;
}

// Delivers a list of UMP words verbatim to a destination this process made, in the port's protocol, through the delivery queue. NO
// when the endpoint is not one of this process's destinations; a destination that is gone takes nothing, as macOS delivers nothing to
// one (checked on the delivery, not here: the send makes no property read).
Boolean CharonMIDIDeliverInProcess(MIDIEndpointRef endpoint, const UInt32 *words, UInt32 count)
{
    int stamped = 0;
    SInt32 stamp = 0;
    charon_port *port = charon_destination_port(endpoint, 0, &stamped, &stamp);
    if (!port)
        return false;
    if (!port->block) {
        charon_port_release(port);
        return true;
    }
    // The list header, one packet's header, and the words: four bytes a word, summed with checks.
    size_t bytes = 0;
    if (!charon_size_mul(&bytes, 4, count) || !charon_size_add(&bytes, 8 + sizeof(MIDITimeStamp) + sizeof(UInt32))) {
        charon_refused("a UMP send of this many words");
        charon_port_release(port);
        return true;
    }
    charon_delivery *delivery = charon_delivery_new(bytes);
    if (!delivery) {
        charon_port_release(port);
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
    if (CharonMIDIEventListAppend(list, bytes, &list->packet[0], &last, 0, count, words)) {
        charon_enqueue(delivery);
    } else {
        free(delivery);
        charon_port_release(port);
    }
    return true;
}

// A list sent to a 2.0 destination this process made goes to its block as it is: each packet's time stamp and words, with no
// conversion to MIDI 1.0 and back, which cuts a 2.0 value to 7 bits (the release's route). NO when the endpoint is not such a
// destination, and then the list takes the release's route; a list that cannot be copied answers memFullErr and sends nothing.
static int charon_deliver_2_0(MIDIPortRef out, MIDIEndpointRef endpoint, const MIDIEventList *source, OSStatus *status)
{
    int stamped = 0;
    SInt32 stamp = 0;
    charon_port *port = charon_destination_port(endpoint, 1, &stamped, &stamp);
    if (!port)
        return 0;
    *status = noErr;
    if (!port->block) {
        charon_port_release(port);
        return 1;
    }
    size_t bytes = 16;
    const MIDIEventPacket *event = &source->packet[0];
    for (UInt32 i = 0; i < source->numPackets; i++) {
        size_t piece = 0;
        if (!charon_size_mul(&piece, 4, event->wordCount) || !charon_size_add(&piece, 16) || !charon_size_add(&bytes, piece)) {
            *status = charon_memFullErr;
            charon_refused("a 2.0 list of this many words");
            charon_port_release(port);
            return 1;
        }
        event = MIDIEventPacketNext(event);
    }
    charon_delivery *delivery = charon_delivery_new(bytes);
    if (!delivery) {
        *status = charon_memFullErr;
        charon_port_release(port);
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
        end = CharonMIDIEventListAppend(list, bytes, end, &last, event->timeStamp, event->wordCount, event->words);
        event = MIDIEventPacketNext(event);
    }
    if (end) {
        charon_enqueue(delivery);
    } else {
        *status = charon_memFullErr;
        free(delivery);
        charon_port_release(port);
    }
    return 1;
}

OSStatus CharonMIDIDestination(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol,
                                           MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock)
{
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0)
        return charon_paramErr;
    charon_port *port = charon_new_port(protocol, readBlock);
    if (!port)
        return charon_memFullErr;
    OSStatus status = MIDIDestinationCreate(client, name, charon_protocol_read, port, outDest);
    if (status != noErr) {
        charon_port_release(port);
        return status;
    }
    status = charon_set_protocol(*outDest, protocol);
    if (status != noErr) {
        // The destination is not handed out: it is disposed, and nothing of the port is kept.
        if (MIDIEndpointDispose(*outDest) != noErr)
            charon_refused("the dispose of a destination whose protocol was refused");
        charon_port_release(port);
        return status;
    }
    charon_own(*outDest, 1, port, NULL);
    return noErr;
}

// The retained block of a port, destination or client that MIDIBlocks9.m made through the release's function form: the block is
// released when the object is gone, as the rows of this file are.
void CharonMIDIOwnBlock(MIDIObjectRef object, void *retainedBlock)
{
    charon_own(object, 0, NULL, retainedBlock);
}

// Drops the route of a reference the library has just given to a new object that it makes outside this file (the Bluetooth source
// of MIDIBluetooth16.m): the route of the object the release had before is not the new object's.
void CharonMIDIForgetRoute(MIDIObjectRef object)
{
    charon_route_forget(object);
}

OSStatus CharonMIDISource(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc)
{
    if (protocol != kMIDIProtocol_1_0 && protocol != kMIDIProtocol_2_0)
        return charon_paramErr;
    OSStatus status = MIDISourceCreate(client, name, outSrc);
    if (status != noErr)
        return status;
    status = charon_set_protocol(*outSrc, protocol);
    if (status != noErr) {
        if (MIDIEndpointDispose(*outSrc) != noErr)
            charon_refused("the dispose of a source whose protocol was refused");
        return status;
    }
    // A source takes no row (sources are not swept), so its reference's route is dropped here: a source of the release's reference
    // that an old endpoint held would otherwise translate its first RPN with the old endpoint's selection.
    charon_route_forget(*outSrc);
    return noErr;
}

// The route of an endpoint, retained for the caller (who releases it), made when the endpoint has none. NULL when the route cannot be
// made or the table cannot grow. The route is made outside the table's lock, and kept only when no other thread made one meanwhile.
static charon_route *charon_route_retain(MIDIEndpointRef endpoint)
{
    pthread_mutex_lock(&charon_lock);
    size_t i = charon_bound(charon_routes, charon_route_count, sizeof(charon_route_entry), endpoint, 0);
    if (i < charon_route_count && charon_routes[i].endpoint == endpoint) {
        charon_route *route = charon_routes[i].route;
        __atomic_add_fetch(&route->references, 1, __ATOMIC_RELAXED);
        pthread_mutex_unlock(&charon_lock);
        return route;
    }
    pthread_mutex_unlock(&charon_lock);
    charon_route *made = calloc(1, sizeof(charon_route));
    if (!made)
        return NULL;
    made->references = 1;
    pthread_mutex_init(&made->lock, NULL);
    charon_route *route = NULL;
    pthread_mutex_lock(&charon_lock);
    i = charon_bound(charon_routes, charon_route_count, sizeof(charon_route_entry), endpoint, 0);
    if (i < charon_route_count && charon_routes[i].endpoint == endpoint) {
        route = charon_routes[i].route;
        __atomic_add_fetch(&route->references, 1, __ATOMIC_RELAXED);
    } else {
        if (charon_route_count == charon_route_capacity) {
            size_t capacity = charon_route_capacity ? charon_grown_capacity(charon_route_capacity, sizeof(charon_route_entry)) : 16;
            charon_route_entry *grown = capacity ? realloc(charon_routes, capacity * sizeof(charon_route_entry)) : NULL;
            if (grown) {
                charon_routes = grown;
                charon_route_capacity = capacity;
            }
        }
        if (charon_route_count < charon_route_capacity) {
            memmove(&charon_routes[i + 1], &charon_routes[i], (charon_route_count - i) * sizeof(charon_route_entry));
            charon_routes[i].endpoint = endpoint;
            charon_routes[i].route = made;
            charon_route_count++;
            made->references++;
            route = made;
        }
    }
    pthread_mutex_unlock(&charon_lock);
    if (route != made) {
        pthread_mutex_destroy(&made->lock);
        free(made);
    }
    return route;
}

// Converts an event list to MIDI 1.0 packets and hands them to the release: MIDISend for a list sent from a port,
// MIDIReceived for one that comes from a source. A list with no 1.0 form sends nothing and answers noErr, as the
// release does for an empty list; a list that cannot be converted answers memFullErr and sends nothing.
static OSStatus charon_send(MIDIPortRef port, MIDIEndpointRef endpoint, const MIDIEventList *list, int received)
{
    // The capacity is summed from the packets' word counts with checks, before any word is read: a count that wraps the size_t
    // is refused here, and no conversion reads past the list.
    size_t capacity = 16;
    const MIDIEventPacket *event = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; i++) {
        // A MIDI 1.0 packet's header and up to three bytes for each word, plus the parameter's own bytes.
        size_t piece = 0;
        if (!charon_size_mul(&piece, 8, event->wordCount) || !charon_size_add(&piece, 10) || !charon_size_add(&capacity, piece))
            return charon_memFullErr;
        event = MIDIEventPacketNext(event);
    }
    uint32_t stackPackets[CHARON_STACK_LIST_WORDS] __attribute__((aligned(8)));
    MIDIPacketList *packets = (MIDIPacketList *)stackPackets;
    MIDIPacketList *heapPackets = NULL;
    if (capacity > sizeof(stackPackets)) {
        heapPackets = malloc(capacity);
        if (!heapPackets)
            return charon_memFullErr;
        packets = heapPackets;
    }
    uint8_t stackBytes[CHARON_STACK_BYTES];
    CharonMIDIBytes bytes;
    CharonMIDIBytesUseStorage(&bytes, stackBytes, CHARON_STACK_BYTES);
    OSStatus status = noErr;
    charon_route *route = charon_route_retain(endpoint);
    if (!route) {
        status = charon_memFullErr;
    } else {
        // The route's lock is held for the translation of the whole list: the 1.0 state it carries is the route's, and no other list
        // of this endpoint may be translated on it meanwhile.
        int failed = 0;
        pthread_mutex_lock(&route->lock);
        MIDIPacket *packet = MIDIPacketListInit(packets);
        event = &list->packet[0];
        for (UInt32 i = 0; i < list->numPackets && !failed; i++) {
            bytes.count = 0;
            CharonMIDIUMPToBytes(event->words, event->wordCount, route->rpn, &bytes);
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
        charon_route_release(route);
        if (failed)
            status = charon_memFullErr;
    }
    CharonMIDIBytesRelease(&bytes);
    if (status == noErr && packets->numPackets > 0)
        status = received ? MIDIReceived(endpoint, packets) : MIDISend(port, endpoint, packets);
    free(heapPackets);
    return status;
}

OSStatus CharonMIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist)
{
    OSStatus status = noErr;
    if (charon_deliver_2_0(port, dest, evtlist, &status))
        return status;
    return charon_send(port, dest, evtlist, 0);
}

OSStatus CharonMIDIReceive(MIDIEndpointRef src, const MIDIEventList *evtlist)
{
    return charon_send(0, src, evtlist, 1);
}
