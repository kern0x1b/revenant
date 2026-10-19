/* domains.m - the three Metal error domains (MTLCommandBufferErrorDomain, MTLLibraryErrorDomain, MTLIOErrorDomain),
 * compared byte for byte with the strings Apple's own Metal holds.
 *
 * Apple's constants are read by dlsym from Apple's Metal, opened by path, never by naming the symbol: a name the
 * case declared would bind to whichever definition the link chose, and a port that defined it wrongly would be
 * compared with itself. The port's values are read from the port's own definitions, linked into this binary.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dlfcn.h>

extern NSErrorDomain const MTLCommandBufferErrorDomain;
extern NSErrorDomain const MTLLibraryErrorDomain;
extern NSErrorDomain const MTLIOErrorDomain;

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static void compare(void *appleMetal, const char *name, NSString *port)
{
    __unsafe_unretained NSString **slot = (__unsafe_unretained NSString **)dlsym(appleMetal, name);
    if (slot == NULL) {
        check(NO, [NSString stringWithFormat:@"%s: Apple's Metal has no such symbol", name]);
        return;
    }
    NSString *apple = *slot;
    check(apple != nil && port != nil && [apple isEqualToString:port] && apple.length == port.length,
          [NSString stringWithFormat:@"%s: the port's \"%@\" is Apple's \"%@\"", name, port ?: @"(nil)", apple ?: @"(nil)"]);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    void *appleMetal = dlopen("/System/Library/Frameworks/Metal.framework/Metal", RTLD_LAZY);
    check(appleMetal != NULL, @"Apple's Metal opens by path");
    if (!appleMetal)
        return 1;
    /* A planted name proves the lookup can say a symbol is not there. */
    check(dlsym(appleMetal, "MTLCharonNoSuchErrorDomain") == NULL, @"a planted name is not in Apple's Metal");
    compare(appleMetal, "MTLCommandBufferErrorDomain", MTLCommandBufferErrorDomain);
    compare(appleMetal, "MTLLibraryErrorDomain", MTLLibraryErrorDomain);
    compare(appleMetal, "MTLIOErrorDomain", MTLIOErrorDomain);
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
