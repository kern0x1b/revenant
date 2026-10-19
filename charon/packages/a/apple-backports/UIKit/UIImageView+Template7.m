#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_template_image_key;
static const char charon_template_highlighted_key;
static const char charon_template_tint_key;

static void (*charon_set_image)(id, SEL, id);
static void (*charon_set_highlighted)(id, SEL, id);
static id (*charon_get_image)(id, SEL);
static id (*charon_get_highlighted)(id, SEL);

static UIImage *charon_tinted(UIImage *image, UIColor *color)
{
    if (!image.CGImage || image.images.count)
        return image;
    CGSize size = image.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    [image drawInRect:rect];
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [color setFill];
    CGContextFillRect(context, rect);
    UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIEdgeInsets capInsets = image.capInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
        tinted = [tinted resizableImageWithCapInsets:capInsets resizingMode:image.resizingMode];
    UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(alignmentInsets, UIEdgeInsetsZero))
        tinted = [tinted imageWithAlignmentRectInsets:alignmentInsets];
    return tinted;
}

static BOOL charon_is_template(UIImage *image)
{
    return image && image.renderingMode == UIImageRenderingModeAlwaysTemplate;
}

static NSString *charon_color_key(UIColor *color)
{
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        CGFloat white = 0;
        [color getWhite:&white alpha:&alpha];
        red = green = blue = white;
    }
    return [NSString stringWithFormat:@"%.4f %.4f %.4f %.4f", red, green, blue, alpha];
}

static void charon_apply(UIImageView *view, BOOL highlighted)
{
    const void *key = highlighted ? &charon_template_highlighted_key : &charon_template_image_key;
    UIImage *template = objc_getAssociatedObject(view, key);
    if (!template)
        return;
    void (*set)(id, SEL, id) = highlighted ? charon_set_highlighted : charon_set_image;
    set(view, highlighted ? @selector(setHighlightedImage:) : @selector(setImage:), charon_tinted(template, view.tintColor));
}

static void charon_refresh(UIImageView *view)
{
    NSString *now = charon_color_key(view.tintColor);
    if ([now isEqualToString:objc_getAssociatedObject(view, &charon_template_tint_key)])
        return;
    objc_setAssociatedObject(view, &charon_template_tint_key, now, OBJC_ASSOCIATION_COPY_NONATOMIC);
    charon_apply(view, NO);
    charon_apply(view, YES);
}

static void charon_store(UIImageView *view, UIImage *image, BOOL highlighted)
{
    const void *key = highlighted ? &charon_template_highlighted_key : &charon_template_image_key;
    BOOL template = charon_is_template(image);
    objc_setAssociatedObject(view, key, template ? image : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    void (*set)(id, SEL, id) = highlighted ? charon_set_highlighted : charon_set_image;
    SEL selector = highlighted ? @selector(setHighlightedImage:) : @selector(setImage:);
    if (template)
        objc_setAssociatedObject(view, &charon_template_tint_key, charon_color_key(view.tintColor), OBJC_ASSOCIATION_COPY_NONATOMIC);
    set(view, selector, template ? charon_tinted(image, view.tintColor) : image);
}

@interface CharonImageTemplate : NSObject
@end

@implementation CharonImageTemplate

+ (void)load
{
    if ([UIImage instancesRespondToSelector:@selector(imageWithRenderingMode:)])
        return;
    Class view = [UIImageView class];
    SEL setImage = @selector(setImage:), setHighlighted = @selector(setHighlightedImage:), image = @selector(image), highlighted = @selector(highlightedImage);
    charon_set_image = (void (*)(id, SEL, id))class_getMethodImplementation(view, setImage);
    charon_set_highlighted = (void (*)(id, SEL, id))class_getMethodImplementation(view, setHighlighted);
    charon_get_image = (id (*)(id, SEL))class_getMethodImplementation(view, image);
    charon_get_highlighted = (id (*)(id, SEL))class_getMethodImplementation(view, highlighted);
    class_replaceMethod(view, setImage, imp_implementationWithBlock(^(UIImageView *self_, UIImage *value) {
        charon_store(self_, value, NO);
    }), method_getTypeEncoding(class_getInstanceMethod(view, setImage)));
    class_replaceMethod(view, setHighlighted, imp_implementationWithBlock(^(UIImageView *self_, UIImage *value) {
        charon_store(self_, value, YES);
    }), method_getTypeEncoding(class_getInstanceMethod(view, setHighlighted)));
    class_replaceMethod(view, image, imp_implementationWithBlock(^UIImage *(UIImageView *self_) {
        return objc_getAssociatedObject(self_, &charon_template_image_key) ?: charon_get_image(self_, image);
    }), method_getTypeEncoding(class_getInstanceMethod(view, image)));
    class_replaceMethod(view, highlighted, imp_implementationWithBlock(^UIImage *(UIImageView *self_) {
        return objc_getAssociatedObject(self_, &charon_template_highlighted_key) ?: charon_get_highlighted(self_, highlighted);
    }), method_getTypeEncoding(class_getInstanceMethod(view, highlighted)));
    for (NSValue *value in @[[NSValue valueWithPointer:@selector(initWithImage:)]]) {
        SEL selector = [value pointerValue];
        id (*original)(id, SEL, id) = (id (*)(id, SEL, id))class_getMethodImplementation(view, selector);
        class_replaceMethod(view, selector, imp_implementationWithBlock(^id(UIImageView *self_, UIImage *value_) {
            id result = original(self_, selector, value_);
            if (result && charon_is_template(value_))
                [result setImage:value_];
            return result;
        }), method_getTypeEncoding(class_getInstanceMethod(view, selector)));
    }
    SEL initBoth = @selector(initWithImage:highlightedImage:);
    id (*originalBoth)(id, SEL, id, id) = (id (*)(id, SEL, id, id))class_getMethodImplementation(view, initBoth);
    class_replaceMethod(view, initBoth, imp_implementationWithBlock(^id(UIImageView *self_, UIImage *value_, UIImage *highlighted_) {
        id result = originalBoth(self_, initBoth, value_, highlighted_);
        if (result && charon_is_template(value_))
            [result setImage:value_];
        if (result && charon_is_template(highlighted_))
            [result setHighlightedImage:highlighted_];
        return result;
    }), method_getTypeEncoding(class_getInstanceMethod(view, initBoth)));
    SEL moved = @selector(didMoveToSuperview);
    void (*originalMoved)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(view, moved);
    class_replaceMethod(view, moved, imp_implementationWithBlock(^(UIImageView *self_) {
        originalMoved(self_, moved);
        charon_refresh(self_);
    }), method_getTypeEncoding(class_getInstanceMethod(view, moved)));
    SEL tint = @selector(tintColorDidChange);
    class_replaceMethod(view, tint, imp_implementationWithBlock(^(UIImageView *self_) {
        void (*super_)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation([UIView class], tint);
        super_(self_, tint);
        charon_refresh(self_);
    }), "v@:");
}

@end
