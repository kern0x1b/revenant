#import <UIKit/UIKit.h>

@implementation UIListContentView (RevenantSupportsConfiguration16)

- (BOOL)supportsConfiguration:(id<UIContentConfiguration>)configuration
{
    if (!configuration)
        return NO;
    return [[[configuration makeContentView] class] isSubclassOfClass:[self class]];
}

@end
