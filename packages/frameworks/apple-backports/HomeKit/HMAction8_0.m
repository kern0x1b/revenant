#import "RevenantHomeKitInternal.h"

@implementation HMAction
@synthesize revenant_identifier = _revenant_identifier;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _revenant_identifier = [RevenantHomeKitNewIdentifier() copy];
        RevenantHomeKitRecord(@"actions", _revenant_identifier);
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _revenant_identifier;
}

@end

HMAction *RevenantHomeKitAction(NSString *identifier, NSString *homeIdentifier)
{
    HMAction *action = [[HMAction alloc] init];
    action.revenant_identifier = identifier;
    return action;
}
