#import "RevenantLists.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *revenant_style_name(NSInteger style)
{
    static NSString *const names[] = {@"Cell", @"Cell", @"Subtitle Cell", @"Value Cell", @"Plain Header", @"Plain Footer", @"Grouped Header", @"Grouped Footer", @"Sidebar Cell",
                                      @"Sidebar Subtitle Cell", @"Accompanied Sidebar Cell", @"Accompanied Sidebar Subtitle Cell", @"Sidebar Header", @"Header", @"Footer"};
    return style >= 0 && style < 15 ? names[style] : @"Cell";
}

static BOOL revenant_is_sidebar_cell(NSInteger style)
{
    return style == RevenantListStyleSidebarCell || style == RevenantListStyleSidebarSubtitle || style == RevenantListStyleAccompaniedSidebar || style == RevenantListStyleAccompaniedSidebarSubtitle;
}

static BOOL revenant_is_plain_cell(NSInteger style)
{
    return style == RevenantListStyleCell || style == RevenantListStyleSubtitle || style == RevenantListStyleValue;
}

static NSString *revenant_axes_text(UIAxis axes)
{
    if (axes == (UIAxisHorizontal | UIAxisVertical))
        return @"Both";
    return axes == UIAxisVertical ? @"[Vertical]" : @"[Horizontal]";
}

static NSString *revenant_attributed_text(NSAttributedString *text)
{
    return text.string;
}

static UIConfigurationColorTransformer revenant_thirty_percent(void)
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

+ (instancetype)revenant_configurationWithStyle:(NSInteger)style
{
    return [[UIListContentConfiguration alloc] initRevenantWithStyle:style];
}

+ (instancetype)cellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleCell];
}

+ (instancetype)headerConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleHeader];
}

+ (instancetype)footerConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleFooter];
}

+ (instancetype)subtitleCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleSubtitle];
}

+ (instancetype)valueCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleValue];
}

+ (instancetype)plainHeaderConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStylePlainHeader];
}

+ (instancetype)plainFooterConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStylePlainFooter];
}

+ (instancetype)groupedHeaderConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleGroupedHeader];
}

+ (instancetype)groupedFooterConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleGroupedFooter];
}

+ (instancetype)sidebarCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleSidebarCell];
}

+ (instancetype)sidebarSubtitleCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleSidebarSubtitle];
}

+ (instancetype)accompaniedSidebarCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleAccompaniedSidebar];
}

+ (instancetype)accompaniedSidebarSubtitleCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleAccompaniedSidebarSubtitle];
}

+ (instancetype)sidebarHeaderConfiguration
{
    return [self revenant_configurationWithStyle:RevenantListStyleSidebarHeader];
}

