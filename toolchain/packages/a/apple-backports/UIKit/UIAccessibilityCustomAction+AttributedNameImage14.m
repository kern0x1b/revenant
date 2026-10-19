#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wnonnull"

@implementation UIAccessibilityCustomAction (CharonAttributedNameImage14)

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName image:(UIImage *)image target:(id)target selector:(SEL)selector
{
    if ((self = [self initWithAttributedName:attributedName target:target selector:selector]))
        [self setImage:image];
    return self;
}

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName image:(UIImage *)image actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    if ((self = [self initWithAttributedName:attributedName target:nil selector:NULL])) {
        [self setActionHandler:actionHandler];
        [self setImage:image];
    }
    return self;
}

@end
