#import "CharonSCN.h"
#import "../CharonSRGB.h"
#import <objc/runtime.h>

// An archived NSColor carries its components in the color space it was authored in (sRGB,
// linear sRGB, Display P3, a gray profile), with that space's ICC profile alongside. UIColor on
// this platform has no color space, so the components are brought to sRGB here: through the
// profile's own matrix/TRC for an ICC-backed color, through the measured Generic Gray (gamma 1.8)
// for a calibrated white without one. Values are checked against macOS SceneKit's own
// -[NSColor usingColorSpace:NSColorSpace.sRGB] in facts/SceneKit/SceneKit.md.

static uint32_t CharonICCRead32(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | bytes[3];
}

static double CharonICCReadFixed(const uint8_t *bytes)
{
    return (int32_t)CharonICCRead32(bytes) / 65536.0;
}

static const uint8_t *CharonICCTag(NSData *profile, const char signature[4], uint32_t *length)
{
    const uint8_t *bytes = profile.bytes;
    NSUInteger size = profile.length;
    if (size < 132) {
        return NULL;
    }
    uint32_t count = CharonICCRead32(bytes + 128);
    for (uint32_t i = 0; i < count && 144 + 12 * (NSUInteger)i <= size; i++) {
        const uint8_t *entry = bytes + 132 + 12 * i;
        if (memcmp(entry, signature, 4) != 0) {
            continue;
        }
        uint32_t offset = CharonICCRead32(entry + 4);
        uint32_t tagLength = CharonICCRead32(entry + 8);
        if (tagLength < 12 || offset > size || tagLength > size - offset) {
            return NULL;
        }
        *length = tagLength;
        return bytes + offset;
    }
    return NULL;
}

static BOOL CharonICCEvaluateCurve(const uint8_t *tag, uint32_t length, double x, double *result)
{
    if (memcmp(tag, "curv", 4) == 0) {
        uint32_t count = CharonICCRead32(tag + 8);
        if (12 + 2 * (NSUInteger)count > length) {
            return NO;
        }
        if (count == 0) {
            *result = x;
        } else if (count == 1) {
            double gamma = ((tag[12] << 8) | tag[13]) / 256.0;
            *result = pow(fmax(x, 0), gamma);
        } else {
            double position = fmin(fmax(x, 0), 1) * (count - 1);
            uint32_t index = (uint32_t)position;
            if (index >= count - 1) {
                index = count - 2;
            }
            double fraction = position - index;
            double low = ((tag[12 + 2 * index] << 8) | tag[13 + 2 * index]) / 65535.0;
            double high = ((tag[14 + 2 * index] << 8) | tag[15 + 2 * index]) / 65535.0;
            *result = low + (high - low) * fraction;
        }
        return YES;
    }
    if (memcmp(tag, "para", 4) == 0) {
        static const int parameterCounts[] = {1, 3, 4, 5, 7};
        uint16_t function = (uint16_t)((tag[8] << 8) | tag[9]);
        if (function > 4 || 12 + 4 * (NSUInteger)parameterCounts[function] > length) {
            return NO;
        }
        double p[7] = {0};
        for (int i = 0; i < parameterCounts[function]; i++) {
            p[i] = CharonICCReadFixed(tag + 12 + 4 * i);
        }
        double g = p[0], a = p[1], b = p[2], c = p[3], d = p[4], e = p[5], f = p[6];
        switch (function) {
        case 0:
            *result = pow(fmax(x, 0), g);
            break;
        case 1:
            *result = x >= -b / a ? pow(a * x + b, g) : 0;
            break;
        case 2:
            *result = x >= -b / a ? pow(a * x + b, g) + c : c;
            break;
        case 3:
            *result = x >= d ? pow(a * x + b, g) : c * x;
            break;
        default:
            *result = x >= d ? pow(a * x + b, g) + e : c * x + f;
            break;
        }
        return YES;
    }
    return NO;
}

