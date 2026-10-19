//
//  CharonNSExtensionContext+IntentsUI.m
//  IntentsUI
//
//  The three members IntentsUI adds to NSExtensionContext (INUIHostedViewControlling.h), for the context the Foundation
//  backport defines. A context with no host has no size to be shown in and no parameters to describe, so the answers are
//  the host's values for a fresh context, measured by tests/backports/host/nsextension-context: both sizes {0, 0} and
//  interfaceParametersDescription nil.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface NSExtensionContext (CharonIntentsUIHostedView)
@end

@implementation NSExtensionContext (CharonIntentsUIHostedView)

- (CGSize)hostedViewMinimumAllowedSize
{
    return CGSizeMake(0, 0);
}

- (CGSize)hostedViewMaximumAllowedSize
{
    return CGSizeMake(0, 0);
}

- (NSString *)interfaceParametersDescription
{
    return nil;
}

@end
