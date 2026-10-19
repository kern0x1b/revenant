/*
 * The browser object of Network, and the calls the 12.0 cache already carries.
 *
 * What a browser is here: a Bonjour browse, over the release's own DNS-SD client, asked with the entry
 * point that is a browse - `DNSServiceBrowse`, which names each instance the browse finds and the
 * interface it was found on. Every answer is taken from a dispatch source over the reference's own
 * descriptor (`DNSServiceRefSockFD` says when a result is waiting, `DNSServiceProcessResult` is the call
 * that takes it), so every callback runs on the queue the program gave the browser and none of them runs
 * before the browser has been started. `DNSServiceResolve` answers for each instance with the port it
 * publishes and the record it advertises. Nothing here is a second DNS-SD: the release answers the
 * queries and the release decides what is on the link.
 *
 * Why `DNSServiceBrowse` and not a PTR record query: measured on this machine, a PTR question asked with
 * `DNSServiceQueryRecord` is not answered at all - not for the type being browsed, not for a type that is
 * on the link, and not for the TXT or SRV record of the very service the same process registered, while a
 * browse for the same type answers and a `DNSServiceResolve` in the same process answers three times.
 * `tests/backports/host/network-browser/run.sh` is the differential, and `facts/Network/NWBrowser.md`
 * carries the reading. The entry point was not called before because the SDK's header declares an
 * `interfaceIndex` these releases were believed not to pass; that belief was wrong, and the next
 * paragraph is what measures it.
 *
 * What a browse result is: one service instance the browse reported, with the endpoint a program
 * connects to, the interfaces the browse named the service on - the `interfaceIndex` every answer
 * carries, which is what tells one answer on the Wi-Fi radio from the same answer on a Personal
 * Hotspot's bridge - and the TXT record when the descriptor asked for one.
 *
 * A result is reported once it can be used. The browse says an instance exists, and the port resolves
 * it before the result is handed over, because the record the descriptor asked for is the resolve's to
 * answer. That is also what makes the change bits mean what the header says: a service that has not
 * resolved has no record to compare, so it is never the `old_result` of a pair.
 *
 * The endpoint of a result carries no port, and this is measured rather than chosen: Apple's own browse
 * result for the same service, on the same link, in the same second, answers `nw_endpoint_get_port`
 * with 0 (`tests/backports/host/network-browser` prints it on both sides). That is also what the header
 * of `nw_endpoint_get_port` says - 0 for an endpoint that is not a host or address endpoint - and a
 * Bonjour service endpoint is named by its instance, its type and its domain; the port it publishes
 * belongs to the service, not to the endpoint, and a program reads it by connecting and letting the
 * resolve that a connection makes answer it. So the port the resolve brings is not put on the endpoint.
 *
 * The interfaces of a result are this library's own interface objects, reached through the path monitor
 * the library already carries (`nw_path_monitor_*`, `nw_path_enumerate_interfaces`,
 * `nw_interface_get_index`). A browse result hands out `nw_interface_t`, and the only objects of that
 * type anywhere on this release are the ones the path monitor makes, so the browser keeps one object
 * per index as the monitor reports it, and an answer naming an index picks its object out of that
 * table. An answer naming an interface the port has no object for - one that went down between the
 * answer and the last path update - contributes no interface, and the count says so.
 *
 * Why the browse is `DNSServiceBrowse` on every release this port builds: the SDK's header and the
 * releases' own symbols agree, which is measured rather than assumed. One image is taken out of each
 * cache of the ladder with `tools/cache-extract.lua` (dyld.lua's own `extract()`) and the symbol's own
 * disassembly is read, and on 4.3, 6.1.3 and 8.0 the entry point consumes seven parameters in the
 * header's order - r0 the reference, r1 the flags, r2 a 32-bit word compared against zero for
 * `kDNSServiceInterfaceIndexAny`, r3 the service type as a string, and three incoming stack words for
 * the domain, the reply and the context - and the reply it makes carries six parameters in the header's
 * order, the third being the interface index the reply names the instance on.
 * `facts/Network/NWBrowser.md` carries the reading, the addresses and the run.
 *
 * This file holds the two calls the 12.0 cache already exports - `nw_browser_create` and
 * `nw_browser_cancel`, measured in `coordination/corpus/caches/12.0.tsv` - and the object itself. The
 * rest of the surface is in nw16-browser.m, because the ladder has no rung between 12.0 and 16.0 and
 * those calls are first exported by the 16.0 cache; `tools/release-split.lua` is what says so, and the
 * SDK's header gives the whole family iOS 13. The file reaches the object through the C functions at the
 * end of this one, for the reason `nw12-listener.m` gives for the listener's.
 */

