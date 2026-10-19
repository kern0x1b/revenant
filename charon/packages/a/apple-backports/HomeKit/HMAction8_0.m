#import "CharonHomeKitInternal.h"

@implementation HMAction
@synthesize charon_identifier = _charon_identifier;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _charon_identifier = [CharonHomeKitNewIdentifier() copy];
        CharonHomeKitRecord(@"actions", _charon_identifier);
    }
    return self;
}

- (NSString *)uniqueIdentifier
{
    return _charon_identifier;
}

@end

HMAction *CharonHomeKitAction(NSString *identifier, NSString *homeIdentifier)
{
    HMAction *action = [[HMAction alloc] init];
    action.charon_identifier = identifier;
    return action;
}
