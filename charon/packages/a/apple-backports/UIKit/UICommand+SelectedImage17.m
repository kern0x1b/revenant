#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UICommand (CharonSelectedImage17)

static char CharonCommandSelectedImageKey;

- (UIImage *)selectedImage
{
    return objc_getAssociatedObject(self, &CharonCommandSelectedImageKey);
}

- (void)setSelectedImage:(UIImage *)selectedImage
{
    objc_setAssociatedObject(self, &CharonCommandSelectedImageKey, [selectedImage copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
