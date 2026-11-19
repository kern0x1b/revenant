#import "RevenantSymbols.h"
#import <dlfcn.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *const RevenantPointSizeKey = @"UIPointSize";
static NSString *const RevenantWeightKey = @"UISymbolWeight";
static NSString *const RevenantScaleKey = @"UISymbolScale";
static NSString *const RevenantTextStyleKey = @"UITextStyle";
static NSString *const RevenantRenderingKey = @"UISymbolRendering";
static NSString *const RevenantColorsKey = @"UISymbolRenderingColors";

static const double RevenantDefaultPointSize = 17;

static double revenant_text_style_size(NSString *style)
{
    static NSDictionary *sizes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sizes = @{@"UICTFontTextStyleTitle0": @34, @"UICTFontTextStyleTitle1": @28, @"UICTFontTextStyleTitle2": @22,
                  @"UICTFontTextStyleTitle3": @20, @"UICTFontTextStyleHeadline": @17, @"UICTFontTextStyleBody": @17,
                  @"UICTFontTextStyleCallout": @16, @"UICTFontTextStyleSubhead": @15, @"UICTFontTextStyleFootnote": @13,
                  @"UICTFontTextStyleCaption1": @12, @"UICTFontTextStyleCaption2": @11};
    });
    return [sizes[style] doubleValue];
}

static BOOL revenant_traits_resolve_text_size(UITraitCollection *traits)
{
    if (!traits)
        return YES;
    if (![traits respondsToSelector:@selector(preferredContentSizeCategory)])
        return NO;
    NSString *category = traits.preferredContentSizeCategory;
    return category.length && ![category isEqualToString:UIContentSizeCategoryUnspecified];
}

static double revenant_font_weight_trait(UIFont *font)
{
    typedef CFTypeRef (*CreateWithName)(CFStringRef, CGFloat, const CGAffineTransform *);
    typedef CFDictionaryRef (*CopyTraits)(CFTypeRef);
    static CreateWithName createWithName;
    static CopyTraits copyTraits;
    static CFStringRef *weightKey;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        createWithName = (CreateWithName)dlsym(RTLD_DEFAULT, "CTFontCreateWithName");
        copyTraits = (CopyTraits)dlsym(RTLD_DEFAULT, "CTFontCopyTraits");
        weightKey = (CFStringRef *)dlsym(RTLD_DEFAULT, "kCTFontWeightTrait");
    });
    if (!font || !createWithName || !copyTraits || !weightKey)
        return 0;
    BOOL bridged = kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0;
    CFTypeRef coreText = bridged ? (__bridge CFTypeRef)font : createWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
    if (!coreText)
        return 0;
    NSDictionary *traits = CFBridgingRelease(copyTraits(coreText));
    if (!bridged)
        CFRelease(coreText);
    return [traits[(__bridge id)*weightKey] doubleValue];
}

static NSString *revenant_weight_name(NSInteger weight)
{
    static NSString *const names[] = {nil, @"Ultra Light", @"Thin", @"Light", @"Regular", @"Medium", @"Semibold", @"Bold", @"Heavy", @"Black"};
    return weight >= 1 && weight <= 9 ? names[weight] : nil;
}

static NSString *revenant_scale_name(NSInteger scale)
{
    switch (scale) {
    case -1: return @"Default";
    case 1: return @"Small";
    case 2: return @"Medium";
    case 3: return @"Large";
    default: return @"Unknown";
    }
}

@implementation UIImageSymbolConfiguration {
@private
    double _pointSize;
    BOOL _hasPointSize;
    NSInteger _weight;
    NSInteger _scale;
    NSString *_textStyle;
    RevenantSymbolRendering _rendering;
    NSArray<UIColor *> *_colors;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (UIImageSymbolConfiguration *)unspecifiedConfiguration
{
    static UIImageSymbolConfiguration *unspecified;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unspecified = [[UIImageSymbolConfiguration alloc] initRevenantWithPointSize:0 hasPointSize:NO weight:0 scale:0 textStyle:nil traitCollection:nil];
    });
    return unspecified;
}

