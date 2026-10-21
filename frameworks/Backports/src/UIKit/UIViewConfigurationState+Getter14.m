#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIViewConfigurationState (RevenantGetter14)

- (BOOL)disabled
{
    return [self isDisabled];
}

- (BOOL)focused
{
    return [self isFocused];
}

- (BOOL)highlighted
{
    return [self isHighlighted];
}

- (BOOL)selected
{
    return [self isSelected];
}

- (BOOL)pinned
{
    return [self isPinned];
}

@end
