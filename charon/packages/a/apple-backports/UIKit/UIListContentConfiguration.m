#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *charon_style_name(NSInteger style)
{
    static NSString *const names[] = {@"Cell", @"Cell", @"Subtitle Cell", @"Value Cell", @"Plain Header", @"Plain Footer", @"Grouped Header", @"Grouped Footer", @"Sidebar Cell",
                                      @"Sidebar Subtitle Cell", @"Accompanied Sidebar Cell", @"Accompanied Sidebar Subtitle Cell", @"Sidebar Header", @"Header", @"Footer"};
    return style >= 0 && style < 15 ? names[style] : @"Cell";
}

static BOOL charon_is_sidebar_cell(NSInteger style)
{
    return style == CharonListStyleSidebarCell || style == CharonListStyleSidebarSubtitle || style == CharonListStyleAccompaniedSidebar || style == CharonListStyleAccompaniedSidebarSubtitle;
}

static BOOL charon_is_plain_cell(NSInteger style)
{
    return style == CharonListStyleCell || style == CharonListStyleSubtitle || style == CharonListStyleValue;
}

static NSString *charon_axes_text(UIAxis axes)
{
    if (axes == (UIAxisHorizontal | UIAxisVertical))
        return @"Both";
    return axes == UIAxisVertical ? @"[Vertical]" : @"[Horizontal]";
}

static NSString *charon_attributed_text(NSAttributedString *text)
{
    return text.string;
}

static UIConfigurationColorTransformer charon_thirty_percent(void)
{
    return ^UIColor *(UIColor *color) {
        return [color colorWithAlphaComponent:CGColorGetAlpha(color.CGColor) * 0.3];
    };
}

@implementation UIListContentConfiguration {
@private
    NSInteger _style;
    UIImage *_image;
    NSString *_text;
    NSAttributedString *_attributedText;
    NSString *_secondaryText;
    NSAttributedString *_secondaryAttributedText;
    UIListContentTextProperties *_textProperties;
    UIListContentTextProperties *_secondaryTextProperties;
    UIListContentImageProperties *_imageProperties;
    UIAxis _axes;
    NSDirectionalEdgeInsets _margins;
    BOOL _sideBySide;
    CGFloat _imageToTextPadding;
    CGFloat _horizontalPadding;
    CGFloat _verticalPadding;
    CGFloat _alpha;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_configurationWithStyle:(NSInteger)style
{
    return [[UIListContentConfiguration alloc] initCharonWithStyle:style];
}

+ (instancetype)cellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleCell];
}

// The 18.0 spelling of the two header/footer styles this file already has.  Measured: the 16.4 SDK's own
// UIListContentConfiguration.h declares plainHeaderConfiguration and plainFooterConfiguration and does NOT
// declare headerConfiguration or footerConfiguration, so these are new names and not renames - and the port
// already carries the two styles they name, CharonListStyleHeader and CharonListStyleFooter, in the
// -initCharonWithStyle: switch above and in the coder, -copyWithZone: and -isEqual: below.  What 18.0 added
// is the door, not the style, so each is the one-line shape every other class method in this file is.
+ (instancetype)headerConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleHeader];
}

+ (instancetype)footerConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleFooter];
}

+ (instancetype)subtitleCellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleSubtitle];
}

+ (instancetype)valueCellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleValue];
}

+ (instancetype)plainHeaderConfiguration
{
    return [self charon_configurationWithStyle:CharonListStylePlainHeader];
}

+ (instancetype)plainFooterConfiguration
{
    return [self charon_configurationWithStyle:CharonListStylePlainFooter];
}

+ (instancetype)groupedHeaderConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleGroupedHeader];
}

+ (instancetype)groupedFooterConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleGroupedFooter];
}

+ (instancetype)sidebarCellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleSidebarCell];
}

+ (instancetype)sidebarSubtitleCellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleSidebarSubtitle];
}

+ (instancetype)accompaniedSidebarCellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleAccompaniedSidebar];
}

+ (instancetype)accompaniedSidebarSubtitleCellConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleAccompaniedSidebarSubtitle];
}

+ (instancetype)sidebarHeaderConfiguration
{
    return [self charon_configurationWithStyle:CharonListStyleSidebarHeader];
}

