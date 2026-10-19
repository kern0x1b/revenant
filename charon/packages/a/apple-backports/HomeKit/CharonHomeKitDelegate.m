// The one place the home graph reports through HMHomeDelegate. An object's home is its own member, and
// the delegate is asked twice: once when the change is made, and again when the message is delivered on
// the main queue, so that an application which released its delegate between the two is not messaged.
// Every trigger, action set and service group delivers through here, so the check is written once.
#import "CharonHomeKitInternal.h"

@implementation NSObject (CharonHomeKitDelegate)

- (void)charon_tellHome:(SEL)selector object:(id)object block:(void (^)(id<HMHomeDelegate> delegate, HMHome *home, id object))block
{
    id identifier = [self valueForKey:@"charon_homeIdentifier"];
    if (![identifier isKindOfClass:[NSString class]] || ![(NSString *)identifier length])
        return;
    HMHome *home = CharonHomeKitHome(identifier);
    CharonHomeKitTell(home.delegate, selector, ^(id target) {
        block((id<HMHomeDelegate>)target, home, object);
    });
}

@end
