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
