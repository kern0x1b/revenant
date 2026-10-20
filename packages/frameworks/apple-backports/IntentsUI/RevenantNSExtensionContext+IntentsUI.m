#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface NSExtensionContext (RevenantIntentsUIHostedView)
@end

@implementation NSExtensionContext (RevenantIntentsUIHostedView)

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
