#import <UIKit/UIKit.h>

// A focus guide is a layout guide the focus engine reads: a focus move that crosses its frame goes to
// preferredFocusedView, or to the first of preferredFocusEnvironments that can take focus. iOS 6 has no focus
// engine, so the values are kept exactly as they were set and nothing in the release ever reads them. The
// defaults are the ones the host gives: enabled, no preferred view, and an empty environment list.
@implementation UIFocusGuide {
    BOOL _enabled;
    __weak UIView *_preferredFocusedView;
    NSArray *_preferredFocusEnvironments;
}

- (void)charon_setDefaults
{
    _enabled = YES;
    _preferredFocusedView = nil;
    _preferredFocusEnvironments = @[];
}

- (instancetype)init
{
    if ((self = [super init]))
        [self charon_setDefaults];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        [self charon_setDefaults];
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
