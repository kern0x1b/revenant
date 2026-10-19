#import "CharonSymbols.h"
#import <dlfcn.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *const CharonPointSizeKey = @"UIPointSize";
static NSString *const CharonWeightKey = @"UISymbolWeight";
static NSString *const CharonScaleKey = @"UISymbolScale";
static NSString *const CharonTextStyleKey = @"UITextStyle";

static const double CharonDefaultPointSize = 17;

static double charon_text_style_size(NSString *style)
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

static BOOL charon_traits_resolve_text_size(UITraitCollection *traits)
{
    if (!traits)
        return YES;
    if (![traits respondsToSelector:@selector(preferredContentSizeCategory)])
        return NO;
    NSString *category = traits.preferredContentSizeCategory;
    return category.length && ![category isEqualToString:UIContentSizeCategoryUnspecified];
}

static double charon_font_weight_trait(UIFont *font)
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

static NSString *charon_weight_name(NSInteger weight)
{
    static NSString *const names[] = {nil, @"Ultra Light", @"Thin", @"Light", @"Regular", @"Medium", @"Semibold", @"Bold", @"Heavy", @"Black"};
    return weight >= 1 && weight <= 9 ? names[weight] : nil;
}

static NSString *charon_scale_name(NSInteger scale)
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
        unspecified = [[UIImageSymbolConfiguration alloc] initCharonWithPointSize:0 hasPointSize:NO weight:0 scale:0 textStyle:nil traitCollection:nil];
    });
    return unspecified;
}

+ (instancetype)charon_configurationWithPointSize:(double)pointSize hasPointSize:(BOOL)hasPointSize weight:(NSInteger)weight scale:(NSInteger)scale
                                        textStyle:(NSString *)textStyle
{
    return [[UIImageSymbolConfiguration alloc] initCharonWithPointSize:pointSize hasPointSize:hasPointSize weight:weight scale:scale textStyle:textStyle traitCollection:nil];
}

