#import <UIKit/UIKit.h>
#import <UIKit/UIImageConfiguration.h>

// An image asset is a set of images, each registered for a trait collection or a configuration, that the
// asset hands back for whichever variant fits. iOS 6 has no asset catalogue to draw one from, so the asset
// keeps its variants itself, in the order they were registered, and answers a lookup by the rule in
// facts/UIKit/UIImageAsset.md, which the host's own answers were measured to. The release never reads an
// asset on its own, so this store is only ever asked by the application that made it.

// The traits one key names: a trait collection names its scale, idiom, style and layout direction, and a
// configuration names none. A key that names no scale has scale 0.
typedef struct {
    CGFloat scale;
    NSInteger idiom;
    NSInteger style;
    NSInteger direction;
} CharonImageVariantTraits;

static CharonImageVariantTraits charon_traitsOf(id key)
{
    CharonImageVariantTraits traits = { 0, UIUserInterfaceIdiomUnspecified, UIUserInterfaceStyleUnspecified,
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

// Two keys name the same rendition when their traits are equal, a key that names no scale being held at scale 1.
// Measured on the host: an unregister removes every variant of the rendition it names, and a configuration is held
// at scale 1 (see -charon_unregisterKey:).
static BOOL charon_sameRendition(CharonImageVariantTraits a, CharonImageVariantTraits b)
{
    return (a.scale > 0 ? a.scale : 1) == (b.scale > 0 ? b.scale : 1) && a.idiom == b.idiom && a.style == b.style
        && a.direction == b.direction;
}

// How well a variant fits a lookup, in the order the host ranks them: a named style, a named idiom, the scale
// (an exact match beats any other, and of the rest the highest wins), then a named layout direction.
typedef struct {
    BOOL style;
    BOOL idiom;
    CGFloat scale;
    BOOL direction;
} CharonImageVariantRank;

// Whether a ranks at least as well as b. Ties go to the later registration, so the caller passes <= in order.
static BOOL charon_ranksAtLeast(CharonImageVariantRank a, CharonImageVariantRank b)
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

// A nil image is not added: measured on the host for a trait collection, where the register call answers nothing.
- (void)charon_registerImage:(UIImage *)image forKey:(id)key
{
    if (!image)
        return;
    NSUInteger index = [_keys indexOfObject:key];
    if (index != NSNotFound) {
        _images[index] = image;
        return;
    }
    [_keys addObject:key];
    [_images addObject:image];
}

// Measured on the host: an unregister names a rendition by its traits, and removes every variant of that rendition.
// A nil key names none, so it removes nothing.
- (void)charon_unregisterKey:(id)key
{
    if (!key)
        return;
    CharonImageVariantTraits named = charon_traitsOf(key);
    for (NSUInteger index = _keys.count; index-- > 0;) {
        if (charon_sameRendition(named, charon_traitsOf(_keys[index]))) {
            [_keys removeObjectAtIndex:index];
            [_images removeObjectAtIndex:index];
        }
    }
}

// The variant that fits the lookup best, copied at the scale of the key it was registered for: measured on the host,
// where a lookup answers a copy and never the registered object. A lookup reads what it does not name as the current
// environment: the display scale and idiom of the running device, and light style (a nil lookup and a configuration
// name none of them; on the Catalyst host the current values are scale 2 and pad). A variant whose idiom or style the
// lookup does not name in the same way does not fit at all. Nothing fits, nil.
- (UIImage *)charon_imageForKey:(id)key
{
    CharonImageVariantTraits want = charon_traitsOf(key);
    if (want.scale <= 0)
        want.scale = [UIScreen mainScreen].scale;
    if (want.idiom == UIUserInterfaceIdiomUnspecified)
        want.idiom = [UIDevice currentDevice].userInterfaceIdiom;
    // 6.1.3 has no dark appearance, so light is the current style there; the 26.2 host answers light in its light
    // environment too (measured).
    if (want.style == UIUserInterfaceStyleUnspecified)
        want.style = UIUserInterfaceStyleLight;

    NSUInteger best = NSNotFound;
    CharonImageVariantRank bestRank = { NO, NO, 0, NO };
    for (NSUInteger index = 0; index < _keys.count; index++) {
        CharonImageVariantTraits have = charon_traitsOf(_keys[index]);
        if (have.idiom != UIUserInterfaceIdiomUnspecified && have.idiom != want.idiom)
            continue;
        if (have.style != UIUserInterfaceStyleUnspecified && have.style != want.style)
            continue;
        CGFloat scale = have.scale > 0 ? have.scale : 1;
        CharonImageVariantRank rank = {
            have.style != UIUserInterfaceStyleUnspecified,
            have.idiom != UIUserInterfaceIdiomUnspecified,
            want.scale > 0 && scale == want.scale ? CGFLOAT_MAX : scale,
            have.direction != UITraitEnvironmentLayoutDirectionUnspecified,
        };
        if (best == NSNotFound || charon_ranksAtLeast(rank, bestRank)) {
            best = index;
            bestRank = rank;
        }
    }
    if (best == NSNotFound)
        return nil;

    UIImage *image = _images[best];
    CharonImageVariantTraits matched = charon_traitsOf(_keys[best]);
    CGFloat scale = matched.scale > 0 ? matched.scale : image.scale;
    return [UIImage imageWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
}

- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)configuration
{
    return [self charon_imageForKey:configuration];
}

// Measured on the host: a nil configuration raises the same exception as a nil trait collection.
- (void)registerImage:(UIImage *)image withConfiguration:(UIImageConfiguration *)configuration
{
    if (!configuration)
        [NSException raise:NSInternalInconsistencyException format:@"scale must be > 0"];
    [self charon_registerImage:image forKey:configuration];
}

- (void)unregisterImageWithConfiguration:(UIImageConfiguration *)configuration
{
    [self charon_unregisterKey:configuration];
}

- (UIImage *)imageWithTraitCollection:(UITraitCollection *)traitCollection
{
    return [self charon_imageForKey:traitCollection];
}

// Measured on the host: a nil collection raises "scale must be > 0". A negative scale raises another exception, which
// names the scale as an unsigned 16-bit value: -1 reads as 65535 (only -1 is measured). A scale of 0, and a
// collection that names no scale, register without an error.
- (void)registerImage:(UIImage *)image withTraitCollection:(UITraitCollection *)traitCollection
{
    if (!traitCollection)
        [NSException raise:NSInternalInconsistencyException format:@"scale must be > 0"];
    CGFloat scale = traitCollection.displayScale;
    if (scale < 0)
        [NSException raise:NSInternalInconsistencyException
                    format:@"scale %u in rendition key does not match with scale %f passed in the image description",
                           (unsigned)(uint16_t)(int)scale, scale];
    [self charon_registerImage:image forKey:traitCollection];
}

- (void)unregisterImageWithTraitCollection:(UITraitCollection *)traitCollection
{
    [self charon_unregisterKey:traitCollection];
}

@end
