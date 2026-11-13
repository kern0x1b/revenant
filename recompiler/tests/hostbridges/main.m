#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <arpa/inet.h>
#include <copyfile.h>
#include <crt_externs.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <ifaddrs.h>
#include <locale.h>
#include <malloc/malloc.h>
#include <mach/mach.h>
#include <net/if.h>
#include <net/if_types.h>
#include <net/if_var.h>
#include <netdb.h>
#include <nl_types.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wchar.h>
#include <xlocale.h>

extern const char *__progname;
extern id objc_initWeak(id *location, id value);
extern id objc_loadWeakRetained(id *location);
extern void objc_destroyWeak(id *location);
extern void (^NSDataDeallocatorFree)(void *, NSUInteger);
extern void (^NSDataDeallocatorUnmap)(void *, NSUInteger);
extern void (^NSDataDeallocatorVM)(void *, NSUInteger);
extern const struct dispatch_source_type_s _dispatch_source_type_vm;

@interface IvarProbe : NSObject {
@public
    int alpha;
    id beta;
    double gamma;
}
@end

@implementation IvarProbe
@end

@interface Probe : NSObject
- (int)plus:(int)a to:(int)b;
- (BOOL)isKindOfClass:(Class)cls;
- (NSString *)label;
+ (int)answer;
@end

@implementation Probe
- (int)plus:(int)a to:(int)b
{
    return a + b;
}
- (BOOL)isKindOfClass:(Class)cls
{
    return NO;
}
- (NSString *)label
{
    return @"probe";
}
+ (int)answer
{
    return 42;
}
@end

@interface ProbeChild : Probe
@end

@implementation ProbeChild
- (int)plus:(int)a to:(int)b
{
    return 1000 + a + b;
}
@end

static int triple(id self, SEL command, int x)
{
    return x * 3;
}

static int replacement(id self, SEL command, int a, int b)
{
    return a * b;
}

static int scan_through(const char *text, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int count = vsscanf(text, format, arguments);
    va_end(arguments);
    return count;
}

static void scanf_checks(void)
{
    int i = 0, hex = 0, counted = -1;
    long l = 0, position = -1;
    long long ll = 0;
    size_t z = 0;
    double d = 0;
    float f = 0;
    short h = 0;
    signed char hh = 0;
    void *pointer = 0;
    char word[16] = {0}, letter = 0;
    int count = sscanf("42 -7 123456789012 99 2.5 1.25 hello 12 -3 ff 0x1234 Z", "%d %ld %lld %zu %lf %f %15s %hd %hhd %x %p %c%ln",
                       &i, &l, &ll, &z, &d, &f, word, &h, &hh, &hex, &pointer, &letter, &position);
    printf("sscanf %d: %d %ld %lld %zu %.2f %.2f %s %d %d %d %p %c %ld\n", count, i, l, ll, z, d, f, word, h, hh, hex, pointer, letter, position);

    long untouched = -5;
    int first = 0;
    count = sscanf("5 x", "%d %ld", &first, &untouched);
    printf("sscanf partial %d: %d %ld\n", count, first, untouched);

    count = sscanf("", "%d", &first);
    printf("sscanf empty %d\n", count);

    unsigned long unsigned_long = 0;
    long negative = 0;
    count = sscanf("4000000000 -2000000000", "%lu %ld", &unsigned_long, &negative);
    printf("sscanf long %d: %lu %ld\n", count, unsigned_long, negative);

    long skipped = 7;
    int kept = 0;
    count = sscanf("1 2", "%*d %d%ln", &kept, &skipped);
    printf("sscanf suppressed %d: %d %ld\n", count, kept, skipped);

    count = scan_through("77 88 3", "%d %ld %zd", &i, &l, (ssize_t *)&z);
    printf("vsscanf %d: %d %ld %zd\n", count, i, l, (ssize_t)z);

    int a = 0, b = 0;
    count = sscanf("12:34", "%d:%d", &a, &b);
    printf("sscanf pair %d: %d %d\n", count, a, b);
}

