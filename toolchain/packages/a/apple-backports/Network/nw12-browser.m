#define DNSServiceBrowse DNSServiceBrowseAsThisSDKDeclaresIt
#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <arpa/inet.h>
#include <dns_sd.h>
#include <string.h>
#undef DNSServiceBrowse

typedef void (*CharonDNSServiceBrowseReply)(DNSServiceRef, DNSServiceFlags, uint32_t, DNSServiceErrorType,
                                            const char *);

extern DNSServiceErrorType DNSServiceBrowse(DNSServiceRef *, DNSServiceFlags, uint32_t, const char *,
                                            const char *, CharonDNSServiceBrowseReply, void *);
extern DNSServiceErrorType DNSServiceResolve(DNSServiceRef *, DNSServiceFlags, uint32_t, const char *,
                                            const char *, const char *, DNSServiceResolveReply, void *);
extern void DNSServiceRefDeallocate(DNSServiceRef);
extern int DNSServiceProcessResult(DNSServiceRef);
extern int DNSServiceRefSockFD(DNSServiceRef);

@class CharonNWBrowser;

@interface CharonNWBrowserLookup : NSObject {
@public
    NSString *_key;
    NSString *_name;
    NSString *_type;
    NSString *_domain;
    NSMutableArray *_interfaceIndexes;
    __weak CharonNWBrowser *_browser;
    DNSServiceRef _resolve;
    dispatch_source_t _source;
    CharonNWTxtRecord *_txt;
    BOOL _resolved;
    BOOL _reported;
    BOOL _wantRecord;
}
@end

@implementation CharonNWBrowserLookup

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

@interface CharonNWBrowser : NSObject <OS_nw_browser> {
@public
    CharonNWBrowseDescriptor *_descriptor;
    CharonNWParameters *_parameters;
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

@implementation CharonNWBrowser
@end

static void charon_browser_report(CharonNWBrowser *browser, nw_browser_state_t state, CharonNWError *error)
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

static CharonNWError *charon_browser_error(nw_error_domain_t domain, int code)
{
    CharonNWError *error = [[CharonNWError alloc] init];
    error->_domain = domain;
    error->_code = code;
    return error;
}

static dispatch_source_t charon_browser_source(int handle, dispatch_queue_t queue)
{
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)handle, 0, queue);
    if (source)
        dispatch_resume(source);
    return source;
}

static nw_interface_t charon_browser_interface(CharonNWBrowser *browser, NSNumber *index)
{
    return (nw_interface_t)browser->_interfaces[index];
}

static CharonNWBrowseResult *charon_browser_result(CharonNWBrowser *browser, CharonNWBrowserLookup *lookup)
{
    CharonNWBrowseResult *result = [[CharonNWBrowseResult alloc] init];
    result->_name = lookup->_name;
    result->_type = lookup->_type;
    result->_domain = lookup->_domain;
    result->_txtRecord = lookup->_txt;
    NSMutableArray *interfaces = [NSMutableArray array];
    for (NSNumber *index in lookup->_interfaceIndexes) {
        nw_interface_t interface = charon_browser_interface(browser, index);
        if (interface)
            [interfaces addObject:(id)interface];
    }
    result->_interfaces = interfaces;
    CharonNWEndpoint *endpoint = [[CharonNWEndpoint alloc] init];
    endpoint->_type = nw_endpoint_type_bonjour_service;
    endpoint->_bonjourName = lookup->_name;
    endpoint->_bonjourType = lookup->_type;
    endpoint->_bonjourDomain = lookup->_domain;
    endpoint->_txtRecord = lookup->_txt;
    result->_endpoint = endpoint;
    return result;
}

static void charon_browser_enqueue(CharonNWBrowser *browser, CharonNWBrowseResult *old, CharonNWBrowseResult *fresh)
{
    [browser->_batch addObject:[NSArray arrayWithObjects:(id)(old ?: [NSNull null]),
                                                   (id)(fresh ?: [NSNull null]), nil]];
}

static void charon_browser_drain(CharonNWBrowser *browser)
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

static void charon_browser_pump(DNSServiceRef reference, CharonNWBrowser *browser)
{
    if (reference)
        DNSServiceProcessResult(reference);
    charon_browser_drain(browser);
}

static void charon_browser_gone(CharonNWBrowser *browser, CharonNWBrowserLookup *lookup)
{
    CharonNWBrowseResult *reported = browser->_reported[lookup->_key];
    [lookup close];
    [browser->_lookups removeObjectForKey:lookup->_key];
    if (!reported)
        return;
    [browser->_reported removeObjectForKey:lookup->_key];
    charon_browser_enqueue(browser, reported, nil);
}