// The sRGB profile's D50-adapted colorants, as carried by the sRGB profiles in real .scn files.
static const double CharonSRGBColorants[3][3] = {
    {0.436065673828125, 0.3851470947265625, 0.14306640625},
    {0.2224884033203125, 0.7168731689453125, 0.06060791015625},
    {0.013916015625, 0.097076416015625, 0.7140960693359375},
};

static void CharonInvert3x3(const double m[3][3], double out[3][3])
{
    double det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
               - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
               + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
    out[0][0] = (m[1][1] * m[2][2] - m[1][2] * m[2][1]) / det;
    out[0][1] = (m[0][2] * m[2][1] - m[0][1] * m[2][2]) / det;
    out[0][2] = (m[0][1] * m[1][2] - m[0][2] * m[1][1]) / det;
    out[1][0] = (m[1][2] * m[2][0] - m[1][0] * m[2][2]) / det;
    out[1][1] = (m[0][0] * m[2][2] - m[0][2] * m[2][0]) / det;
    out[1][2] = (m[0][2] * m[1][0] - m[0][0] * m[1][2]) / det;
    out[2][0] = (m[1][0] * m[2][1] - m[1][1] * m[2][0]) / det;
    out[2][1] = (m[0][1] * m[2][0] - m[0][0] * m[2][1]) / det;
    out[2][2] = (m[0][0] * m[1][1] - m[0][1] * m[1][0]) / det;
}

// Converts `components` (color channels only, no alpha) through a matrix/TRC or gray ICC profile
// to sRGB. Anything else (LUT-based profiles, CMYK, Lab) is refused rather than approximated.
static BOOL CharonICCComponentsToSRGB(NSData *profile, const double *components, NSUInteger count, double rgb[3])
{
    if (profile.length < 132) {
        return NO;
    }
    const uint8_t *header = profile.bytes;
    uint32_t length = 0;
    if (memcmp(header + 16, "GRAY", 4) == 0 && count >= 1) {
        const uint8_t *curve = CharonICCTag(profile, "kTRC", &length);
        double luminance = 0;
        if (curve == NULL || !CharonICCEvaluateCurve(curve, length, components[0], &luminance)) {
            return NO;
        }
        rgb[0] = rgb[1] = rgb[2] = charon_srgb_encode(luminance);
        return YES;
    }
    if (memcmp(header + 16, "RGB ", 4) != 0 || memcmp(header + 20, "XYZ ", 4) != 0 || count < 3) {
        return NO;
    }
    static const char *colorantTags[3] = {"rXYZ", "gXYZ", "bXYZ"};
    static const char *curveTags[3] = {"rTRC", "gTRC", "bTRC"};
    double colorants[3][3];
    double linear[3];
    for (int channel = 0; channel < 3; channel++) {
        const uint8_t *colorant = CharonICCTag(profile, colorantTags[channel], &length);
        if (colorant == NULL || length < 20) {
            return NO;
        }
        for (int row = 0; row < 3; row++) {
            colorants[row][channel] = CharonICCReadFixed(colorant + 8 + 4 * row);
        }
        const uint8_t *curve = CharonICCTag(profile, curveTags[channel], &length);
        if (curve == NULL || !CharonICCEvaluateCurve(curve, length, components[channel], &linear[channel])) {
            return NO;
        }
    }
    double toSRGB[3][3];
    CharonInvert3x3(CharonSRGBColorants, toSRGB);
    double xyz[3];
    for (int row = 0; row < 3; row++) {
        xyz[row] = colorants[row][0] * linear[0] + colorants[row][1] * linear[1] + colorants[row][2] * linear[2];
    }
    for (int row = 0; row < 3; row++) {
        rgb[row] = charon_srgb_encode(toSRGB[row][0] * xyz[0] + toSRGB[row][1] * xyz[1] + toSRGB[row][2] * xyz[2]);
    }
    return YES;
}