+ (instancetype)revenant_configurationWithPointSize:(double)pointSize hasPointSize:(BOOL)hasPointSize weight:(NSInteger)weight scale:(NSInteger)scale
                                        textStyle:(NSString *)textStyle
{
    return [[UIImageSymbolConfiguration alloc] initRevenantWithPointSize:pointSize hasPointSize:hasPointSize weight:weight scale:scale textStyle:textStyle traitCollection:nil];
}

+ (instancetype)configurationWithScale:(UIImageSymbolScale)scale
{
    return [self revenant_configurationWithPointSize:0 hasPointSize:NO weight:0 scale:scale textStyle:nil];
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize
{
    return [self configurationWithPointSize:pointSize weight:UIImageSymbolWeightUnspecified scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithWeight:(UIImageSymbolWeight)weight
{
    return [self revenant_configurationWithPointSize:0 hasPointSize:NO weight:weight scale:0 textStyle:nil];
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight
{
    return [self configurationWithPointSize:pointSize weight:weight scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight scale:(UIImageSymbolScale)scale
{
    double size = pointSize > 0 ? pointSize : RevenantDefaultPointSize;
    return [self revenant_configurationWithPointSize:size hasPointSize:YES weight:weight scale:scale textStyle:nil];
}

+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle
{
    return [self configurationWithTextStyle:textStyle scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle scale:(UIImageSymbolScale)scale
{
    return [self revenant_configurationWithPointSize:0 hasPointSize:NO weight:0 scale:scale textStyle:textStyle];
}

+ (instancetype)configurationWithFont:(UIFont *)font
{
    return [self configurationWithFont:font scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithFont:(UIFont *)font scale:(UIImageSymbolScale)scale
{
    NSInteger weight = UIImageSymbolWeightForFontWeight(revenant_font_weight_trait(font));
    return [self revenant_configurationWithPointSize:font.pointSize hasPointSize:YES weight:weight scale:scale textStyle:nil];
}

+ (UIImageSymbolConfiguration *)revenant_configurationWithRendering:(RevenantSymbolRendering)rendering colors:(NSArray<UIColor *> *)colors
{
    UIImageSymbolConfiguration *configuration = [[self alloc] initRevenantWithPointSize:0 hasPointSize:NO weight:0 scale:0 textStyle:nil traitCollection:nil];
    configuration->_rendering = rendering;
    configuration->_colors = [colors copy];
    return configuration;
}

+ (UIImageSymbolConfiguration *)configurationPreferringMonochrome
{
    return [self revenant_configurationWithRendering:RevenantSymbolRenderingMonochrome colors:nil];
}

+ (UIImageSymbolConfiguration *)configurationPreferringMulticolor
{
    return [self revenant_configurationWithRendering:RevenantSymbolRenderingMulticolor colors:nil];
}

+ (UIImageSymbolConfiguration *)configurationWithHierarchicalColor:(UIColor *)color
{
    return [self revenant_configurationWithRendering:RevenantSymbolRenderingHierarchical colors:@[color ?: [UIColor blackColor]]];
}

+ (UIImageSymbolConfiguration *)configurationWithPaletteColors:(NSArray<UIColor *> *)colors
{
    if (!colors.count)
        return [self revenant_configurationWithRendering:RevenantSymbolRenderingMonochrome colors:nil];
    return [self revenant_configurationWithRendering:RevenantSymbolRenderingPalette colors:colors];
}

- (instancetype)initRevenantWithPointSize:(double)pointSize hasPointSize:(BOOL)hasPointSize weight:(NSInteger)weight scale:(NSInteger)scale
                               textStyle:(NSString *)textStyle traitCollection:(UITraitCollection *)traits
{
    if ((self = [super initRevenantWithTraitCollection:traits])) {
        _pointSize = pointSize;
        _hasPointSize = hasPointSize;
        _weight = weight;
        _scale = scale;
        _textStyle = textStyle;
        _rendering = RevenantSymbolRenderingAutomatic;
        _colors = nil;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _hasPointSize = [coder containsValueForKey:RevenantPointSizeKey];
        _pointSize = fmax(0, [coder decodeDoubleForKey:RevenantPointSizeKey]);
        _weight = [coder decodeIntegerForKey:RevenantWeightKey];
        _scale = [coder decodeIntegerForKey:RevenantScaleKey];
        _textStyle = [coder decodeObjectOfClass:[NSString class] forKey:RevenantTextStyleKey];
        _rendering = [coder decodeIntegerForKey:RevenantRenderingKey];
        NSArray *encoded = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil] forKey:RevenantColorsKey];
        NSMutableArray *colors = [NSMutableArray array];
        for (NSArray *parts in encoded) {
            if (parts.count < 4)
                continue;
            [colors addObject:[UIColor colorWithRed:[parts[0] doubleValue] green:[parts[1] doubleValue]
                                              blue:[parts[2] doubleValue] alpha:[parts[3] doubleValue]]];
        }
        _colors = colors.count ? colors : nil;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if (_hasPointSize && _pointSize != 0)
        [coder encodeDouble:_pointSize forKey:RevenantPointSizeKey];
    if (_weight)
        [coder encodeInteger:_weight forKey:RevenantWeightKey];
    if (_scale)
        [coder encodeInteger:_scale forKey:RevenantScaleKey];
    if (_textStyle)
        [coder encodeObject:_textStyle forKey:RevenantTextStyleKey];
    if (_rendering)
        [coder encodeInteger:_rendering forKey:RevenantRenderingKey];
    if (_colors) {
        NSMutableArray *encoded = [NSMutableArray array];
        for (UIColor *color in _colors) {
            CGColorRef cg = color.CGColor;
            size_t components = CGColorGetNumberOfComponents(cg);
            const CGFloat *parts = CGColorGetComponents(cg);
            CGFloat red = 0, green = 0, blue = 0, alpha = 1;
            if (components >= 4) {
                red = parts[0];
                green = parts[1];
                blue = parts[2];
                alpha = parts[3];
            } else if (components >= 2) {
                red = green = blue = parts[0];
                alpha = parts[1];
            }
            [encoded addObject:@[@(red), @(green), @(blue), @(alpha)]];
        }
        [coder encodeObject:encoded forKey:RevenantColorsKey];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    UIImageSymbolConfiguration *copy = [super copyWithZone:zone];
    copy->_pointSize = _pointSize;
    copy->_hasPointSize = _hasPointSize;
    copy->_weight = _weight;
    copy->_scale = _scale;
    copy->_textStyle = _textStyle;
    copy->_rendering = _rendering;
    copy->_colors = _colors;
    return copy;
}

- (BOOL)revenant_isUnspecified
{
    return [super revenant_isUnspecified] && !_hasPointSize && !_weight && !_scale && !_textStyle &&
           _rendering == RevenantSymbolRenderingAutomatic && !_colors;
}

- (void)revenant_applyFieldsOfConfiguration:(UIImageConfiguration *)other
{
    if (![other isKindOfClass:[UIImageSymbolConfiguration class]])
        return;
    UIImageSymbolConfiguration *symbols = (UIImageSymbolConfiguration *)other;
    if (symbols->_textStyle) {
        _textStyle = symbols->_textStyle;
        _pointSize = 0;
        _hasPointSize = NO;
    } else if (symbols->_hasPointSize) {
        _pointSize = symbols->_pointSize;
        _hasPointSize = YES;
        _textStyle = nil;
    }
    if (symbols->_weight)
        _weight = symbols->_weight;
    if (symbols->_scale)
        _scale = symbols->_scale;
    if (symbols->_rendering != RevenantSymbolRenderingAutomatic) {
        _rendering = symbols->_rendering;
        _colors = symbols->_colors;
    }
}

- (instancetype)configurationByApplyingConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if ([otherConfiguration isKindOfClass:[UIImageSymbolConfiguration class]] && [self isEqualToConfiguration:(UIImageSymbolConfiguration *)otherConfiguration])
        return self;
    return [super configurationByApplyingConfiguration:otherConfiguration];
}

- (double)revenant_symbolPointSize
{
    double size = _hasPointSize ? _pointSize : _textStyle ? revenant_text_style_size(_textStyle) : RevenantDefaultPointSize;
    return size > 0 ? size : RevenantDefaultPointSize;
}

- (NSInteger)revenant_symbolWeight
{
    return _weight >= 1 && _weight <= 9 ? _weight : 4;
}

- (NSInteger)revenant_symbolScale
{
    return _scale >= 1 && _scale <= 3 ? _scale : 2;
}

- (instancetype)configurationWithoutTextStyle
{
    if (!_textStyle)
        return self;
    UIImageSymbolConfiguration *copy = [self copy];
    copy->_textStyle = nil;
    copy->_hasPointSize = revenant_traits_resolve_text_size(self.traitCollection);
    copy->_pointSize = copy->_hasPointSize ? revenant_text_style_size(_textStyle) : 0;
    return copy;
}

- (instancetype)configurationWithoutScale
{
    if (!_scale)
        return self;
    UIImageSymbolConfiguration *copy = [self copy];
    copy->_scale = 0;
    return copy;
}

- (instancetype)configurationWithoutWeight
{
    if (!_weight)
        return self;
    UIImageSymbolConfiguration *copy = [self copy];
    copy->_weight = 0;
    return copy;
}

- (instancetype)configurationWithoutPointSizeAndWeight
{
    if (!_hasPointSize && !_weight)
        return self;
    UIImageSymbolConfiguration *copy = [self copy];
    copy->_pointSize = 0;
    copy->_hasPointSize = NO;
    copy->_weight = 0;
    return copy;
}

- (BOOL)isEqualToConfiguration:(UIImageSymbolConfiguration *)otherConfiguration
{
    if (otherConfiguration == self)
        return YES;
    if (!otherConfiguration)
        return [self revenant_isUnspecified];
    if (![otherConfiguration isKindOfClass:[UIImageSymbolConfiguration class]])
        return NO;
    BOOL sameColors = _colors == otherConfiguration->_colors || [_colors isEqual:otherConfiguration->_colors];
    return _hasPointSize == otherConfiguration->_hasPointSize && _pointSize == otherConfiguration->_pointSize && _weight == otherConfiguration->_weight &&
           _scale == otherConfiguration->_scale && (_textStyle == otherConfiguration->_textStyle || [_textStyle isEqual:otherConfiguration->_textStyle]) &&
           _rendering == otherConfiguration->_rendering && sameColors && [self revenant_hasTraitsOfConfiguration:otherConfiguration];
}

- (NSUInteger)hash
{
    double scaled = _hasPointSize ? _pointSize * 100 : 0;
    NSUInteger size = scaled > 0 && scaled < (double)NSUIntegerMax ? (NSUInteger)scaled : 0;
    return size ^ (NSUInteger)_weight ^ (NSUInteger)_scale ^ (NSUInteger)_rendering ^ _textStyle.hash ^ _colors.hash ^ [super hash];
}

- (NSMutableArray<NSString *> *)revenant_fieldDescriptions
{
    NSMutableArray *fields = [super revenant_fieldDescriptions];
    if (_hasPointSize)
        [fields addObject:[NSString stringWithFormat:@"pointSize=%g", _pointSize]];
    if (_textStyle)
        [fields addObject:[@"textStyle=" stringByAppendingString:_textStyle]];
    if (_weight)
        [fields addObject:[NSString stringWithFormat:@"weight=%@", revenant_weight_name(_weight)]];
    if (_scale)
        [fields addObject:[@"scale=" stringByAppendingString:revenant_scale_name(_scale)]];
    if (_rendering)
        [fields addObject:[NSString stringWithFormat:@"rendering=%ld", (long)_rendering]];
    if (_colors)
        [fields addObject:[NSString stringWithFormat:@"colors=%lu", (unsigned long)_colors.count]];
    return fields;
}

- (RevenantSymbolRendering)revenant_symbolRendering
{
    return _rendering;
}

- (NSArray<UIColor *> *)revenant_symbolColors
{
    return _colors;
}

@end