static void charon_browser_resolved(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                                    DNSServiceErrorType errorCode, const char *fullname, const char *hosttarget,
                                    uint16_t port, uint16_t txtLen, const unsigned char *txtRecord, void *context)
{
    CharonNWBrowserLookup *lookup = (__bridge CharonNWBrowserLookup *)context;
    CharonNWBrowser *browser = lookup->_browser;
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
        lookup->_txt = (CharonNWTxtRecord *)nw_txt_record_create_with_bytes(txtRecord, txtLen);
    lookup->_resolved = YES;
    CharonNWBrowseResult *old = browser->_reported[lookup->_key];
    CharonNWBrowseResult *fresh = charon_browser_result(browser, lookup);
    lookup->_reported = YES;
    browser->_reported[lookup->_key] = fresh;
    if (old && nw_txt_record_is_equal((nw_txt_record_t)old->_txtRecord, (nw_txt_record_t)fresh->_txtRecord))
        return;
    charon_browser_enqueue(browser, old, fresh);
}

static CharonNWBrowserLookup *charon_browser_lookup(CharonNWBrowser *browser, NSString *name, NSString *type,
                                                    NSString *domain)
{
    CharonNWBrowserLookup *lookup = [[CharonNWBrowserLookup alloc] init];
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

static void charon_browser_resolve(CharonNWBrowser *browser, CharonNWBrowserLookup *lookup)
{
    DNSServiceRef resolve = NULL;
    if (DNSServiceResolve(&resolve, 0, kDNSServiceInterfaceIndexAny, lookup->_name.UTF8String,
                          lookup->_type.UTF8String, lookup->_domain.UTF8String, charon_browser_resolved,
                          (__bridge void *)lookup) != kDNSServiceErr_NoError || !resolve)
        return;
    lookup->_resolve = resolve;
    lookup->_source = charon_browser_source(DNSServiceRefSockFD(resolve), browser->_queue);
    if (!lookup->_source) {
        [lookup close];
        return;
    }
    __weak CharonNWBrowser *weak = browser;
    dispatch_source_set_event_handler(lookup->_source, ^{
        CharonNWBrowser *strong = weak;
        if (strong && !strong->_cancelled)
            charon_browser_pump(lookup->_resolve, strong);
    });
}

static void charon_browser_browsed(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                                   DNSServiceErrorType errorCode, const char *name)
{
    CharonNWBrowser *browser = (__bridge CharonNWBrowser *)dispatch_get_specific((const void *)sdRef);
    if (!browser || browser->_cancelled || errorCode != kDNSServiceErr_NoError)
        return;
    if (!name || !name[0])
        return;
    NSString *instance = [NSString stringWithUTF8String:name];
    if (!instance.length)
        return;
    BOOL added = (flags & kDNSServiceFlagsAdd) != 0;
    CharonNWBrowserLookup *lookup = browser->_lookups[instance];
    if (!lookup) {
        if (!added)
            return;
        lookup = charon_browser_lookup(browser, instance, browser->_type, browser->_domain);
    }
    NSNumber *index = @(interfaceIndex);
    if (added == (BOOL)[lookup->_interfaceIndexes containsObject:index])
        return;
    if (added)
        [lookup->_interfaceIndexes addObject:index];
    else
        [lookup->_interfaceIndexes removeObject:index];
    if (!lookup->_interfaceIndexes.count) {
        charon_browser_gone(browser, lookup);
        charon_browser_drain(browser);
        return;
    }
    if (!lookup->_resolve && !lookup->_resolved) {
        charon_browser_resolve(browser, lookup);
        return;
    }
    CharonNWBrowseResult *old = browser->_reported[lookup->_key];
    if (!old)
        return;
    CharonNWBrowseResult *fresh = charon_browser_result(browser, lookup);
    browser->_reported[lookup->_key] = fresh;
    charon_browser_enqueue(browser, old, fresh);
}

static void charon_browser_interfaces(CharonNWBrowser *browser, nw_path_t path)
{
    NSMutableDictionary *interfaces = [NSMutableDictionary dictionary];
    nw_path_enumerate_interfaces_block_t each = ^(nw_interface_t interface) {
        interfaces[@(nw_interface_get_index(interface))] = (id)interface;
        return (bool)true;
    };
    nw_path_enumerate_interfaces(path, each);
    browser->_interfaces = interfaces;
}

static BOOL charon_browser_target(CharonNWBrowser *browser, NSString **out_type, NSString **out_domain)
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

static void charon_browser_begin(nw_browser_t browser)
{
    CharonNWBrowser *self = (CharonNWBrowser *)browser;
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        charon_browser_report(self, nw_browser_state_waiting, nil);
        NSString *type = nil, *domain = nil;
        if (!charon_browser_target(self, &type, &domain)) {
            charon_browser_report(self, nw_browser_state_failed,
                                  charon_browser_error(nw_error_domain_dns, kDNSServiceErr_BadParam));
            return;
        }
        self->_type = type;
        self->_domain = domain;
        DNSServiceRef browse = NULL;
        DNSServiceErrorType failure = DNSServiceBrowse(&browse, 0, kDNSServiceInterfaceIndexAny,
                                                       type.UTF8String, domain.UTF8String,
                                                       charon_browser_browsed, (__bridge void *)self);
        int descriptor = browse ? DNSServiceRefSockFD(browse) : -1;
        if (failure != kDNSServiceErr_NoError || !browse || descriptor < 0) {
            if (browse)
                DNSServiceRefDeallocate(browse);
            charon_browser_report(self, nw_browser_state_failed,
                                  charon_browser_error(nw_error_domain_dns,
                                                       (int)(failure != kDNSServiceErr_NoError ? failure
                                                                                          : kDNSServiceErr_Unknown)));
            return;
        }
        self->_browse = browse;
        dispatch_queue_set_specific(self->_queue, (const void *)browse, (__bridge void *)self, NULL);
        self->_source = charon_browser_source(descriptor, self->_queue);
        if (!self->_source) {
            charon_browser_report(self, nw_browser_state_failed,
                                  charon_browser_error(nw_error_domain_dns, kDNSServiceErr_Unknown));
            return;
        }
        __weak CharonNWBrowser *weak = self;
        dispatch_source_set_event_handler(self->_source, ^{
            CharonNWBrowser *strong = weak;
            if (strong && !strong->_cancelled)
                charon_browser_pump(strong->_browse, strong);
        });
        self->_monitor = nw_path_monitor_create();
        nw_path_monitor_set_queue(self->_monitor, self->_queue);
        nw_path_monitor_set_update_handler(self->_monitor, ^(nw_path_t path) {
            CharonNWBrowser *strong = weak;
            if (strong && !strong->_cancelled)
                charon_browser_interfaces(strong, path);
        });
        nw_path_monitor_start(self->_monitor);
        charon_browser_report(self, nw_browser_state_ready, nil);
    });
}