+ (instancetype)configurationWithScale:(UIImageSymbolScale)scale
{
    return [self charon_configurationWithPointSize:0 hasPointSize:NO weight:0 scale:scale textStyle:nil];
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize
{
    return [self configurationWithPointSize:pointSize weight:UIImageSymbolWeightUnspecified scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithWeight:(UIImageSymbolWeight)weight
{
    return [self charon_configurationWithPointSize:0 hasPointSize:NO weight:weight scale:0 textStyle:nil];
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight
{
    return [self configurationWithPointSize:pointSize weight:weight scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight scale:(UIImageSymbolScale)scale
{
    double size = pointSize > 0 ? pointSize : CharonDefaultPointSize;
    return [self charon_configurationWithPointSize:size hasPointSize:YES weight:weight scale:scale textStyle:nil];
}

+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle
{
    return [self configurationWithTextStyle:textStyle scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle scale:(UIImageSymbolScale)scale
{
    return [self charon_configurationWithPointSize:0 hasPointSize:NO weight:0 scale:scale textStyle:textStyle];
}

+ (instancetype)configurationWithFont:(UIFont *)font
{
    return [self configurationWithFont:font scale:UIImageSymbolScaleUnspecified];
}

+ (instancetype)configurationWithFont:(UIFont *)font scale:(UIImageSymbolScale)scale
{
    NSInteger weight = UIImageSymbolWeightForFontWeight(charon_font_weight_trait(font));
    return [self charon_configurationWithPointSize:font.pointSize hasPointSize:YES weight:weight scale:scale textStyle:nil];
}

- (instancetype)initCharonWithPointSize:(double)pointSize hasPointSize:(BOOL)hasPointSize weight:(NSInteger)weight scale:(NSInteger)scale
                               textStyle:(NSString *)textStyle traitCollection:(UITraitCollection *)traits
{
    if ((self = [super initCharonWithTraitCollection:traits])) {
        _pointSize = pointSize;
        _hasPointSize = hasPointSize;
        _weight = weight;
        _scale = scale;
        _textStyle = textStyle;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _hasPointSize = [coder containsValueForKey:CharonPointSizeKey];
        _pointSize = fmax(0, [coder decodeDoubleForKey:CharonPointSizeKey]);
        _weight = [coder decodeIntegerForKey:CharonWeightKey];
        _scale = [coder decodeIntegerForKey:CharonScaleKey];
        _textStyle = [coder decodeObjectOfClass:[NSString class] forKey:CharonTextStyleKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if (_hasPointSize && _pointSize != 0)
        [coder encodeDouble:_pointSize forKey:CharonPointSizeKey];
    if (_weight)
        [coder encodeInteger:_weight forKey:CharonWeightKey];
    if (_scale)
        [coder encodeInteger:_scale forKey:CharonScaleKey];
    if (_textStyle)
        [coder encodeObject:_textStyle forKey:CharonTextStyleKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIImageSymbolConfiguration *copy = [super copyWithZone:zone];
    copy->_pointSize = _pointSize;
    copy->_hasPointSize = _hasPointSize;
    copy->_weight = _weight;
    copy->_scale = _scale;
    copy->_textStyle = _textStyle;
    return copy;
}

- (BOOL)charon_isUnspecified
{
    return [super charon_isUnspecified] && !_hasPointSize && !_weight && !_scale && !_textStyle;
}

- (void)charon_applyFieldsOfConfiguration:(UIImageConfiguration *)other
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
}

- (instancetype)configurationByApplyingConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if ([otherConfiguration isKindOfClass:[UIImageSymbolConfiguration class]] && [self isEqualToConfiguration:(UIImageSymbolConfiguration *)otherConfiguration])
        return self;
    return [super configurationByApplyingConfiguration:otherConfiguration];
}

- (double)charon_symbolPointSize
{
    double size = _hasPointSize ? _pointSize : _textStyle ? charon_text_style_size(_textStyle) : CharonDefaultPointSize;
    return size > 0 ? size : CharonDefaultPointSize;
}

- (NSInteger)charon_symbolWeight
{
    return _weight >= 1 && _weight <= 9 ? _weight : 4;
}

- (NSInteger)charon_symbolScale
{
    return _scale >= 1 && _scale <= 3 ? _scale : 2;
}

- (instancetype)configurationWithoutTextStyle
{
    if (!_textStyle)
        return self;
    UIImageSymbolConfiguration *copy = [self copy];
    copy->_textStyle = nil;
    copy->_hasPointSize = charon_traits_resolve_text_size(self.traitCollection);
    copy->_pointSize = copy->_hasPointSize ? charon_text_style_size(_textStyle) : 0;
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
        return [self charon_isUnspecified];
    if (![otherConfiguration isKindOfClass:[UIImageSymbolConfiguration class]])
        return NO;
    return _hasPointSize == otherConfiguration->_hasPointSize && _pointSize == otherConfiguration->_pointSize && _weight == otherConfiguration->_weight &&
           _scale == otherConfiguration->_scale && (_textStyle == otherConfiguration->_textStyle || [_textStyle isEqual:otherConfiguration->_textStyle]) &&
           [self charon_hasTraitsOfConfiguration:otherConfiguration];
}

- (NSUInteger)hash
{
    double scaled = _hasPointSize ? _pointSize * 100 : 0;
    NSUInteger size = scaled > 0 && scaled < (double)NSUIntegerMax ? (NSUInteger)scaled : 0;
    return size ^ (NSUInteger)_weight ^ (NSUInteger)_scale ^ _textStyle.hash ^ [super hash];
}

- (NSMutableArray<NSString *> *)charon_fieldDescriptions
{
    NSMutableArray *fields = [super charon_fieldDescriptions];
    if (_hasPointSize)
        [fields addObject:[NSString stringWithFormat:@"pointSize=%g", _pointSize]];
    if (_textStyle)
        [fields addObject:[@"textStyle=" stringByAppendingString:_textStyle]];
    if (_weight)
        [fields addObject:[NSString stringWithFormat:@"weight=%@", charon_weight_name(_weight)]];
    if (_scale)
        [fields addObject:[@"scale=" stringByAppendingString:charon_scale_name(_scale)]];
    return fields;
}

@end
