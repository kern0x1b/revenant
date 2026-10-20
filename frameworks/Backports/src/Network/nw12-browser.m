#define DNSServiceBrowse DNSServiceBrowseAsThisSDKDeclaresIt
#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <arpa/inet.h>
#include <dns_sd.h>
#include <string.h>
#undef DNSServiceBrowse

typedef void (*RevenantDNSServiceBrowseReply)(DNSServiceRef, DNSServiceFlags, uint32_t, DNSServiceErrorType,
                                            const char *);

extern DNSServiceErrorType DNSServiceBrowse(DNSServiceRef *, DNSServiceFlags, uint32_t, const char *,
                                            const char *, RevenantDNSServiceBrowseReply, void *);
extern DNSServiceErrorType DNSServiceResolve(DNSServiceRef *, DNSServiceFlags, uint32_t, const char *,
                                            const char *, const char *, DNSServiceResolveReply, void *);
extern void DNSServiceRefDeallocate(DNSServiceRef);
extern int DNSServiceProcessResult(DNSServiceRef);
extern int DNSServiceRefSockFD(DNSServiceRef);

@class RevenantNWBrowser;

@interface RevenantNWBrowserLookup : NSObject {
@public
    NSString *_key;
    NSString *_name;
    NSString *_type;
    NSString *_domain;
    NSMutableArray *_interfaceIndexes;
    __weak RevenantNWBrowser *_browser;
    DNSServiceRef _resolve;
    dispatch_source_t _source;
    RevenantNWTxtRecord *_txt;
    BOOL _resolved;
    BOOL _reported;
    BOOL _wantRecord;
}
@end

@implementation RevenantNWBrowserLookup

- (void)close
{
    if (_source) {
        dispatch_source_cancel(_source);
        _source = nil;
    }
    if (_resolve) {
        DNSServiceRefDeallocate(_resolve);
        _resolve = NULL;
    }
}

@end

@interface RevenantNWBrowser : NSObject <OS_nw_browser> {
@public
    RevenantNWBrowseDescriptor *_descriptor;
    RevenantNWParameters *_parameters;
    dispatch_queue_t _queue;
    nw_browser_state_changed_handler_t _state;
    nw_browser_browse_results_changed_handler_t _results;
    nw_browser_state_t _value;
    NSString *_type;
    NSString *_domain;
    DNSServiceRef _browse;
    dispatch_source_t _source;
    NSMutableDictionary *_reported;
    NSMutableDictionary *_lookups;
    NSMutableArray *_batch;
    NSMutableDictionary *_interfaces;
    nw_path_monitor_t _monitor;
    BOOL _started;
    BOOL _cancelled;
}
@end

@implementation RevenantNWBrowser
@end

static void revenant_browser_report(RevenantNWBrowser *browser, nw_browser_state_t state, RevenantNWError *error)
{
    @synchronized(browser) {
        if (browser->_cancelled && state != nw_browser_state_cancelled)
            return;
        if (browser->_value == state && state != nw_browser_state_failed && state != nw_browser_state_ready)
            return;
        browser->_value = state;
    }
    nw_browser_state_changed_handler_t handler = browser->_state;
    if (handler)
        handler(state, (nw_error_t)error);
}

static RevenantNWError *revenant_browser_error(nw_error_domain_t domain, int code)
{
    RevenantNWError *error = [[RevenantNWError alloc] init];
    error->_domain = domain;
    error->_code = code;
    return error;
}

static dispatch_source_t revenant_browser_source(int handle, dispatch_queue_t queue)
{
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)handle, 0, queue);
    if (source)
        dispatch_resume(source);
    return source;
}

static nw_interface_t revenant_browser_interface(RevenantNWBrowser *browser, NSNumber *index)
{
    return (nw_interface_t)browser->_interfaces[index];
}

static RevenantNWBrowseResult *revenant_browser_result(RevenantNWBrowser *browser, RevenantNWBrowserLookup *lookup)
{
    RevenantNWBrowseResult *result = [[RevenantNWBrowseResult alloc] init];
    result->_name = lookup->_name;
    result->_type = lookup->_type;
    result->_domain = lookup->_domain;
    result->_txtRecord = lookup->_txt;
    NSMutableArray *interfaces = [NSMutableArray array];
    for (NSNumber *index in lookup->_interfaceIndexes) {
        nw_interface_t interface = revenant_browser_interface(browser, index);
        if (interface)
            [interfaces addObject:(id)interface];
    }
    result->_interfaces = interfaces;
    RevenantNWEndpoint *endpoint = [[RevenantNWEndpoint alloc] init];
    endpoint->_type = nw_endpoint_type_bonjour_service;
    endpoint->_bonjourName = lookup->_name;
    endpoint->_bonjourType = lookup->_type;
    endpoint->_bonjourDomain = lookup->_domain;
    endpoint->_txtRecord = lookup->_txt;
    result->_endpoint = endpoint;
    return result;
}

