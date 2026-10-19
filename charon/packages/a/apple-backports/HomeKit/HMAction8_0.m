// HMAction, of iOS 8.0: what an action set holds. It is the base of the one action HomeKit names --
// HMCharacteristicWriteAction, which writes a value to a characteristic -- and carries the identifier
// the set's own list of actions is keyed by.
//
// One release's API per object file, which is what the band machinery needs.
#import "CharonHomeKitInternal.h"

@implementation HMAction
@synthesize charon_identifier = _charon_identifier;

// -init, as the release's own class answers it: the body read out of the arm64e cache of iOS 16.0 is
// `[self initWithUUID:[NSUUID UUID]]`, so an action made this way carries an identifier nobody supplied,
// which is what a fresh action has, and it is not a raise. The header closes -init; Apple's class does
// not. facts/HomeKit/HMAccessoryProfile.md carries the body and the names out of it.
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
