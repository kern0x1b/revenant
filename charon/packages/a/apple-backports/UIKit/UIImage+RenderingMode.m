#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#import <objc/runtime.h>

static char charon_rendering_mode_key;

@implementation UIImage (CharonRenderingMode)

- (UIImageRenderingMode)renderingMode
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_rendering_mode_key);
    return stored ? (UIImageRenderingMode)stored.integerValue : UIImageRenderingModeAutomatic;
}

- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)renderingMode
{
    UIImage *image = nil;
    if (self.images.count)
        image = [UIImage animatedImageWithImages:self.images duration:self.duration];
    else if (self.CGImage)
        image = [UIImage imageWithCGImage:self.CGImage scale:self.scale orientation:self.imageOrientation];
    else if (self.CIImage)
        image = [UIImage imageWithCIImage:self.CIImage scale:self.scale orientation:self.imageOrientation];
    if (!image)
        image = self;
    UIEdgeInsets capInsets = self.capInsets;
    if (image != self && !UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
        image = [image resizableImageWithCapInsets:capInsets resizingMode:self.resizingMode];
    UIEdgeInsets alignmentInsets = self.alignmentRectInsets;
    if (image != self && !UIEdgeInsetsEqualToEdgeInsets(alignmentInsets, UIEdgeInsetsZero))
        image = [image imageWithAlignmentRectInsets:alignmentInsets];
    objc_setAssociatedObject(image, &charon_rendering_mode_key, @(renderingMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return image;
}

@end

static UIImage *charon_keep_mode(UIImage *source, UIImage *result)
{
    NSNumber *stored = objc_getAssociatedObject(source, &charon_rendering_mode_key);
    if (stored && result != source)
        objc_setAssociatedObject(result, &charon_rendering_mode_key, stored, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return result;
}

@interface CharonImageModeKeeper : NSObject
@end

@implementation CharonImageModeKeeper

+ (void)load
{
    if ([UIImage instancesRespondToSelector:@selector(imageWithRenderingMode:)])
        return;
    Class image = [UIImage class];
    SEL caps = @selector(resizableImageWithCapInsets:);
    UIImage *(*originalCaps)(id, SEL, UIEdgeInsets) = (UIImage *(*)(id, SEL, UIEdgeInsets))class_getMethodImplementation(image, caps);
    class_replaceMethod(image, caps, imp_implementationWithBlock(^UIImage *(UIImage *self_, UIEdgeInsets insets) {
        return charon_keep_mode(self_, originalCaps(self_, caps, insets));
    }), method_getTypeEncoding(class_getInstanceMethod(image, caps)));
    SEL capsMode = @selector(resizableImageWithCapInsets:resizingMode:);
    UIImage *(*originalCapsMode)(id, SEL, UIEdgeInsets, NSInteger) = (UIImage *(*)(id, SEL, UIEdgeInsets, NSInteger))class_getMethodImplementation(image, capsMode);
    class_replaceMethod(image, capsMode, imp_implementationWithBlock(^UIImage *(UIImage *self_, UIEdgeInsets insets, NSInteger mode) {
        return charon_keep_mode(self_, originalCapsMode(self_, capsMode, insets, mode));
    }), method_getTypeEncoding(class_getInstanceMethod(image, capsMode)));
    SEL alignment = @selector(imageWithAlignmentRectInsets:);
    UIImage *(*originalAlignment)(id, SEL, UIEdgeInsets) = (UIImage *(*)(id, SEL, UIEdgeInsets))class_getMethodImplementation(image, alignment);
    class_replaceMethod(image, alignment, imp_implementationWithBlock(^UIImage *(UIImage *self_, UIEdgeInsets insets) {
        return charon_keep_mode(self_, originalAlignment(self_, alignment, insets));
    }), method_getTypeEncoding(class_getInstanceMethod(image, alignment)));
}

@end
