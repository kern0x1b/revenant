#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
        printf("  %s arguments %u returns %s\n", sel_getName(method_getName(methods[i])), method_getNumberOfArguments(methods[i]), result);
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

int main(void)
{
    @autoreleasepool {
        scanf_checks();
        address_checks();
        method_list_checks();
        implementation_checks();
    }
    return 0;
}
