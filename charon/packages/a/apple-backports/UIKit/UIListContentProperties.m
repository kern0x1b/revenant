#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

const CGFloat UIListContentImageStandardDimension = -CGFLOAT_MAX;

static UIFont *charon_private_style_font(NSString *style, UIFontTextStyle fallback, CGFloat size)
{
    UIFont *font = [UIFont preferredFontForTextStyle:style];
    return font && font.pointSize == size ? font : [UIFont preferredFontForTextStyle:fallback];
}

static UIFont *charon_list_font(NSInteger kind)
{
    switch (kind) {
    case 1:
        return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    case 2:
        return charon_private_style_font(@"UICTFontTextStyleShortFootnote", UIFontTextStyleFootnote, 13);
    case 3:
        return charon_private_style_font(@"UICTFontTextStyleEmphasizedBody", UIFontTextStyleHeadline, 17);
    case 4:
        return charon_medium_body_font();
    }
    return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

static NSString *charon_alignment_name(UIListContentTextAlignment alignment)
{
    return alignment == UIListContentTextAlignmentCenter ? @"center" : alignment == UIListContentTextAlignmentJustified ? @"justified" : @"natural";
}

static NSString *charon_transform_name(UIListContentTextTransform transform)
{
    static NSString *const names[] = {@"none", @"uppercase", @"lowercase", @"capitalized"};
    return transform >= 0 && transform < 4 ? names[transform] : @"none";
}

static NSString *charon_yes(BOOL value)
{
    return value ? @"YES" : @"NO";
}

@implementation UIListContentTextProperties {
@private
    UIFont *_font;
    UIColor *_color;
    UIConfigurationColorTransformer _colorTransformer;
    UIListContentTextAlignment _alignment;
    NSLineBreakMode _lineBreakMode;
    NSInteger _numberOfLines;
    BOOL _adjustsFontSizeToFitWidth;
    CGFloat _minimumScaleFactor;
    BOOL _allowsDefaultTighteningForTruncation;
    BOOL _adjustsFontForContentSizeCategory;
    UIListContentTextTransform _transform;
    NSString *_ownerText;
    BOOL _fontCustomized;
    BOOL _colorCustomized;
    BOOL _transformerCustomized;
    NSString *_transformerName;
    BOOL _showsExpansionTextWhenTruncated;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initCharonWithStyle:(NSInteger)style secondary:(BOOL)secondary
{
    if ((self = [super init])) {
        NSInteger fontKind = 0;
        CharonSemanticColor color = CharonSemanticColorLabel;
        _lineBreakMode = NSLineBreakByTruncatingTail;
        _numberOfLines = 1;
        switch (style) {
        case CharonListStyleCell:
        case CharonListStyleSubtitle:
            _numberOfLines = 0;
            _adjustsFontForContentSizeCategory = YES;
            if (secondary) {
                fontKind = 1;
                color = CharonSemanticColorSecondaryLabel;
            }
            break;
        case CharonListStyleValue:
            _numberOfLines = 0;
            _adjustsFontForContentSizeCategory = YES;
            color = secondary ? CharonSemanticColorSecondaryLabel : CharonSemanticColorLabel;
            break;
        case CharonListStylePlainHeader:
        case CharonListStyleGroupedHeader:
        case CharonListStyleHeader:
            _numberOfLines = 0;
            _adjustsFontForContentSizeCategory = YES;
            fontKind = 3;
            color = CharonSemanticColorSecondaryLabel;
            break;
        case CharonListStylePlainFooter:
        case CharonListStyleGroupedFooter:
        case CharonListStyleFooter:
            _numberOfLines = 0;
            _adjustsFontForContentSizeCategory = YES;
            fontKind = 2;
            color = CharonSemanticColorSecondaryLabel;
            break;
        case CharonListStyleSidebarCell:
        case CharonListStyleSidebarSubtitle:
        case CharonListStyleAccompaniedSidebar:
        case CharonListStyleAccompaniedSidebarSubtitle:
        case CharonListStyleSidebarHeader:
            _adjustsFontForContentSizeCategory = YES;
            _adjustsFontSizeToFitWidth = YES;
            _minimumScaleFactor = 0.9;
            _allowsDefaultTighteningForTruncation = YES;
            fontKind = secondary ? 2 : style == CharonListStyleSidebarHeader ? 4 : 0;
            color = (secondary || style == CharonListStyleSidebarHeader) ? CharonSemanticColorSecondaryLabel : CharonSemanticColorLabel;
            break;
        default:
            break;
        }
        if (style == CharonListStyleBare - 1) {
            _lineBreakMode = NSLineBreakByWordWrapping;
            _numberOfLines = 0;
            return self;
        }
        _font = charon_list_font(fontKind);
        _color = charon_semantic_color(color);
    }
    return self;
}

- (instancetype)init
{
    return [self initCharonWithStyle:CharonListStyleBare secondary:NO];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        UIFont *font = [coder decodeObjectOfClass:[UIFont class] forKey:@"font"];
        UIColor *color = [coder decodeObjectOfClass:[UIColor class] forKey:@"color"];
        if (font)
            _font = font;
        if (color)
            _color = color;
        _alignment = (UIListContentTextAlignment)[coder decodeIntegerForKey:@"alignment"];
        _lineBreakMode = (NSLineBreakMode)[coder decodeIntegerForKey:@"lineBreakMode"];
        _numberOfLines = [coder decodeIntegerForKey:@"numberOfLines"];
        _adjustsFontSizeToFitWidth = [coder decodeBoolForKey:@"adjustsFontSizeToFitWidth"];
        _minimumScaleFactor = (CGFloat)[coder decodeDoubleForKey:@"minimumScaleFactor"];
        _allowsDefaultTighteningForTruncation = [coder decodeBoolForKey:@"allowsDefaultTighteningForTruncation"];
        _adjustsFontForContentSizeCategory = [coder decodeBoolForKey:@"adjustsFontForContentSizeCategory"];
        _transform = (UIListContentTextTransform)[coder decodeIntegerForKey:@"transform"];
        _showsExpansionTextWhenTruncated = [coder decodeBoolForKey:@"showsExpansionTextWhenTruncated"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_font forKey:@"font"];
    [coder encodeObject:_color forKey:@"color"];
    [coder encodeInteger:_alignment forKey:@"alignment"];
    [coder encodeInteger:_lineBreakMode forKey:@"lineBreakMode"];
    [coder encodeInteger:_numberOfLines forKey:@"numberOfLines"];
    [coder encodeBool:_adjustsFontSizeToFitWidth forKey:@"adjustsFontSizeToFitWidth"];
    [coder encodeDouble:_minimumScaleFactor forKey:@"minimumScaleFactor"];
    [coder encodeBool:_allowsDefaultTighteningForTruncation forKey:@"allowsDefaultTighteningForTruncation"];
    [coder encodeBool:_adjustsFontForContentSizeCategory forKey:@"adjustsFontForContentSizeCategory"];
    [coder encodeInteger:_transform forKey:@"transform"];
    [coder encodeBool:_showsExpansionTextWhenTruncated forKey:@"showsExpansionTextWhenTruncated"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIListContentTextProperties *copy = [[[self class] allocWithZone:zone] init];
    copy->_font = _font;
    copy->_color = _color;
    copy->_colorTransformer = [_colorTransformer copy];
    copy->_alignment = _alignment;
    copy->_lineBreakMode = _lineBreakMode;
    copy->_numberOfLines = _numberOfLines;
    copy->_adjustsFontSizeToFitWidth = _adjustsFontSizeToFitWidth;
    copy->_minimumScaleFactor = _minimumScaleFactor;
    copy->_allowsDefaultTighteningForTruncation = _allowsDefaultTighteningForTruncation;
    copy->_adjustsFontForContentSizeCategory = _adjustsFontForContentSizeCategory;
    copy->_transform = _transform;
    copy->_ownerText = _ownerText;
    copy->_fontCustomized = _fontCustomized;
    copy->_colorCustomized = _colorCustomized;
    copy->_transformerCustomized = _transformerCustomized;
    copy->_transformerName = _transformerName;
    copy->_showsExpansionTextWhenTruncated = _showsExpansionTextWhenTruncated;
    return copy;
}

- (BOOL)showsExpansionTextWhenTruncated
{
    return _showsExpansionTextWhenTruncated;
}

- (void)setShowsExpansionTextWhenTruncated:(BOOL)showsExpansionTextWhenTruncated
{
    _showsExpansionTextWhenTruncated = showsExpansionTextWhenTruncated;
}

- (UIFont *)font
{
    return _font;
}

- (void)setFont:(UIFont *)font
{
    _font = font;
    _fontCustomized = YES;
}

- (UIColor *)color
{
    return _color;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    _colorCustomized = YES;
}

- (UIConfigurationColorTransformer)colorTransformer
{
    return _colorTransformer;
}

- (void)setColorTransformer:(UIConfigurationColorTransformer)colorTransformer
{
    _colorTransformer = [colorTransformer copy];
    _transformerName = nil;
    _transformerCustomized = YES;
}

- (UIColor *)resolvedColor
{
    return _colorTransformer ? _colorTransformer(_color) : _color;
}

- (UIListContentTextAlignment)alignment
{
    return _alignment;
}

- (void)setAlignment:(UIListContentTextAlignment)alignment
{
    _alignment = alignment;
}

- (NSLineBreakMode)lineBreakMode
{
    return _lineBreakMode;
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode
{
    _lineBreakMode = lineBreakMode;
}

- (NSInteger)numberOfLines
{
    return _numberOfLines;
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
    _numberOfLines = numberOfLines;
}

- (BOOL)adjustsFontSizeToFitWidth
{
    return _adjustsFontSizeToFitWidth;
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth
{
    _adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth;
}

- (CGFloat)minimumScaleFactor
{
    return _minimumScaleFactor;
}

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor
{
    _minimumScaleFactor = minimumScaleFactor;
}

- (BOOL)allowsDefaultTighteningForTruncation
{
    return _allowsDefaultTighteningForTruncation;
}

- (void)setAllowsDefaultTighteningForTruncation:(BOOL)allowsDefaultTighteningForTruncation
{
    _allowsDefaultTighteningForTruncation = allowsDefaultTighteningForTruncation;
}

- (BOOL)adjustsFontForContentSizeCategory
{
    return _adjustsFontForContentSizeCategory;
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjustsFontForContentSizeCategory
{
    _adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory;
}

- (UIListContentTextTransform)transform
{
    return _transform;
}

- (void)setTransform:(UIListContentTextTransform)transform
{
    _transform = transform;
}

- (void)charon_setOwnerText:(NSString *)text
{
    _ownerText = text;
}

- (NSString *)charon_ownerText
{
    return _ownerText;
}

- (BOOL)charon_fontCustomized
{
    return _fontCustomized;
}

- (BOOL)charon_colorCustomized
{
    return _colorCustomized;
}

- (void)charon_setDefaultFont:(UIFont *)font
{
    _font = font;
}

- (void)charon_setDefaultColor:(UIColor *)color
{
    _color = color;
}

- (void)charon_setTransformerNamed:(NSString *)name block:(UIConfigurationColorTransformer)block
{
    if (_transformerCustomized)
        return;
    _colorTransformer = [block copy];
    _transformerName = name;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIListContentTextProperties class]])
        return NO;
    UIListContentTextProperties *other = object;
    return (_font == other->_font || [_font isEqual:other->_font]) && (_color == other->_color || [_color isEqual:other->_color]) &&
           (_colorTransformer == other->_colorTransformer || (_transformerName && [_transformerName isEqual:other->_transformerName])) &&
           _alignment == other->_alignment && _lineBreakMode == other->_lineBreakMode && _numberOfLines == other->_numberOfLines &&
           _adjustsFontSizeToFitWidth == other->_adjustsFontSizeToFitWidth && _minimumScaleFactor == other->_minimumScaleFactor &&
           _allowsDefaultTighteningForTruncation == other->_allowsDefaultTighteningForTruncation &&
           _adjustsFontForContentSizeCategory == other->_adjustsFontForContentSizeCategory && _transform == other->_transform;
}

- (NSUInteger)hash
{
    return [_font hash] ^ ([_color hash] << 1) ^ ((NSUInteger)_alignment << 3) ^ ((NSUInteger)_numberOfLines << 5) ^ ((NSUInteger)_transform << 9) ^
           ((_adjustsFontSizeToFitWidth ? 1u : 0u) << 11) ^ ((_adjustsFontForContentSizeCategory ? 1u : 0u) << 12);
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (_ownerText)
        [text appendFormat:@"; text = %@", charon_elided_text(_ownerText)];
    if (_font)
        [text appendFormat:@"; font = %@", _font];
    if (_color)
        [text appendFormat:@"; color = %@", _color];
    if (_colorTransformer)
        [text appendFormat:@"; colorTransformer = %@", _transformerName ?: @"Custom"];
    if (_alignment)
        [text appendFormat:@"; alignment = %@", charon_alignment_name(_alignment)];
    [text appendFormat:@"; numberOfLines = %ld", (long)_numberOfLines];
    if (_adjustsFontSizeToFitWidth)
        [text appendString:@"; adjustsFontSizeToFitWidth = YES"];
    if (_minimumScaleFactor)
        [text appendFormat:@"; minimumScaleFactor = %g", _minimumScaleFactor];
    if (_allowsDefaultTighteningForTruncation)
        [text appendString:@"; allowsDefaultTighteningForTruncation = YES"];
    if (_adjustsFontForContentSizeCategory)
        [text appendFormat:@"; adjustsFontForContentSizeCategory = %@", charon_yes(YES)];
    if (_transform)
        [text appendFormat:@"; transform = %@", charon_transform_name(_transform)];
    [text appendString:@">"];
    return text;
}

@end

@implementation UIListContentImageProperties {
@private
    UIImageSymbolConfiguration *_preferredSymbolConfiguration;
    UIColor *_tintColor;
    UIConfigurationColorTransformer _tintColorTransformer;
    CGFloat _cornerRadius;
    CGSize _maximumSize;
    CGSize _reservedLayoutSize;
    BOOL _accessibilityIgnoresInvertColors;
    BOOL _tintCustomized;
    BOOL _tintDescribed;
    BOOL _bare;
    BOOL _transformerCustomized;
    UIImage *_ownerImage;
    NSString *_transformerName;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init]))
        _tintDescribed = YES;
    return self;
}

