//
//  CharonFeatureOverride.m
//  Accessibility
//
//  The two classes of the feature-override session, which arrived with iOS 18.2 and are in an
//  object of their own for the same reason every other object in this package is: an object
//  carries API of one release, and AXRequest is 18.0.
//
//  What they answer is in facts/Accessibility/Accessibility.md. In one line: the system that
//  begins an override does not run on this release, so the manager answers nil with the header's
//  own Undefined and there is no session to end.
//

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
    // The system that turns these on is not on this release. Undefined is the header's own name
    // for a session that could not be begun for no more specific reason, and there is no more
    // specific one here: there is no service, so there is nothing to be entitled to and nothing
    // already active and nothing registered under a UUID. The manager is real and answers.
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
    // No session was begun, so none is active. Ending one is therefore a NO, and it says why.
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

// The header gives the session nothing: it is a token the manager hands out and takes back. There
// is no manager that can hand one out on this release, so the class is a container of its own and
// the equality the header implies is by identity.
@implementation AXFeatureOverrideSession

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXFeatureOverrideSession %p>", self];
}

@end