static void revenant_browser_enqueue(RevenantNWBrowser *browser, RevenantNWBrowseResult *old, RevenantNWBrowseResult *fresh)
{
    [browser->_batch addObject:[NSArray arrayWithObjects:(id)(old ?: [NSNull null]),
                                                   (id)(fresh ?: [NSNull null]), nil]];
}

static void revenant_browser_drain(RevenantNWBrowser *browser)
{
    if (!browser->_batch.count)
        return;
    NSArray *batch = [browser->_batch copy];
    [browser->_batch removeAllObjects];
    nw_browser_browse_results_changed_handler_t handler = browser->_results;
    if (!handler)
        return;
    for (NSUInteger index = 0; index < batch.count; index++) {
        id old = [batch[index][0] isKindOfClass:[NSNull class]] ? nil : batch[index][0];
        id fresh = [batch[index][1] isKindOfClass:[NSNull class]] ? nil : batch[index][1];
        handler((nw_browse_result_t)old, (nw_browse_result_t)fresh, index + 1 == batch.count);
    }
}

static void revenant_browser_pump(DNSServiceRef reference, RevenantNWBrowser *browser)
{
    if (reference)
        DNSServiceProcessResult(reference);
    revenant_browser_drain(browser);
}

static void revenant_browser_gone(RevenantNWBrowser *browser, RevenantNWBrowserLookup *lookup)
{
    RevenantNWBrowseResult *reported = browser->_reported[lookup->_key];
    [lookup close];
    [browser->_lookups removeObjectForKey:lookup->_key];
    if (!reported)
        return;
    [browser->_reported removeObjectForKey:lookup->_key];
    revenant_browser_enqueue(browser, reported, nil);
}

static void revenant_browser_resolved(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                                    DNSServiceErrorType errorCode, const char *fullname, const char *hosttarget,
                                    uint16_t port, uint16_t txtLen, const unsigned char *txtRecord, void *context)
{
    RevenantNWBrowserLookup *lookup = (__bridge RevenantNWBrowserLookup *)context;
    RevenantNWBrowser *browser = lookup->_browser;
    (void)sdRef;
    (void)flags;
    (void)interfaceIndex;
    (void)fullname;
    (void)hosttarget;
    (void)port;
    [lookup close];
    if (!browser || browser->_cancelled)
        return;
    if (errorCode != kDNSServiceErr_NoError)
        return;
    if (lookup->_wantRecord && txtLen)
        lookup->_txt = (RevenantNWTxtRecord *)nw_txt_record_create_with_bytes(txtRecord, txtLen);
    lookup->_resolved = YES;
    RevenantNWBrowseResult *old = browser->_reported[lookup->_key];
    RevenantNWBrowseResult *fresh = revenant_browser_result(browser, lookup);
    lookup->_reported = YES;
    browser->_reported[lookup->_key] = fresh;
    if (old && nw_txt_record_is_equal((nw_txt_record_t)old->_txtRecord, (nw_txt_record_t)fresh->_txtRecord))
        return;
    revenant_browser_enqueue(browser, old, fresh);
}

static RevenantNWBrowserLookup *revenant_browser_lookup(RevenantNWBrowser *browser, NSString *name, NSString *type,
                                                    NSString *domain)
{
    RevenantNWBrowserLookup *lookup = [[RevenantNWBrowserLookup alloc] init];
    lookup->_key = name;
    lookup->_name = name;
    lookup->_type = type;
    lookup->_domain = domain;
    lookup->_interfaceIndexes = [NSMutableArray array];
    lookup->_wantRecord = browser->_descriptor->_includeTxtRecord;
    lookup->_browser = browser;
    browser->_lookups[name] = lookup;
    return lookup;
}

static void revenant_browser_resolve(RevenantNWBrowser *browser, RevenantNWBrowserLookup *lookup)
{
    DNSServiceRef resolve = NULL;
    if (DNSServiceResolve(&resolve, 0, kDNSServiceInterfaceIndexAny, lookup->_name.UTF8String,
                          lookup->_type.UTF8String, lookup->_domain.UTF8String, revenant_browser_resolved,
                          (__bridge void *)lookup) != kDNSServiceErr_NoError || !resolve)
        return;
    lookup->_resolve = resolve;
    lookup->_source = revenant_browser_source(DNSServiceRefSockFD(resolve), browser->_queue);
    if (!lookup->_source) {
        [lookup close];
        return;
    }
    __weak RevenantNWBrowser *weak = browser;
    dispatch_source_set_event_handler(lookup->_source, ^{
        RevenantNWBrowser *strong = weak;
        if (strong && !strong->_cancelled)
            revenant_browser_pump(lookup->_resolve, strong);
    });
}

