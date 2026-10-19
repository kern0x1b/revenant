// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Exercise the firmware asynchronous DNS resolver from a real ARM
// guest executable.

// ARMv6 iPhoneOS guest probe. This intentionally uses only the target
// libSystem ABI: it is linked against the extracted firmware library and runs
// under the firmware dyld, so reaching either marker proves guest execution.

#include "runtime_initializers.h"
#include "system_configuration_probe.h"

typedef unsigned int uint32_t;
typedef unsigned short uint16_t;
typedef int int32_t;
typedef unsigned int mach_port_t;
typedef unsigned int mach_msg_option_t;
typedef unsigned int mach_msg_size_t;
typedef int mach_msg_return_t;

struct mach_msg_header {
    uint32_t bits;
    uint32_t size;
    mach_port_t remote_port;
    mach_port_t local_port;
    uint32_t reserved;
    int32_t identifier;
};

struct addrinfo;
struct sockaddr {
    unsigned char length;
    unsigned char family;
    unsigned char bytes[2];
};
typedef void (*getaddrinfo_async_callback)(
    int32_t status, struct addrinfo* result, void* context);

typedef struct dns_service_ref* DNSServiceRef;
typedef uint32_t DNSServiceFlags;
typedef int32_t DNSServiceErrorType;
typedef void (*DNSServiceGetAddrInfoReply)(DNSServiceRef service,
    DNSServiceFlags flags, uint32_t interface_index, DNSServiceErrorType error,
    const char* hostname, const struct sockaddr* address, uint32_t ttl,
    void* context);

extern int write(int descriptor, const void* bytes, unsigned long size);
extern __attribute__((noreturn)) void _exit(int status);
extern mach_msg_return_t mach_msg(struct mach_msg_header* message,
    mach_msg_option_t option, mach_msg_size_t send_size,
    mach_msg_size_t receive_limit, mach_port_t receive_name, uint32_t timeout,
    mach_port_t notify);
extern int32_t getaddrinfo_async_start(mach_port_t* port, const char* node,
    const char* service, const struct addrinfo* hints,
    getaddrinfo_async_callback callback, void* context);
extern int32_t getaddrinfo_async_handle_reply(void* message);
extern DNSServiceErrorType DNSServiceGetAddrInfo(DNSServiceRef* service,
    DNSServiceFlags flags, uint32_t interface_index, uint32_t protocols,
    const char* hostname, DNSServiceGetAddrInfoReply callback, void* context);
extern DNSServiceErrorType DNSServiceProcessResult(DNSServiceRef service);
extern void DNSServiceRefDeallocate(DNSServiceRef service);
extern void freeaddrinfo(struct addrinfo* result);

typedef void (*darwin_init_routine)(void);
extern darwin_init_routine mach_init_routine;
extern darwin_init_routine _cthread_init_routine;

int NXArgc;
char** NXArgv;
char** environ;
char* __progname;

enum {
    mach_receive_message = 2,
    dns_protocol_ipv4 = 1,
    dns_protocol_ipv6 = 2,
    address_family_inet = 2,
    address_family_inet6 = 30,
};

static const char libinfo_started[] = "PROBE libinfo started\n";
static const char libinfo_callback_marker[] = "PROBE libinfo callback\n";
static const char libinfo_callback_error[] = "PROBE libinfo callback error\n";
static const char libinfo_failed[] = "PROBE libinfo failed\n";
static const char dnssd_started[] = "PROBE dnssd started\n";
static const char dnssd_callback_marker[] = "PROBE dnssd callback\n";
static const char dnssd_callback_error[] = "PROBE dnssd callback error\n";
static const char dnssd_a[] = "PROBE dnssd A callback\n";
static const char dnssd_aaaa[] = "PROBE dnssd AAAA callback\n";
static const char dnssd_failed[] = "PROBE dnssd failed\n";
static const char probe_complete[] = "PROBE complete\n";
static const char local_hostname[] = "iPhone-021a543a0002.local";

static volatile int libinfo_result;
static volatile int dnssd_result;

static void emit(const char* text, unsigned long size)
{
    (void)write(1, text, size);
}

static void emit_status(
    const char* prefix, unsigned long prefix_size, int32_t status)
{
    char text[16];
    unsigned int value;
    unsigned long cursor = 0;
    int significant = 0;
    static const unsigned int decimal_places[] = {
        1000000000U,
        100000000U,
        10000000U,
        1000000U,
        100000U,
        10000U,
        1000U,
        100U,
        10U,
        1U,
    };
    if (status < 0) {
        value = (unsigned int)(-(status + 1)) + 1;
        text[cursor++] = '-';
    } else {
        value = (unsigned int)status;
    }
    for (unsigned long i = 0;
        i < sizeof(decimal_places) / sizeof(decimal_places[0]); ++i) {
        unsigned int digit = 0;
        while (value >= decimal_places[i]) {
            value -= decimal_places[i];
            ++digit;
        }
        if (digit != 0 || significant || decimal_places[i] == 1) {
            text[cursor++] = (char)('0' + digit);
            significant = 1;
        }
    }
    text[cursor++] = '\n';
    emit(prefix, prefix_size);
    emit(text, cursor);
}