- (instancetype)initCharonBare
{
    if ((self = [self init]))
        _bare = YES;
    return self;
}

- (instancetype)initCharonDefault
{
    if ((self = [super init]))
        _preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody scale:UIImageSymbolScaleLarge];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initCharonDefault])) {
        if ([coder containsValueForKey:@"preferredSymbolConfiguration"])
            _preferredSymbolConfiguration = [coder decodeObjectOfClass:[UIImageSymbolConfiguration class] forKey:@"preferredSymbolConfiguration"];
        else if ([coder decodeBoolForKey:@"noSymbolConfiguration"])
            _preferredSymbolConfiguration = nil;
        _tintColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"tintColor"];
        _tintCustomized = [coder decodeBoolForKey:@"tintCustomized"];
        _cornerRadius = (CGFloat)[coder decodeDoubleForKey:@"cornerRadius"];
        _maximumSize = CGSizeMake([coder decodeDoubleForKey:@"maximumSizeWidth"], [coder decodeDoubleForKey:@"maximumSizeHeight"]);
        _reservedLayoutSize = CGSizeMake([coder decodeDoubleForKey:@"reservedLayoutSizeWidth"], [coder decodeDoubleForKey:@"reservedLayoutSizeHeight"]);
        _accessibilityIgnoresInvertColors = [coder decodeBoolForKey:@"accessibilityIgnoresInvertColors"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_preferredSymbolConfiguration)
        [coder encodeObject:_preferredSymbolConfiguration forKey:@"preferredSymbolConfiguration"];
    else
        [coder encodeBool:YES forKey:@"noSymbolConfiguration"];
    [coder encodeObject:_tintColor forKey:@"tintColor"];
    [coder encodeBool:_tintCustomized forKey:@"tintCustomized"];
    [coder encodeDouble:_cornerRadius forKey:@"cornerRadius"];
    [coder encodeDouble:_maximumSize.width forKey:@"maximumSizeWidth"];
    [coder encodeDouble:_maximumSize.height forKey:@"maximumSizeHeight"];
    [coder encodeDouble:_reservedLayoutSize.width forKey:@"reservedLayoutSizeWidth"];
    [coder encodeDouble:_reservedLayoutSize.height forKey:@"reservedLayoutSizeHeight"];
    [coder encodeBool:_accessibilityIgnoresInvertColors forKey:@"accessibilityIgnoresInvertColors"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIListContentImageProperties *copy = [[[self class] allocWithZone:zone] initCharonDefault];
    copy->_preferredSymbolConfiguration = [_preferredSymbolConfiguration copy];
    copy->_tintColor = _tintColor;
    copy->_tintColorTransformer = [_tintColorTransformer copy];
    copy->_cornerRadius = _cornerRadius;
    copy->_maximumSize = _maximumSize;
    copy->_reservedLayoutSize = _reservedLayoutSize;
    copy->_accessibilityIgnoresInvertColors = _accessibilityIgnoresInvertColors;
    copy->_tintCustomized = _tintCustomized;
    copy->_tintDescribed = _tintDescribed;
    copy->_bare = _bare;
    copy->_ownerImage = _ownerImage;
    copy->_transformerCustomized = _transformerCustomized;
    copy->_transformerName = _transformerName;
    return copy;
}

