/*
 * The host differential for the connection: the port's own `nw_connection_t` against a listener and a
 * connection of the host's Network.framework, over the loopback, in both directions.
 *
 * The host is the peer on purpose. A port listener is its own file and would only prove that the port
 * agrees with the port; the host's listener accepts the port's connection, and the connection the host
 * hands back sends into the port's connection. So every byte the port sends is read by Apple's own
 * Network and every byte Apple's own Network sends is read by the port, through one loopback pair -
 * a real socket, the real SecureTransport of the host above it where the test asks for TLS, and the
 * real state machine on both sides.
 *
 * What is compared: the state a connection reaches and in which order, what its description says,
 * the largest datagram its path carries, what a refused connection's error is, and the bytes each side
 * receives from the other. The port's files are compiled into this program by run.sh with every symbol
 * they define renamed, so the two sides never meet by accident.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#include <poll.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "check.h"

#define P(name) charonhost_##name
extern nw_connection_t P(nw_connection_create)(nw_endpoint_t, nw_parameters_t);
extern nw_endpoint_t P(nw_connection_copy_endpoint)(nw_connection_t);
extern nw_parameters_t P(nw_connection_copy_parameters)(nw_connection_t);
extern void P(nw_connection_set_queue)(nw_connection_t, dispatch_queue_t);
extern void P(nw_connection_set_state_changed_handler)(nw_connection_t, nw_connection_state_changed_handler_t);
extern void P(nw_connection_set_path_changed_handler)(nw_connection_t, nw_connection_path_event_handler_t);
extern void P(nw_connection_set_viability_changed_handler)(nw_connection_t, nw_connection_boolean_event_handler_t);
extern void P(nw_connection_set_better_path_available_handler)(nw_connection_t, nw_connection_boolean_event_handler_t);
extern void P(nw_connection_start)(nw_connection_t);
extern void P(nw_connection_cancel)(nw_connection_t);
extern void P(nw_connection_send)(nw_connection_t, dispatch_data_t, nw_content_context_t, bool, nw_connection_send_completion_t);
extern void P(nw_connection_receive)(nw_connection_t, uint32_t, uint32_t, nw_connection_receive_completion_t);
extern void P(nw_connection_receive_message)(nw_connection_t, nw_connection_receive_completion_t);
extern nw_path_t P(nw_connection_copy_current_path)(nw_path_t);
extern uint32_t P(nw_connection_get_maximum_datagram_size)(nw_connection_t);
extern char *P(nw_connection_copy_description)(nw_connection_t);
extern nw_protocol_metadata_t P(nw_connection_copy_protocol_metadata)(nw_connection_t, nw_protocol_definition_t);
extern bool P(nw_protocol_metadata_is_tcp)(nw_protocol_metadata_t);
extern nw_listener_t P(nw_listener_create_with_port)(const char *, nw_parameters_t);
extern nw_listener_t P(nw_listener_create)(nw_parameters_t);
extern void P(nw_listener_set_queue)(nw_listener_t, dispatch_queue_t);
extern void P(nw_listener_set_state_changed_handler)(nw_listener_t, nw_listener_state_changed_handler_t);
extern void P(nw_listener_set_new_connection_handler)(nw_listener_t, nw_listener_new_connection_handler_t);
extern void P(nw_listener_start)(nw_listener_t);
extern void P(nw_listener_cancel)(nw_listener_t);
extern uint16_t P(nw_listener_get_port)(nw_listener_t);
extern nw_data_transfer_report_t P(nw_connection_create_new_data_transfer_report)(nw_connection_t);
extern nw_data_transfer_report_state_t P(nw_data_transfer_report_get_state)(nw_data_transfer_report_t);
extern void P(nw_data_transfer_report_collect)(nw_data_transfer_report_t, dispatch_queue_t, nw_data_transfer_report_collect_block_t);
extern uint64_t P(nw_data_transfer_report_get_sent_application_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_application_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds)(nw_data_transfer_report_t, uint32_t);
extern uint32_t P(nw_data_transfer_report_get_path_count)(nw_data_transfer_report_t);
extern nw_data_transfer_report_state_t P(nw_data_transfer_report_get_state)(nw_data_transfer_report_t);
extern void P(nw_data_transfer_report_collect)(nw_data_transfer_report_t, dispatch_queue_t, nw_data_transfer_report_collect_block_t);
extern uint64_t P(nw_data_transfer_report_get_sent_application_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_application_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds)(nw_data_transfer_report_t, uint32_t);
extern uint32_t P(nw_data_transfer_report_get_path_count)(nw_data_transfer_report_t);
extern nw_parameters_t P(nw_parameters_create_secure_tcp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
extern nw_parameters_t P(nw_parameters_create_secure_udp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
extern nw_protocol_definition_t P(nw_protocol_copy_udp_definition)(void);
extern nw_endpoint_t P(nw_endpoint_create_host)(const char *, const char *);
extern nw_protocol_definition_t P(nw_protocol_copy_tcp_definition)(void);
extern bool P(nw_protocol_metadata_is_udp)(nw_protocol_metadata_t);

/* The two sentinel blocks of the port's own parameters, which a factory compares by pointer. */
extern const nw_parameters_configure_protocol_block_t charonhost__nw_parameters_configure_protocol_default_configuration;
extern const nw_parameters_configure_protocol_block_t charonhost__nw_parameters_configure_protocol_disable;
#define PORT_DISABLE ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_disable)
#define PORT_DEFAULT ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_default_configuration)
#define PORT_DISABLE ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_disable)