static void address_checks(void)
{
    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
    struct addrinfo *result = NULL;
    int status = getaddrinfo("127.0.0.1", "8080", &hints, &result);
    printf("getaddrinfo v4 %d\n", status);
    int nodes = 0;
    for (struct addrinfo *node = result; node; node = node->ai_next) {
        char text[INET_ADDRSTRLEN];
        struct sockaddr_in *address = (struct sockaddr_in *)node->ai_addr;
        inet_ntop(AF_INET, &address->sin_addr, text, sizeof text);
        printf("  node family %d type %d protocol %d length %d address %s port %d\n", node->ai_family, node->ai_socktype,
               node->ai_protocol, (int)node->ai_addrlen, text, ntohs(address->sin_port));
        nodes++;
    }
    printf("  nodes %d\n", nodes);
    freeaddrinfo(result);

    hints.ai_family = AF_INET6;
    hints.ai_socktype = SOCK_DGRAM;
    result = NULL;
    status = getaddrinfo("::1", NULL, &hints, &result);
    printf("getaddrinfo v6 %d\n", status);
    for (struct addrinfo *node = result; node; node = node->ai_next) {
        char text[INET6_ADDRSTRLEN];
        struct sockaddr_in6 *address = (struct sockaddr_in6 *)node->ai_addr;
        inet_ntop(AF_INET6, &address->sin6_addr, text, sizeof text);
        printf("  node family %d type %d length %d address %s\n", node->ai_family, node->ai_socktype, (int)node->ai_addrlen, text);
    }
    freeaddrinfo(result);

    result = NULL;
    hints.ai_family = AF_UNSPEC;
    status = getaddrinfo("not-an-address.invalid", "80", &hints, &result);
    printf("getaddrinfo numeric host that is a name %d\n", status);

    hints.ai_flags = AI_NUMERICHOST | AI_PASSIVE;
    result = NULL;
    status = getaddrinfo(NULL, "9", &hints, &result);
    printf("getaddrinfo passive %d has nodes %d\n", status, result != NULL);
    freeaddrinfo(result);
}

static int compare_methods(const void *a, const void *b)
{
    return strcmp(sel_getName(method_getName(*(const Method *)a)), sel_getName(method_getName(*(const Method *)b)));
}

static void list_methods(const char *label, Class cls)
{
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    qsort(methods, count, sizeof methods[0], compare_methods);
    printf("%s %u\n", label, count);
    for (unsigned i = 0; i < count; i++) {
        char *result = method_copyReturnType(methods[i]);
        const char *shown = strcmp(result, "B") == 0 || strcmp(result, "c") == 0 ? "BOOL" : result;
        printf("  %s arguments %u returns %s\n", sel_getName(method_getName(methods[i])), method_getNumberOfArguments(methods[i]), shown);
        free(result);
    }
    free(methods);
}

static void method_list_checks(void)
{
    list_methods("Probe instance methods", [Probe class]);
    list_methods("Probe class methods", object_getClass([Probe class]));
    list_methods("ProbeChild instance methods", [ProbeChild class]);
    unsigned count = 99;
    Method *none = class_copyMethodList([NSObject class], &count);
    free(none);
    printf("NSObject has methods %d\n", count > 10);
}