/* The SDK's own declaration of `DNSServiceBrowse` is renamed out of the way while this file's headers
   are read, and the entry point is declared below under the name the header gives it. `Network.framework`
   pulls `dns_sd.h` in through `error.h`, so the rename has to cover the framework import as well as the
   direct include, and this file is the only one of the package that names any of it. The header's
   declaration is the newest one: its reply type carries two parameters a release that makes six never
   writes, so a call written against it would read registers this program never set. What each release's
   own symbol takes is read out of its disassembly, and the paragraph on the browse above names the
   reading; the declaration below is therefore the port's own and does not depend on the header's. */
#define DNSServiceBrowse DNSServiceBrowseAsThisSDKDeclaresIt
#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <arpa/inet.h>
#include <dns_sd.h>
#include <string.h>
#undef DNSServiceBrowse

/* The reply a browse makes, read as far as every release's own reply handler agrees: the reference, the
   flags, the interface the instance was found on, the error, and the instance name. What comes after the
   name is not this port's business, because it is not the same on every release - the reply handlers of
   4.3, 6.1.3 and 8.0 hand the program's reply six words, the SDK 16.4 header's typedef declares eight
   (the service type and the domain between the name and the context), and a function that ignores the
   arguments past the ones it names is called correctly by both, since they arrive in the same registers
   and the same stack words either way. So the browser is not taken from the reply: it is the queue's own
   answer, through the reference the reply carries and `dispatch_get_specific()`. Every reference of a
   browser is created and driven on the queue the program gave it, so the key - the reference itself - is
   found on that queue and nowhere else, and two browsers on one queue cannot answer for each other.
   Both dispatch calls are exported by the 6.0 and the 6.1.3 cache, and no band below 6.0 links this
   library at all - `facts/Network/NWFloor.md` is why, and the export measurement is in
   `facts/Network/NWBrowser.md`. */
typedef void (*CharonDNSServiceBrowseReply)(DNSServiceRef, DNSServiceFlags, uint32_t, DNSServiceErrorType,
                                            const char *);

/* The DNS-SD entry points, redeclared to be reached under the names dns_sd.h gives them. Nothing here
   is a fallback: every one of them is exported by every release this package builds, measured on the
   ladder's own caches - `tools/corpus/cache-exports.lua` over the export tries, because the trie
   compresses names and a raw search over the cache bytes is not an oracle:

       4.3     _DNSServiceBrowse, _DNSServiceResolve, _DNSServiceProcessResult,
               _DNSServiceRefSockFD, _DNSServiceRefDeallocate
               all in /usr/lib/system/libsystem_dnssd.dylib
       6.0     the same five, the same image
       6.1.3   the same five, the same image

   The redeclarations are here because the port does not take the SDK header's word for what a release's
   own symbol takes - the header's answer is the newest one, and a release is free to be older. Each is
   spelled out here, and what each release's own symbol takes is read out of its disassembly; the two
   paragraphs above name the reading for the browse, and it agrees with the header's declaration on every
   release the ladder holds. `facts/Network/NWBrowser.md` carries the addresses and the run. */
extern DNSServiceErrorType DNSServiceBrowse(DNSServiceRef *, DNSServiceFlags, uint32_t, const char *,
                                            const char *, CharonDNSServiceBrowseReply, void *);
extern DNSServiceErrorType DNSServiceResolve(DNSServiceRef *, DNSServiceFlags, uint32_t, const char *,
                                            const char *, const char *, DNSServiceResolveReply, void *);
extern void DNSServiceRefDeallocate(DNSServiceRef);
extern int DNSServiceProcessResult(DNSServiceRef);
extern int DNSServiceRefSockFD(DNSServiceRef);

@class CharonNWBrowser;

/* One service instance the browse reported, and the resolve that turns its name into a port and a
   record. The browser owns every lookup, so the way back to it is weak: a resolve that answers after
   the browser is gone finds nothing and does nothing. */
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

/* The reference owns the descriptor the source watches, so the source goes first and never fires
   against a reference that is gone. Nothing else closes that descriptor: `DNSServiceRefDeallocate` is
   what closes it, and a source that closed it as well would close a descriptor number the process may
   have handed out again in between. */
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

/* The states are the SDK's: never backwards, `waiting` before the browse runs, `ready` once it does,
   `failed` with the error that stopped it and `cancelled` when the program said so. */
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

