// ASCredentialIdentityStoreState, of iOS 12.0: whether the store can be written to, and whether it
// takes changes or the whole set.
//
// Two readonly booleans and no method, and the header is explicit that they are a gate: "You can only
// modify the credential identity store when it is enabled", and -supportsIncrementalUpdates decides
// whether -saveCredentialIdentities:completion: is given the new entries or all of them. So the two
// answers here are the answers a caller needs before it writes anything, which is why they are a value
// of their own rather than a return code buried in a completion handler.
//
// **What the port says, and why it is not simply YES.** A port that answered `enabled = YES` to this
// would be claiming a store the system does not have: the credential identity store on this release is
// a system service, and the port's own store is the application's own file, not the system's autofill
// database. An application that read YES and then saved would be told its passwords went somewhere the
// system will not read them from. So this is the value the port's own store reports, and the facts file
// says plainly that it is not the system store's state.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASCredentialIdentityStoreState

@synthesize enabled = _enabled;
@synthesize supportsIncrementalUpdates = _supportsIncrementalUpdates;

- (instancetype)charon_initWithEnabled:(BOOL)enabled
           supportsIncrementalUpdates:(BOOL)supportsIncrementalUpdates
{
    self = [super init];
    if (self) {
        _enabled = enabled;
        _supportsIncrementalUpdates = supportsIncrementalUpdates;
    }
    return self;
}

// The header does not mark -init unavailable on this class, so the port's own construction is the extra
// way in and the release's -init is left alone: an object with no state to report is not a state.
- (instancetype)init
{
    return [self charon_initWithEnabled:NO supportsIncrementalUpdates:NO];
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (BOOL)supportsIncrementalUpdates
{
    return _supportsIncrementalUpdates;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // Two booleans, and a copy at a different answer would be a different answer about a different store.
    return [[[self class] allocWithZone:zone] charon_initWithEnabled:_enabled
                                    supportsIncrementalUpdates:_supportsIncrementalUpdates];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithEnabled:[coder decodeBoolForKey:@"enabled"]
                supportsIncrementalUpdates:[coder decodeBoolForKey:@"supportsIncrementalUpdates"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_enabled forKey:@"enabled"];
    [coder encodeBool:_supportsIncrementalUpdates forKey:@"supportsIncrementalUpdates"];
}

@end
