#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_image_key;

@implementation UIAccessibilityCustomAction (CharonImage14)

- (instancetype)initWithName:(NSString *)name image:(UIImage *)image actionHandler:(UIAccessibilityCustomActionHandler)actionHandler
{
    if ((self = [self initWithName:name actionHandler:actionHandler]))
        [self setImage:image];  // a send, not a dot-syntax write: see UIAccessibilityCustomAction+Handler13.m
    return self;
}

- (instancetype)initWithName:(NSString *)name image:(UIImage *)image target:(id)target selector:(SEL)selector
{
    if ((self = [self initWithName:name target:target selector:selector]))
        [self setImage:image];  // a send, not a dot-syntax write: see UIAccessibilityCustomAction+Handler13.m
    return self;
}

- (UIImage *)image
{
    return objc_getAssociatedObject(self, &charon_image_key);
}

- (void)setImage:(UIImage *)image
{
    objc_setAssociatedObject(self, &charon_image_key, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
