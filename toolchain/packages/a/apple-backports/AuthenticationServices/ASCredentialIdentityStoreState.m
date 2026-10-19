#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@implementation ASCredentialIdentityStoreState

@synthesize enabled = _enabled;
@synthesize supportsIncrementalUpdates = _supportsIncrementalUpdates;

- (instancetype)revenant_initWithEnabled:(BOOL)enabled
           supportsIncrementalUpdates:(BOOL)supportsIncrementalUpdates
{
    self = [super init];
    if (self) {
        _enabled = enabled;
        _supportsIncrementalUpdates = supportsIncrementalUpdates;
    }
    return self;
}

- (instancetype)init
{
    return [self revenant_initWithEnabled:NO supportsIncrementalUpdates:NO];
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
    return [[[self class] allocWithZone:zone] revenant_initWithEnabled:_enabled
                                    supportsIncrementalUpdates:_supportsIncrementalUpdates];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self revenant_initWithEnabled:[coder decodeBoolForKey:@"enabled"]
                supportsIncrementalUpdates:[coder decodeBoolForKey:@"supportsIncrementalUpdates"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_enabled forKey:@"enabled"];
    [coder encodeBool:_supportsIncrementalUpdates forKey:@"supportsIncrementalUpdates"];
}

@end
