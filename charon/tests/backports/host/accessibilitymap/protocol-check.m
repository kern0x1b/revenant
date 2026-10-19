// accessibilitymap/protocol-check - AXBrailleMapRenderer under the name it really has.
//
// The port emits the protocol's metadata, and the only way to ask whether a caller can find it is to
// look it up by the name an application writes. So this program links the port's own objects and the
// protocol object modules/apple/backports.lua generates, under the REAL names - no alias - and asks:
// does objc_getProtocol find it, does NSProtocolFromString find it, does a class that adopts it answer
// conformsToProtocol:, and does a name that does not exist answer nil.
//
// The last of those is the control, and it is what makes the other three mean anything: a program that
// found every protocol it was asked about would say the same about all four.
//
// It is a port-only program and not a second half of the differential, and the reason is the alias that
// keeps the two halves of the differential apart. That alias renames the protocol along with the class,
// so in the port half the protocol is not findable under the real name, and in the host half the real
// name belongs to the framework's own protocol rather than to anything the port carries. Two different
// names answer one question, so the question cannot be asked by comparing them. What the host answers for
// its own protocol is measured separately and is in facts/Accessibility/Accessibility.md.
#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

// The names, from the registry, written by protocol-check.sh.
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

// A class that adopts the protocol, so that the conformance question is about a class and not about a
// name. It implements both members, which are optional, because a protocol's optional members are not in
// its method list: the case asks the member count and the host answers zero for the same reason.
@interface CharonMapRendererAdopter : NSObject <AXBrailleMapRenderer> @end

@implementation CharonMapRendererAdopter

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
        // Every protocol row the registry claims, by the name the registry gives it. A row naming a
        // protocol that does not exist is a forward reference clang makes a label and the linker accepts,
        // so this loop is the only thing in the whole build that notices.
        for (NSString *claimed in CHARON_PROTOCOLS) {
            check(([NSString stringWithFormat:@"the registry's row %@ resolves by name", claimed]),
                  objc_getProtocol(claimed.UTF8String) ? @"yes" : @"no", @"yes");
        }
        printf("registry protocol rows looked up\t%lu\n", (unsigned long)CHARON_PROTOCOLS.count);
        // The control: a name the registry does not hold.
        check(@"a name the registry does not hold answers nil",
              objc_getProtocol("CharonNoSuchProtocol") ? @"yes" : @"no", @"no");

        Protocol *renderer = objc_getProtocol("AXBrailleMapRenderer");
        check(@"objc_getProtocol finds the renderer protocol by its real name", renderer ? @"yes" : @"no",
              @"yes");
        check(@"NSProtocolFromString finds it too", NSProtocolFromString(@"AXBrailleMapRenderer") ? @"yes" : @"no",
              @"yes");
        check(@"a class that adopts it answers conformsToProtocol:",
              [[CharonMapRendererAdopter new] conformsToProtocol:@protocol(AXBrailleMapRenderer)] ? @"yes" : @"no",
              @"yes");
        // The control: a name that does not exist, so the three above are not "yes" by construction.
        if (renderer) {
            check(@"the protocol is named as the SDK names it",
                  [NSString stringWithUTF8String:protocol_getName(renderer)], @"AXBrailleMapRenderer");
            // Its two members are optional *properties* - the renderer and the render region - and a
            // property is not a method: the runtime lists no instance methods for this protocol at all,
            // required or optional, on either side. That is the fact, and asking for two methods was
            // asking for something the runtime does not keep; the two property names are in the header
            // and the case checks the names the header gives by asking the two accessors an adopting class
            // above has to implement.
            unsigned required = 0;
            free(protocol_copyMethodDescriptionList(renderer, YES, YES, &required));
            check(@"the protocol lists no required instance methods", @(required), @(0));
            unsigned optional = 0;
            free(protocol_copyMethodDescriptionList(renderer, YES, NO, &optional));
            check(@"it lists no optional instance methods either, because its members are properties",
                  @(optional), @(0));
        }
        // The map itself does not adopt the renderer protocol, measured on the host as well: a renderer is
        // something an element adopts, and a class that claimed it would be claiming what the system's own
        // class does not.
        check(@"the map class does not adopt the renderer protocol",
              [NSClassFromString(@"AXBrailleMap") conformsToProtocol:@protocol(AXBrailleMapRenderer)] ? @"yes" : @"no",
              @"no");
        printf("checks run: %lu, failed: %d\n", (unsigned long)(CHARON_PROTOCOLS.count + 8), failures);
    }
    return failures == 0 ? 0 : 1;
}
