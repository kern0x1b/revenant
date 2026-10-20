#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char RevenantGestureRecognizerNameKey;

@implementation UIGestureRecognizer (RevenantName)

- (NSString *)name
{
    return objc_getAssociatedObject(self, &RevenantGestureRecognizerNameKey);
}

- (void)setName:(NSString *)name
{
    objc_setAssociatedObject(self, &RevenantGestureRecognizerNameKey, [name copy], OBJC_ASSOCIATION_RETAIN);
}

@end
