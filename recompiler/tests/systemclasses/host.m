#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

#include "xl_guest_image.h"
#include "xl_loader.h"

@interface NSObject (SCNative)
- (NSUInteger)scNative:(NSInteger)n;
- (NSInteger)scMix:(NSInteger)a with:(NSInteger)b and:(NSInteger)c;
@end

@interface SCHostWide : NSObject
@end

@implementation SCHostWide
+ (long long)scMix:(int)a with:(long long)b
{
    return b + a;
}

+ (long long)scPair:(long long)a and:(long long)b
{
    return a - b;
}

+ (long long)scTail:(int)a b:(int)b c:(int)c d:(long long)d
{
    return d + a + b + c;
}

+ (unsigned long long)scUnsigned:(unsigned char)a with:(unsigned long long)b
{
    return b + a;
}
@end

int main(int argc, char **argv)
{
    alarm(60);
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: host LIBRARY\n");
            return 2;
        }
        if (xl_reserve(argv[1]) != XL_LOAD_OK || xl_load(argv[1]) != XL_LOAD_OK) {
            printf("FAIL load %s\n", xl_load_error());
            return 1;
        }
        Class cls = NSClassFromString(@"SCFixture");
        if (!cls) {
            printf("FAIL class\n");
            return 1;
        }
        for (NSString *line in [cls performSelector:@selector(run)])
            printf("%s\n", line.UTF8String);
        NSObject *object = [[NSObject alloc] init];
        BOOL native = [object scNative:-5] == 2 && [object scNative:0x40000000] == 0x40000007u && [object scNative:-1] == 6 && [object scMix:100 with:58 and:7] == 5 && [object scMix:-100 with:58 and:7] == -195;
        printf("%s native\n", native ? "ok" : "FAIL");
        printf("done\n");
        fflush(stdout);
    }
    return 0;
}
