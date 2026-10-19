#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_invalidating_key;
static void (*charon_layout_original)(id, SEL);
static void (*charon_flow_original)(id, SEL);

@interface CharonLayoutInvalidation : NSObject
@end

@implementation CharonLayoutInvalidation

+ (void)load
{
    if ([UICollectionViewLayout instancesRespondToSelector:@selector(invalidateLayoutWithContext:)])
        return;
    for (Class layout in @[[UICollectionViewLayout class], [UICollectionViewFlowLayout class]]) {
        unsigned count = 0;
        Method *methods = class_copyMethodList(layout, &count);
        Method own = NULL;
        for (unsigned index = 0; index < count && !own; index++)
            if (method_getName(methods[index]) == @selector(invalidateLayout))
                own = methods[index];
        free(methods);
        if (!own)
            continue;
        void (*original)(id, SEL) = (void (*)(id, SEL))method_getImplementation(own);
        if (layout == [UICollectionViewFlowLayout class])
            charon_flow_original = original;
        else
            charon_layout_original = original;
        method_setImplementation(own, imp_implementationWithBlock(^(UICollectionViewLayout *self_) {
            if (objc_getAssociatedObject(self_, &charon_invalidating_key)) {
                original(self_, @selector(invalidateLayout));
                return;
            }
            [self_ invalidateLayoutWithContext:[[[[self_ class] invalidationContextClass] alloc] init]];
        }));
    }
}

@end

@implementation UICollectionViewLayout (CharonInvalidation7)

+ (Class)invalidationContextClass
{
    return [UICollectionViewLayoutInvalidationContext class];
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    objc_setAssociatedObject(self, &charon_invalidating_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    void (*original)(id, SEL) = ([self isKindOfClass:[UICollectionViewFlowLayout class]] && charon_flow_original) ? charon_flow_original : charon_layout_original;
    original(self, @selector(invalidateLayout));
    objc_setAssociatedObject(self, &charon_invalidating_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds
{
    return [[[[self class] invalidationContextClass] alloc] init];
}

@end

@implementation UICollectionViewFlowLayout (CharonInvalidation7)

+ (Class)invalidationContextClass
{
    return [UICollectionViewFlowLayoutInvalidationContext class];
}

@end