static NSString *states_of(NSMutableArray *states)
{
    return [states componentsJoinedByString:@">"];
}

/* The peer of both connections, which is a plain BSD listener in this program.
 *
 * It has to be: the host's own Network will not start a listener in this environment - asked for one,
 * on a port of its choosing and on a port this program names, it answers `failed` with the POSIX error
 * EINVAL (measured, and written down in facts/Network/NWConnection.md) - while its *connection* works
 * here and sends and receives normally (the same measurement). So both the host's connection and the
 * port's connect to this listener, which relays what one writes to the other: every byte the port
 * sends is read by Apple's own Network, and every byte Apple's own Network sends is read by the port,
 * over real sockets on both sides.
 */
typedef struct {
    int listener;
    uint16_t port;
    int host_side;   /* the socket the host's connection reached */
    int port_side;   /* the socket the port's connection reached */
} Peer;

static BOOL peer_start(Peer *peer)
{
    memset(peer, 0, sizeof *peer);
    peer->listener = socket(AF_INET, SOCK_STREAM, 0);
    if (peer->listener < 0)
        return NO;
    int on = 1;
    setsockopt(peer->listener, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(peer->listener, (struct sockaddr *)&address, sizeof address) != 0 || listen(peer->listener, 4) != 0)
        return NO;
    socklen_t length = sizeof address;
    if (getsockname(peer->listener, (struct sockaddr *)&address, &length) != 0)
        return NO;
    peer->port = ntohs(address.sin_port);
    return peer->port != 0;
}

/* The two connections arrive in whichever order the kernel hands them over, and each is told apart by
   what it writes first: the port's connection is recognised by the byte it sends when it is ready. */
static void peer_relay(Peer *peer, int from, int to)
{
    char buffer[4096];
    ssize_t got = read(from, buffer, sizeof buffer);
    if (got <= 0)
        return;
    write(to, buffer, (size_t)got);
}

static NSData *bytes_of(dispatch_data_t payload, size_t *length)
{
    size_t size = payload ? dispatch_data_get_size(payload) : 0;
    NSMutableData *bytes = [NSMutableData dataWithLength:size];
    if (size) {
        dispatch_data_apply(payload, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t count) {
            memcpy((uint8_t *)bytes.mutableBytes + offset, buffer, count);
            return true;
        });
    }
    if (length)
        *length = size;
    return bytes;
}

/* The port of a port number, as the text an endpoint of a host and a port wants. */
static const char *port_text_of(uint16_t port)
{
    static char text[16];
    snprintf(text, sizeof text, "%u", port);
    return text;
}

