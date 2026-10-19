#import "CharonMenus.h"

// UIPencilInteraction, iOS 12.1. An interaction the port carries because an application strong-imports
// its class symbol, and whose event no device of this release can produce: the Apple Pencil is a stylus
// with its own radio and sensors, and no device this package runs on has one. The class is made, added to
// a view and removed like any other interaction, keeps its delegate weakly, and never calls back - the
// same shape UIScribbleInteraction carries for the same wall (facts/UIKit/UIInertInteractions.md).
//
// The two class properties answer the capability honestly. +preferredTapAction is the action to perform
// when the user taps the side of the pencil; with no pencil there is no tap and so no action, which is
// what UIPencilPreferredActionIgnore says in the SDK, namely that there is no action, or that pencil interactions
// are disabled in the accessibility settings. It is not read from a preference: iOS 6 has no
// Settings pane for it, so there is nothing to read and Ignore is the only answer that is true.
// +prefersPencilOnlyDrawing is NO, which is what the host's own UIKit answers
// (facts/UIKit/UIPencilInteraction12.md).
@implementation UIPencilInteraction {
@private
    __weak id<UIPencilInteractionDelegate> _delegate;
    __weak UIView *_view;
    BOOL _enabled;
}

+ (UIPencilPreferredAction)preferredTapAction
{
    return UIPencilPreferredActionIgnore;
}

+ (BOOL)prefersPencilOnlyDrawing
{
    return NO;
}

- (instancetype)init
{
    if ((self = [super init]))
        _enabled = YES;
    return self;
}

- (id<UIPencilInteractionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIPencilInteractionDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (view)
        charon_menus_say_once(@"pencil", @"UIPencilInteraction: this release has no Apple Pencil, so the interaction is attached and its delegate is never called; preferredTapAction is UIPencilPreferredActionIgnore");
}

@end