static void revenant_browser_browsed(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                                   DNSServiceErrorType errorCode, const char *name)
{
    RevenantNWBrowser *browser = (__bridge RevenantNWBrowser *)dispatch_get_specific((const void *)sdRef);
    if (!browser || browser->_cancelled || errorCode != kDNSServiceErr_NoError)
        return;
    if (!name || !name[0])
        return;
    NSString *instance = [NSString stringWithUTF8String:name];
    if (!instance.length)
        return;
    BOOL added = (flags & kDNSServiceFlagsAdd) != 0;
    RevenantNWBrowserLookup *lookup = browser->_lookups[instance];
    if (!lookup) {
        if (!added)
            return;
        lookup = revenant_browser_lookup(browser, instance, browser->_type, browser->_domain);
    }
    NSNumber *index = @(interfaceIndex);
    if (added == (BOOL)[lookup->_interfaceIndexes containsObject:index])
        return;
    if (added)
        [lookup->_interfaceIndexes addObject:index];
    else
        [lookup->_interfaceIndexes removeObject:index];
    if (!lookup->_interfaceIndexes.count) {
        revenant_browser_gone(browser, lookup);
        revenant_browser_drain(browser);
        return;
    }
    if (!lookup->_resolve && !lookup->_resolved) {
        revenant_browser_resolve(browser, lookup);
        return;
    }
    RevenantNWBrowseResult *old = browser->_reported[lookup->_key];
    if (!old)
        return;
    RevenantNWBrowseResult *fresh = revenant_browser_result(browser, lookup);
    browser->_reported[lookup->_key] = fresh;
    revenant_browser_enqueue(browser, old, fresh);
}

static void revenant_browser_interfaces(RevenantNWBrowser *browser, nw_path_t path)
{
    NSMutableDictionary *interfaces = [NSMutableDictionary dictionary];
    nw_path_enumerate_interfaces_block_t each = ^(nw_interface_t interface) {
        interfaces[@(nw_interface_get_index(interface))] = (id)interface;
        return (bool)true;
    };
    nw_path_enumerate_interfaces(path, each);
    browser->_interfaces = interfaces;
}

static BOOL revenant_browser_target(RevenantNWBrowser *browser, NSString **out_type, NSString **out_domain)
{
    NSString *application = browser->_descriptor->_applicationService;
    if (application.length) {
        *out_type = [NSString stringWithFormat:@"_%@._tcp", application];
        *out_domain = @"local.";
        return YES;
    }
    if (!browser->_descriptor->_bonjourType.length || !browser->_descriptor->_bonjourDomain.length)
        return NO;
    *out_type = browser->_descriptor->_bonjourType;
    *out_domain = browser->_descriptor->_bonjourDomain;
    return YES;
}

static void revenant_browser_begin(nw_browser_t browser)
{
    RevenantNWBrowser *self = (RevenantNWBrowser *)browser;
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        revenant_browser_report(self, nw_browser_state_waiting, nil);
        NSString *type = nil, *domain = nil;
        if (!revenant_browser_target(self, &type, &domain)) {
            revenant_browser_report(self, nw_browser_state_failed,
                                  revenant_browser_error(nw_error_domain_dns, kDNSServiceErr_BadParam));
            return;
        }
        self->_type = type;
        self->_domain = domain;
        DNSServiceRef browse = NULL;
        DNSServiceErrorType failure = DNSServiceBrowse(&browse, 0, kDNSServiceInterfaceIndexAny,
                                                       type.UTF8String, domain.UTF8String,
                                                       revenant_browser_browsed, (__bridge void *)self);
        int descriptor = browse ? DNSServiceRefSockFD(browse) : -1;
        if (failure != kDNSServiceErr_NoError || !browse || descriptor < 0) {
            if (browse)
                DNSServiceRefDeallocate(browse);
            revenant_browser_report(self, nw_browser_state_failed,
                                  revenant_browser_error(nw_error_domain_dns,
                                                       (int)(failure != kDNSServiceErr_NoError ? failure
                                                                                          : kDNSServiceErr_Unknown)));
            return;
        }
        self->_browse = browse;
        dispatch_queue_set_specific(self->_queue, (const void *)browse, (__bridge void *)self, NULL);
        self->_source = revenant_browser_source(descriptor, self->_queue);
        if (!self->_source) {
            revenant_browser_report(self, nw_browser_state_failed,
                                  revenant_browser_error(nw_error_domain_dns, kDNSServiceErr_Unknown));
            return;
        }
        __weak RevenantNWBrowser *weak = self;
        dispatch_source_set_event_handler(self->_source, ^{
            RevenantNWBrowser *strong = weak;
            if (strong && !strong->_cancelled)
                revenant_browser_pump(strong->_browse, strong);
        });
        self->_monitor = nw_path_monitor_create();
        nw_path_monitor_set_queue(self->_monitor, self->_queue);
        nw_path_monitor_set_update_handler(self->_monitor, ^(nw_path_t path) {
            RevenantNWBrowser *strong = weak;
            if (strong && !strong->_cancelled)
                revenant_browser_interfaces(strong, path);
        });
        nw_path_monitor_start(self->_monitor);
        revenant_browser_report(self, nw_browser_state_ready, nil);
    });
}

