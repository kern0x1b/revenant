#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#include <dns_sd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SERVICE_TYPE "_revenant-browser-differential._tcp"
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
typedef id NS_BROWSER;
typedef id NS_DESCRIPTOR;
typedef id NS_RESULT;
extern NS_BROWSER revenanthost_nw_browser_create(id, void *);
extern void revenanthost_nw_browser_set_queue(NS_BROWSER, dispatch_queue_t);
extern void revenanthost_nw_browser_set_browse_results_changed_handler(NS_BROWSER, void (^)(NS_RESULT, NS_RESULT, bool));
extern void revenanthost_nw_browser_set_state_changed_handler(NS_BROWSER, void (^)(int, void *));
extern void revenanthost_nw_browser_start(NS_BROWSER);
extern void revenanthost_nw_browser_cancel(NS_BROWSER);
extern void revenanthost_nw_browse_descriptor_set_include_txt_record(id, bool);
extern id revenanthost_nw_browse_descriptor_create_bonjour_service(const char *, const char *);
extern id revenanthost_nw_browse_result_copy_endpoint(NS_RESULT);
extern id revenanthost_nw_browse_result_copy_txt_record_object(NS_RESULT);
extern size_t revenanthost_nw_browse_result_get_interfaces_count(NS_RESULT);
extern const char *revenanthost_nw_browse_result_get_changes(NS_RESULT, NS_RESULT);
extern const char *revenanthost_nw_endpoint_get_type(id);
extern const char *revenanthost_nw_endpoint_get_bonjour_service_name(id);
extern const char *revenanthost_nw_endpoint_get_bonjour_service_type(id);
extern const char *revenanthost_nw_endpoint_get_bonjour_service_domain(id);
extern uint16_t revenanthost_nw_endpoint_get_port(id);
extern size_t revenanthost_nw_txt_record_get_key_count(id);
extern bool revenanthost_nw_txt_record_is_dictionary(id);
#endif

static volatile int printed = 0;
static DNSServiceRef registered = NULL;
static DNSServiceRef browsed = NULL;

static void withdraw(void)
{
    if (registered) {
        DNSServiceRefDeallocate(registered);
        registered = NULL;
    }
}

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
    id endpoint = revenanthost_nw_browse_result_copy_endpoint(new_result);
    id record = revenanthost_nw_browse_result_copy_txt_record_object(new_result);
#endif
    char number[32];
    emit("found", "yes");
#ifdef HOST_SIDE
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
    snprintf(number, sizeof number, "%d", (int)revenanthost_nw_endpoint_get_type(endpoint));
    emit("endpoint.type", number);
    emit("endpoint.name", revenanthost_nw_endpoint_get_bonjour_service_name(endpoint));
    emit("endpoint.serviceType", revenanthost_nw_endpoint_get_bonjour_service_type(endpoint));
    emit("endpoint.domain", revenanthost_nw_endpoint_get_bonjour_service_domain(endpoint));
    char port_text[16];
    snprintf(port_text, sizeof port_text, "%u", revenanthost_nw_endpoint_get_port(endpoint));
    emit("endpoint.port", port_text);
    emit("record.keys", record ? ([NSString stringWithFormat:@"%lu",
            (unsigned long)revenanthost_nw_txt_record_get_key_count(record)].UTF8String) : "(nil)");
    emit("record.isDictionary", record ? (revenanthost_nw_txt_record_is_dictionary(record) ? "YES" : "NO") : "(nil)");
    snprintf(number, sizeof number, "%llu", (unsigned long long)revenanthost_nw_browse_result_get_changes(NULL, new_result));
    emit("changes.added", number);
    emit("interfaces.count", ([NSString stringWithFormat:@"%lu",
            (unsigned long)revenanthost_nw_browse_result_get_interfaces_count(new_result)].UTF8String));
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
        const uint8_t txt[] = { 3, 'k', '=', 'v' };
        char name[64];
        snprintf(name, sizeof name, "revenant-diff-%d", (int)getpid());
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
        id descriptor = revenanthost_nw_browse_descriptor_create_bonjour_service(SERVICE_TYPE, "local.");
        revenanthost_nw_browse_descriptor_set_include_txt_record(descriptor, true);
        NS_BROWSER browser = revenanthost_nw_browser_create(descriptor, NULL);
        revenanthost_nw_browser_set_queue(browser, dispatch_get_main_queue());
        revenanthost_nw_browser_set_browse_results_changed_handler(browser,
            ^(NS_RESULT o, NS_RESULT n, bool c) { (void)o; (void)c; report_result(o, n); });
        revenanthost_nw_browser_set_state_changed_handler(browser, ^(int state, void *error) {
            char line[64];
            snprintf(line, sizeof line, "state.%d", state);
            emit(line, error ? "an error" : "no error");
        });
        revenanthost_nw_browser_start(browser);
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