static void implementation_checks(void)
{
    Probe *probe = [[Probe alloc] init];
    ProbeChild *child = [[ProbeChild alloc] init];
    SEL plus = @selector(plus:to:);

    IMP guest = class_getMethodImplementation([Probe class], plus);
    IMP from_method = method_getImplementation(class_getInstanceMethod([Probe class], plus));
    printf("guest imp same %d stable %d\n", guest == from_method, guest == class_getMethodImplementation([Probe class], plus));
    printf("guest imp on probe %d, on child %d\n", ((int (*)(id, SEL, int, int))guest)(probe, plus, 2, 3),
           ((int (*)(id, SEL, int, int))guest)(child, plus, 2, 3));
    printf("child imp differs %d, on child %d\n", class_getMethodImplementation([ProbeChild class], plus) != guest,
           ((int (*)(id, SEL, int, int))class_getMethodImplementation([ProbeChild class], plus))(child, plus, 2, 3));

    Class concrete = object_getClass(@"hello");
    IMP length = class_getMethodImplementation(concrete, @selector(length));
    printf("host imp length %lu\n", (unsigned long)((NSUInteger (*)(id, SEL))length)(@"hello", @selector(length)));
    IMP upper = class_getMethodImplementation(concrete, @selector(uppercaseString));
    printf("host imp uppercase %s\n", [((id (*)(id, SEL))upper)(@"hello", @selector(uppercaseString)) UTF8String]);
    IMP prefix = class_getMethodImplementation(concrete, @selector(hasPrefix:));
    printf("host imp prefix %d %d\n", ((BOOL (*)(id, SEL, id))prefix)(@"hello", @selector(hasPrefix:), @"he"),
           ((BOOL (*)(id, SEL, id))prefix)(@"hello", @selector(hasPrefix:), @"lo"));
    printf("host imp stable %d same as method %d\n", length == class_getMethodImplementation(concrete, @selector(length)),
           length == method_getImplementation(class_getInstanceMethod(concrete, @selector(length))));

    IMP kind = class_getMethodImplementation([NSObject class], @selector(isKindOfClass:));
    printf("override says %d, NSObject imp says %d %d\n", [probe isKindOfClass:[NSObject class]],
           ((BOOL (*)(id, SEL, Class))kind)(probe, @selector(isKindOfClass:), [NSObject class]),
           ((BOOL (*)(id, SEL, Class))kind)(probe, @selector(isKindOfClass:), [NSString class]));

    IMP answer = method_getImplementation(class_getClassMethod([Probe class], @selector(answer)));
    printf("class method imp %d\n", ((int (*)(id, SEL))answer)([Probe class], @selector(answer)));

    __block int captured = 5;
    IMP block_imp = imp_implementationWithBlock(^int(id self, int x) {
        return x * 2 + captured;
    });
    BOOL added = class_addMethod([Probe class], @selector(twice:), block_imp, "i@:i");
    printf("block imp added %d again %d\n", added, class_addMethod([Probe class], @selector(twice:), block_imp, "i@:i"));
    printf("block imp called by the host %d\n", ((int (*)(id, SEL, int))objc_msgSend)(probe, @selector(twice:), 21));
    captured = 100;
    printf("block imp sees the capture %d\n", ((int (*)(id, SEL, int))objc_msgSend)(probe, @selector(twice:), 1));
    BOOL has_block = imp_getBlock(block_imp) != nil;
    BOOL removed = imp_removeBlock(block_imp);
    printf("block of the imp exists %d removed %d\n", has_block, removed);

    printf("function imp added %d\n", class_addMethod([Probe class], @selector(triple:), (IMP)triple, "i@:i"));
    printf("function imp called by the host %d\n", ((int (*)(id, SEL, int))objc_msgSend)(probe, @selector(triple:), 21));
    IMP added_triple = class_getMethodImplementation([Probe class], @selector(triple:));
    printf("function imp read back %d same %d\n", ((int (*)(id, SEL, int))added_triple)(probe, @selector(triple:), 4),
           added_triple == (IMP)triple);

    IMP old = class_replaceMethod([Probe class], plus, (IMP)replacement, "i@:ii");
    printf("replaced old is the original %d, old computes %d\n", old == guest, ((int (*)(id, SEL, int, int))old)(probe, plus, 2, 3));
    printf("replacement computes %d\n", [probe plus:6 to:7]);
    Method method = class_getInstanceMethod([Probe class], plus);
    IMP replaced = method_setImplementation(method, old);
    printf("set returned the replacement %d, restored computes %d\n", replaced == (IMP)replacement, [probe plus:6 to:7]);

    IMP original_label = class_getMethodImplementation([Probe class], @selector(label));
    Method label = class_getInstanceMethod([Probe class], @selector(label));
    IMP shown = imp_implementationWithBlock(^NSString *(id self) {
        return @"changed";
    });
    IMP before = method_setImplementation(label, shown);
    printf("label before %d now %s\n", before == original_label, [[probe label] UTF8String]);
    method_setImplementation(label, before);
    printf("label restored %s\n", [[probe label] UTF8String]);

    IMP swapped = class_replaceMethod([Probe class], @selector(label), imp_implementationWithBlock(^NSString *(id self) {
        return @"swapped";
    }), "@@:");
    printf("replace returned original %d label %s\n", swapped == original_label, [[probe label] UTF8String]);
    class_replaceMethod([Probe class], @selector(label), swapped, "@@:");
    printf("label back %s\n", [[probe label] UTF8String]);
}