- (instancetype)initCharonWithStyle:(NSInteger)style
{
    if ((self = [super init])) {
        _style = style;
        _alpha = style == CharonListStyleBare ? 0 : 1;
        NSInteger textStyle = style == CharonListStyleBare ? CharonListStyleBare - 1 : style;
        _textProperties = [[UIListContentTextProperties alloc] initCharonWithStyle:textStyle secondary:NO];
        _secondaryTextProperties = [[UIListContentTextProperties alloc] initCharonWithStyle:textStyle secondary:YES];
        _imageProperties = style == CharonListStyleBare ? [[UIListContentImageProperties alloc] initCharonBare] : [[UIListContentImageProperties alloc] initCharonDefault];
        _axes = style == CharonListStyleBare ? 0 : UIAxisHorizontal;
        _horizontalPadding = style == CharonListStyleBare ? 0 : 8;
        _verticalPadding = 4;
        _imageToTextPadding = 16;
        switch (style) {
        case CharonListStyleBare:
            _verticalPadding = 0;
            _imageToTextPadding = 0;
            break;
        case CharonListStyleCell:
            _margins = NSDirectionalEdgeInsetsMake(15, 16, 15, 8);
            break;
        case CharonListStyleSubtitle:
            _margins = NSDirectionalEdgeInsetsMake(15, 16, 15, 8);
            _verticalPadding = 0;
            break;
        case CharonListStyleValue:
            _margins = NSDirectionalEdgeInsetsMake(15, 16, 15, 8);
            _sideBySide = YES;
            break;
        case CharonListStylePlainHeader:
        case CharonListStyleGroupedHeader:
        case CharonListStyleHeader:
            _margins = NSDirectionalEdgeInsetsMake(10, 8, 10, 8);
            break;
        case CharonListStylePlainFooter:
        case CharonListStyleGroupedFooter:
        case CharonListStyleFooter:
            _margins = NSDirectionalEdgeInsetsMake(8, 8, 6, 8);
            break;
        case CharonListStyleSidebarCell:
        case CharonListStyleAccompaniedSidebar:
        case CharonListStyleSidebarHeader:
            _margins = NSDirectionalEdgeInsetsMake(11, 8, 11, 8);
            _imageToTextPadding = 10;
            break;
        case CharonListStyleSidebarSubtitle:
        case CharonListStyleAccompaniedSidebarSubtitle:
            _margins = NSDirectionalEdgeInsetsMake(4, 8, 4, 8);
            _imageToTextPadding = 10;
            _verticalPadding = 0;
            break;
        }
    }
    return self;
}

- (instancetype)init
{
    return [self initCharonWithStyle:CharonListStyleBare];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initCharonWithStyle:(NSInteger)[coder decodeIntegerForKey:@"style"]])) {
        _image = [coder decodeObjectOfClass:[UIImage class] forKey:@"image"];
        _text = [coder decodeObjectOfClass:[NSString class] forKey:@"text"];
        _attributedText = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedText"];
        _secondaryText = [coder decodeObjectOfClass:[NSString class] forKey:@"secondaryText"];
        _secondaryAttributedText = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"secondaryAttributedText"];
        UIListContentTextProperties *text = [coder decodeObjectOfClass:[UIListContentTextProperties class] forKey:@"textProperties"];
        UIListContentTextProperties *secondary = [coder decodeObjectOfClass:[UIListContentTextProperties class] forKey:@"secondaryTextProperties"];
        UIListContentImageProperties *image = [coder decodeObjectOfClass:[UIListContentImageProperties class] forKey:@"imageProperties"];
        if (text)
            _textProperties = text;
        if (secondary)
            _secondaryTextProperties = secondary;
        if (image)
            _imageProperties = image;
        _axes = (UIAxis)[coder decodeIntegerForKey:@"axesPreservingSuperviewLayoutMargins"];
        _margins = NSDirectionalEdgeInsetsMake([coder decodeDoubleForKey:@"marginTop"], [coder decodeDoubleForKey:@"marginLeading"], [coder decodeDoubleForKey:@"marginBottom"],
                                               [coder decodeDoubleForKey:@"marginTrailing"]);
        _sideBySide = [coder decodeBoolForKey:@"prefersSideBySideTextAndSecondaryText"];
        _imageToTextPadding = (CGFloat)[coder decodeDoubleForKey:@"imageToTextPadding"];
        _horizontalPadding = (CGFloat)[coder decodeDoubleForKey:@"textToSecondaryTextHorizontalPadding"];
        _verticalPadding = (CGFloat)[coder decodeDoubleForKey:@"textToSecondaryTextVerticalPadding"];
        _alpha = (CGFloat)[coder decodeDoubleForKey:@"alpha"];
        [self charon_syncOwners];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"style"];
    [coder encodeObject:_image forKey:@"image"];
    [coder encodeObject:_text forKey:@"text"];
    [coder encodeObject:_attributedText forKey:@"attributedText"];
    [coder encodeObject:_secondaryText forKey:@"secondaryText"];
    [coder encodeObject:_secondaryAttributedText forKey:@"secondaryAttributedText"];
    [coder encodeObject:_textProperties forKey:@"textProperties"];
    [coder encodeObject:_secondaryTextProperties forKey:@"secondaryTextProperties"];
    [coder encodeObject:_imageProperties forKey:@"imageProperties"];
    [coder encodeInteger:_axes forKey:@"axesPreservingSuperviewLayoutMargins"];
    [coder encodeDouble:_margins.top forKey:@"marginTop"];
    [coder encodeDouble:_margins.leading forKey:@"marginLeading"];
    [coder encodeDouble:_margins.bottom forKey:@"marginBottom"];
    [coder encodeDouble:_margins.trailing forKey:@"marginTrailing"];
    [coder encodeBool:_sideBySide forKey:@"prefersSideBySideTextAndSecondaryText"];
    [coder encodeDouble:_imageToTextPadding forKey:@"imageToTextPadding"];
    [coder encodeDouble:_horizontalPadding forKey:@"textToSecondaryTextHorizontalPadding"];
    [coder encodeDouble:_verticalPadding forKey:@"textToSecondaryTextVerticalPadding"];
    [coder encodeDouble:_alpha forKey:@"alpha"];
}

