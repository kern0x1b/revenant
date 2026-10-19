#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>

/* One reader, two binaries.
 *
 *   A (default)     the system alone. The five answers are the system's, and dladdr names the image
 *                   that answered each selector.
 *   B (-DPORT_SIDE) the same probe with the port's object linked in. NSMutableURLRequest is the
 *                   system's class and the port adds a category to it, so in this binary the port's
 *                   methods are the ones that answer those ten selectors, and dladdr has to say so.
 *
 * The port's answers are therefore only believable if B's image is the port object for every one of
 * them, which is what run.sh asserts before it compares anything: a B that still answers from the
 * system is a run that would compare the system with itself and pass.
 */
static BOOL sendBool(id target, SEL selector) { return ((BOOL (*)(id, SEL))objc_msgSend)(target, selector); }
static void sendBoolSet(id target, SEL selector, BOOL value) { ((void (*)(id, SEL, BOOL))objc_msgSend)(target, selector, value); }
static id sendId(id target, SEL selector) { return ((id (*)(id, SEL))objc_msgSend)(target, selector); }
static void sendIdSet(id target, SEL selector, id value) { ((void (*)(id, SEL, id))objc_msgSend)(target, selector, value); }

static NSMutableURLRequest *make_request(void)
{
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/"]];
}

static const char *image_of(SEL selector)
{
    Method m = class_getInstanceMethod([NSMutableURLRequest class], selector);
    Dl_info info;
    memset(&info, 0, sizeof info);
    if (!m || !dladdr((const void *)method_getImplementation(m), &info) || !info.dli_fname)
        return "(unresolved)";
    /* The whole path: the port's code is in a binary under this worktree, the system's is under
       /System/Library, and a basename cannot tell those apart when the build is named anything. */
    return info.dli_fname;
}

static void flag(const char *name, const char *getter, const char *setter)
{
    SEL g = NSSelectorFromString(@(getter));
    SEL s = NSSelectorFromString(@(setter));
    BOOL fresh = sendBool(make_request(), g);
    NSMutableURLRequest *mutable = [make_request() mutableCopy];
    sendBoolSet(mutable, s, !fresh);
    BOOL after = sendBool(mutable, g);
    printf("fresh.%s\t%s\n", name, fresh ? "YES" : "NO");
    printf("roundtrip.%s\t%s\n", name, after != fresh ? (after ? "YES" : "NO") : "STUCK");
    /* -copy and -mutableCopy both have to carry what was set, or the key does not survive a hand-off */
    printf("copy.%s\t%s\n", name, sendBool([mutable copy], g) == after ? "carried" : "LOST");
    NSMutableURLRequest *handed = [make_request() mutableCopy];
    sendBoolSet(handed, s, !fresh);
    printf("mutablecopy.%s\t%s\n", name, sendBool([handed copy], g) != fresh ? "carried" : "LOST");
    printf("image.%s.get\t%s\n", name, image_of(g));
    printf("image.%s.set\t%s\n", name, image_of(s));
}

static void object(const char *name, const char *getter, const char *setter)
{
    SEL g = NSSelectorFromString(@(getter));
    SEL s = NSSelectorFromString(@(setter));
    id value = sendId(make_request(), g);
    printf("fresh.%s\t%s\n", name, value ? "an object" : "(nil)");
    NSMutableURLRequest *mutable = [make_request() mutableCopy];
    sendIdSet(mutable, s, @"charon-probe");
    id after = sendId(mutable, g);
    printf("roundtrip.%s\t%s\n", name, [after isEqual:@"charon-probe"] ? "read back" : "LOST");
    printf("copy.%s\t%s\n", name, [sendId([mutable copy], g) isEqual:@"charon-probe"] ? "carried" : "LOST");
    NSMutableURLRequest *handed = [make_request() mutableCopy];
    sendIdSet(handed, s, @"charon-probe");
    printf("mutablecopy.%s\t%s\n", name, [sendId([handed copy], g) isEqual:@"charon-probe"] ? "carried" : "LOST");
    printf("image.%s.get\t%s\n", name, image_of(g));
    printf("image.%s.set\t%s\n", name, image_of(s));
}

int main(void) { @autoreleasepool {
#ifdef PORT_SIDE
    printf("side\tport\n");
#else
    printf("side\tsystem\n");
#endif
    flag("attribution", "attribution", "setAttribution:");
    flag("requiresDNSSECValidation", "requiresDNSSECValidation", "setRequiresDNSSECValidation:");
    flag("allowsPersistentDNS", "allowsPersistentDNS", "setAllowsPersistentDNS:");
    flag("allowsUltraConstrainedNetworkAccess", "allowsUltraConstrainedNetworkAccess",
         "setAllowsUltraConstrainedNetworkAccess:");
    object("cookiePartitionIdentifier", "cookiePartitionIdentifier", "setCookiePartitionIdentifier:");
    return 0;
} }
