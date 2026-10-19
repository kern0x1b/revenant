/*
 * The browser differential: one binary registers a Bonjour service and browses for it with Apple's own
 * nw_browser, the other does the same with the port's browser compiled beside it under renamed symbols,
 * and run.sh compares what each found.
 *
 * Both sides register the service themselves, through the release's own DNSServiceRegister, so the thing
 * on the link is one thing on the link and the only difference between the two runs is the browser. The
 * comparison is of what a program can observe: that the service was found, what its endpoint says, the
 * port it publishes, the record it advertises, and the interfaces it was found on.
 *
 * The browse is asynchronous on both sides, so the program runs its own run loop with a deadline and
 * prints what it has when the deadline passes. A line the other side also prints is a comparison; a line
 * only one side prints is a difference the harness reports.
 */
#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#include <dns_sd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SERVICE_TYPE "_charon-browser-differential._tcp"
#define SERVICE_PORT 45678
#define DEADLINE 8.0

static void emit(const char *name, const char *value)
{
    printf("%s\t%s\n", name, value ? value : "(nil)");
    fflush(stdout);
}

#ifdef HOST_SIDE
#import <Network/Network.h>
#define NS_BROWSER          nw_browser_t
#define NS_DESCRIPTOR       nw_browse_descriptor_t
#define NS_RESULT           nw_browse_result_t
#else
/* The port's browser, renamed. The rename set is read out of the port's objects by run.sh, so a call the
   port adds is renamed with it. */
typedef id NS_BROWSER;
typedef id NS_DESCRIPTOR;
typedef id NS_RESULT;
extern NS_BROWSER charonhost_nw_browser_create(id, void *);
extern void charonhost_nw_browser_set_queue(NS_BROWSER, dispatch_queue_t);
extern void charonhost_nw_browser_set_browse_results_changed_handler(NS_BROWSER, void (^)(NS_RESULT, NS_RESULT, bool));
extern void charonhost_nw_browser_set_state_changed_handler(NS_BROWSER, void (^)(int, void *));
extern void charonhost_nw_browser_start(NS_BROWSER);
extern void charonhost_nw_browser_cancel(NS_BROWSER);
extern void charonhost_nw_browse_descriptor_set_include_txt_record(id, bool);
extern id charonhost_nw_browse_descriptor_create_bonjour_service(const char *, const char *);
extern id charonhost_nw_browse_result_copy_endpoint(NS_RESULT);
extern id charonhost_nw_browse_result_copy_txt_record_object(NS_RESULT);
extern size_t charonhost_nw_browse_result_get_interfaces_count(NS_RESULT);
extern const char *charonhost_nw_browse_result_get_changes(NS_RESULT, NS_RESULT);
extern const char *charonhost_nw_endpoint_get_type(id);
extern const char *charonhost_nw_endpoint_get_bonjour_service_name(id);
extern const char *charonhost_nw_endpoint_get_bonjour_service_type(id);
extern const char *charonhost_nw_endpoint_get_bonjour_service_domain(id);
extern uint16_t charonhost_nw_endpoint_get_port(id);
extern size_t charonhost_nw_txt_record_get_key_count(id);
extern bool charonhost_nw_txt_record_is_dictionary(id);
#endif

static volatile int printed = 0;
static DNSServiceRef registered = NULL;
static DNSServiceRef browsed = NULL;

/* Withdraw the registration before the process leaves, so the name the harness gave this run is free
   for the next process in that same run to take: `DNSServiceRefDeallocate` is what makes mDNSResponder
   send the goodbye, and a process that exits without it leaves the record on the link for as long as
   its timeouts run - which is why two runs of one harness used to collide on the name. */
static void withdraw(void)
{
    if (registered) {
        DNSServiceRefDeallocate(registered);
        registered = NULL;
    }
}

/* The work, with the two sides' own types; the blocks that reach it are spelled with each side's own
   signature at the call site below, because a C function is not a block and the two sides' nw_* types
   differ. */