- (UIImageSymbolConfiguration *)preferredSymbolConfiguration
{
    return _preferredSymbolConfiguration;
}

- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)preferredSymbolConfiguration
{
    _preferredSymbolConfiguration = [preferredSymbolConfiguration copy];
}

- (UIColor *)tintColor
{
    return _tintColor;
}

- (void)setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    _tintCustomized = YES;
    _bare = NO;
}

- (UIConfigurationColorTransformer)tintColorTransformer
{
    return _tintColorTransformer;
}

- (void)setTintColorTransformer:(UIConfigurationColorTransformer)tintColorTransformer
{
    _tintColorTransformer = [tintColorTransformer copy];
    _transformerName = nil;
    _transformerCustomized = YES;
    _tintDescribed = YES;
}

- (UIColor *)resolvedTintColorForTintColor:(UIColor *)tintColor
{
    UIColor *base = _tintColor ?: (_bare ? nil : tintColor);
    return _tintColorTransformer ? _tintColorTransformer(base) : base;
}

- (CGFloat)cornerRadius
{
    return _cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
}

- (CGSize)maximumSize
{
    return _maximumSize;
}

- (void)setMaximumSize:(CGSize)maximumSize
{
    _maximumSize = maximumSize;
}

- (CGSize)reservedLayoutSize
{
    return _reservedLayoutSize;
}