static void charon_browser_stop(nw_browser_t browser)
{
    CharonNWBrowser *self = (CharonNWBrowser *)browser;
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
        for (CharonNWBrowserLookup *lookup in [self->_lookups allValues]) {
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
        charon_browser_report(self, nw_browser_state_cancelled, nil);
    };
    if (self->_queue)
        dispatch_async(self->_queue, stop);
    else
        stop();
}

void CharonNWBrowserSetQueue(nw_browser_t browser, dispatch_queue_t queue)
{
    if (browser)
        ((CharonNWBrowser *)browser)->_queue = queue;
}

void CharonNWBrowserSetStateHandler(nw_browser_t browser, nw_browser_state_changed_handler_t handler)
{
    if (browser)
        ((CharonNWBrowser *)browser)->_state = [handler copy];
}

void CharonNWBrowserSetResultsHandler(nw_browser_t browser, nw_browser_browse_results_changed_handler_t handler)
{
    if (browser)
        ((CharonNWBrowser *)browser)->_results = [handler copy];
}

nw_browse_descriptor_t CharonNWBrowserCopyBrowseDescriptor(nw_browser_t browser)
{
    return browser ? (nw_browse_descriptor_t)((CharonNWBrowser *)browser)->_descriptor : NULL;
}

nw_parameters_t CharonNWBrowserCopyParameters(nw_browser_t browser)
{
    return browser ? (nw_parameters_t)((CharonNWBrowser *)browser)->_parameters : NULL;
}

void CharonNWBrowserStart(nw_browser_t browser)
{
    if (!browser)
        return;
    CharonNWBrowser *self = (CharonNWBrowser *)browser;
    @synchronized(self) {
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    charon_browser_begin(browser);
}

nw_browser_t nw_browser_create(nw_browse_descriptor_t descriptor, nw_parameters_t parameters)
{
    if (!descriptor)
        return NULL;
    CharonNWBrowser *browser = [[CharonNWBrowser alloc] init];
    browser->_descriptor = (CharonNWBrowseDescriptor *)descriptor;
    browser->_parameters = parameters ? (CharonNWParameters *)parameters : (CharonNWParameters *)nw_parameters_create();
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
    charon_browser_stop(browser);
}
