#import <UIKit/UIKit.h>

@implementation UIFocusGuide {
    BOOL _enabled;
    __weak UIView *_preferredFocusedView;
    NSArray *_preferredFocusEnvironments;
}

- (void)revenant_setDefaults
{
    _enabled = YES;
    _preferredFocusedView = nil;
    _preferredFocusEnvironments = @[];
}

- (instancetype)init
{
    if ((self = [super init]))
        [self revenant_setDefaults];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        [self revenant_setDefaults];
    return self;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (UIView *)preferredFocusedView
{
    return _preferredFocusedView;
}

- (void)setPreferredFocusedView:(UIView *)preferredFocusedView
{
    _preferredFocusedView = preferredFocusedView;
}

- (NSArray *)preferredFocusEnvironments
{
    return _preferredFocusEnvironments;
}

- (void)setPreferredFocusEnvironments:(NSArray *)preferredFocusEnvironments
{
    _preferredFocusEnvironments = [preferredFocusEnvironments copy];
}

@end