- (void)setReservedLayoutSize:(CGSize)reservedLayoutSize
{
    _reservedLayoutSize = reservedLayoutSize;
}

- (BOOL)accessibilityIgnoresInvertColors
{
    return _accessibilityIgnoresInvertColors;
}

- (void)setAccessibilityIgnoresInvertColors:(BOOL)accessibilityIgnoresInvertColors
{
    _accessibilityIgnoresInvertColors = accessibilityIgnoresInvertColors;
}

- (void)charon_setOwnerImage:(UIImage *)image
{
    _ownerImage = image;
}

- (BOOL)charon_tintCustomized
{
    return _tintCustomized;
}

- (void)charon_setDefaultTintColor:(UIColor *)color
{
    _tintColor = color;
}

- (void)charon_setTransformerNamed:(NSString *)name block:(UIConfigurationColorTransformer)block
{
    if (_transformerCustomized)
        return;
    _tintColorTransformer = [block copy];
    _transformerName = name;
    _tintDescribed = YES;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIListContentImageProperties class]])
        return NO;
    UIListContentImageProperties *other = object;
    return (_preferredSymbolConfiguration == other->_preferredSymbolConfiguration || [_preferredSymbolConfiguration isEqual:other->_preferredSymbolConfiguration]) &&
           (_tintColor == other->_tintColor || [_tintColor isEqual:other->_tintColor]) &&
           (_tintColorTransformer == other->_tintColorTransformer || (_transformerName && [_transformerName isEqual:other->_transformerName])) &&
           _cornerRadius == other->_cornerRadius && CGSizeEqualToSize(_maximumSize, other->_maximumSize) &&
           CGSizeEqualToSize(_reservedLayoutSize, other->_reservedLayoutSize) && _accessibilityIgnoresInvertColors == other->_accessibilityIgnoresInvertColors;
}