static void color_checks(void)
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGFloat components[4] = {0.25, 0.5, 0.75, 1.0};
    CGColorRef color = CGColorCreate(rgb, components);
    const CGFloat *read = CGColorGetComponents(color);
    printf("color components %zu: %.3f %.3f %.3f %.3f\n", CGColorGetNumberOfComponents(color), read[0], read[1], read[2], read[3]);
    printf("color components stable %d\n", CGColorGetComponents(color) == read);
    CGColorRef other = CGColorCreate(rgb, (CGFloat[]){1.0, 0.0, 0.5, 0.25});
    const CGFloat *again = CGColorGetComponents(other);
    printf("second color %.3f %.3f %.3f %.3f, first kept %.3f\n", again[0], again[1], again[2], again[3], read[0]);
    CGColorRelease(other);
    CGColorRelease(color);

    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(NULL, 2, 2, 8, 2, gray, kCGImageAlphaNone);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGFloat mask[2] = {0, 10};
    CGImageRef masked = CGImageCreateWithMaskingColors(image, mask);
    printf("masked image %d %zux%zu\n", masked != NULL, masked ? CGImageGetWidth(masked) : 0, masked ? CGImageGetHeight(masked) : 0);
    if (masked)
        CGImageRelease(masked);
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(gray);
    CGColorSpaceRelease(rgb);
}

static void process_checks(void)
{
    char ***argv = _NSGetArgv();
    int *argc = _NSGetArgc();
    printf("argv has %d, first names the program %d, terminated %d\n", *argc, strstr((*argv)[0], "HostBridges") != NULL, (*argv)[*argc] == NULL);
    printf("progname names the program %d\n", strstr(__progname, "HostBridges") != NULL);
}

static void interface_checks(void)
{
    struct ifaddrs *list = NULL;
    int status = getifaddrs(&list);
    int nodes = 0;
    char inet_line[96] = "none", link_line[96] = "none";
    for (struct ifaddrs *node = list; node; node = node->ifa_next) {
        nodes++;
        if (!node->ifa_addr || strcmp(node->ifa_name, "lo0"))
            continue;
        if (node->ifa_addr->sa_family == AF_INET) {
            char address[INET_ADDRSTRLEN], netmask[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &((struct sockaddr_in *)node->ifa_addr)->sin_addr, address, sizeof address);
            inet_ntop(AF_INET, &((struct sockaddr_in *)node->ifa_netmask)->sin_addr, netmask, sizeof netmask);
            snprintf(inet_line, sizeof inet_line, "inet %s mask %s loopback %d up %d", address, netmask, (node->ifa_flags & IFF_LOOPBACK) != 0,
                     (node->ifa_flags & IFF_UP) != 0);
        } else if (node->ifa_addr->sa_family == AF_LINK) {
            const struct if_data *data = node->ifa_data;
            snprintf(link_line, sizeof link_line, "link data %d type %u changed %d", data != NULL, data ? data->ifi_type : 0,
                     data && data->ifi_lastchange.tv_sec > 1000000000);
        }
    }
    printf("getifaddrs %d nodes %d\n", status, nodes > 0);
    printf("getifaddrs lo0 %s\n", inet_line);
    printf("getifaddrs lo0 %s\n", link_line);
    freeifaddrs(list);
}

static void service_checks(void)
{
    struct servent *entry = getservbyname("http", "tcp");
    printf("getservbyname %s port %d proto %s\n", entry ? entry->s_name : "-", entry ? ntohs(entry->s_port) : 0, entry ? entry->s_proto : "-");
    printf("getservbyname missing %d\n", getservbyname("xlate-no-such-service", "tcp") == NULL);
}