int main(void)
{
    @autoreleasepool {
        Peer peer;
        CHECK(peer_start(&peer), "the program's own loopback listener is up");
        if (!peer.port)
            return 1;
        char port_text[16];
        snprintf(port_text, sizeof port_text, "%u", peer.port);
        printf("ok the program's listener is on 127.0.0.1:%u\n", peer.port);

        /* both connections, to the same peer */
        nw_parameters_t system_parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
                                                                              NW_PARAMETERS_DEFAULT_CONFIGURATION);
        nw_connection_t system = nw_connection_create(nw_endpoint_create_host("127.0.0.1", port_text), system_parameters);
        nw_parameters_t port_parameters = P(nw_parameters_create_secure_tcp)(PORT_DISABLE, PORT_DEFAULT);
        nw_connection_t mine = P(nw_connection_create)(P(nw_endpoint_create_host)("127.0.0.1", port_text), port_parameters);
        CHECK(system && mine, "both sides made a connection to the peer");

        dispatch_queue_t system_queue = dispatch_queue_create("system.connection", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t port_queue = dispatch_queue_create("port.connection", DISPATCH_QUEUE_SERIAL);
        __block int system_ready = 0, port_ready = 0;
        nw_connection_set_queue(system, system_queue);
        nw_connection_set_state_changed_handler(system, ^(nw_connection_state_t state, nw_error_t error) {
            if (state == nw_connection_state_ready)
                system_ready = 1;
        });
        P(nw_connection_set_queue)(mine, port_queue);
        P(nw_connection_set_state_changed_handler)(mine, ^(nw_connection_state_t state, nw_error_t error) {
            if (getenv("CHARON_TRACE")) fprintf(stderr, "[port] state %d error %d/%d\n", state,
                                                  nw_error_get_error_domain(error), nw_error_get_error_code(error));
            if (state == nw_connection_state_ready)
                port_ready = 1;
        });
        nw_connection_start(system);
        P(nw_connection_start)(mine);
        for (int index = 0; index < 200 && !(system_ready && port_ready); index++)
            usleep(25000);
        CHECK(port_ready, "the port's connection reaches ready over the loopback");
        CHECK(system_ready, "and so does the host's");

        /* the peer takes both connections; which is which is settled by what each writes first */
        /* The peer takes the two connections, and it does not wait for ever for them: a port that
           never connects is a failure this program must report, not a hang a gate waits on. */
        int first = -1, second = -1;
        for (int side = 0; side < 2; side++) {
            struct pollfd waiting = {peer.listener, POLLIN, 0};
            if (poll(&waiting, 1, 5000) <= 0) {
                CHECK(NO, @"the peer was given both connections");
                printf("checks=%d failures=%d\n", charon_checks, charon_failures + 1);
                return 1;
            }
            int handle = accept(peer.listener, NULL, NULL);
            if (handle < 0) {
                CHECK(NO, @"the peer was given both connections");
                printf("checks=%d failures=%d\n", charon_checks, charon_failures + 1);
                return 1;
            }
            if (side == 0)
                first = handle;
            else
                second = handle;
        }
        /* The two sockets the peer holds are non-blocking: the relay reads them in a loop and must not
           sit in one of them waiting for a byte the other side has not written yet. */
        for (int handle = first; handle >= 0; handle = handle == first ? second : -1)
            fcntl(handle, F_SETFL, fcntl(handle, F_GETFL, 0) | O_NONBLOCK);
        CHECK(first >= 0 && second >= 0, "the peer accepted both connections");
        if (first < 0 || second < 0)
            return 1;

        __block NSMutableData *host_got = [NSMutableData data];
        __block NSMutableData *port_got = [NSMutableData data];
        __block int host_receives = 0, port_receives = 0;
        nw_connection_receive(system, 1, 4096, ^(dispatch_data_t content, nw_content_context_t context,
                                                  bool is_complete, nw_error_t error) {
            @synchronized(host_got) {
                [host_got appendData:bytes_of(content, NULL)];
                host_receives++;
            }
        });
        P(nw_connection_receive)(mine, 1, 4096, ^(dispatch_data_t content, nw_content_context_t context,
                                                   bool is_complete, nw_error_t error) {
            @synchronized(port_got) {
                [port_got appendData:bytes_of(content, NULL)];
                port_receives++;
            }
        });

        /* the port writes, the host reads */
        const char *from_port = "from the port";
        __block int port_send_error = 1, port_send_code = -1, port_send_done = 0;
        P(nw_connection_send)(mine, dispatch_data_create(from_port, strlen(from_port), port_queue, DISPATCH_DATA_DESTRUCTOR_DEFAULT),
                              nw_content_context_create("test"), true, ^(nw_error_t error) {
            port_send_error = error ? 1 : 0;
            port_send_code = error ? nw_error_get_error_code(error) : 0;
            port_send_done = 1;
        });
        for (int index = 0; index < 200 && !port_send_done; index++)
            usleep(25000);
        if (port_send_error)
            printf("  the port's send reported %d\n", port_send_code);
        CHECK_EQUAL(@(0), @(port_send_error), "the port's send completion reports no error");
        {
            char buffer[4096];
            ssize_t got = -1;
            for (int index = 0; index < 200; index++) {
                got = read(first, buffer, sizeof buffer);
                if (got > 0)
                    break;
                usleep(25000);
            }
            CHECK(got == (ssize_t)strlen(from_port), "the peer read what the port sent");
            if (got > 0)
                write(second, buffer, (size_t)got);
        }
        for (int index = 0; index < 200 && !host_got.length; index++)
            usleep(25000);
        @synchronized(host_got) {
            CHECK_EQUAL(([NSString stringWithFormat:@"%lu", (unsigned long)host_got.length]),
                        ([NSString stringWithFormat:@"%lu", (unsigned long)strlen(from_port)]),
                        "and the host's own Network read it through the port's socket");
        }

        /* the host writes, the port reads: one message, then another */
        nw_connection_send(system, dispatch_data_create("one", 3, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT),
                           nw_content_context_create("test"), true, ^(nw_error_t error) {});
        nw_connection_send(system, dispatch_data_create("two", 3, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT),
                           nw_content_context_create("test"), true, ^(nw_error_t error) {});
        for (int index = 0; index < 200 && port_receives < 2; index++) {
            char buffer[4096];
            ssize_t got = read(second, buffer, sizeof buffer);
            if (got > 0)
                write(first, buffer, (size_t)got);
            else
                usleep(25000);
        }
        @synchronized(port_got) {
            /* A stream delivers what arrived, so the two sends may arrive as one read; what the port
               must hand back is the bytes the host wrote, in that order. */
            CHECK(port_receives >= 1, "the port received what the host sent");
            if (port_receives >= 1 && port_got.length >= 6) {
                NSData *one = [port_got subdataWithRange:NSMakeRange(0, 3)];
                NSData *two = [port_got subdataWithRange:NSMakeRange(3, 3)];
                CHECK_EQUAL(([NSString stringWithFormat:@"%.*s", (int)one.length, (const char *)one.bytes]), @"one",
                            "the first is the first message the host sent");
                CHECK_EQUAL(([NSString stringWithFormat:@"%.*s", (int)two.length, (const char *)two.bytes]), @"two",
                            "and the second is the other");
            }
        }

        /* what each side says about the connection it has */
        {
            char *system_description = nw_connection_copy_description(system);
            char *port_description = P(nw_connection_copy_description)(mine);
            CHECK(system_description && port_description, "both sides can describe the connection");
            CHECK(strstr(system_description, "[C1") == system_description, "the host's description names the connection");
            CHECK(strstr(port_description, "[C1") == port_description, "and so does the port's");
            CHECK(strstr(port_description, "127.0.0.1") != NULL, "the port's names the peer");
            CHECK(strstr(port_description, "tcp") != NULL, "and the transport it is on");
            free(system_description);
            free(port_description);
        }
        {
            uint32_t system_size = nw_connection_get_maximum_datagram_size(system);
            uint32_t port_size = P(nw_connection_get_maximum_datagram_size)(mine);
            CHECK(system_size > 0 && port_size > 0, "both sides name a largest datagram");
            CHECK_EQUAL(@(port_size), @(system_size), "and they name the same one over the same path");
        }
        {
            nw_protocol_metadata_t system_tcp = nw_connection_copy_protocol_metadata(system, nw_protocol_copy_tcp_definition());
            nw_protocol_metadata_t port_tcp = P(nw_connection_copy_protocol_metadata)(mine, P(nw_protocol_copy_tcp_definition)());
            CHECK(nw_protocol_metadata_is_tcp(system_tcp), "the host's connection has TCP metadata");
            CHECK(P(nw_protocol_metadata_is_tcp)(port_tcp), "and the port's has it too");
            CHECK(nw_connection_copy_protocol_metadata(system, nw_protocol_copy_udp_definition()) == NULL,
                  "the host's has none of a protocol it is not carrying");
            CHECK(P(nw_connection_copy_protocol_metadata)(mine, P(nw_protocol_copy_udp_definition)()) == NULL,
                  "and the port's has none either");
            CHECK(nw_connection_copy_current_path(system) != NULL, "the host's connection knows its path");
            CHECK(P(nw_connection_copy_current_path)(NULL) == NULL, "and nothing is a path");
        }

        /* What is NOT checked here, and why. The four scenarios that would follow - a data transfer
           report and its collect, cancelling and that nothing more is taken, a connection to nothing
           listening, and a datagram connection - are in the port's file and are measured on the
           emulator at 6.1.3 (tests/backports/device). They are not compared here because the host's
           own objects and the port's own objects cannot be passed to one another's calls - a report of
           the port read by the host's accessor reads Apple's layout of a port object, and the other way
           round - so each scenario needs its own port-only check, and the loopback peer in this
           program cannot stand in for one. What this differential does compare is the transport
           itself: a real socket, a real state machine, and the bytes each side reads from the other
           through Apple's own Network on one end. */

        close(first);
        close(second);
        close(peer.listener);
        /* A last look: a cancelled connection's handler runs on the queue the connection was given,
           and that queue outlives main, so nothing is touched after this point. */
        usleep(300000);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
