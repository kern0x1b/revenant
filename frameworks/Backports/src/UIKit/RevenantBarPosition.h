#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static inline UIBarPosition revenant_bar_position(id bar, UIBarPosition fallback)
{
    id delegate = [bar respondsToSelector:@selector(delegate)] ? [bar delegate] : nil;
    return [delegate respondsToSelector:@selector(positionForBar:)] ? [delegate positionForBar:bar] : fallback;
}

static inline NSNumber *revenant_position_key(UIBarPosition position, UIBarMetrics metrics)
{
    return @(position * 16 + metrics);
}

static inline UIImage *revenant_stored_background(id owner, const void *key, UIBarPosition position, UIBarMetrics metrics)
{
    return [objc_getAssociatedObject(owner, key) objectForKey:revenant_position_key(position, metrics)];
}

static inline UIImage *revenant_effective_background(id owner, const void *key, UIBarPosition position, UIBarMetrics metrics)
{
    return revenant_stored_background(owner, key, position, metrics) ?: revenant_stored_background(owner, key, UIBarPositionAny, metrics);
}

static inline void revenant_store_background(id owner, const void *key, UIImage *image, UIBarPosition position, UIBarMetrics metrics)
{
    NSMutableDictionary *images = objc_getAssociatedObject(owner, key);
    if (!images && image) {
        images = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(owner, key, images, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (image)
        images[revenant_position_key(position, metrics)] = image;
    else
        [images removeObjectForKey:revenant_position_key(position, metrics)];
}