static void locale_checks(void)
{
    locale_t locale = newlocale(LC_ALL_MASK, "C", NULL);
    struct lconv *conv = localeconv_l(locale);
    printf("localeconv_l decimal '%s' thousands '%s' grouping '%s' frac %d int_frac %d p_cs %d n_sign %d\n", conv->decimal_point,
           conv->thousands_sep, conv->grouping, conv->frac_digits, conv->int_frac_digits, conv->p_cs_precedes, conv->n_sign_posn);
    printf("localeconv_l stable %d\n", localeconv_l(locale) == conv);
    freelocale(locale);
}

static void ivar_checks(void)
{
    unsigned count = 0;
    Ivar *ivars = class_copyIvarList([IvarProbe class], &count);
    printf("IvarProbe ivars %u\n", count);
    for (unsigned i = 0; i < count; i++)
        printf("  %s %s\n", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i]));
    free(ivars);
    ivars = class_copyIvarList([NSNull class], &count);
    printf("NSNull ivars %u none %d\n", count, ivars == NULL);
    free(ivars);
}

static void memory_checks(void)
{
    malloc_zone_t *zone = malloc_default_zone();
    void *block = malloc_zone_malloc(zone, 48);
    printf("malloc zone %d, owns the block %d\n", zone != NULL, malloc_zone_from_ptr(block) != NULL);
    malloc_zone_free(malloc_zone_from_ptr(block), block);
    int local = 0;
    printf("zone of a stack address is null %d\n", malloc_zone_from_ptr(&local) == NULL);

    size_t size = (size_t)getpagesize();
    void *page = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    printf("page mapped %d\n", page != MAP_FAILED && msync(page, size, MS_ASYNC) == 0);
    NSDataDeallocatorUnmap(page, size);
    printf("unmap deallocator removed the page %d\n", msync(page, size, MS_ASYNC) == -1 && errno == ENOMEM);
    vm_address_t address = 0;
    printf("vm allocated %d\n", vm_allocate(mach_task_self(), &address, size, VM_FLAGS_ANYWHERE) == KERN_SUCCESS && msync((void *)address, size, MS_ASYNC) == 0);
    NSDataDeallocatorVM((void *)address, size);
    printf("vm deallocator removed the page %d\n", msync((void *)address, size, MS_ASYNC) == -1 && errno == ENOMEM);
    NSDataDeallocatorFree(malloc(64), 64);
    printf("free deallocator ran\n");
}

static void catalog_checks(void)
{
    nl_catd catalog = catopen("xlate-no-such-catalog", NL_CAT_LOCALE);
    printf("catopen of a missing catalog %d\n", catalog == (nl_catd)-1);
}

static void wide_checks(void)
{
    wchar_t buffer[64];
    char text[64];
    int written = swprintf(buffer, 64, L"%d|%5.2f|%s|%ls|%c|%lld", 42, 3.14159, "narrow", L"wide", 'x', 123456789012LL);
    for (int i = 0; i <= written; i++)
        text[i] = (char)buffer[i];
    printf("swprintf %d: %s\n", written, text);
    printf("swprintf short %d\n", swprintf(buffer, 4, L"truncated"));
    written = swprintf(buffer, 64, L"é=%d|%lc", 7, (wint_t)'z');
    printf("swprintf wide format %d: %u %u %u %u %u\n", written, (unsigned)buffer[0], (unsigned)buffer[1], (unsigned)buffer[2],
           (unsigned)buffer[3], (unsigned)buffer[4]);
}