- (NSUInteger)hash
{
    return [_preferredSymbolConfiguration hash] ^ ([_tintColor hash] << 1) ^ (NSUInteger)(_cornerRadius * 7) ^ (NSUInteger)(_maximumSize.width * 13) ^ (NSUInteger)(_reservedLayoutSize.width * 17);
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (_ownerImage)
        [text appendFormat:@"; image = %@", _ownerImage];
    if (_preferredSymbolConfiguration)
        [text appendFormat:@"; preferredSymbolConfiguration = %@", _preferredSymbolConfiguration];
    if (_tintColor)
        [text appendFormat:@"; tintColor = %@", _tintColor];
    else if (_tintCustomized || _tintDescribed)
        [text appendString:@"; tintColor = Inherited"];
    if (_tintColorTransformer)
        [text appendFormat:@"; tintColorTransformer = %@", _transformerName ?: @"Custom"];
    if (_cornerRadius)
        [text appendFormat:@"; cornerRadius = %g", _cornerRadius];
    if (!CGSizeEqualToSize(_reservedLayoutSize, CGSizeZero))
        [text appendFormat:@"; reservedLayoutSize = %@", NSStringFromCGSize(_reservedLayoutSize)];
    if (!CGSizeEqualToSize(_maximumSize, CGSizeZero))
        [text appendFormat:@"; maximumSize = %@", NSStringFromCGSize(_maximumSize)];
    if (_accessibilityIgnoresInvertColors)
        [text appendString:@"; accessibilityIgnoresInvertColors = YES"];
    [text appendString:@">"];
    return text;
}

@end
