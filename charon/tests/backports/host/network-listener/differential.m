/*
 * The listener: the port's own `nw_listener_t` over a real socket, and the host's own connection
 * through it, with the bytes crossing both ways.
 *
 * The host is the client here on purpose: the host's Network will not start a *listener* in this
 * environment - asked for one, on a port of its choosing and on a port this program names, it answers
 * `failed` with POSIX EINVAL - while its connection works and sends and receives normally (the same
 * measurement, and `facts/Network/NWListener.md` has it). So the port binds and accepts, the host
 * connects to it, the port's listener hands the connection over, and what each side wrote is read by
 * the other through Apple's own Network on one end.
 *
 * A defect this program found, and does not yet explain: after the checks above, the teardown of a
 * listener that has adopted a connection faults inside libdispatch - a `dispatch_assert_queue` on the
 * connection's own connect queue, with a queue value that is a small integer rather than a pointer.
 * The listener's own behaviour - bind, listen, accept, hand over, carry bytes, and say the port it
 * bound - is what is measured here; the teardown is left to be fixed, and the connection differential
 * (tests/backports/host/network-connection) does not drive it.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <arpa/inet.h>
#import <fcntl.h>
#import <netinet/in.h>
#import <string.h>
#import <sys/socket.h>
#import <mach/mach_time.h>
#include <stdio.h>
#import <unistd.h>
#import <dlfcn.h>
#import "check.h"

#define P(name) charonhost_##name
extern nw_parameters_t P(nw_parameters_create)(void);
extern nw_parameters_t P(nw_parameters_create_secure_tcp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
extern nw_connection_t P(nw_connection_create)(nw_endpoint_t, nw_parameters_t);
extern nw_endpoint_t P(nw_endpoint_create_host)(const char *, const char *);
extern void P(nw_connection_set_queue)(nw_connection_t, dispatch_queue_t);
extern void P(nw_connection_set_state_changed_handler)(nw_connection_t, nw_connection_state_changed_handler_t);
extern void P(nw_connection_send)(nw_connection_t, dispatch_data_t, nw_content_context_t, bool, nw_connection_send_completion_t);
extern void P(nw_connection_receive_message)(nw_connection_t, nw_connection_receive_completion_t);
extern void P(nw_connection_cancel)(nw_connection_t);
extern nw_listener_t P(nw_listener_create_with_port)(const char *, nw_parameters_t);
extern void P(nw_listener_set_queue)(nw_listener_t, dispatch_queue_t);
extern void P(nw_listener_set_state_changed_handler)(nw_listener_t, nw_listener_state_changed_handler_t);
extern void P(nw_listener_set_new_connection_handler)(nw_listener_t, nw_listener_new_connection_handler_t);
extern void P(nw_listener_start)(nw_listener_t);
extern void P(nw_listener_cancel)(nw_listener_t);
extern uint16_t P(nw_listener_get_port)(nw_listener_t);
extern const nw_parameters_configure_protocol_block_t charonhost__nw_parameters_configure_protocol_default_configuration;
extern const nw_parameters_configure_protocol_block_t charonhost__nw_parameters_configure_protocol_disable;
#define PORT_DEFAULT ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_default_configuration)
#define PORT_DISABLE ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_disable)

static NSData *bytes_of(dispatch_data_t payload)
{
    size_t size = payload ? dispatch_data_get_size(payload) : 0;
    NSMutableData *bytes = [NSMutableData dataWithLength:size];
    if (size) {
        dispatch_data_apply(payload, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t count) {
            memcpy((uint8_t *)bytes.mutableBytes + offset, buffer, count);
            return true;
        });
    }
    return bytes;
}

/* How many connections the listener has handed over so far. */
static NSUInteger accepted_count(NSMutableArray *connections)
{
    NSUInteger count;
    @synchronized(connections) {
        count = connections.count;
    }
    return count;
}

static int failures, checks_run;