static void copyfile_checks(void)
{
    char from_path[] = "/var/tmp/hostbridges-from-XXXXXX";
    char to_path[] = "/var/tmp/hostbridges-to-XXXXXX";
    int from = mkstemp(from_path);
    int to = mkstemp(to_path);
    write(from, "copy me", 7);
    lseek(from, 0, SEEK_SET);
    copyfile_state_t state = copyfile_state_alloc();
    printf("copyfile state %d\n", state != NULL);
    int result = fcopyfile(from, to, state, COPYFILE_DATA);
    printf("copyfile state free %d\n", copyfile_state_free(state));
    lseek(to, 0, SEEK_SET);
    char text[16] = {0};
    ssize_t count = read(to, text, sizeof text - 1);
    printf("fcopyfile %d %ld %s\n", result, (long)count, text);
    close(from);
    close(to);
    unlink(from_path);
    unlink(to_path);
}

@interface AlignProbe : NSObject
@property (nonatomic, assign) uintptr_t seen;
- (void)see:(NSString *)value;
@end

@implementation AlignProbe
- (void)see:(NSString *)value
{
    self.seen = (uintptr_t)value;
}
@end

@interface NSString (AlignProbe)
- (uintptr_t)alignProbeSelf;
- (BOOL)alignProbeSuper;
- (const char *)alignProbeSuperClass;
@end

@implementation NSString (AlignProbe)
- (uintptr_t)alignProbeSelf
{
    return (uintptr_t)self;
}

- (BOOL)alignProbeSuper
{
    return [[super description] length] > 0;
}

- (const char *)alignProbeSuperClass
{
    return class_getName([super class]);
}
@end

static uintptr_t see_function(id self, SEL command, id value)
{
    return (uintptr_t)value;
}

static int aligned(const void *pointer)
{
    return ((uintptr_t)pointer & 7) == 0;
}

