#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_semantic_key;

@implementation UIView (CharonSemanticContentAttribute)

- (UISemanticContentAttribute)semanticContentAttribute
{
    return (UISemanticContentAttribute)[objc_getAssociatedObject(self, &charon_semantic_key) integerValue];
}

- (void)setSemanticContentAttribute:(UISemanticContentAttribute)semanticContentAttribute
{
    objc_setAssociatedObject(self, &charon_semantic_key, @(semanticContentAttribute), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute
{
    return [self userInterfaceLayoutDirectionForSemanticContentAttribute:attribute relativeToLayoutDirection:[UIApplication sharedApplication].userInterfaceLayoutDirection];
}

+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)layoutDirection
{
    switch ((NSInteger)attribute) {
    case 4:
        return UIUserInterfaceLayoutDirectionRightToLeft;
    case 1:
    case 2:
    case 3:
        return UIUserInterfaceLayoutDirectionLeftToRight;
    }
    return layoutDirection;
}

- (UIUserInterfaceLayoutDirection)effectiveUserInterfaceLayoutDirection
{
    return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.semanticContentAttribute];
}

@end
