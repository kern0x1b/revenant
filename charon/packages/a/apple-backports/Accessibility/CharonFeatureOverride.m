#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>

#import "CharonAccessibility.h"

#pragma mark - AXFeatureOverrideSessionManager

@implementation AXFeatureOverrideSessionManager

+ (AXFeatureOverrideSessionManager *)sharedInstance
{
    static AXFeatureOverrideSessionManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[AXFeatureOverrideSessionManager alloc] init];
    });
    return shared;
}

- (AXFeatureOverrideSession *)beginOverrideSessionEnablingOptions:(AXFeatureOverrideSessionOptions)enableOptions
                                                   disablingOptions:(AXFeatureOverrideSessionOptions)disableOptions
                                                            error:(NSError **)error
{
    if (error) {
        *error = [NSError errorWithDomain:@"AXFeatureOverrideSessionErrorDomain"
                                     code:AXFeatureOverrideSessionErrorUndefined
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"this release runs no service that overrides an "
                                                @"accessibility feature, so no session can be begun"}];
    }
    return nil;
}

- (BOOL)endOverrideSession:(AXFeatureOverrideSession *)session error:(NSError **)error
{
    if (error) {
        *error = [NSError errorWithDomain:@"AXFeatureOverrideSessionErrorDomain"
                                     code:AXFeatureOverrideSessionErrorUndefined
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"no session was begun, so none is active"}];
    }
    return NO;
}

@end

#pragma mark - AXFeatureOverrideSession

@implementation AXFeatureOverrideSession

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXFeatureOverrideSession %p>", self];
}

@end
