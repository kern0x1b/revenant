#import "RevenantSymbols.h"
#import "RevenantImageBaseline.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_configuration_key;

UIImage *revenant_image_copy(UIImage *image)
{
    UIImage *copy = nil;
    if (image.images.count)
        copy = [UIImage animatedImageWithImages:image.images duration:image.duration];
    else if (image.CGImage)
        copy = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
    else if (image.CIImage)
        copy = [UIImage imageWithCIImage:image.CIImage scale:image.scale orientation:image.imageOrientation];
    if (!copy)
        return image;
    UIEdgeInsets capInsets = image.capInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
        copy = [copy resizableImageWithCapInsets:capInsets resizingMode:image.resizingMode];
    UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(alignmentInsets, UIEdgeInsetsZero))
        copy = [copy imageWithAlignmentRectInsets:alignmentInsets];
    if (image.renderingMode != UIImageRenderingModeAutomatic)
        copy = [copy imageWithRenderingMode:image.renderingMode];
    UIImageSymbolConfiguration *symbol = image.symbolConfiguration;
    if (symbol)
        copy = [copy imageByApplyingSymbolConfiguration:symbol];
    id configuration = objc_getAssociatedObject(image, &revenant_configuration_key);
    if (configuration)
        objc_setAssociatedObject(copy, &revenant_configuration_key, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_set_image_baseline(copy, revenant_image_baseline(image));
    return copy;
}

typedef void (^RevenantGlyph)(CGContextRef context, CGRect bounds);

static UIImage *revenant_glyph(BOOL filled, RevenantGlyph glyph)
{
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    CGRect disc = CGRectInset(bounds, 1.5, 1.5);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    if (filled) {
        CGContextFillEllipseInRect(context, disc);
        CGContextSetBlendMode(context, kCGBlendModeClear);
    } else {
        CGContextSetLineWidth(context, 1.5);
        CGContextStrokeEllipseInRect(context, CGRectInset(disc, 0.75, 0.75));
    }
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 1.8);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    glyph(context, bounds);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static void revenant_check(CGContextRef context, CGRect bounds)
{
    CGContextMoveToPoint(context, 5.8, 10.4);
    CGContextAddLineToPoint(context, 8.8, 13.4);
    CGContextAddLineToPoint(context, 14.4, 6.8);
    CGContextStrokePath(context);
}

@implementation UIImage (RevenantThirteen)

+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle withConfiguration:(UIImageConfiguration *)configuration
{
    UIImage *image = nil;
    if (!bundle || bundle == [NSBundle mainBundle]) {
        image = [UIImage imageNamed:name];
    } else {
        NSString *extension = name.pathExtension.length ? name.pathExtension : @"png";
        NSString *base = name.pathExtension.length ? [name stringByDeletingPathExtension] : name;
        NSString *path = nil;
        if ([UIScreen mainScreen].scale >= 2)
            path = [bundle pathForResource:[base stringByAppendingString:@"@2x"] ofType:extension];
        if (!path)
            path = [bundle pathForResource:base ofType:extension];
        image = path ? [UIImage imageWithContentsOfFile:path] : nil;
    }
    return image && configuration ? [image imageWithConfiguration:configuration] : image;
}

- (UIImageConfiguration *)configuration
{
    UIImageConfiguration *held = self.symbolConfiguration;
    if (!held)
        held = objc_getAssociatedObject(self, &revenant_configuration_key);
    if (held)
        return held;
    return [[UIImageConfiguration alloc] initRevenantWithTraitCollection:[UITraitCollection traitCollectionWithDisplayScale:self.scale]];
}

- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)configuration
{
    if ([configuration isKindOfClass:[UIImageSymbolConfiguration class]])
        return [self imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)configuration];
    UIImage *copy = revenant_image_copy(self);
    if (copy == self)
        copy = [self imageWithRenderingMode:self.renderingMode];
    objc_setAssociatedObject(copy, &revenant_configuration_key, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return copy;
}

- (UIImage *)imageWithTintColor:(UIColor *)color renderingMode:(UIImageRenderingMode)renderingMode
{
    UIImage *result = self;
    if (color && self.CGImage && self.size.width > 0 && self.size.height > 0 && !self.images.count) {
        CGRect bounds = CGRectMake(0, 0, self.size.width, self.size.height);
        UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
        [color setFill];
        UIRectFill(bounds);
        [self drawInRect:bounds blendMode:kCGBlendModeDestinationIn alpha:1];
        UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIEdgeInsets capInsets = self.capInsets;
        if (!UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
            tinted = [tinted resizableImageWithCapInsets:capInsets resizingMode:self.resizingMode];
        UIEdgeInsets alignment = self.alignmentRectInsets;
        if (!UIEdgeInsetsEqualToEdgeInsets(alignment, UIEdgeInsetsZero))
            tinted = [tinted imageWithAlignmentRectInsets:alignment];
        result = tinted;
        revenant_set_image_baseline(result, revenant_image_baseline(self));
        id configuration = objc_getAssociatedObject(self, &revenant_configuration_key);
        if (configuration)
            objc_setAssociatedObject(result, &revenant_configuration_key, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (self.symbolConfiguration)
            result = [result imageByApplyingSymbolConfiguration:self.symbolConfiguration];
    } else {
        result = revenant_image_copy(self);
    }
    UIImage *moded = [result imageWithRenderingMode:renderingMode];
    if (moded != result)
        revenant_set_image_baseline(moded, revenant_image_baseline(result));
    return moded;
}

- (UIImage *)imageWithTintColor:(UIColor *)color
{
    return [self imageWithTintColor:color renderingMode:UIImageRenderingModeAutomatic];
}

+ (UIImage *)checkmarkImage
{
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image = revenant_glyph(YES, ^(CGContextRef context, CGRect bounds) {
            revenant_check(context, bounds);
        });
    });
    return image;
}

+ (UIImage *)strokedCheckmarkImage
{
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image = revenant_glyph(NO, ^(CGContextRef context, CGRect bounds) {
            CGContextSetBlendMode(context, kCGBlendModeNormal);
            revenant_check(context, bounds);
        });
    });
    return image;
}

+ (UIImage *)addImage
{
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image = revenant_glyph(YES, ^(CGContextRef context, CGRect bounds) {
            CGContextMoveToPoint(context, 10, 5.8);
            CGContextAddLineToPoint(context, 10, 14.2);
            CGContextMoveToPoint(context, 5.8, 10);
            CGContextAddLineToPoint(context, 14.2, 10);
            CGContextStrokePath(context);
        });
    });
    return image;
}

+ (UIImage *)removeImage
{
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image = revenant_glyph(YES, ^(CGContextRef context, CGRect bounds) {
            CGContextMoveToPoint(context, 5.8, 10);
            CGContextAddLineToPoint(context, 14.2, 10);
            CGContextStrokePath(context);
        });
    });
    return image;
}

+ (UIImage *)actionsImage
{
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        image = revenant_glyph(YES, ^(CGContextRef context, CGRect bounds) {
            for (CGFloat x = 6; x <= 14; x += 4)
                CGContextFillEllipseInRect(context, CGRectMake(x - 1.1, 8.9, 2.2, 2.2));
        });
    });
    return image;
}

@end