static NSUInteger CharonParseComponents(NSCoder *coder, NSString *key, double *out, NSUInteger capacity)
{
    NSUInteger length = 0;
    const uint8_t *bytes = [coder containsValueForKey:key] ? [coder decodeBytesForKey:key returnedLength:&length] : NULL;
    if (bytes == NULL || length == 0) {
        return 0;
    }
    NSString *text = [[NSString alloc] initWithBytes:bytes length:strnlen((const char *)bytes, length) encoding:NSASCIIStringEncoding];
    NSUInteger count = 0;
    for (NSString *part in [text componentsSeparatedByString:@" "]) {
        if (part.length && count < capacity) {
            out[count++] = part.doubleValue;
        }
    }
    return count;
}

@interface CharonSCNArchivedColorSpace : NSObject <NSSecureCoding>
@property(nonatomic, copy) NSData *profile;
@end

@implementation CharonSCNArchivedColorSpace

@synthesize profile = _profile;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _profile = [coder decodeObjectOfClass:[NSData class] forKey:@"NSICC"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_profile forKey:@"NSICC"];
}

@end

@interface CharonSCNArchivedColor : NSObject <NSSecureCoding>
@property(nonatomic) CGFloat red, green, blue, alpha;
@property(nonatomic) BOOL valid;
@property(nonatomic, copy) NSString *failure;
@end

@implementation CharonSCNArchivedColor

@synthesize red = _red;
@synthesize green = _green;
@synthesize blue = _blue;
@synthesize alpha = _alpha;
@synthesize valid = _valid;
@synthesize failure = _failure;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)setRGB:(const double *)rgb alpha:(double)alpha
{
    _red = rgb[0];
    _green = rgb[1];
    _blue = rgb[2];
    _alpha = fmin(fmax(alpha, 0), 1);
    _valid = YES;
}

// NSColorSpace: 1 calibrated RGB, 2 device RGB, 3 calibrated white, 4 device white; a
// NSCustomColorSpace, when present, names the space NSComponents are expressed in.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSInteger model = [coder containsValueForKey:@"NSColorSpace"] ? [coder decodeIntegerForKey:@"NSColorSpace"] : 0;
        CharonSCNArchivedColorSpace *space = [coder decodeObjectOfClass:[CharonSCNArchivedColorSpace class] forKey:@"NSCustomColorSpace"];
        double components[5];
        double rgb[3];
        NSUInteger count = CharonParseComponents(coder, @"NSComponents", components, 5);
        if (space.profile && count >= 2) {
            NSUInteger channels = count - 1;
            if (CharonICCComponentsToSRGB(space.profile, components, channels, rgb)) {
                [self setRGB:rgb alpha:components[count - 1]];
            } else {
                _failure = [NSString stringWithFormat:@"its ICC profile (%lu bytes) does not convert %lu components to sRGB",
                                                      (unsigned long)space.profile.length, (unsigned long)channels];
            }
            return self;
        }
        if (model == 1 || model == 2) {
            count = CharonParseComponents(coder, @"NSRGB", components, 4);
            // Calibrated RGB without a profile is Generic RGB, which no measured archive uses.
            if (model == 2 && count >= 3) {
                rgb[0] = components[0];
                rgb[1] = components[1];
                rgb[2] = components[2];
                [self setRGB:rgb alpha:count > 3 ? components[3] : 1];
            } else if (model == 1) {
                _failure = @"it is calibrated RGB without a profile (Generic RGB), which this port does not convert";
            } else {
                _failure = [NSString stringWithFormat:@"its NSRGB holds %lu components", (unsigned long)count];
            }
        } else if (model == 3 || model == 4) {
            count = CharonParseComponents(coder, @"NSWhite", components, 2);
            if (count >= 1) {
                double white = model == 3 ? charon_srgb_encode(pow(fmax(components[0], 0), 1.8)) : components[0];
                rgb[0] = rgb[1] = rgb[2] = white;
                [self setRGB:rgb alpha:count > 1 ? components[1] : 1];
            } else {
                _failure = @"its NSWhite holds no component";
            }
        } else {
            _failure = [NSString stringWithFormat:@"its colour space model %ld (catalog, pattern or other) is not read by this port", (long)model];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSString *rgb = [NSString stringWithFormat:@"%g %g %g %g", (double)_red, (double)_green, (double)_blue, (double)_alpha];
    [coder encodeInteger:2 forKey:@"NSColorSpace"];
    [coder encodeBytes:(const uint8_t *)rgb.UTF8String length:strlen(rgb.UTF8String) + 1 forKey:@"NSRGB"];
}

