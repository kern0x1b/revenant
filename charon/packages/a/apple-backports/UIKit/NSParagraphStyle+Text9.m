#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *TighteningKey = &TighteningKey;
static const void *StrategyKey = &StrategyKey;

static BOOL tightening_of(id style)
{
    NSNumber *held = objc_getAssociatedObject(style, TighteningKey);
    return held ? held.boolValue : YES;
}

static NSInteger strategy_of(id style)
{
    return [objc_getAssociatedObject(style, StrategyKey) integerValue];
}

static void carry(id from, id to)
{
    if (!to)
        return;
    objc_setAssociatedObject(to, TighteningKey, objc_getAssociatedObject(from, TighteningKey), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(to, StrategyKey, objc_getAssociatedObject(from, StrategyKey), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

typedef id (*CopyIMP)(id, SEL, NSZone *);
typedef BOOL (*EqualIMP)(id, SEL, id);

static CopyIMP native_copy, native_mutable_copy, native_mutable_class_copy;
static EqualIMP native_equal;

static id copy_with_zone(id self, SEL selector, NSZone *zone)
{
    id copy = native_copy(self, selector, zone);
    if (copy != self)
        carry(self, copy);
    return copy;
}

static id mutable_copy_with_zone(id self, SEL selector, NSZone *zone)
{
    id copy = native_mutable_copy(self, selector, zone);
    carry(self, copy);
    return copy;
}

static id mutable_class_copy_with_zone(id self, SEL selector, NSZone *zone)
{
    id copy = native_mutable_class_copy(self, selector, zone);
    carry(self, copy);
    return copy;
}

static BOOL is_equal(id self, SEL selector, id other)
{
    if (!native_equal(self, selector, other))
        return NO;
    return self == other || ![other isKindOfClass:[NSParagraphStyle class]] || (tightening_of(self) == tightening_of(other) && strategy_of(self) == strategy_of(other));
}

@interface CharonParagraphStyle9 : NSObject
@end

@implementation CharonParagraphStyle9

+ (void)load
{
    if ([NSParagraphStyle instancesRespondToSelector:@selector(lineBreakStrategy)])
        return;
    Class base = [NSParagraphStyle class], mutable = [NSMutableParagraphStyle class];
    Method method = class_getInstanceMethod(base, @selector(copyWithZone:));
    if (method) {
        native_copy = (CopyIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)copy_with_zone);
    }
    method = class_getInstanceMethod(base, @selector(mutableCopyWithZone:));
    if (method) {
        native_mutable_copy = (CopyIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)mutable_copy_with_zone);
    }
    method = class_getInstanceMethod(base, @selector(isEqual:));
    if (method) {
        native_equal = (EqualIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)is_equal);
    }
    Method own = class_getInstanceMethod(mutable, @selector(copyWithZone:));
    if (own && own != class_getInstanceMethod(base, @selector(copyWithZone:))) {
        native_mutable_class_copy = (CopyIMP)method_getImplementation(own);
        method_setImplementation(own, (IMP)mutable_class_copy_with_zone);
    }
}

@end

@implementation NSParagraphStyle (CharonText9)

- (BOOL)allowsDefaultTighteningForTruncation
{
    return tightening_of(self);
}

- (NSLineBreakStrategy)lineBreakStrategy
{
    return (NSLineBreakStrategy)strategy_of(self);
}

@end

@implementation NSMutableParagraphStyle (CharonText9)

- (void)setAllowsDefaultTighteningForTruncation:(BOOL)allows
{
    objc_setAssociatedObject(self, TighteningKey, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setLineBreakStrategy:(NSLineBreakStrategy)strategy
{
    objc_setAssociatedObject(self, StrategyKey, @(strategy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