static void revenant_browser_stop(nw_browser_t browser)
{
    RevenantNWBrowser *self = (RevenantNWBrowser *)browser;
    dispatch_block_t stop = ^{
        @synchronized(self) {
            if (self->_cancelled)
                return;
            self->_cancelled = YES;
        }
        if (self->_source) {
            dispatch_source_cancel(self->_source);
            self->_source = nil;
        }
        if (self->_browse) {
            dispatch_queue_set_specific(self->_queue, (const void *)self->_browse, NULL, NULL);
            DNSServiceRefDeallocate(self->_browse);
            self->_browse = NULL;
        }
        for (RevenantNWBrowserLookup *lookup in [self->_lookups allValues]) {
            [lookup close];
        }
        [self->_lookups removeAllObjects];
        [self->_reported removeAllObjects];
        [self->_batch removeAllObjects];
        if (self->_monitor) {
            nw_path_monitor_cancel(self->_monitor);
            self->_monitor = NULL;
        }
        self->_state = nil;
        self->_results = nil;
        revenant_browser_report(self, nw_browser_state_cancelled, nil);
    };
    if (self->_queue)
        dispatch_async(self->_queue, stop);
    else
        stop();
}

void RevenantNWBrowserSetQueue(nw_browser_t browser, dispatch_queue_t queue)
{
    if (browser)
        ((RevenantNWBrowser *)browser)->_queue = queue;
}

void RevenantNWBrowserSetStateHandler(nw_browser_t browser, nw_browser_state_changed_handler_t handler)
{
    if (browser)
        ((RevenantNWBrowser *)browser)->_state = [handler copy];
}

void RevenantNWBrowserSetResultsHandler(nw_browser_t browser, nw_browser_browse_results_changed_handler_t handler)
{
    if (browser)
        ((RevenantNWBrowser *)browser)->_results = [handler copy];
}

nw_browse_descriptor_t RevenantNWBrowserCopyBrowseDescriptor(nw_browser_t browser)
{
    return browser ? (nw_browse_descriptor_t)((RevenantNWBrowser *)browser)->_descriptor : NULL;
}

nw_parameters_t RevenantNWBrowserCopyParameters(nw_browser_t browser)
{
    return browser ? (nw_parameters_t)((RevenantNWBrowser *)browser)->_parameters : NULL;
}

void RevenantNWBrowserStart(nw_browser_t browser)
{
    if (!browser)
        return;
    RevenantNWBrowser *self = (RevenantNWBrowser *)browser;
    @synchronized(self) {
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    revenant_browser_begin(browser);
}

nw_browser_t nw_browser_create(nw_browse_descriptor_t descriptor, nw_parameters_t parameters)
{
    if (!descriptor)
        return NULL;
    RevenantNWBrowser *browser = [[RevenantNWBrowser alloc] init];
    browser->_descriptor = (RevenantNWBrowseDescriptor *)descriptor;
    browser->_parameters = parameters ? (RevenantNWParameters *)parameters : (RevenantNWParameters *)nw_parameters_create();
    browser->_reported = [NSMutableDictionary dictionary];
    browser->_lookups = [NSMutableDictionary dictionary];
    browser->_batch = [NSMutableArray array];
    browser->_interfaces = [NSMutableDictionary dictionary];
    browser->_value = nw_browser_state_invalid;
    return browser;
}

void nw_browser_cancel(nw_browser_t browser)
{
    if (!browser)
        return;
    revenant_browser_stop(browser);
}