- (UIColor *)toUIColor
{
    return _valid ? [UIColor colorWithRed:_red green:_green blue:_blue alpha:_alpha] : nil;
}

@end

// SCNKeyedArchiver writes NSMutableData under `NS.bytes`; current Foundation writes `NS.data`.
// Measured on 6.1.3: a plain NSKeyedUnarchiver hands the `NS.bytes` form back empty, so every
// nested color came out as an empty payload. This reads either key itself and stays a real
// NSMutableData for whatever else decodes one.
@interface CharonSCNArchivedData : NSMutableData
@end

@implementation CharonSCNArchivedData
{
    NSMutableData *_storage;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSUInteger length = 0;
        const uint8_t *bytes = NULL;
        if ([coder containsValueForKey:@"NS.bytes"]) {
            bytes = [coder decodeBytesForKey:@"NS.bytes" returnedLength:&length];
        } else if ([coder containsValueForKey:@"NS.data"]) {
            bytes = [coder decodeBytesForKey:@"NS.data" returnedLength:&length];
        }
        _storage = bytes ? [NSMutableData dataWithBytes:bytes length:length] : [NSMutableData data];
    }
    return self;
}

- (NSUInteger)length
{
    return _storage.length;
}

- (const void *)bytes
{
    return _storage.bytes;
}

- (void *)mutableBytes
{
    return _storage.mutableBytes;
}

- (void)setLength:(NSUInteger)length
{
    _storage.length = length;
}

@end

static void CharonSCNMapColorClasses(NSKeyedUnarchiver *unarchiver)
{
    [unarchiver setClass:[CharonSCNArchivedColor class] forClassName:@"NSColor"];
    [unarchiver setClass:[CharonSCNArchivedColorSpace class] forClassName:@"NSColorSpace"];
    [unarchiver setClass:[CharonSCNArchivedData class] forClassName:@"NSMutableData"];
}

@implementation CharonSCNCoding

+ (SCNVector3)decodeVector3:(NSCoder *)coder forKey:(NSString *)key
{
    NSUInteger length = 0;
    const uint8_t *bytes = [coder decodeBytesForKey:key returnedLength:&length];
    if (bytes == NULL || length != sizeof(SCNVector3)) {
        return SCNVector3Make(0, 0, 0);
    }
    SCNVector3 vector;
    memcpy(&vector, bytes, sizeof(SCNVector3));
    return vector;
}

+ (void)encodeVector3:(SCNVector3)vector coder:(NSCoder *)coder forKey:(NSString *)key
{
    [coder encodeBytes:(const uint8_t *)&vector length:sizeof(SCNVector3) forKey:key];
}

+ (SCNVector4)decodeVector4:(NSCoder *)coder forKey:(NSString *)key
{
    NSUInteger length = 0;
    const uint8_t *bytes = [coder decodeBytesForKey:key returnedLength:&length];
    if (bytes == NULL || length != sizeof(SCNVector4)) {
        return SCNVector4Make(0, 0, 0, 1);
    }
    SCNVector4 vector;
    memcpy(&vector, bytes, sizeof(SCNVector4));
    return vector;
}

+ (void)encodeVector4:(SCNVector4)vector coder:(NSCoder *)coder forKey:(NSString *)key
{
    [coder encodeBytes:(const uint8_t *)&vector length:sizeof(SCNVector4) forKey:key];
}

