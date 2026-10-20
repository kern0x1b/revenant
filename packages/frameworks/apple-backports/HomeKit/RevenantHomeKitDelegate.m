#import "RevenantHomeKitInternal.h"

@implementation NSObject (RevenantHomeKitDelegate)

- (void)revenant_tellHome:(SEL)selector object:(id)object block:(void (^)(id<HMHomeDelegate> delegate, HMHome *home, id object))block
{
    id identifier = [self valueForKey:@"revenant_homeIdentifier"];
    if (![identifier isKindOfClass:[NSString class]] || ![(NSString *)identifier length])
        return;
    HMHome *home = RevenantHomeKitHome(identifier);
    RevenantHomeKitTell(home.delegate, selector, ^(id target) {
        block((id<HMHomeDelegate>)target, home, object);
    });
}

@end
