#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UICommand (RevenantSelectedImage17)

static char RevenantCommandSelectedImageKey;

- (UIImage *)selectedImage
{
    return objc_getAssociatedObject(self, &RevenantCommandSelectedImageKey);
}

- (void)setSelectedImage:(UIImage *)selectedImage
{
    objc_setAssociatedObject(self, &RevenantCommandSelectedImageKey, [selectedImage copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