// SCNMatrix4 is archived the same way as the vectors: its sixteen floats m11..m44 as raw bytes (star2.scn's
// contentsTransform keys, 64 bytes each).
+ (SCNMatrix4)decodeMatrix4:(NSCoder *)coder forKey:(NSString *)key
{
    NSUInteger length = 0;
    const uint8_t *bytes = [coder decodeBytesForKey:key returnedLength:&length];
    if (bytes == NULL || length != sizeof(SCNMatrix4)) {
        return SCNMatrix4Identity;
    }
    SCNMatrix4 matrix;
    memcpy(&matrix, bytes, sizeof(SCNMatrix4));
    return matrix;
}

+ (void)encodeMatrix4:(SCNMatrix4)matrix coder:(NSCoder *)coder forKey:(NSString *)key
{
    [coder encodeBytes:(const uint8_t *)&matrix length:sizeof(SCNMatrix4) forKey:key];
}

+ (NSArray *)decodeArrayOfClass:(Class)cls coder:(NSCoder *)coder forKey:(NSString *)key
{
    id decoded = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], cls, nil] forKey:key];
    if (decoded == nil) {
        return @[];
    }
    if ([decoded isKindOfClass:cls]) {
        return @[decoded];
    }
    // Only a secure decode holds the value to the two classes asked for; an application's own plain unarchiver
    // hands back whatever the archive holds.
    if (![decoded isKindOfClass:[NSArray class]]) {
        NSLog(@"SceneKit: the archive's %@ holds a %@ where a %@ or an array of them belongs; it is left out", key, [decoded class], cls);
        return @[];
    }
    NSMutableArray *objects = [NSMutableArray array];
    for (id object in (NSArray *)decoded) {
        if ([object isKindOfClass:cls]) {
            [objects addObject:object];
        } else {
            NSLog(@"SceneKit: the archive's %@ holds a %@ where a %@ belongs; it is left out", key, [object class], cls);
        }
    }
    return objects;
}

// A colour the archive holds and this port cannot read leaves the property at its default; it is said, with the key
// and the reason, so that a scene drawn in the wrong colour is not silent.
static void CharonSCNColorFailed(NSString *key, NSString *reason)
{
    NSLog(@"SceneKit: the colour under %@ is not read, and the property keeps its default: %@", key, reason);
}

static UIColor *CharonSCNArchivedColorValue(CharonSCNArchivedColor *color, NSString *key)
{
    if (!color.valid) {
        CharonSCNColorFailed(key, color.failure ?: @"it holds no components this port reads");
        return nil;
    }
    return [color toUIColor];
}

