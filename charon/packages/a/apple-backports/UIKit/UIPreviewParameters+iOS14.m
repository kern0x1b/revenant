#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UIPreviewParameters (CharonFourteen)

- (UIBezierPath *)shadowPath
{
    return objc_getAssociatedObject(self, @selector(shadowPath));
}

- (void)setShadowPath:(UIBezierPath *)shadowPath
{
    objc_setAssociatedObject(self, @selector(shadowPath), shadowPath, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
