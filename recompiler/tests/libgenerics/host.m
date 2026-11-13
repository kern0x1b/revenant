#import <Foundation/Foundation.h>
#include <objc/message.h>
#include <stdio.h>
#include "xl_loader.h"

int main(int argc, char **argv)
{
    setbuf(stdout, NULL);
    if (argc < 4) {
        printf("FAIL usage\n");
        return 2;
    }
    xl_load_status reserved = xl_reserve(argv[1]);
    if (reserved != XL_LOAD_OK) {
        printf("FAIL reserve %d %s\n", (int)reserved, xl_load_error());
        return 1;
    }
    xl_load_status loaded = xl_load(argv[1]);
    if (loaded != XL_LOAD_OK) {
        printf("FAIL load %d %s\n", (int)loaded, xl_load_error());
        return 1;
    }
    @autoreleasepool {
        Class cls = NSClassFromString([NSString stringWithUTF8String:argv[2]]);
        if (cls == Nil) {
            printf("FAIL class.absent %s\n", argv[2]);
            return 1;
        }
        id runner = [[cls alloc] init];
        SEL selector = NSSelectorFromString([NSString stringWithUTF8String:argv[3]]);
        if (![runner respondsToSelector:selector]) {
            printf("FAIL selector.absent %s\n", argv[3]);
            return 1;
        }
        ((void (*)(id, SEL))objc_msgSend)(runner, selector);
    }
    printf("done\n");
    return 0;
}
