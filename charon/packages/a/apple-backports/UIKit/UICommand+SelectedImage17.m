#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// UICommand's selected image, iOS 17.
//
// UIMenuLeaf.h:27 of the 26.2 SDK declares `@property (nullable, nonatomic, copy) UIImage *selectedImage
// API_AVAILABLE(ios(17.0))`, and the header describes it as the image shown beside this action while the `state` is
// `UIMenuElementStateOn`, and Apple's own classes answer it on BOTH conformers of that protocol: read out of
// the arm64e shared cache of iOS 18.0 with modules/apple/objc.lua's inventory, the own instance lists of
// UIAction and of UICommand each carry -selectedImage and -setSelectedImage:. The port answers it on UIAction
// (UIAction.m) and on no other class, so a command in a menu drew no selected image.
//
// A category cannot add an ivar, so the storage is the object's own associated value, which is what the rest
// of this package does for a member a category has to carry (UIKit26_0.m's UIColor
// linearExposure is the same shape). UIAction keeps its own copy in its own ivar and neither reaches the
// other's: the two classes are siblings under UIMenuElement, not one under the other. A copy of the image on
// the way in and on the way out, because the header says `copy`.
//
// One release per object: selectedImage is 17.0 and UICommand.m holds the 13.0 members, so this is its own
// file rather than a line in that one.
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