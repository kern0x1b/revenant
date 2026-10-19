/*
 * The few pieces of C every file of this library needs, in one file of its own.
 *
 * The file is C and not Objective-C on purpose: `modules/apple/backports.lua` compiles C hidden, so
 * nothing here is exported and nothing here is a symbol the registry has to describe. A helper that
 * an Objective-C file defined would be exported from the library, and one that lived in a file that
 * also carried API of a release could be dropped from a band that keeps the file's other symbols -
 * both are reasons this file exists.
 */

#ifndef CHARON_NW_SUPPORT_H
#define CHARON_NW_SUPPORT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/socket.h>
#include <CoreFoundation/CoreFoundation.h>

/* A copy of a C string, or NULL for nothing. The caller owns it and frees it with free(). */
char *charon_nw_copy_cstring(const char *text);

/* A CFString of a C string in UTF-8, or NULL for nothing. */
CFStringRef charon_nw_cfstring(const char *text);

/* The bytes of a socket address, and the address back out of them. A CFData's bytes are not
   aligned, so the address is copied out rather than pointed into. */
CFDataRef charon_nw_sockaddr_data(const struct sockaddr *address, socklen_t length);
const struct sockaddr *charon_nw_sockaddr_of(CFDataRef data, socklen_t *length);

/* The port a string names: a number, or the name of a service in the system's own services file,
   which is what a program that writes "http" means. False for a string that names neither. */
bool charon_nw_resolve_port(const char *text, uint16_t *out);

/* The port a URL's scheme answers when the URL has none of its own - 80 for http, 443 for https and so
   on - and 0 for a scheme the system has no service for. */
uint16_t charon_nw_default_port_for_scheme(const char *url);

/* A socket address in the text a program would write: "192.0.2.1", "2001:db8::1", or the name of a
   Unix socket's path. False for an address of a family with no such text. */
bool charon_nw_sockaddr_text(const struct sockaddr *address, char *out, size_t size);
uint16_t charon_nw_sockaddr_port(const struct sockaddr *address);
socklen_t charon_nw_sockaddr_length(const struct sockaddr *address);

/* Whether a host is a bare address of one of the two families rather than a name to look up, and
   the address it is, with the port filled in from the port given. */
bool charon_nw_host_is_address(const char *host, uint16_t port, CFDataRef *out_address);

/* The host and the port of a URL, as nw_endpoint_create_url's endpoint answers them: the host is
   what the URL names without its port, and the port is the URL's own when it has one and the
   scheme's default otherwise. */
CFStringRef charon_nw_url_host(const char *url);
uint16_t charon_nw_url_port(const char *url);

/* The host and the port of an "http://host:port/path" text, for the endpoints a proxy and a
   resolver are named with. */
bool charon_nw_split_url(const char *url, CFStringRef *out_host, uint16_t *out_port);

/* Milliseconds since the boot of the device, which is the clock every duration in a report is
   measured against. */
uint64_t charon_nw_uptime_milliseconds(void);

/* A dictionary of a key's integer value, or NULL when the key is not there: the one place a
   settings value is read and written. */
void charon_nw_set_number(CFMutableDictionaryRef values, const char *key, double value);
double charon_nw_number(CFDictionaryRef values, const char *key, double fallback);
void charon_nw_set_flag(CFMutableDictionaryRef values, const char *key, bool value);
bool charon_nw_flag(CFDictionaryRef values, const char *key, bool fallback);
void charon_nw_set_integer(CFMutableDictionaryRef values, const char *key, int64_t value);
int64_t charon_nw_integer(CFDictionaryRef values, const char *key, int64_t fallback);

#endif

/* A socket of that kind, already close-on-exec and non-blocking: the port's own sockets are driven by
   dispatch sources, which ask for the non-blocking kind, and a signal from a closed socket must not
   kill the process (Darwin has no MSG_NOSIGNAL, so SO_NOSIGPIPE is the way). -1 with errno set on
   failure, as socket() itself answers. */
int charon_nw_socket(int family, int type, int protocol);

/* A socket of that kind, close-on-exec and *blocking*, for the one call that has to wait: the
   connect of a connection, which runs on a queue of its own so that nothing else waits with it. After
   it has answered, charon_nw_set_nonblocking() makes it what the two dispatch sources need. */
int charon_nw_blocking_socket(int family, int type, int protocol);
bool charon_nw_set_nonblocking(int handle);

/* The two dispatch sources a socket's traffic is read on, on the queue given, each asking for that
   socket's descriptor only. Sources over a descriptor are created disabled and resumed here, so a
   caller that wants to add its own handler first can. */
dispatch_source_t charon_nw_read_source(int handle, dispatch_queue_t queue);
dispatch_source_t charon_nw_write_source(int handle, dispatch_queue_t queue);

/* The kernel's buffer sizes for that socket, for the data transfer report's available-buffer
   accessors, which are the room the transport has rather than the room the program asked for. */
uint32_t charon_nw_available_send_buffer(int handle);
uint32_t charon_nw_available_receive_buffer(int handle);

/* The round trip times the kernel has measured for that TCP connection, in milliseconds, through the
   TCP_CONNECTION_INFO the SDK declares. false for a kernel that has no such option, which is what a
   report says then: a measurement the port could not take. */
bool charon_nw_tcp_round_trips(int handle, uint64_t *smoothed, uint64_t *minimum, uint64_t *variance);