/* A source over a descriptor, without the close-on-cancel of `charon_nw_read_source`: a DNS-SD
   reference closes its own descriptor in `DNSServiceRefDeallocate`, and a source that closed it as
   well would close a descriptor number the process may have handed out again in between. */
static dispatch_source_t charon_browser_source(int handle, dispatch_queue_t queue)
{
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)handle, 0, queue);
    if (source)
        dispatch_resume(source);
    return source;
}

/* One interface object of this library, or NULL when the path monitor has not reported that index:
   `nw_interface_get_index` is the port's own way of saying which interface an object is, and the
   monitor is where those objects come from. */
static nw_interface_t charon_browser_interface(CharonNWBrowser *browser, NSNumber *index)
{
    return (nw_interface_t)browser->_interfaces[index];
}

/* The result as the service is known now: a fresh instance every time, because the handler's contract
   is that the new result replaces the old one. */
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

/* One batch of browse answers is one batch of handler calls and the last of them says so, which is
   what `batch_complete` is for: a program that draws a list of services redraws it once. */
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

/* Take what a reference has waiting. The answers delivered here may have started resolves of their
   own; each of those has a reference and a source of its own and is taken the same way. */
static void charon_browser_pump(DNSServiceRef reference, CharonNWBrowser *browser)
{
    if (reference)
        DNSServiceProcessResult(reference);
    charon_browser_drain(browser);
}

/* The service is no longer on any interface: the last result the program was given goes away with it,
   and a service that never resolved was never given one, so it goes quietly. */
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

/* The resolve answered: the record the service advertises, when the descriptor asked for one. The port
   it publishes is not carried anywhere - the endpoint of a browse result answers 0 for it, which is what
   Apple's own browse result answers, and the paragraph at the head of this file is the measurement. */
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
    /* A resolve that failed is a service the port cannot connect to. Nothing is reported for it, and a
       service already reported keeps the result it had: a browse keeps going when one service on the
       link goes away mid-resolve, and no browse error is raised for that. */
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

/* Resolve the service once: its port, and its record when the descriptor asked for one. A resolve that
   cannot be started leaves the service unreported - there is no port to connect to - and the next
   browse answer for it tries again. */
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

/* One browse answer: the instance is on an interface, or it is not any more. The reply is read as far as
   every release agrees (the typedef above), and the browser is the queue's own answer for the reference
   the reply carries, because the arguments after the name are not the same on every release and the one
   of them that is the context is not in the same place twice. */
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
    /* `Add` is what a browse answer carries when the instance is there; the same answer without it is the
       instance going away, which is what the flag's own documentation says of an enumeration. */
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
        /* Nothing has been reported for this service yet; the first result is the resolve's, and it
           carries the interfaces as they stand when the resolve answers. */
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
    /* The typedef, not a spelled-out `bool`: dns_sd.h above pulled in stdbool.h, where `bool` is a
       macro, and the block's own return type is C99 bool. */
    nw_path_enumerate_interfaces_block_t each = ^(nw_interface_t interface) {
        interfaces[@(nw_interface_get_index(interface))] = (id)interface;
        return (bool)true;
    };
    nw_path_enumerate_interfaces(path, each);
    browser->_interfaces = interfaces;
}

/* What the browser browses for. A Bonjour descriptor names the type and the domain itself; an
   application service is one name that stands for both, and an application service's name on the link
   is `_<name>._tcp` in the local domain - the spelling facts/Network/NWBrowser.md carries. */
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
        /* The reply finds the browser through this key rather than through an argument of its own: every
           reference of a browser is created and driven on the queue the program gave it, so the key - the
           reference itself - is on that queue and on no other, and the answer to a browse cannot reach a
           queue that never created one. `charon_browser_stop` takes it back off before it releases the
           reference, so a queue never keeps a pointer to a browser that is gone. */
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
        /* The interfaces a browse answer names are handed out as objects of the library's own path
           monitor, which is where `nw_interface_t` comes from on a release with no Network.framework. */
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
            /* The key comes off the queue before the reference it names is released, so no queue is left
               holding a pointer to a browser that is gone. */
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

/* What nw16-browser.m needs from the object, as C functions, for the reason the listener's are: with
   the fragile ABI a class's ivar offsets are emitted by every file that sees its @interface, so the
   class lives in this one file and its neighbour asks for what it needs. */
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
        /* The header says the queue must be set before the browser is started, and a browser started
           twice is the same browse: the second start says nothing and calls nobody. */
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
    /* The header says an empty parameters object is created internally when the caller has none, and
       `nw_browser_copy_parameters` hands back what the browse runs with either way. */
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