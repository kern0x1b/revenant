#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

/* One reader, two binaries.
 *
 *   -DHOST_SIDE   link Apple's NetworkExtension only: every answer below is Apple's own, and the
 *                 dladdr line proves it per selector, so nothing this process links can be mistaken
 *                 for the framework.
 *   -DHOST_SIDE unset, with the port's NEDNSSettings.m in the same link: every answer is the port's.
 *
 * Both print the same `name<TAB>value` lines, and the harness compares them line by line. Only the
 * six names Apple's class also answers are compared; the other three are checked against the iOS 26.2
 * header's own declarations, which is a different oracle and says so.
 */
static NSString *const CLASS_NAME = @"NEDNSSettings";

#ifdef HOST_SIDE
#import <NetworkExtension/NetworkExtension.h>
#else
#import "CharonNEDNSSettings.h"
#endif

static void emit(const char *name, const char *value)
{
    printf("%s\t%s\n", name, value ? value : "(nil)");
}

/* an id, as the two words a reader wants: present or not, or the string it holds */
static void emit_id(const char *name, id value)
{
    if (!value) {
        emit(name, "(nil)");
        return;
    }
    emit(name, [value isKindOfClass:[NSString class]] ? "a string" : "an object");
}

static void emit_bool(const char *name, BOOL value)
{
    emit(name, value ? "YES" : "NO");
}

int main(void)
{
    @autoreleasepool {
        Class cls = NSClassFromString(CLASS_NAME);
        printf("class\t%s\n", cls ? "present" : "ABSENT");
        if (!cls)
            return 1;

        /* the dladdr proof: whose implementation answers this selector in this binary */
        Method servers = class_getInstanceMethod(cls, @selector(servers));
        IMP imp = servers ? method_getImplementation(servers) : NULL;
        Dl_info info;
        memset(&info, 0, sizeof info);
        const char *image = (imp && dladdr((const void *)imp, &info) && info.dli_fname)
                                ? info.dli_fname : "(unresolved)";
        printf("dladdr\t%s\n", strrchr(image, '/') ? strrchr(image, '/') + 1 : image);

        id fresh = [[cls alloc] init];
        emit("fresh.servers", [fresh valueForKey:@"servers"] ? "an array" : "(nil)");
        emit("fresh.searchDomains", [fresh valueForKey:@"searchDomains"] ? "an array" : "(nil)");
        emit("fresh.matchDomains", [fresh valueForKey:@"matchDomains"] ? "an array" : "(nil)");
        emit_bool("fresh.matchDomainsNoSearch", [fresh valueForKey:@"matchDomainsNoSearch"] ? YES : NO);
        emit_bool("copy.isSameObject", [fresh copy] == fresh ? YES : NO);
        emit_bool("copy.isKindOfClass", [[fresh copy] isKindOfClass:cls] ? YES : NO);

        NSError *error = nil;
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:fresh requiringSecureCoding:YES error:&error];
        emit_bool("archive.hasData", archived != nil);
        emit("archive.errorDomain", error ? [error.domain UTF8String] : "(none)");
        id back = archived ? [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:archived error:&error] : nil;
        emit_bool("roundTrip.isKindOfClass", [back isKindOfClass:cls] ? YES : NO);
        emit("roundTrip.servers", [back valueForKey:@"servers"] ? "an array" : "(nil)");

#ifndef HOST_SIDE
        /* The three names Apple's class does not carry (dnsProtocol, domainName, allowFailover) have no
           host oracle, so they are checked on the port side alone: the header's declared default, the
           setter round trip, and the keyed-archive round trip. These lines are the whole oracle, and
           the facts page says so where a reader looks. */
        {
            NEDNSSettings *built = [[cls alloc] init];
            /* read through the typed getter, not through KVC: a KVC read of an integer property is
               an NSNumber that is never nil, so `== nil` would read NO with an inverted getter too */
            emit("portOnly.dnsProtocol.default", built.dnsProtocol == (NEDNSProtocol)0 ? "YES" : "NO");
            [built setDnsProtocol:NEDNSProtocolTLS];
            emit("portOnly.dnsProtocol.afterSet", built.dnsProtocol == NEDNSProtocolTLS ? "TLS" : "other");
            emit_bool("portOnly.domainName.default", built.domainName == nil);
            emit_bool("portOnly.domainName.isNil", built.domainName == nil);
            [built setValue:@"example.com" forKey:@"domainName"];
            emit("portOnly.domainName.afterSet", [built valueForKey:@"domainName"] ? [[built valueForKey:@"domainName"] UTF8String] : "(nil)");
            emit("portOnly.allowFailover.default", built.allowFailover ? "YES" : "NO");
            [built setAllowFailover:YES];
            emit("portOnly.allowFailover.afterSet", built.allowFailover ? "YES" : "NO");
            NSError *codingError = nil;
            NSData *coded = [NSKeyedArchiver archivedDataWithRootObject:built requiringSecureCoding:YES error:&codingError];
            id decoded = coded ? [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:coded error:&codingError] : nil;
            emit("portOnly.coding.domainName", [decoded valueForKey:@"domainName"] ? [[decoded valueForKey:@"domainName"] UTF8String] : "(nil)");
            emit("portOnly.coding.allowFailover", [(NEDNSSettings *)decoded allowFailover] ? "YES" : "NO");
        }
#endif

#ifdef HOST_SIDE
        /* the three names Apple's class does not carry, so they are not compared; what is compared is
           that both binaries agree on the two classes' protocol conformance */
        printf("conforms.NSCopying\t%s\n", [cls conformsToProtocol:@protocol(NSCopying)] ? "YES" : "NO");
        printf("conforms.NSSecureCoding\t%s\n", [cls conformsToProtocol:@protocol(NSSecureCoding)] ? "YES" : "NO");
#endif
    }
    return 0;
}
