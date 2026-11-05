#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UIPresentationController (RevenantUIKit26_1)

static char RevenantPresentationBackgroundEffectKey;

- (id)backgroundEffect { return objc_getAssociatedObject(self, &RevenantPresentationBackgroundEffectKey); }
- (void)setBackgroundEffect:(id)effect
{
    objc_setAssociatedObject(self, &RevenantPresentationBackgroundEffectKey, effect,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