static void report_result(id old_result, id new_result)
{
    (void)old_result;
    if (!new_result || printed)
        return;
    printed = 1;
#ifdef HOST_SIDE
    nw_endpoint_t endpoint = nw_browse_result_copy_endpoint(new_result);
    nw_txt_record_t record = nw_browse_result_copy_txt_record_object(new_result);
#else
    id endpoint = charonhost_nw_browse_result_copy_endpoint(new_result);
    id record = charonhost_nw_browse_result_copy_txt_record_object(new_result);
#endif
    char number[32];
    emit("found", "yes");
#ifdef HOST_SIDE
    /* nw_endpoint_get_type and nw_browse_result_get_changes return numbers, not strings: casting them to
       char * and printing them with %s is what segfaulted this probe on its first run. */
    snprintf(number, sizeof number, "%d", (int)nw_endpoint_get_type(endpoint));
    emit("endpoint.type", number);
    emit("endpoint.name", nw_endpoint_get_bonjour_service_name(endpoint));
    emit("endpoint.serviceType", nw_endpoint_get_bonjour_service_type(endpoint));
    emit("endpoint.domain", nw_endpoint_get_bonjour_service_domain(endpoint));
    char port_text[16];
    snprintf(port_text, sizeof port_text, "%u", nw_endpoint_get_port(endpoint));
    emit("endpoint.port", port_text);
    emit("record.keys", record ? ([NSString stringWithFormat:@"%lu",
            (unsigned long)nw_txt_record_get_key_count(record)].UTF8String) : "(nil)");
    emit("record.isDictionary", record ? (nw_txt_record_is_dictionary(record) ? "YES" : "NO") : "(nil)");
    snprintf(number, sizeof number, "%llu", (unsigned long long)nw_browse_result_get_changes(NULL, new_result));
    emit("changes.added", number);
    emit("interfaces.count", ([NSString stringWithFormat:@"%lu",
            (unsigned long)nw_browse_result_get_interfaces_count(new_result)].UTF8String));
#else
    snprintf(number, sizeof number, "%d", (int)charonhost_nw_endpoint_get_type(endpoint));
    emit("endpoint.type", number);
    emit("endpoint.name", charonhost_nw_endpoint_get_bonjour_service_name(endpoint));
    emit("endpoint.serviceType", charonhost_nw_endpoint_get_bonjour_service_type(endpoint));
    emit("endpoint.domain", charonhost_nw_endpoint_get_bonjour_service_domain(endpoint));
    char port_text[16];
    snprintf(port_text, sizeof port_text, "%u", charonhost_nw_endpoint_get_port(endpoint));
    emit("endpoint.port", port_text);
    emit("record.keys", record ? ([NSString stringWithFormat:@"%lu",
            (unsigned long)charonhost_nw_txt_record_get_key_count(record)].UTF8String) : "(nil)");
    emit("record.isDictionary", record ? (charonhost_nw_txt_record_is_dictionary(record) ? "YES" : "NO") : "(nil)");
    snprintf(number, sizeof number, "%llu", (unsigned long long)charonhost_nw_browse_result_get_changes(NULL, new_result));
    emit("changes.added", number);
    emit("interfaces.count", ([NSString stringWithFormat:@"%lu",
            (unsigned long)charonhost_nw_browse_result_get_interfaces_count(new_result)].UTF8String));
#endif
    withdraw();
    exit(0);
}

static void registered_svc(DNSServiceRef sdRef, DNSServiceFlags flags, DNSServiceErrorType error,
                           const char *name, const char *regtype, const char *domain, void *context)
{
    (void)sdRef; (void)flags; (void)error; (void)name; (void)regtype; (void)domain; (void)context;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        /* one service, registered by this process. The name is the harness's, so that the two processes
           of one run register and browse for the SAME instance and `endpoint.name` is a comparison at
           all; it used to be the pid, which made the two sides answer two different names by
           construction. The harness's name carries its own pid, so two runs on one machine never
           collide either. */
        /* a TXT record on the wire is length-prefixed: one byte naming the length of each entry, then the
           entry. A bare { 'k', '=', 'v' } reads as an entry of 107 bytes and DNSServiceRegister refuses it
           with kDNSServiceErr_Invalid, which is what it did before this line. */
        const uint8_t txt[] = { 3, 'k', '=', 'v' };
        char name[64];
        snprintf(name, sizeof name, "charon-diff-%d", (int)getpid());
        if (argc > 1 && argv[1][0])
            snprintf(name, sizeof name, "%s", argv[1]);
        DNSServiceErrorType failure = DNSServiceRegister(&registered, 0, 0, name, SERVICE_TYPE, "local.",
                                                          NULL, htons(SERVICE_PORT), (uint16_t)sizeof txt,
                                                          txt, registered_svc, NULL);
        if (failure != kDNSServiceErr_NoError || !registered) {
            fprintf(stderr, "the service could not be registered: %d\n", (int)failure);
            return 2;
        }
#ifdef HOST_SIDE
        nw_browse_descriptor_t descriptor = nw_browse_descriptor_create_bonjour_service(SERVICE_TYPE, "local.");
        nw_browse_descriptor_set_include_txt_record(descriptor, true);
        nw_browser_t browser = nw_browser_create(descriptor, NULL);
        nw_browser_set_queue(browser, dispatch_get_main_queue());
        nw_browser_set_browse_results_changed_handler(browser,
            ^(nw_browse_result_t o, nw_browse_result_t n, bool c) { (void)o; (void)c; report_result(o, n); });
        nw_browser_start(browser);
#else
        id descriptor = charonhost_nw_browse_descriptor_create_bonjour_service(SERVICE_TYPE, "local.");
        charonhost_nw_browse_descriptor_set_include_txt_record(descriptor, true);
        NS_BROWSER browser = charonhost_nw_browser_create(descriptor, NULL);
        charonhost_nw_browser_set_queue(browser, dispatch_get_main_queue());
        charonhost_nw_browser_set_browse_results_changed_handler(browser,
            ^(NS_RESULT o, NS_RESULT n, bool c) { (void)o; (void)c; report_result(o, n); });
        charonhost_nw_browser_set_state_changed_handler(browser, ^(int state, void *error) {
            char line[64];
            snprintf(line, sizeof line, "state.%d", state);
            emit(line, error ? "an error" : "no error");
        });
        charonhost_nw_browser_start(browser);
#endif
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DEADLINE * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{

            emit("found", printed ? "yes" : "no");
            emit("endpoint.name", NULL);
            emit("endpoint.serviceType", NULL);
            emit("endpoint.domain", NULL);
            emit("endpoint.port", NULL);
            emit("record.keys", NULL);
            emit("record.isDictionary", NULL);
            emit("changes.added", NULL);
            emit("interfaces.count", NULL);
            withdraw();
            exit(printed ? 0 : 1);
        });
        dispatch_main();
    }
    return 0;
}