- (void)charon_syncOwners
{
    [_textProperties charon_setOwnerText:_text ?: _attributedText.string];
    [_secondaryTextProperties charon_setOwnerText:_secondaryText ?: _secondaryAttributedText.string];
    [_imageProperties charon_setOwnerImage:_image];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIListContentConfiguration *copy = [[[self class] allocWithZone:zone] initCharonWithStyle:_style];
    copy->_image = _image;
    copy->_text = _text;
    copy->_attributedText = _attributedText;
    copy->_secondaryText = _secondaryText;
    copy->_secondaryAttributedText = _secondaryAttributedText;
    copy->_textProperties = [_textProperties copy];
    copy->_secondaryTextProperties = [_secondaryTextProperties copy];
    copy->_imageProperties = [_imageProperties copy];
    copy->_axes = _axes;
    copy->_margins = _margins;
    copy->_sideBySide = _sideBySide;
    copy->_imageToTextPadding = _imageToTextPadding;
    copy->_horizontalPadding = _horizontalPadding;
    copy->_verticalPadding = _verticalPadding;
    copy->_alpha = _alpha;
    return copy;
}

- (NSInteger)charon_style
{
    return _style;
}

- (BOOL)charon_isHeaderFooterStyle
{
    return _style >= CharonListStylePlainHeader && _style != CharonListStyleSidebarCell && !charon_is_sidebar_cell(_style) && _style != CharonListStyleSidebarHeader;
}

- (CGFloat)charon_alpha
{
    return _alpha;
}

// The public spelling of the alpha this object already stored, encoded, copied and applied.  The ivar, the
// -initCharonWithStyle: default (0 for a bare configuration, 1 otherwise), the NSCoding key, -copyWithZone:,
// -isEqual: and the three views UIListContentView.m sets the alpha on are all this file's own and all
// predate the accessors below; what 18.0 added is only that a caller can reach the value, and the storage
// it would write is the storage the drawing path already reads.  So the accessors are the same
// -image/-setImage:/ -textProperties pair this file already writes, and -charon_alpha is kept beside them
// because UIListContentView.m:187 reads it and the registry check counts selectors, not which of two
// spellings a caller prefers.
- (CGFloat)alpha
{
    return _alpha;
}

- (void)setAlpha:(CGFloat)alpha
{
    _alpha = alpha;
}

- (UIImage *)image
{
    return _image;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    [_imageProperties charon_setOwnerImage:image];
}

- (UIListContentImageProperties *)imageProperties
{
    return _imageProperties;
}

- (NSString *)text
{
    return _text;
}

- (void)setText:(NSString *)text
{
    _text = [text copy];
    if (text)
        _attributedText = nil;
    [_textProperties charon_setOwnerText:_text ?: _attributedText.string];
}