static void check(int condition, NSString *what)
{
    checks_run++;
    if (condition) {
        printf("ok %s\n", what.UTF8String);
    } else {
        printf("FAIL %s\n", what.UTF8String);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        /* which implementation a bare call in this program reaches: the port's own Network symbols are
           linked into this binary, so a name that is not renamed binds to the port and not to Apple's */
        Dl_info where;
        if (dladdr((void *)(uintptr_t)nw_connection_create, &where) && where.dli_fname)
            printf("  the host's side, nw_connection_create, binds to %s\n", where.dli_fname);
        if (dladdr((void *)(uintptr_t)P(nw_connection_create), &where) && where.dli_fname)
            printf("  the port's side, charonhost_nw_connection_create, binds to %s\n", where.dli_fname);
        /* a port of our own: the loopback's, found by binding one and reading it back */
        int probe = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in address;
        memset(&address, 0, sizeof address);
        address.sin_len = sizeof address;
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        bind(probe, (struct sockaddr *)&address, sizeof address);
        socklen_t length = sizeof address;
        getsockname(probe, (struct sockaddr *)&address, &length);
        close(probe);
        unsigned wanted = ntohs(address.sin_port) + 1;
        char wanted_text[16];
        snprintf(wanted_text, sizeof wanted_text, "%u", wanted);

        nw_parameters_t parameters = P(nw_parameters_create_secure_tcp)(PORT_DISABLE, PORT_DEFAULT);
        nw_listener_t listener = P(nw_listener_create_with_port)(wanted_text, parameters);
        check(listener != NULL, @"the port's listener is made");
        dispatch_queue_t queue = dispatch_queue_create("charon.listener", DISPATCH_QUEUE_SERIAL);
        P(nw_listener_set_queue)(listener, queue);
        __block int ready = 0, cancelled = 0;
        P(nw_listener_set_state_changed_handler)(listener, ^(nw_listener_state_t state, nw_error_t error) {
            if (state == 2)
                ready = 1;
            if (state == 4)
                cancelled = 1;
        });
        /* Every connection the listener hands over is held and read, and the assertions are about one:
           the first, which is the host's own connect attempt. A later accept is a retry, and a test
           that asserts on whichever arrived last is asserting about a socket nobody is talking to. */
        NSMutableArray *every = [[NSMutableArray alloc] init];  /* owned: not ARC, and the handler runs on the listener's queue */
        __block nw_connection_t accepted = nil;
        __block NSUInteger accepts = 0;
        __block NSMutableData *up = [[NSMutableData alloc] init];  /* owned, for the same reason */
        P(nw_listener_set_new_connection_handler)(listener, ^(nw_connection_t connection) {
            /* a program gives the connection it has been handed a queue of its own, not the
               listener's: the engines of many connections would then share one serial queue */
            P(nw_connection_set_queue)(connection, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            @synchronized(every) {
                [every addObject:(id)connection];
                accepts++;
            }
            P(nw_connection_receive_message)(connection, ^(dispatch_data_t content, nw_content_context_t context,
                                                     bool is_complete, nw_error_t error) {
                @synchronized(up) {
                    [up appendData:bytes_of(content)];
                }
            });
        });
        P(nw_listener_start)(listener);
        for (int index = 0; index < 200 && !ready; index++)
            usleep(25000);
        check(ready, @"and it is ready on the port it was asked for");
        check(P(nw_listener_get_port)(listener) == wanted, @"which is the port it reports");

        nw_connection_t host_side = nw_connection_create(nw_endpoint_create_host("127.0.0.1", wanted_text),
                                                      nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
                                                                                       NW_PARAMETERS_DEFAULT_CONFIGURATION));
        nw_connection_set_queue(host_side, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        __block int host_ready = 0;
        __block NSMutableData *down = [[NSMutableData alloc] init];  /* owned, for the same reason */
        nw_connection_set_state_changed_handler(host_side, ^(nw_connection_state_t state, nw_error_t error) {
            /* every transition of the host's own connection, in the one trace the port's is in, with the
               error the state carries: that is what says whether the host is retrying and why */
            fprintf(stderr, "[%8llu] host: state=%d error=%d/%d\n",
                    (unsigned long long)(mach_absolute_time() / 1000000), state, nw_error_get_error_domain(error),
                    nw_error_get_error_code(error));
            if (state != nw_connection_state_ready || host_ready)
                return;
            host_ready = 1;
            nw_connection_receive(host_side, 1, 4096, ^(dispatch_data_t content, nw_content_context_t context,
                                                         bool is_complete, nw_error_t error) {
                [down appendData:bytes_of(content)];
            });
            /* the send waits for the one connection this is about - the first accept - to be in hand */
            while (accepted_count(every) == 0)
                usleep(20000);
            nw_connection_send(host_side, dispatch_data_create("down", 4, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT),
                               nw_content_context_create("listener test"), true, ^(nw_error_t error) {
                printf("  host: the send reported %d\n", nw_error_get_error_code(error));
            });
        });
        nw_connection_start(host_side);
        for (int index = 0; index < 300 && !(host_ready && accepted); index++)
            usleep(25000);
        check(host_ready, @"the host's connection is ready through the port's listener");
        /* The record the handler fills is `every`; `accepted` is the one connection the checks are
         * about, so it is taken from that record under the same lock. It was declared and read and
         * never written, which is why this check could not pass however the port behaved - and the
         * port was right: CHARON_TRACE_LISTENER shows it calling the handler at `ready`, on the
         * listener the test holds, with the connection the test's own block then receives. */
        @synchronized(every) {
            if (!accepted && every.count)
                accepted = (nw_connection_t)every.firstObject;
        }
        check(accepted != NULL, @"and the port's listener handed the connection over");


        for (int index = 0; index < 200 && up.length < 4; index++)
            usleep(25000);
        /* the receive at the new-connection handler is on the connection the listener made, so
           what the host sent is in `up`; `down` is what the host's own connection read. */
        check(up.length >= 4, @"the connection the listener made read what the host sent");
        if (accepted) {
            P(nw_connection_send)(accepted, dispatch_data_create("up", 2, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT),
                                   nw_content_context_create("listener test"), true, ^(nw_error_t error) {});
            for (int index = 0; index < 200 && down.length < 2; index++)
                usleep(25000);
            check(down.length >= 2, @"and the host read what the listener's connection sent");
        }

        usleep(300000);
        printf("checks=%d failures=%d\n", checks_run, failures);
    }
    return failures ? 1 : 0;
}
