#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const RevenantMultiplyKey = @"contentsMultiplyColor";
static NSString *const RevenantMultiplyName = @"revenantContentsMultiplyColor";
static NSString *const RevenantMultiplyKeyPath = @"filters.revenantContentsMultiplyColor.inputColor";
static const char RevenantMultiplyColorKey;

static void (*RevenantSetFilters)(CALayer *, SEL, NSArray *);
static void (*RevenantAddAnimation)(CALayer *, SEL, CAAnimation *, NSString *);

static CGColorRef revenant_multiply_white(void)
{
    static CGColorRef white;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        const CGFloat components[] = {1, 1, 1, 1};
        white = CGColorCreate(space, components);
        CGColorSpaceRelease(space);
    });
    return white;
}

static BOOL revenant_multiply_identity(CGColorRef color)
{
    if (!color)
        return YES;
    CGColorSpaceModel model = CGColorSpaceGetModel(CGColorGetColorSpace(color));
    if (model != kCGColorSpaceModelRGB && model != kCGColorSpaceModelMonochrome)
        return NO;
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    for (size_t index = 0; index < count; index++) {
        if (components[index] != 1)
            return NO;
    }
    return YES;
}

static id revenant_multiply_stored(CALayer *layer)
{
    return objc_getAssociatedObject(layer, &RevenantMultiplyColorKey);
}

static CGColorRef revenant_multiply_color(id stored)
{
    return stored == [NSNull null] ? NULL : (__bridge CGColorRef)stored;
}

static BOOL revenant_multiply_ours(id filter)
{
    return [[filter valueForKey:@"name"] isEqual:RevenantMultiplyName];
}

static id revenant_multiply_filter(CGColorRef color)
{
    static Class filterClass;
    static SEL filterWithName;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        filterClass = NSClassFromString(@"CAFilter");
        filterWithName = NSSelectorFromString(@"filterWithName:");
    });
    id filter = filterClass ? ((id (*)(Class, SEL, NSString *))objc_msgSend)(filterClass, filterWithName, @"multiplyColor") : nil;
    [filter setValue:RevenantMultiplyName forKey:@"name"];
    [filter setValue:(__bridge id)color forKey:@"inputColor"];
    return filter;
}

static NSArray *revenant_multiply_arrange(NSArray *filters, CGColorRef tint)
{
    NSMutableArray *arranged = [NSMutableArray arrayWithCapacity:filters.count + 1];
    id ours = tint ? revenant_multiply_filter(tint) : nil;
    if (ours)
        [arranged addObject:ours];
    for (id filter in filters) {
        if (!revenant_multiply_ours(filter))
            [arranged addObject:filter];
    }
    return arranged.count ? arranged : nil;
}

static void revenant_multiply_update(CALayer *layer, CGColorRef tint)
{
    NSArray *filters = layer.filters;
    BOOL present = NO;
    for (id filter in filters) {
        if (revenant_multiply_ours(filter)) {
            present = YES;
            break;
        }
    }
    if (!tint && !present)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (tint && present)
        [layer setValue:(__bridge id)tint forKeyPath:RevenantMultiplyKeyPath];
    else
        RevenantSetFilters(layer, @selector(setFilters:), revenant_multiply_arrange(filters, tint));
    [CATransaction commit];
}

static id revenant_multiply_value(id value)
{
    static SEL CGColor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGColor = NSSelectorFromString(@"CGColor");
    });
    if (value && CFGetTypeID((__bridge CFTypeRef)value) != CGColorGetTypeID() && [value respondsToSelector:CGColor])
        return (__bridge id)((CGColorRef (*)(id, SEL))objc_msgSend)(value, CGColor);
    return value;
}

static CAAnimation *revenant_multiply_translate(CAPropertyAnimation *animation)
{
    CAPropertyAnimation *translated = [animation copy];
    translated.keyPath = RevenantMultiplyKeyPath;
    if ([translated isKindOfClass:[CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *)translated;
        basic.fromValue = revenant_multiply_value(basic.fromValue);
        basic.toValue = revenant_multiply_value(basic.toValue);
        basic.byValue = revenant_multiply_value(basic.byValue);
    } else if ([translated isKindOfClass:[CAKeyframeAnimation class]]) {
        CAKeyframeAnimation *keyframes = (CAKeyframeAnimation *)translated;
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:keyframes.values.count];
        for (id value in keyframes.values)
            [values addObject:revenant_multiply_value(value)];
        keyframes.values = values;
    }
    return translated;
}

static void revenant_multiply_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method setFilters = class_getInstanceMethod([CALayer class], @selector(setFilters:));
        RevenantSetFilters = (void (*)(CALayer *, SEL, NSArray *))method_getImplementation(setFilters);
        method_setImplementation(setFilters, imp_implementationWithBlock(^(CALayer *self, NSArray *filters) {
            id stored = revenant_multiply_stored(self);
            if (stored) {
                CGColorRef color = revenant_multiply_color(stored);
                filters = revenant_multiply_arrange(filters, revenant_multiply_identity(color) ? NULL : color);
            }
            RevenantSetFilters(self, @selector(setFilters:), filters);
        }));
        Method addAnimation = class_getInstanceMethod([CALayer class], @selector(addAnimation:forKey:));
        RevenantAddAnimation = (void (*)(CALayer *, SEL, CAAnimation *, NSString *))method_getImplementation(addAnimation);
        method_setImplementation(addAnimation, imp_implementationWithBlock(^(CALayer *self, CAAnimation *animation, NSString *key) {
            if ([animation isKindOfClass:[CAPropertyAnimation class]] && [((CAPropertyAnimation *)animation).keyPath isEqualToString:RevenantMultiplyKey]) {
                id stored = revenant_multiply_stored(self);
                CGColorRef color = stored ? revenant_multiply_color(stored) : NULL;
                revenant_multiply_update(self, color ?: revenant_multiply_white());
                animation = revenant_multiply_translate((CAPropertyAnimation *)animation);
            }
            RevenantAddAnimation(self, @selector(addAnimation:forKey:), animation, key);
        }));
    });
}

@interface CALayer (RevenantContentsMultiplyColor)
- (id)contentsMultiplyColor;
- (void)setContentsMultiplyColor:(id)color;
@end

@implementation CALayer (RevenantContentsMultiplyColor)

- (id)contentsMultiplyColor
{
    id stored = revenant_multiply_stored(self);
    if (!stored)
        return (__bridge id)revenant_multiply_white();
    return stored == [NSNull null] ? nil : stored;
}

- (void)setContentsMultiplyColor:(id)color
{
    revenant_multiply_install();
    color = revenant_multiply_value(color);
    if (color && CFGetTypeID((__bridge CFTypeRef)color) != CGColorGetTypeID())
        color = nil;
    objc_setAssociatedObject(self, &RevenantMultiplyColorKey, color ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGColorRef tint = (__bridge CGColorRef)color;
    revenant_multiply_update(self, revenant_multiply_identity(tint) ? NULL : tint);
}

@end
