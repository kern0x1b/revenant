#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

#import "names.h"

static int failures = 0;

static void check(NSString *rule, id got, id want)
{
    BOOL same = (got == want) || [got isEqual:want];
    printf("check\t%s\t%s\t%s\n", rule.UTF8String, same ? "ok" : "FAILED",
           same ? [[want description] UTF8String]
                : [[NSString stringWithFormat:@"got %@ wanted %@", got, want] UTF8String]);
    if (!same) failures++;
}

@interface RevenantMapRendererAdopter : NSObject <AXBrailleMapRenderer> @end

@implementation RevenantMapRendererAdopter

- (id)accessibilityBrailleMapRenderer
{
    return nil;
}

- (id)accessibilityBrailleMapRenderRegion
{
    return nil;
}

@end

int main(void)
{
    @autoreleasepool {
        for (NSString *claimed in REVENANT_PROTOCOLS) {
            check(([NSString stringWithFormat:@"the registry's row %@ resolves by name", claimed]),
                  objc_getProtocol(claimed.UTF8String) ? @"yes" : @"no", @"yes");
        }
        printf("registry protocol rows looked up\t%lu\n", (unsigned long)REVENANT_PROTOCOLS.count);
        check(@"a name the registry does not hold answers nil",
              objc_getProtocol("RevenantNoSuchProtocol") ? @"yes" : @"no", @"no");

        Protocol *renderer = objc_getProtocol("AXBrailleMapRenderer");
        check(@"objc_getProtocol finds the renderer protocol by its real name", renderer ? @"yes" : @"no",
              @"yes");
        check(@"NSProtocolFromString finds it too", NSProtocolFromString(@"AXBrailleMapRenderer") ? @"yes" : @"no",
              @"yes");
        check(@"a class that adopts it answers conformsToProtocol:",
              [[RevenantMapRendererAdopter new] conformsToProtocol:@protocol(AXBrailleMapRenderer)] ? @"yes" : @"no",
              @"yes");
        if (renderer) {
            check(@"the protocol is named as the SDK names it",
                  [NSString stringWithUTF8String:protocol_getName(renderer)], @"AXBrailleMapRenderer");
            unsigned required = 0;
            free(protocol_copyMethodDescriptionList(renderer, YES, YES, &required));
            check(@"the protocol lists no required instance methods", @(required), @(0));
            unsigned optional = 0;
            free(protocol_copyMethodDescriptionList(renderer, YES, NO, &optional));
            check(@"it lists no optional instance methods either, because its members are properties",
                  @(optional), @(0));
        }
        check(@"the map class does not adopt the renderer protocol",
              [NSClassFromString(@"AXBrailleMap") conformsToProtocol:@protocol(AXBrailleMapRenderer)] ? @"yes" : @"no",
              @"no");
        printf("checks run: %lu, failed: %d\n", (unsigned long)(REVENANT_PROTOCOLS.count + 8), failures);
    }
    return failures == 0 ? 0 : 1;
}
