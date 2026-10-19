#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class cls = NSClassFromString([NSString stringWithFormat:@"%sNSExtensionContext", PREFIX]);
        if (!cls) {
            printf("class missing\n");
            return 2;
        }
        printf("class NSExtensionContext\n");
        id context = [[cls alloc] init];
        if (!context) {
            printf("init nil\n");
            return 2;
        }
        id items = [context valueForKey:@"inputItems"];
        printf("inputItems %s count %lu\n", items ? class_getName([items class]) : "nil",
               items ? (unsigned long)[items count] : 0UL);
        CGSize minimum = ((CGSize (*)(id, SEL))objc_msgSend)(context, NSSelectorFromString(@"hostedViewMinimumAllowedSize"));
        CGSize maximum = ((CGSize (*)(id, SEL))objc_msgSend)(context, NSSelectorFromString(@"hostedViewMaximumAllowedSize"));
        printf("hostedViewMinimumAllowedSize %g %g\n", minimum.width, minimum.height);
        printf("hostedViewMaximumAllowedSize %g %g\n", maximum.width, maximum.height);
        id description = ((id (*)(id, SEL))objc_msgSend)(context, NSSelectorFromString(@"interfaceParametersDescription"));
        printf("interfaceParametersDescription %s\n", description ? "string" : "nil");
        __block int calls = 0;
        __block int expired = -1;
        ((void (*)(id, SEL, id, id))objc_msgSend)(context, NSSelectorFromString(@"completeRequestReturningItems:completionHandler:"),
                                                  @[], ^(BOOL value) { calls++; expired = value; });
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        printf("completeRequest callback %d expired %d\n", calls, expired);
        SEL active = NSSelectorFromString(@"widgetActiveDisplayMode");
        SEL largest = NSSelectorFromString(@"widgetLargestAvailableDisplayMode");
        if ([context respondsToSelector:active]) printf("widgetActiveDisplayMode %ld\n", (long)((NSInteger (*)(id, SEL))objc_msgSend)(context, active));
        else printf("widgetActiveDisplayMode absent\n");
        if ([context respondsToSelector:largest]) printf("widgetLargestAvailableDisplayMode %ld\n", (long)((NSInteger (*)(id, SEL))objc_msgSend)(context, largest));
        else printf("widgetLargestAvailableDisplayMode absent\n");
        SEL maximumSelector = NSSelectorFromString(@"widgetMaximumSizeForDisplayMode:");
        for (NSInteger mode = 0; mode <= 1; mode++) {
            if (![context respondsToSelector:maximumSelector]) { printf("widgetMaximumSizeForDisplayMode:%ld absent\n", (long)mode); continue; }
            CGSize size = ((CGSize (*)(id, SEL, NSInteger))objc_msgSend)(context, maximumSelector, mode);
            printf("widgetMaximumSizeForDisplayMode:%ld %g %g\n", (long)mode, size.width, size.height);
        }
        printf("screen width %g\n", [UIScreen mainScreen].bounds.size.width);
    }
    return 0;
}
