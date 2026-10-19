#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wprotocol"

@implementation UITextFormattingCoordinator {
@private
    __weak id<UITextFormattingCoordinatorDelegate> _delegate;
}

+ (BOOL)isFontPanelVisible
{
    return NO;
}

+ (instancetype)textFormattingCoordinatorForWindowScene:(UIWindowScene *)windowScene
{
    return [[self alloc] initWithWindowScene:windowScene];
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene
{
    return [super init];
}

- (id<UITextFormattingCoordinatorDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UITextFormattingCoordinatorDelegate>)delegate
{
    _delegate = delegate;
}

- (void)setSelectedAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes isMultiple:(BOOL)flag
{
}

+ (void)toggleFontPanel:(id)sender
{
    charon_menus_say_once(@"font-panel", @"UITextFormattingCoordinator: the font panel belongs to Mac Catalyst, so iOS 6 shows none and the delegate is never asked to update attributes");
}

@end