static void alignment_checks(void)
{
    NSString *mode = NSDefaultRunLoopMode;
    printf("align data import %d\n", aligned((const void *)mode));
    printf("align core foundation data import %d\n", aligned(kCFRunLoopDefaultMode));
    printf("align locale key %d\n", aligned((const void *)NSLocaleLanguageCode));
    NSArray *array = [NSArray arrayWithObject:mode];
    id fetched = [array objectAtIndex:0];
    printf("align message return %d\n", aligned((const void *)fetched));
    printf("align same constant twice %d\n", fetched == mode && [array objectAtIndex:0] == fetched);
    int enumerated = 0;
    for (id item in array)
        enumerated += aligned((const void *)item) && item == mode;
    printf("align fast enumeration %d\n", enumerated);
    CFMutableDictionaryRef table = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(table, kCFBundleNameKey, kCFRunLoopDefaultMode);
    const void *value = CFDictionaryGetValue(table, kCFBundleNameKey);
    printf("align core foundation return %d %d\n", aligned(value), value == (const void *)kCFRunLoopDefaultMode);
    CFRelease(table);
    printf("align host sees the constant %s\n", class_getName(object_getClass(mode)));
    printf("align host sees the constant %d\n", [mode isEqualToString:(NSString *)kCFRunLoopDefaultMode]);
    AlignProbe *probe = [[AlignProbe alloc] init];
    [[NSArray arrayWithObject:probe] makeObjectsPerformSelector:@selector(see:) withObject:mode];
    printf("align guest method argument %d %d\n", aligned((const void *)probe.seen), probe.seen == (uintptr_t)mode);
    Protocol *named = NSProtocolFromString(@"NSObject");
    printf("align protocol %d %d %s\n", aligned((const void *)named), (int)protocol_isEqual(named, @protocol(NSObject)), protocol_getName(named));
    id weak_slot = nil;
    id stored = objc_initWeak(&weak_slot, mode);
    id loaded = objc_loadWeakRetained(&weak_slot);
    id plain = objc_loadWeak(&weak_slot);
    id replaced = objc_storeWeak(&weak_slot, mode);
    printf("align weak %d %d %d %d\n", aligned((const void *)stored) && stored == mode, aligned((const void *)loaded) && loaded == mode,
           aligned((const void *)plain) && plain == mode, aligned((const void *)replaced) && replaced == mode);
    [loaded release];
    objc_destroyWeak(&weak_slot);
    NSDictionary *pairs = [NSDictionary dictionaryWithObjectsAndKeys:mode, NSLocaleLanguageCode, nil];
    id kept = [pairs objectForKey:NSLocaleLanguageCode];
    printf("align variadic dictionary %d %d %d\n", aligned((const void *)kept), kept == mode, (int)([[pairs allValues] indexOfObjectIdenticalTo:mode] == 0));
    NSArray *listed = [NSArray arrayWithObjects:mode, nil];
    kept = [listed objectAtIndex:0];
    printf("align variadic array %d %d %d\n", aligned((const void *)kept), kept == mode, (int)([listed indexOfObjectIdenticalTo:mode] == 0));
    listed = [[NSArray alloc] initWithObjects:mode, nil];
    kept = [listed objectAtIndex:0];
    printf("align variadic init %d %d %d\n", aligned((const void *)kept), kept == mode, (int)([listed indexOfObjectIdenticalTo:mode] == 0));
    NSSet *unique = [NSSet setWithObjects:mode, nil];
    kept = [unique anyObject];
    printf("align variadic set %d %d %d\n", aligned((const void *)kept), kept == mode, (int)([[unique allObjects] indexOfObjectIdenticalTo:mode] == 0));
    NSString *formatted = [NSString stringWithFormat:@"%@", mode];
    printf("align format argument %d %d\n", (int)[formatted isEqualToString:mode], (int)[formatted length]);    NSArray *two = [NSArray arrayWithObjects:mode, NSLocaleLanguageCode, nil];
    __block int block_aligned = 0, block_same = 0;
    [two enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        block_aligned += aligned((const void *)obj);
        block_same += obj == (index == 0 ? mode : (id)NSLocaleLanguageCode);
    }];
    printf("align block arguments %d %d\n", block_aligned, block_same);
    __block uintptr_t seen_in_block = 0;
    IMP echo = imp_implementationWithBlock(^id(id self_, id value) {
        seen_in_block = (uintptr_t)value;
        return value;
    });
    class_addMethod([AlignProbe class], @selector(echo:), echo, "@@:@");
    id echoed = ((id (*)(id, SEL, id))objc_msgSend)(probe, @selector(echo:), mode);
    printf("align block result %d %d %d %d\n", aligned((const void *)echoed), echoed == mode, aligned((const void *)seen_in_block), seen_in_block == (uintptr_t)mode);
    class_addMethod([AlignProbe class], @selector(seeFunction:), (IMP)see_function, "L@:@");
    uintptr_t seen_by_function = ((uintptr_t (*)(id, SEL, id))objc_msgSend)(probe, @selector(seeFunction:), mode);
    printf("align function imp argument %d %d\n", aligned((const void *)seen_by_function), seen_by_function == (uintptr_t)mode);
    printf("align category self %d %d\n", aligned((const void *)[mode alignProbeSelf]), [mode alignProbeSelf] == (uintptr_t)mode);
    printf("align category super %d %s\n", (int)[mode alignProbeSuper], [mode alignProbeSuperClass]);
    uintptr_t *seen_by = calloc(64, sizeof *seen_by);
    dispatch_apply(64, dispatch_get_global_queue(0, 0), ^(size_t index) {
        seen_by[index] = (uintptr_t)[array objectAtIndex:0];
    });
    int same = 1;
    for (int i = 0; i < 64; i++)
        same &= seen_by[i] == (uintptr_t)fetched;
    free(seen_by);
    printf("align constant across threads %d\n", same);
}

static void source_checks(void)
{
    dispatch_queue_t queue = dispatch_queue_create("hostbridges.source", NULL);
    dispatch_source_t source = dispatch_source_create(&_dispatch_source_type_vm, 0, 0, queue);
    printf("vm dispatch source %d\n", source != NULL);
    if (source)
        dispatch_source_cancel(source);
}

int main(void)
{
    @autoreleasepool {
        scanf_checks();
        address_checks();
        method_list_checks();
        implementation_checks();
        color_checks();
        process_checks();
        interface_checks();
        service_checks();
        locale_checks();
        ivar_checks();
        memory_checks();
        catalog_checks();
        wide_checks();
        copyfile_checks();
        source_checks();
        alignment_checks();
    }
    return 0;
}
