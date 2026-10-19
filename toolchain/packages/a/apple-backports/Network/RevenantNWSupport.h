#ifndef CHARON_NW_SUPPORT_H
#define CHARON_NW_SUPPORT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/socket.h>
#include <CoreFoundation/CoreFoundation.h>

char *charon_nw_copy_cstring(const char *text);

CFStringRef charon_nw_cfstring(const char *text);

CFDataRef charon_nw_sockaddr_data(const struct sockaddr *address, socklen_t length);
const struct sockaddr *charon_nw_sockaddr_of(CFDataRef data, socklen_t *length);

bool charon_nw_resolve_port(const char *text, uint16_t *out);

uint16_t charon_nw_default_port_for_scheme(const char *url);

bool charon_nw_sockaddr_text(const struct sockaddr *address, char *out, size_t size);
uint16_t charon_nw_sockaddr_port(const struct sockaddr *address);
socklen_t charon_nw_sockaddr_length(const struct sockaddr *address);

bool charon_nw_host_is_address(const char *host, uint16_t port, CFDataRef *out_address);

CFStringRef charon_nw_url_host(const char *url);
uint16_t charon_nw_url_port(const char *url);

bool charon_nw_split_url(const char *url, CFStringRef *out_host, uint16_t *out_port);

uint64_t charon_nw_uptime_milliseconds(void);

void charon_nw_set_number(CFMutableDictionaryRef values, const char *key, double value);
double charon_nw_number(CFDictionaryRef values, const char *key, double fallback);
void charon_nw_set_flag(CFMutableDictionaryRef values, const char *key, bool value);
bool charon_nw_flag(CFDictionaryRef values, const char *key, bool fallback);
void charon_nw_set_integer(CFMutableDictionaryRef values, const char *key, int64_t value);
int64_t charon_nw_integer(CFDictionaryRef values, const char *key, int64_t fallback);

#endif

int charon_nw_socket(int family, int type, int protocol);

int charon_nw_blocking_socket(int family, int type, int protocol);
bool charon_nw_set_nonblocking(int handle);

dispatch_source_t charon_nw_read_source(int handle, dispatch_queue_t queue);
dispatch_source_t charon_nw_write_source(int handle, dispatch_queue_t queue);

uint32_t charon_nw_available_send_buffer(int handle);
uint32_t charon_nw_available_receive_buffer(int handle);

bool charon_nw_tcp_round_trips(int handle, uint64_t *smoothed, uint64_t *minimum, uint64_t *variance);