- (NSAttributedString *)attributedText
{
    return _attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    _attributedText = [attributedText copy];
    if (attributedText)
        _text = nil;
    [_textProperties charon_setOwnerText:_text ?: _attributedText.string];
}

- (UIListContentTextProperties *)textProperties
{
    return _textProperties;
}

- (NSString *)secondaryText
{
    return _secondaryText;
}

- (void)setSecondaryText:(NSString *)secondaryText
{
    _secondaryText = [secondaryText copy];
    if (secondaryText)
        _secondaryAttributedText = nil;
    [_secondaryTextProperties charon_setOwnerText:_secondaryText ?: _secondaryAttributedText.string];
}

- (NSAttributedString *)secondaryAttributedText
{
    return _secondaryAttributedText;
}

- (void)setSecondaryAttributedText:(NSAttributedString *)secondaryAttributedText
{
    _secondaryAttributedText = [secondaryAttributedText copy];
    if (secondaryAttributedText)
        _secondaryText = nil;
    [_secondaryTextProperties charon_setOwnerText:_secondaryText ?: _secondaryAttributedText.string];
}

- (UIListContentTextProperties *)secondaryTextProperties
{
    return _secondaryTextProperties;
}

- (UIAxis)axesPreservingSuperviewLayoutMargins
{
    return _axes;
}

- (void)setAxesPreservingSuperviewLayoutMargins:(UIAxis)axesPreservingSuperviewLayoutMargins
{
    _axes = axesPreservingSuperviewLayoutMargins;
}

- (NSDirectionalEdgeInsets)directionalLayoutMargins
{
    return _margins;
}

- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)directionalLayoutMargins
{
    _margins = directionalLayoutMargins;
}

- (BOOL)prefersSideBySideTextAndSecondaryText
{
    return _sideBySide;
}

- (void)setPrefersSideBySideTextAndSecondaryText:(BOOL)prefersSideBySideTextAndSecondaryText
{
    _sideBySide = prefersSideBySideTextAndSecondaryText;
}

- (CGFloat)imageToTextPadding
{
    return _imageToTextPadding;
}

- (void)setImageToTextPadding:(CGFloat)imageToTextPadding
{
    _imageToTextPadding = imageToTextPadding;
}

- (CGFloat)textToSecondaryTextHorizontalPadding
{
    return _horizontalPadding;
}

- (void)setTextToSecondaryTextHorizontalPadding:(CGFloat)textToSecondaryTextHorizontalPadding
{
    _horizontalPadding = textToSecondaryTextHorizontalPadding;
}

- (CGFloat)textToSecondaryTextVerticalPadding
{
    return _verticalPadding;
}

- (void)setTextToSecondaryTextVerticalPadding:(CGFloat)textToSecondaryTextVerticalPadding
{
    _verticalPadding = textToSecondaryTextVerticalPadding;
}

- (__kindof UIView<UIContentView> *)makeContentView
{
    return [[UIListContentView alloc] initWithConfiguration:self];
}

- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state
{
    UIListContentConfiguration *updated = [self copy];
    if (_style == CharonListStyleBare || ![(id)state isKindOfClass:[UIViewConfigurationState class]])
        return updated;
    UIViewConfigurationState *view = (UIViewConfigurationState *)state;
    UICellConfigurationState *cell = [view isKindOfClass:[UICellConfigurationState class]] ? (UICellConfigurationState *)view : nil;
    BOOL sidebar = charon_is_sidebar_cell(_style);
    BOOL sidebarLike = sidebar || _style == CharonListStyleSidebarHeader;
    BOOL faded = view.disabled && !cell.swiped;
    UIListContentTextProperties *text = updated->_textProperties, *secondary = updated->_secondaryTextProperties;
    UIListContentImageProperties *image = updated->_imageProperties;
    if (faded) {
        if (sidebarLike) {
            updated->_alpha = 0.5;
        } else {
            if (charon_is_plain_cell(_style)) {
                if (![text charon_colorCustomized])
                    [text charon_setDefaultColor:charon_semantic_color(CharonSemanticColorTertiaryLabel)];
                if (![secondary charon_colorCustomized])
                    [secondary charon_setDefaultColor:charon_semantic_color(CharonSemanticColorQuaternaryLabel)];
            }
            if (![image charon_tintCustomized])
                [image charon_setDefaultTintColor:charon_semantic_color(CharonSemanticColorTertiaryLabel)];
        }
    }
    BOOL targeted = cell.cellDropState == UICellConfigurationDropStateTargeted;
    BOOL fontLike = sidebar && !cell.editing && ((view.selected && !faded) || targeted) && !(view.focused && faded);
    BOOL whiteLike = sidebar && view.focused && ((view.selected && !cell.editing) || targeted) && !faded;
    if (fontLike && ![text charon_fontCustomized])
        [text charon_setDefaultFont:charon_medium_font(text.font.pointSize)];
    if (whiteLike) {
        if (![text charon_colorCustomized])
            [text charon_setDefaultColor:[UIColor whiteColor]];
        if (![secondary charon_colorCustomized])
            [secondary charon_setDefaultColor:[UIColor colorWithWhite:1 alpha:0.8]];
        if (![image charon_tintCustomized])
            [image charon_setDefaultTintColor:[UIColor whiteColor]];
    }
    if (view.highlighted && sidebarLike) {
        [text charon_setTransformerNamed:@"30% Alpha" block:charon_thirty_percent()];
        [secondary charon_setTransformerNamed:@"30% Alpha" block:charon_thirty_percent()];
        [image charon_setTransformerNamed:@"30% Alpha" block:charon_thirty_percent()];
    }
    return updated;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIListContentConfiguration class]])
        return NO;
    UIListContentConfiguration *other = object;
    return _style == other->_style && (_image == other->_image || [_image isEqual:other->_image]) && (_text == other->_text || [_text isEqual:other->_text]) &&
           (_attributedText == other->_attributedText || [_attributedText isEqual:other->_attributedText]) &&
           (_secondaryText == other->_secondaryText || [_secondaryText isEqual:other->_secondaryText]) &&
           (_secondaryAttributedText == other->_secondaryAttributedText || [_secondaryAttributedText isEqual:other->_secondaryAttributedText]) &&
           [_textProperties isEqual:other->_textProperties] && [_secondaryTextProperties isEqual:other->_secondaryTextProperties] && [_imageProperties isEqual:other->_imageProperties] &&
           _axes == other->_axes && NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(_margins, other->_margins) && _sideBySide == other->_sideBySide &&
           _imageToTextPadding == other->_imageToTextPadding && _horizontalPadding == other->_horizontalPadding && _verticalPadding == other->_verticalPadding && _alpha == other->_alpha;
}

- (NSUInteger)hash
{
    return (NSUInteger)_style ^ [_image hash] ^ ([_text hash] << 1) ^ ([_secondaryText hash] << 2) ^ ([_textProperties hash] << 3) ^ ([_secondaryTextProperties hash] << 4) ^
           ([_imageProperties hash] << 5) ^ (NSUInteger)(_imageToTextPadding * 31) ^ (NSUInteger)(_verticalPadding * 37) ^ (NSUInteger)(_margins.top * 41);
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (_image)
        [text appendFormat:@"; image = <UIImage: %p; anonymous>", _image];
    if (_text || _attributedText)
        [text appendFormat:@"; text = %@", charon_elided_text(_text ?: charon_attributed_text(_attributedText))];
    if (_secondaryText || _secondaryAttributedText)
        [text appendFormat:@"; secondaryText = %@", charon_elided_text(_secondaryText ?: charon_attributed_text(_secondaryAttributedText))];
    if (_alpha != 1)
        [text appendFormat:@"; alpha = %g", _alpha];
    [text appendFormat:@"; Base Style = %@", charon_style_name(_style)];
    if (!NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(_margins, NSDirectionalEdgeInsetsZero))
        [text appendFormat:@"; directionalLayoutMargins = %@", NSStringFromDirectionalEdgeInsets(_margins)];
    if (_axes)
        [text appendFormat:@"; axesPreservingSuperviewLayoutMargins = %@", charon_axes_text(_axes)];
    if (_sideBySide)
        [text appendString:@"; prefersSideBySideTextAndSecondaryText = YES"];
    [text appendFormat:@"; imageToTextPadding = %g", _imageToTextPadding];
    if (_sideBySide)
        [text appendFormat:@"; textToSecondaryTextHorizontalPadding = %g", _horizontalPadding];
    [text appendFormat:@"; textToSecondaryTextVerticalPadding = %g", _verticalPadding];
    [text appendString:@">"];
    return text;
}

@end
