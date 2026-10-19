#import <UIKit/UIKit.h>

@implementation UITextField (CharonEditMenu16)

- (UIMenu *)editMenuForTextRange:(UITextRange *)textRange suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions
{
    return nil;
}

- (void)willPresentEditMenuWithAnimator:(id<UIEditMenuInteractionAnimating>)animator
{
}

- (void)willDismissEditMenuWithAnimator:(id<UIEditMenuInteractionAnimating>)animator
{
}

@end