- (instancetype)initRevenantWithStyle:(NSInteger)style
{
    if ((self = [super init])) {
        _style = style;
        _alpha = style == RevenantListStyleBare ? 0 : 1;
        NSInteger textStyle = style == RevenantListStyleBare ? RevenantListStyleBare - 1 : style;
        _textProperties = [[UIListContentTextProperties alloc] initRevenantWithStyle:textStyle secondary:NO];
        _secondaryTextProperties = [[UIListContentTextProperties alloc] initRevenantWithStyle:textStyle secondary:YES];
        _imageProperties = style == RevenantListStyleBare ? [[UIListContentImageProperties alloc] initRevenantBare] : [[UIListContentImageProperties alloc] initRevenantDefault];
        _axes = style == RevenantListStyleBare ? 0 : UIAxisHorizontal;
        _horizontalPadding = style == RevenantListStyleBare ? 0 : 8;
        _verticalPadding = 4;
        _imageToTextPadding = 16;
        switch (style) {
        case RevenantListStyleBare:
            _verticalPadding = 0;
            _imageToTextPadding = 0;
            break;
        case RevenantListStyleCell:
            _margins = NSDirectionalEdgeInsetsMake(15, 16, 15, 8);
            break;
        case RevenantListStyleSubtitle:
            _margins = NSDirectionalEdgeInsetsMake(15, 16, 15, 8);
            _verticalPadding = 0;
            break;
        case RevenantListStyleValue:
            _margins = NSDirectionalEdgeInsetsMake(15, 16, 15, 8);
            _sideBySide = YES;
            break;
        case RevenantListStylePlainHeader:
        case RevenantListStyleGroupedHeader:
        case RevenantListStyleHeader:
            _margins = NSDirectionalEdgeInsetsMake(10, 8, 10, 8);
            break;
        case RevenantListStylePlainFooter:
        case RevenantListStyleGroupedFooter:
        case RevenantListStyleFooter:
            _margins = NSDirectionalEdgeInsetsMake(8, 8, 6, 8);
            break;
        case RevenantListStyleSidebarCell:
        case RevenantListStyleAccompaniedSidebar:
        case RevenantListStyleSidebarHeader:
            _margins = NSDirectionalEdgeInsetsMake(11, 8, 11, 8);
            _imageToTextPadding = 10;
            break;
        case RevenantListStyleSidebarSubtitle:
        case RevenantListStyleAccompaniedSidebarSubtitle:
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
    return [self initRevenantWithStyle:RevenantListStyleBare];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initRevenantWithStyle:(NSInteger)[coder decodeIntegerForKey:@"style"]])) {
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
        [self revenant_syncOwners];
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

- (void)revenant_syncOwners
{
    [_textProperties revenant_setOwnerText:_text ?: _attributedText.string];
    [_secondaryTextProperties revenant_setOwnerText:_secondaryText ?: _secondaryAttributedText.string];
    [_imageProperties revenant_setOwnerImage:_image];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIListContentConfiguration *copy = [[[self class] allocWithZone:zone] initRevenantWithStyle:_style];
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

- (NSInteger)revenant_style
{
    return _style;
}

- (BOOL)revenant_isHeaderFooterStyle
{
    return _style >= RevenantListStylePlainHeader && _style != RevenantListStyleSidebarCell && !revenant_is_sidebar_cell(_style) && _style != RevenantListStyleSidebarHeader;
}

- (CGFloat)revenant_alpha
{
    return _alpha;
}

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
    [_imageProperties revenant_setOwnerImage:image];
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
    [_textProperties revenant_setOwnerText:_text ?: _attributedText.string];
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
    [_textProperties revenant_setOwnerText:_text ?: _attributedText.string];
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
    [_secondaryTextProperties revenant_setOwnerText:_secondaryText ?: _secondaryAttributedText.string];
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
    [_secondaryTextProperties revenant_setOwnerText:_secondaryText ?: _secondaryAttributedText.string];
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
    if (_style == RevenantListStyleBare || ![(id)state isKindOfClass:[UIViewConfigurationState class]])
        return updated;
    UIViewConfigurationState *view = (UIViewConfigurationState *)state;
    UICellConfigurationState *cell = [view isKindOfClass:[UICellConfigurationState class]] ? (UICellConfigurationState *)view : nil;
    BOOL sidebar = revenant_is_sidebar_cell(_style);
    BOOL sidebarLike = sidebar || _style == RevenantListStyleSidebarHeader;
    BOOL faded = view.disabled && !cell.swiped;
    UIListContentTextProperties *text = updated->_textProperties, *secondary = updated->_secondaryTextProperties;
    UIListContentImageProperties *image = updated->_imageProperties;
    if (faded) {
        if (sidebarLike) {
            updated->_alpha = 0.5;
        } else {
            if (revenant_is_plain_cell(_style)) {
                if (![text revenant_colorCustomized])
                    [text revenant_setDefaultColor:revenant_semantic_color(RevenantSemanticColorTertiaryLabel)];
                if (![secondary revenant_colorCustomized])
                    [secondary revenant_setDefaultColor:revenant_semantic_color(RevenantSemanticColorQuaternaryLabel)];
            }
            if (![image revenant_tintCustomized])
                [image revenant_setDefaultTintColor:revenant_semantic_color(RevenantSemanticColorTertiaryLabel)];
        }
    }
    BOOL targeted = cell.cellDropState == UICellConfigurationDropStateTargeted;
    BOOL fontLike = sidebar && !cell.editing && ((view.selected && !faded) || targeted) && !(view.focused && faded);
    BOOL whiteLike = sidebar && view.focused && ((view.selected && !cell.editing) || targeted) && !faded;
    if (fontLike && ![text revenant_fontCustomized])
        [text revenant_setDefaultFont:revenant_medium_font(text.font.pointSize)];
    if (whiteLike) {
        if (![text revenant_colorCustomized])
            [text revenant_setDefaultColor:[UIColor whiteColor]];
        if (![secondary revenant_colorCustomized])
            [secondary revenant_setDefaultColor:[UIColor colorWithWhite:1 alpha:0.8]];
        if (![image revenant_tintCustomized])
            [image revenant_setDefaultTintColor:[UIColor whiteColor]];
    }
    if (view.highlighted && sidebarLike) {
        [text revenant_setTransformerNamed:@"30% Alpha" block:revenant_thirty_percent()];
        [secondary revenant_setTransformerNamed:@"30% Alpha" block:revenant_thirty_percent()];
        [image revenant_setTransformerNamed:@"30% Alpha" block:revenant_thirty_percent()];
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
        [text appendFormat:@"; text = %@", revenant_elided_text(_text ?: revenant_attributed_text(_attributedText))];
    if (_secondaryText || _secondaryAttributedText)
        [text appendFormat:@"; secondaryText = %@", revenant_elided_text(_secondaryText ?: revenant_attributed_text(_secondaryAttributedText))];
    if (_alpha != 1)
        [text appendFormat:@"; alpha = %g", _alpha];
    [text appendFormat:@"; Base Style = %@", revenant_style_name(_style)];
    if (!NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(_margins, NSDirectionalEdgeInsetsZero))
        [text appendFormat:@"; directionalLayoutMargins = %@", NSStringFromDirectionalEdgeInsets(_margins)];
    if (_axes)
        [text appendFormat:@"; axesPreservingSuperviewLayoutMargins = %@", revenant_axes_text(_axes)];
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
