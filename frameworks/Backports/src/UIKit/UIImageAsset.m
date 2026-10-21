#import <UIKit/UIKit.h>
#import <UIKit/UIImageConfiguration.h>
#import "RevenantImageAsset.h"

typedef struct {
    CGFloat scale;
    NSInteger idiom;
    NSInteger style;
    NSInteger direction;
} RevenantImageVariantTraits;

static RevenantImageVariantTraits revenant_traitsOf(id key)
{
    RevenantImageVariantTraits traits = { 0, UIUserInterfaceIdiomUnspecified, UIUserInterfaceStyleUnspecified,
        UITraitEnvironmentLayoutDirectionUnspecified };
    if ([key isKindOfClass:[UITraitCollection class]]) {
        UITraitCollection *collection = key;
        traits.scale = collection.displayScale;
        traits.idiom = collection.userInterfaceIdiom;
        traits.style = collection.userInterfaceStyle;
        traits.direction = collection.layoutDirection;
    }
    return traits;
}

static BOOL revenant_sameRendition(RevenantImageVariantTraits a, RevenantImageVariantTraits b)
{
    return (a.scale > 0 ? a.scale : 1) == (b.scale > 0 ? b.scale : 1) && a.idiom == b.idiom && a.style == b.style
        && a.direction == b.direction;
}

typedef struct {
    BOOL style;
    BOOL idiom;
    CGFloat scale;
    BOOL direction;
} RevenantImageVariantRank;

static BOOL revenant_ranksAtLeast(RevenantImageVariantRank a, RevenantImageVariantRank b)
{
    if (a.style != b.style)
        return a.style;
    if (a.idiom != b.idiom)
        return a.idiom;
    if (a.scale != b.scale)
        return a.scale > b.scale;
    return a.direction || !b.direction;
}

@implementation UIImageAsset {
    NSMutableArray *_keys;
    NSMutableArray *_images;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _keys = [[NSMutableArray alloc] init];
        _images = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSArray *keys = [coder decodeObjectForKey:@"UIImageAssetKeys"];
        NSArray *images = [coder decodeObjectForKey:@"UIImageAssetImages"];
        _keys = [keys mutableCopy] ?: [[NSMutableArray alloc] init];
        _images = [images mutableCopy] ?: [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_keys forKey:@"UIImageAssetKeys"];
    [coder encodeObject:_images forKey:@"UIImageAssetImages"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)revenant_registerImage:(UIImage *)image forKey:(id)key
{
    if (!image)
        return;
    revenant_image_set_asset(image, self);
    NSUInteger index = [_keys indexOfObject:key];
    if (index != NSNotFound) {
        _images[index] = image;
        return;
    }
    [_keys addObject:key];
    [_images addObject:image];
}

- (void)revenant_unregisterKey:(id)key
{
    if (!key)
        return;
    RevenantImageVariantTraits named = revenant_traitsOf(key);
    for (NSUInteger index = _keys.count; index-- > 0;) {
        if (revenant_sameRendition(named, revenant_traitsOf(_keys[index]))) {
            [_keys removeObjectAtIndex:index];
            [_images removeObjectAtIndex:index];
        }
    }
}

- (UIImage *)revenant_imageForKey:(id)key
{
    RevenantImageVariantTraits want = revenant_traitsOf(key);
    if (want.scale <= 0)
        want.scale = [UIScreen mainScreen].scale;
    if (want.idiom == UIUserInterfaceIdiomUnspecified)
        want.idiom = [UIDevice currentDevice].userInterfaceIdiom;
    if (want.style == UIUserInterfaceStyleUnspecified)
        want.style = UIUserInterfaceStyleLight;

    NSUInteger best = NSNotFound;
    RevenantImageVariantRank bestRank = { NO, NO, 0, NO };
    for (NSUInteger index = 0; index < _keys.count; index++) {
        RevenantImageVariantTraits have = revenant_traitsOf(_keys[index]);
        if (have.idiom != UIUserInterfaceIdiomUnspecified && have.idiom != want.idiom)
            continue;
        if (have.style != UIUserInterfaceStyleUnspecified && have.style != want.style)
            continue;
        CGFloat scale = have.scale > 0 ? have.scale : 1;
        RevenantImageVariantRank rank = {
            have.style != UIUserInterfaceStyleUnspecified,
            have.idiom != UIUserInterfaceIdiomUnspecified,
            want.scale > 0 && scale == want.scale ? CGFLOAT_MAX : scale,
            have.direction != UITraitEnvironmentLayoutDirectionUnspecified,
        };
        if (best == NSNotFound || revenant_ranksAtLeast(rank, bestRank)) {
            best = index;
            bestRank = rank;
        }
    }
    if (best == NSNotFound)
        return nil;

    UIImage *image = _images[best];
    RevenantImageVariantTraits matched = revenant_traitsOf(_keys[best]);
    CGFloat scale = matched.scale > 0 ? matched.scale : image.scale;
    UIImage *variant = [UIImage imageWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
    revenant_image_set_asset(variant, self);
    return variant;
}

- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)configuration
{
    return [self revenant_imageForKey:configuration];
}

- (void)registerImage:(UIImage *)image withConfiguration:(UIImageConfiguration *)configuration
{
    if (!configuration)
        [NSException raise:NSInternalInconsistencyException format:@"scale must be > 0"];
    [self revenant_registerImage:image forKey:configuration];
}

- (void)unregisterImageWithConfiguration:(UIImageConfiguration *)configuration
{
    [self revenant_unregisterKey:configuration];
}

- (UIImage *)imageWithTraitCollection:(UITraitCollection *)traitCollection
{
    return [self revenant_imageForKey:traitCollection];
}

- (void)registerImage:(UIImage *)image withTraitCollection:(UITraitCollection *)traitCollection
{
    if (!traitCollection)
        [NSException raise:NSInternalInconsistencyException format:@"scale must be > 0"];
    CGFloat scale = traitCollection.displayScale;
    if (scale < 0)
        [NSException raise:NSInternalInconsistencyException
                    format:@"scale %u in rendition key does not match with scale %f passed in the image description",
                           (unsigned)(uint16_t)(int)scale, scale];
    [self revenant_registerImage:image forKey:traitCollection];
}

- (void)unregisterImageWithTraitCollection:(UITraitCollection *)traitCollection
{
    [self revenant_unregisterKey:traitCollection];
}

@end