static void libinfo_callback(
    int32_t status, struct addrinfo* result, void* context)
{
    (void)context;
    if (status == 0 && result != (struct addrinfo*)0) {
        emit(libinfo_callback_marker, sizeof(libinfo_callback_marker) - 1);
        libinfo_result = 1;
        freeaddrinfo(result);
    } else {
        emit(libinfo_callback_error, sizeof(libinfo_callback_error) - 1);
        emit_status("PROBE libinfo status ", 21, status);
        libinfo_result = -1;
    }
}

static void dnssd_callback(DNSServiceRef service, DNSServiceFlags flags,
    uint32_t interface_index, DNSServiceErrorType error, const char* hostname,
    const struct sockaddr* address, uint32_t ttl, void* context)
{
    (void)service;
    (void)flags;
    (void)interface_index;
    (void)hostname;
    (void)ttl;
    (void)context;
    emit(dnssd_callback_marker, sizeof(dnssd_callback_marker) - 1);
    if (error != 0) {
        emit(dnssd_callback_error, sizeof(dnssd_callback_error) - 1);
        emit_status("PROBE dnssd status ", 19, error);
        dnssd_result = -1;
    } else if (address != (const struct sockaddr*)0 &&
               address->family == address_family_inet &&
               address->length >= 16) {
        emit(dnssd_a, sizeof(dnssd_a) - 1);
        dnssd_result = 1;
    } else if (address != (const struct sockaddr*)0 &&
               address->family == address_family_inet6 &&
               address->length >= 28) {
        emit(dnssd_aaaa, sizeof(dnssd_aaaa) - 1);
        dnssd_result = 1;
    } else {
        emit(dnssd_callback_error, sizeof(dnssd_callback_error) - 1);
        dnssd_result = -1;
    }
}

static int probe_main(void)
{
    mach_port_t response_port = 0;
    if (getaddrinfo_async_start(&response_port, local_hostname, (const char*)0,
            (const struct addrinfo*)0, libinfo_callback, (void*)0) != 0) {
        emit(libinfo_failed, sizeof(libinfo_failed) - 1);
    } else {
        union {
            struct mach_msg_header header;
            unsigned char bytes[4096];
        } response;
        emit(libinfo_started, sizeof(libinfo_started) - 1);
        if (mach_msg(&response.header, mach_receive_message, 0,
                sizeof(response.bytes), response_port, 0, 0) == 0) {
            (void)getaddrinfo_async_handle_reply(&response.header);
        } else {
            emit(libinfo_failed, sizeof(libinfo_failed) - 1);
        }
    }
    if (libinfo_result != 1)
        return 1;

    DNSServiceRef service = (DNSServiceRef)0;
    // The target firmware's iPhone-specific mDNSResponder derives its fallback
    // label from en0's MAC when Lockdown has not set a local hostname. The
    // emulator's deterministic 02:00:00:00:00:01 link address therefore
    // registers this name without external DNS or mutable guest preferences.
    if (DNSServiceGetAddrInfo(&service, 0, 0,
            dns_protocol_ipv4 | dns_protocol_ipv6, local_hostname,
            dnssd_callback, (void*)0) != 0) {
        emit(dnssd_failed, sizeof(dnssd_failed) - 1);
        return 1;
    }
    emit(dnssd_started, sizeof(dnssd_started) - 1);
    while (dnssd_result == 0) {
        if (DNSServiceProcessResult(service) != 0) {
            emit(dnssd_failed, sizeof(dnssd_failed) - 1);
            DNSServiceRefDeallocate(service);
            return 1;
        }
    }
    DNSServiceRefDeallocate(service);
    if (dnssd_result != 1)
        return 1;
    if (shade_run_system_configuration_probe(local_hostname) != 0)
        return 1;
    emit(probe_complete, sizeof(probe_complete) - 1);
    return 0;
}

__attribute__((noreturn)) void shade_guest_start(
    int argc, char** argv, char** environment)
{
    NXArgc = argc;
    NXArgv = argv;
    environ = environment;
    __progname = (argc > 0 && argv != (char**)0) ? argv[0] : (char*)0;
    if (mach_init_routine != (darwin_init_routine)0) {
        mach_init_routine();
    }
    if (_cthread_init_routine != (darwin_init_routine)0) {
        _cthread_init_routine();
    }
    shade_guest_run_runtime_initializers();
    _exit(probe_main());
}