// Three shapes reach here: an NSColor object directly in the graph (material property
// `color`), an NSData holding a separate keyed archive of one (SCNLight/SCNParticleSystem), or a
// UIColor from an iOS-authored archive. NSColor/NSColorSpace are mapped on whichever unarchiver
// holds them before the decode, so secure coding never meets a class this platform lacks.
+ (UIColor *)decodeColor:(NSCoder *)coder forKey:(NSString *)key
{
    if (![coder containsValueForKey:key]) {
        return nil;
    }
    if ([coder isKindOfClass:[NSKeyedUnarchiver class]]) {
        CharonSCNMapColorClasses((NSKeyedUnarchiver *)coder);
    }
    id decoded = nil;
    @try {
        decoded = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSData class], [UIColor class], [CharonSCNArchivedColor class], nil] forKey:key];
    } @catch (NSException *exception) {
        CharonSCNColorFailed(key, [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
        return nil;
    }
    if ([decoded isKindOfClass:[CharonSCNArchivedColor class]]) {
        return CharonSCNArchivedColorValue(decoded, key);
    }
    if ([decoded isKindOfClass:[UIColor class]]) {
        return decoded;
    }
    NSData *nested = decoded;
    if (decoded == nil) {
        CharonSCNColorFailed(key, @"it holds nothing");
        return nil;
    }
    if (![nested isKindOfClass:[NSData class]]) {
        // only a decode without secure coding hands back an object of another class
        CharonSCNColorFailed(key, [NSString stringWithFormat:@"it holds a %@ where a colour belongs", [decoded class]]);
        return nil;
    }
    if (nested.length == 0) {
        CharonSCNColorFailed(key, @"it holds an empty NSData");
        return nil;
    }
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:nested];
    unarchiver.requiresSecureCoding = YES;
    CharonSCNMapColorClasses(unarchiver);
    id archived = nil;
    @try {
        archived = [unarchiver decodeObjectOfClasses:[NSSet setWithObjects:[CharonSCNArchivedColor class], [UIColor class], nil] forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
        CharonSCNColorFailed(key, [NSString stringWithFormat:@"its nested archive: %@: %@", exception.name, exception.reason]);
        return nil;
    }
    [unarchiver finishDecoding];
    if ([archived isKindOfClass:[CharonSCNArchivedColor class]]) {
        return CharonSCNArchivedColorValue(archived, key);
    }
    if (![archived isKindOfClass:[UIColor class]]) {
        CharonSCNColorFailed(key, @"its nested archive holds no colour");
        return nil;
    }
    return archived;
}

+ (UIColor *)colorWithLinearWhite:(double)white
{
    double encoded = charon_srgb_encode(white);
    return [UIColor colorWithRed:encoded green:encoded blue:encoded alpha:1];
}

+ (BOOL)decodeBool:(NSCoder *)coder forKey:(NSString *)key default:(BOOL)fallback
{
    if (![coder containsValueForKey:key]) {
        return fallback;
    }
    // An archive stores a flag either as a boolean or as an integer (facts: castsShadow is 0, hidden is false, in one
    // file), each decode raises on the other, and NSKeyedUnarchiver answers no question about a value's type.
    @try {
        return [coder decodeBoolForKey:key];
    } @catch (NSException *exception) {
        @try {
            return [coder decodeIntegerForKey:key] != 0;
        } @catch (NSException *stillNotAnInteger) {
            NSLog(@"SceneKit: the flag under %@ is neither a boolean nor an integer, and keeps its default %@: %@: %@", key,
                  fallback ? @"YES" : @"NO", stillNotAnInteger.name, stillNotAnInteger.reason);
            return fallback;
        }
    }
}

+ (NSString *)decodeFileReferenceName:(NSCoder *)coder forKey:(NSString *)key
{
    if (![coder containsValueForKey:key]) {
        return nil;
    }
    id decoded = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], nil] forKey:key];
    NSString *path = nil;
    if ([decoded isKindOfClass:[NSDictionary class]]) {
        path = [(NSDictionary *)decoded objectForKey:@"path"];
    } else if ([decoded isKindOfClass:[NSString class]]) {
        path = decoded;
    }
    return path.length ? path : nil;
}

static NSMutableArray *CharonSCNSourceURLStack(void)
{
    static NSMutableArray<NSURL *> *stack;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stack = [NSMutableArray array];
    });
    return stack;
}

+ (void)pushSourceURL:(NSURL *)url
{
    [CharonSCNSourceURLStack() addObject:url ?: [NSNull null]];
}

+ (void)popSourceURL
{
    NSMutableArray *stack = CharonSCNSourceURLStack();
    if (stack.count) {
        [stack removeLastObject];
    }
}

+ (NSURL *)currentSourceURL
{
    id last = CharonSCNSourceURLStack().lastObject;
    return [last isKindOfClass:[NSURL class]] ? last : nil;
}

static const void *CharonSCNProvenanceKey = &CharonSCNProvenanceKey;

+ (void)markFound:(BOOL)found forKey:(NSString *)key onObject:(id)object
{
    if (object == nil) {
        return;
    }
    NSMutableDictionary<NSString *, NSNumber *> *provenance = objc_getAssociatedObject(object, CharonSCNProvenanceKey);
    if (!provenance) {
        provenance = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(object, CharonSCNProvenanceKey, provenance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    provenance[key] = @(found);
}

+ (BOOL)wasFound:(NSString *)key onObject:(id)object
{
    NSMutableDictionary<NSString *, NSNumber *> *provenance = objc_getAssociatedObject(object, CharonSCNProvenanceKey);
    return provenance[key].boolValue;
}

@end
