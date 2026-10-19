#import "RevenantSCN.h"
#import "../RevenantSRGB.h"
#import <objc/runtime.h>

static uint32_t RevenantICCRead32(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | bytes[3];
}

static double RevenantICCReadFixed(const uint8_t *bytes)
{
    return (int32_t)RevenantICCRead32(bytes) / 65536.0;
}

static const uint8_t *RevenantICCTag(NSData *profile, const char signature[4], uint32_t *length)
{
    const uint8_t *bytes = profile.bytes;
    NSUInteger size = profile.length;
    if (size < 132) {
        return NULL;
    }
    uint32_t count = RevenantICCRead32(bytes + 128);
    for (uint32_t i = 0; i < count && 144 + 12 * (NSUInteger)i <= size; i++) {
        const uint8_t *entry = bytes + 132 + 12 * i;
        if (memcmp(entry, signature, 4) != 0) {
            continue;
        }
        uint32_t offset = RevenantICCRead32(entry + 4);
        uint32_t tagLength = RevenantICCRead32(entry + 8);
        if (tagLength < 12 || offset > size || tagLength > size - offset) {
            return NULL;
        }
        *length = tagLength;
        return bytes + offset;
    }
    return NULL;
}

static BOOL RevenantICCEvaluateCurve(const uint8_t *tag, uint32_t length, double x, double *result)
{
    if (memcmp(tag, "curv", 4) == 0) {
        uint32_t count = RevenantICCRead32(tag + 8);
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
            p[i] = RevenantICCReadFixed(tag + 12 + 4 * i);
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

static const double RevenantSRGBColorants[3][3] = {
    {0.436065673828125, 0.3851470947265625, 0.14306640625},
    {0.2224884033203125, 0.7168731689453125, 0.06060791015625},
    {0.013916015625, 0.097076416015625, 0.7140960693359375},
};

static void RevenantInvert3x3(const double m[3][3], double out[3][3])
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

static BOOL RevenantICCComponentsToSRGB(NSData *profile, const double *components, NSUInteger count, double rgb[3])
{
    if (profile.length < 132) {
        return NO;
    }
    const uint8_t *header = profile.bytes;
    uint32_t length = 0;
    if (memcmp(header + 16, "GRAY", 4) == 0 && count >= 1) {
        const uint8_t *curve = RevenantICCTag(profile, "kTRC", &length);
        double luminance = 0;
        if (curve == NULL || !RevenantICCEvaluateCurve(curve, length, components[0], &luminance)) {
            return NO;
        }
        rgb[0] = rgb[1] = rgb[2] = revenant_srgb_encode(luminance);
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
        const uint8_t *colorant = RevenantICCTag(profile, colorantTags[channel], &length);
        if (colorant == NULL || length < 20) {
            return NO;
        }
        for (int row = 0; row < 3; row++) {
            colorants[row][channel] = RevenantICCReadFixed(colorant + 8 + 4 * row);
        }
        const uint8_t *curve = RevenantICCTag(profile, curveTags[channel], &length);
        if (curve == NULL || !RevenantICCEvaluateCurve(curve, length, components[channel], &linear[channel])) {
            return NO;
        }
    }
    double toSRGB[3][3];
    RevenantInvert3x3(RevenantSRGBColorants, toSRGB);
    double xyz[3];
    for (int row = 0; row < 3; row++) {
        xyz[row] = colorants[row][0] * linear[0] + colorants[row][1] * linear[1] + colorants[row][2] * linear[2];
    }
    for (int row = 0; row < 3; row++) {
        rgb[row] = revenant_srgb_encode(toSRGB[row][0] * xyz[0] + toSRGB[row][1] * xyz[1] + toSRGB[row][2] * xyz[2]);
    }
    return YES;
}

static NSUInteger RevenantParseComponents(NSCoder *coder, NSString *key, double *out, NSUInteger capacity)
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

@interface RevenantSCNArchivedColorSpace : NSObject <NSSecureCoding>
@property(nonatomic, copy) NSData *profile;
@end

@implementation RevenantSCNArchivedColorSpace

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

@interface RevenantSCNArchivedColor : NSObject <NSSecureCoding>
@property(nonatomic) CGFloat red, green, blue, alpha;
@property(nonatomic) BOOL valid;
@property(nonatomic, copy) NSString *failure;
@end

@implementation RevenantSCNArchivedColor

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

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSInteger model = [coder containsValueForKey:@"NSColorSpace"] ? [coder decodeIntegerForKey:@"NSColorSpace"] : 0;
        RevenantSCNArchivedColorSpace *space = [coder decodeObjectOfClass:[RevenantSCNArchivedColorSpace class] forKey:@"NSCustomColorSpace"];
        double components[5];
        double rgb[3];
        NSUInteger count = RevenantParseComponents(coder, @"NSComponents", components, 5);
        if (space.profile && count >= 2) {
            NSUInteger channels = count - 1;
            if (RevenantICCComponentsToSRGB(space.profile, components, channels, rgb)) {
                [self setRGB:rgb alpha:components[count - 1]];
            } else {
                _failure = [NSString stringWithFormat:@"its ICC profile (%lu bytes) does not convert %lu components to sRGB",
                                                      (unsigned long)space.profile.length, (unsigned long)channels];
            }
            return self;
        }
        if (model == 1 || model == 2) {
            count = RevenantParseComponents(coder, @"NSRGB", components, 4);
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
            count = RevenantParseComponents(coder, @"NSWhite", components, 2);
            if (count >= 1) {
                double white = model == 3 ? revenant_srgb_encode(pow(fmax(components[0], 0), 1.8)) : components[0];
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

@interface RevenantSCNArchivedData : NSMutableData
@end

@implementation RevenantSCNArchivedData
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

static void RevenantSCNMapColorClasses(NSKeyedUnarchiver *unarchiver)
{
    [unarchiver setClass:[RevenantSCNArchivedColor class] forClassName:@"NSColor"];
    [unarchiver setClass:[RevenantSCNArchivedColorSpace class] forClassName:@"NSColorSpace"];
    [unarchiver setClass:[RevenantSCNArchivedData class] forClassName:@"NSMutableData"];
}

@implementation RevenantSCNCoding

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

static void RevenantSCNColorFailed(NSString *key, NSString *reason)
{
    NSLog(@"SceneKit: the colour under %@ is not read, and the property keeps its default: %@", key, reason);
}

static UIColor *RevenantSCNArchivedColorValue(RevenantSCNArchivedColor *color, NSString *key)
{
    if (!color.valid) {
        RevenantSCNColorFailed(key, color.failure ?: @"it holds no components this port reads");
        return nil;
    }
    return [color toUIColor];
}

+ (UIColor *)decodeColor:(NSCoder *)coder forKey:(NSString *)key
{
    if (![coder containsValueForKey:key]) {
        return nil;
    }
    if ([coder isKindOfClass:[NSKeyedUnarchiver class]]) {
        RevenantSCNMapColorClasses((NSKeyedUnarchiver *)coder);
    }
    id decoded = nil;
    @try {
        decoded = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSData class], [UIColor class], [RevenantSCNArchivedColor class], nil] forKey:key];
    } @catch (NSException *exception) {
        RevenantSCNColorFailed(key, [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
        return nil;
    }
    if ([decoded isKindOfClass:[RevenantSCNArchivedColor class]]) {
        return RevenantSCNArchivedColorValue(decoded, key);
    }
    if ([decoded isKindOfClass:[UIColor class]]) {
        return decoded;
    }
    NSData *nested = decoded;
    if (decoded == nil) {
        RevenantSCNColorFailed(key, @"it holds nothing");
        return nil;
    }
    if (![nested isKindOfClass:[NSData class]]) {
        RevenantSCNColorFailed(key, [NSString stringWithFormat:@"it holds a %@ where a colour belongs", [decoded class]]);
        return nil;
    }
    if (nested.length == 0) {
        RevenantSCNColorFailed(key, @"it holds an empty NSData");
        return nil;
    }
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:nested];
    unarchiver.requiresSecureCoding = YES;
    RevenantSCNMapColorClasses(unarchiver);
    id archived = nil;
    @try {
        archived = [unarchiver decodeObjectOfClasses:[NSSet setWithObjects:[RevenantSCNArchivedColor class], [UIColor class], nil] forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
        RevenantSCNColorFailed(key, [NSString stringWithFormat:@"its nested archive: %@: %@", exception.name, exception.reason]);
        return nil;
    }
    [unarchiver finishDecoding];
    if ([archived isKindOfClass:[RevenantSCNArchivedColor class]]) {
        return RevenantSCNArchivedColorValue(archived, key);
    }
    if (![archived isKindOfClass:[UIColor class]]) {
        RevenantSCNColorFailed(key, @"its nested archive holds no colour");
        return nil;
    }
    return archived;
}

+ (UIColor *)colorWithLinearWhite:(double)white
{
    double encoded = revenant_srgb_encode(white);
    return [UIColor colorWithRed:encoded green:encoded blue:encoded alpha:1];
}

+ (BOOL)decodeBool:(NSCoder *)coder forKey:(NSString *)key default:(BOOL)fallback
{
    if (![coder containsValueForKey:key]) {
        return fallback;
    }
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

static NSMutableArray *RevenantSCNSourceURLStack(void)
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
    [RevenantSCNSourceURLStack() addObject:url ?: [NSNull null]];
}

+ (void)popSourceURL
{
    NSMutableArray *stack = RevenantSCNSourceURLStack();
    if (stack.count) {
        [stack removeLastObject];
    }
}

+ (NSURL *)currentSourceURL
{
    id last = RevenantSCNSourceURLStack().lastObject;
    return [last isKindOfClass:[NSURL class]] ? last : nil;
}

static const void *RevenantSCNProvenanceKey = &RevenantSCNProvenanceKey;

+ (void)markFound:(BOOL)found forKey:(NSString *)key onObject:(id)object
{
    if (object == nil) {
        return;
    }
    NSMutableDictionary<NSString *, NSNumber *> *provenance = objc_getAssociatedObject(object, RevenantSCNProvenanceKey);
    if (!provenance) {
        provenance = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(object, RevenantSCNProvenanceKey, provenance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    provenance[key] = @(found);
}

+ (BOOL)wasFound:(NSString *)key onObject:(id)object
{
    NSMutableDictionary<NSString *, NSNumber *> *provenance = objc_getAssociatedObject(object, RevenantSCNProvenanceKey);
    return provenance[key].boolValue;
}

@end
