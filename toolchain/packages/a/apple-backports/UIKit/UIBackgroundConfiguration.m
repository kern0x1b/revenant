#import "RevenantLists.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *revenant_background_style_name(NSInteger style)
{
    static NSString *const names[] = {@"Custom", @"List Plain Cell", @"List Plain Header/Footer", @"List Grouped Cell", @"List Grouped Header/Footer", @"List Grouped Header/Footer",
                                      @"List Sidebar Cell", @"List Accompanied Sidebar Cell", @"List Cell"};
    return style >= 0 && style < 9 ? names[style] : @"Custom";
}

static NSString *revenant_edges_text(NSDirectionalRectEdge edges)
{
    if (edges == NSDirectionalRectEdgeAll)
        return @"All";
    NSMutableArray *names = [NSMutableArray array];
    if (edges & NSDirectionalRectEdgeTop)
        [names addObject:@"Top"];
    if (edges & NSDirectionalRectEdgeLeading)
        [names addObject:@"Leading"];
    if (edges & NSDirectionalRectEdgeBottom)
        [names addObject:@"Bottom"];
    if (edges & NSDirectionalRectEdgeTrailing)
        [names addObject:@"Trailing"];
    return [NSString stringWithFormat:@"[%@]", [names componentsJoinedByString:@", "]];
}

static BOOL revenant_is_clear(UIColor *color)
{
    CGFloat white = 0, alpha = 1;
    return [color getWhite:&white alpha:&alpha] && white == 0 && alpha == 0;
}

static UIConfigurationColorTransformer revenant_alpha_block(CGFloat alpha)
{
    return ^UIColor *(UIColor *color) {
        return [color colorWithAlphaComponent:CGColorGetAlpha(color.CGColor) * alpha];
    };
}

@implementation UIBackgroundConfiguration {
@private
    NSInteger _style;
    UIView *_customView;
    CGFloat _cornerRadius;
    NSDirectionalEdgeInsets _backgroundInsets;
    NSDirectionalRectEdge _edges;
    UIColor *_backgroundColor;
    UIConfigurationColorTransformer _backgroundColorTransformer;
    NSString *_backgroundTransformerName;
    UIVisualEffect *_visualEffect;
    UIColor *_strokeColor;
    UIConfigurationColorTransformer _strokeColorTransformer;
    CGFloat _strokeWidth;
    CGFloat _strokeOutset;
    BOOL _colorCustomized;
    BOOL _transformerCustomized;
    BOOL _insetsCustomized;
    BOOL _cornerCustomized;
    UIImage *_image;
    UIViewContentMode _imageContentMode;
}

- (UIImage *)image
{
    return _image;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
}

- (UIViewContentMode)imageContentMode
{
    return _imageContentMode;
}

- (void)setImageContentMode:(UIViewContentMode)imageContentMode
{
    _imageContentMode = imageContentMode;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)revenant_configurationWithStyle:(NSInteger)style
{
    return [[UIBackgroundConfiguration alloc] initRevenantWithStyle:style];
}

+ (instancetype)clearConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleCustom];
}

+ (instancetype)listPlainCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListPlainCell];
}

+ (instancetype)listCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListCell];
}

+ (instancetype)listHeaderConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListPlainHeaderFooter];
}

+ (instancetype)listPlainHeaderFooterConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListPlainHeaderFooter];
}

+ (instancetype)listGroupedCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListGroupedCell];
}

+ (instancetype)listGroupedHeaderFooterConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListGroupedHeaderFooter];
}

+ (instancetype)listSidebarHeaderConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListSidebarHeader];
}

+ (instancetype)listSidebarCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListSidebarCell];
}

+ (instancetype)listAccompaniedSidebarCellConfiguration
{
    return [self revenant_configurationWithStyle:RevenantBackgroundStyleListAccompaniedSidebarCell];
}

- (instancetype)initRevenantWithStyle:(NSInteger)style
{
    if ((self = [super init])) {
        _style = style;
        _strokeColor = [UIColor clearColor];
        _backgroundColor = [UIColor clearColor];
        switch (style) {
        case RevenantBackgroundStyleListPlainCell:
        case RevenantBackgroundStyleListCell:
            _backgroundColor = revenant_semantic_color(RevenantSemanticColorSystemBackground);
            break;
        case RevenantBackgroundStyleListGroupedCell:
            _backgroundColor = revenant_semantic_color(RevenantSemanticColorSecondarySystemGroupedBackground);
            break;
        case RevenantBackgroundStyleListGroupedHeaderFooter:
        case RevenantBackgroundStyleListSidebarHeader:
        case RevenantBackgroundStyleListSidebarCell:
        case RevenantBackgroundStyleListAccompaniedSidebarCell:
            _cornerRadius = 26;
            break;
        }
    }
    return self;
}

- (instancetype)init
{
    if ((self = [self initRevenantWithStyle:RevenantBackgroundStyleCustom])) {
        _backgroundColor = nil;
        _strokeColor = nil;
        _colorCustomized = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initRevenantWithStyle:(NSInteger)[coder decodeIntegerForKey:@"style"]])) {
        _customView = [coder decodeObjectOfClass:[UIView class] forKey:@"customView"];
        _cornerRadius = (CGFloat)[coder decodeDoubleForKey:@"cornerRadius"];
        _backgroundInsets = NSDirectionalEdgeInsetsMake([coder decodeDoubleForKey:@"insetTop"], [coder decodeDoubleForKey:@"insetLeading"], [coder decodeDoubleForKey:@"insetBottom"],
                                                        [coder decodeDoubleForKey:@"insetTrailing"]);
        _edges = (NSDirectionalRectEdge)[coder decodeIntegerForKey:@"edgesAddingLayoutMarginsToBackgroundInsets"];
        _colorCustomized = [coder decodeBoolForKey:@"colorCustomized"];
        _backgroundColor = [coder containsValueForKey:@"backgroundColor"] ? [coder decodeObjectOfClass:[UIColor class] forKey:@"backgroundColor"] : nil;
        _visualEffect = [coder decodeObjectOfClass:[UIVisualEffect class] forKey:@"visualEffect"];
        _strokeColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"strokeColor"] ?: [UIColor clearColor];
        _strokeWidth = (CGFloat)[coder decodeDoubleForKey:@"strokeWidth"];
        _strokeOutset = (CGFloat)[coder decodeDoubleForKey:@"strokeOutset"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_style forKey:@"style"];
    [coder encodeObject:_customView forKey:@"customView"];
    [coder encodeDouble:_cornerRadius forKey:@"cornerRadius"];
    [coder encodeDouble:_backgroundInsets.top forKey:@"insetTop"];
    [coder encodeDouble:_backgroundInsets.leading forKey:@"insetLeading"];
    [coder encodeDouble:_backgroundInsets.bottom forKey:@"insetBottom"];
    [coder encodeDouble:_backgroundInsets.trailing forKey:@"insetTrailing"];
    [coder encodeInteger:(NSInteger)_edges forKey:@"edgesAddingLayoutMarginsToBackgroundInsets"];
    [coder encodeBool:_colorCustomized forKey:@"colorCustomized"];
    if (_backgroundColor)
        [coder encodeObject:_backgroundColor forKey:@"backgroundColor"];
    [coder encodeObject:_visualEffect forKey:@"visualEffect"];
    [coder encodeObject:_strokeColor forKey:@"strokeColor"];
    [coder encodeDouble:_strokeWidth forKey:@"strokeWidth"];
    [coder encodeDouble:_strokeOutset forKey:@"strokeOutset"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIBackgroundConfiguration *copy = [[[self class] allocWithZone:zone] initRevenantWithStyle:_style];
    copy->_customView = _customView;
    copy->_cornerRadius = _cornerRadius;
    copy->_backgroundInsets = _backgroundInsets;
    copy->_edges = _edges;
    copy->_backgroundColor = _backgroundColor;
    copy->_backgroundColorTransformer = [_backgroundColorTransformer copy];
    copy->_backgroundTransformerName = _backgroundTransformerName;
    copy->_visualEffect = [_visualEffect copy];
    copy->_strokeColor = _strokeColor;
    copy->_strokeColorTransformer = [_strokeColorTransformer copy];
    copy->_strokeWidth = _strokeWidth;
    copy->_strokeOutset = _strokeOutset;
    copy->_colorCustomized = _colorCustomized;
    copy->_transformerCustomized = _transformerCustomized;
    copy->_insetsCustomized = _insetsCustomized;
    copy->_cornerCustomized = _cornerCustomized;
    copy->_image = _image;
    copy->_imageContentMode = _imageContentMode;
    return copy;
}

- (NSInteger)revenant_style
{
    return _style;
}

- (UIView *)customView
{
    return _customView;
}

- (void)setCustomView:(UIView *)customView
{
    _customView = customView;
}

- (CGFloat)cornerRadius
{
    return _cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
    _cornerCustomized = YES;
}

- (NSDirectionalEdgeInsets)backgroundInsets
{
    return _backgroundInsets;
}

- (void)setBackgroundInsets:(NSDirectionalEdgeInsets)backgroundInsets
{
    _backgroundInsets = backgroundInsets;
    _insetsCustomized = YES;
}

- (NSDirectionalRectEdge)edgesAddingLayoutMarginsToBackgroundInsets
{
    return _edges;
}

- (void)setEdgesAddingLayoutMarginsToBackgroundInsets:(NSDirectionalRectEdge)edgesAddingLayoutMarginsToBackgroundInsets
{
    _edges = edgesAddingLayoutMarginsToBackgroundInsets;
}

- (UIColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
    _colorCustomized = YES;
}

- (UIConfigurationColorTransformer)backgroundColorTransformer
{
    return _backgroundColorTransformer;
}

- (void)setBackgroundColorTransformer:(UIConfigurationColorTransformer)backgroundColorTransformer
{
    _backgroundColorTransformer = [backgroundColorTransformer copy];
    _backgroundTransformerName = nil;
    _transformerCustomized = YES;
}

- (UIColor *)resolvedBackgroundColorForTintColor:(UIColor *)tintColor
{
    UIColor *base = _backgroundColor ?: tintColor;
    return _backgroundColorTransformer ? _backgroundColorTransformer(base) : base;
}

- (UIVisualEffect *)visualEffect
{
    return _visualEffect;
}

- (void)setVisualEffect:(UIVisualEffect *)visualEffect
{
    _visualEffect = [visualEffect copy];
}

- (UIColor *)strokeColor
{
    return _strokeColor;
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;
}

- (UIConfigurationColorTransformer)strokeColorTransformer
{
    return _strokeColorTransformer;
}

- (void)setStrokeColorTransformer:(UIConfigurationColorTransformer)strokeColorTransformer
{
    _strokeColorTransformer = [strokeColorTransformer copy];
}

- (UIColor *)resolvedStrokeColorForTintColor:(UIColor *)tintColor
{
    UIColor *base = _strokeColor ?: tintColor;
    return _strokeColorTransformer ? _strokeColorTransformer(base) : base;
}

- (CGFloat)strokeWidth
{
    return _strokeWidth;
}

- (void)setStrokeWidth:(CGFloat)strokeWidth
{
    _strokeWidth = strokeWidth;
}

- (CGFloat)strokeOutset
{
    return _strokeOutset;
}

- (void)setStrokeOutset:(CGFloat)strokeOutset
{
    _strokeOutset = strokeOutset;
}

- (UIColor *)revenant_styleColor
{
    switch (_style) {
    case RevenantBackgroundStyleListPlainCell:
    case RevenantBackgroundStyleListCell:
        return revenant_semantic_color(RevenantSemanticColorSystemBackground);
    case RevenantBackgroundStyleListGroupedCell:
        return revenant_semantic_color(RevenantSemanticColorSecondarySystemGroupedBackground);
    }
    return [UIColor clearColor];
}

- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state
{
    UIBackgroundConfiguration *updated = [self copy];
    if (![(id)state isKindOfClass:[UIViewConfigurationState class]])
        return updated;
    UIViewConfigurationState *view = (UIViewConfigurationState *)state;
    UICellConfigurationState *cell = [view isKindOfClass:[UICellConfigurationState class]] ? (UICellConfigurationState *)view : nil;
    BOOL plain = _style == RevenantBackgroundStyleListPlainCell || _style == RevenantBackgroundStyleListCell;
    BOOL grouped = _style == RevenantBackgroundStyleListGroupedCell;
    BOOL sidebar = _style == RevenantBackgroundStyleListSidebarCell || _style == RevenantBackgroundStyleListAccompaniedSidebarCell;
    BOOL header = _style == RevenantBackgroundStyleListGroupedHeaderFooter || _style == RevenantBackgroundStyleListSidebarHeader;
    if (!(plain || grouped || sidebar || header))
        return updated;
    BOOL selected = view.selected, highlighted = view.highlighted, focused = view.focused, swiped = cell.swiped, editing = cell.editing;
    BOOL targeted = cell.cellDropState == UICellConfigurationDropStateTargeted;
    BOOL faded = view.disabled && !swiped;
    UIColor *gray5 = [UIColor colorWithRed:229.0 / 255 green:229.0 / 255 blue:234.0 / 255 alpha:1];
    UIColor *gray2 = [UIColor colorWithRed:174.0 / 255 green:174.0 / 255 blue:178.0 / 255 alpha:1];
    UIColor *color = [self revenant_styleColor];
    CGFloat alpha = 0;
    NSString *name = nil;
    if (plain || grouped) {
        if (swiped && !_cornerCustomized)
            updated->_cornerRadius = 26;
        if (focused) {
            if (highlighted && targeted) {
                color = selected ? [UIColor colorWithRed:0 green:136.0 / 255 blue:1 alpha:1] : gray2;
            } else {
                color = nil;
            }
            if (!(highlighted && targeted)) {
                alpha = 0.12;
                name = @"Dynamic Light Alpha";
            }
        } else if (targeted && highlighted) {
            color = gray2;
        } else if (selected || targeted) {
            color = plain ? [UIColor colorWithWhite:220.0 / 255 alpha:1] : [UIColor whiteColor];
        } else if (swiped) {
            color = gray5;
        }
        if (cell.reordering && color)
            color = [color colorWithAlphaComponent:0.8];
    } else if (sidebar) {
        BOOL like = (selected && !editing) || targeted;
        if (like)
            color = revenant_semantic_color(RevenantSemanticColorQuaternarySystemFill);
        else if (swiped)
            color = gray5;
        if (focused && !(selected && (faded || editing) && !targeted))
            color = nil;
        if (targeted && !selected && !_insetsCustomized)
            updated->_backgroundInsets = NSDirectionalEdgeInsetsMake(1, 0, 1, 0);
        if (faded) {
            alpha = 0.5;
            name = @"50% Alpha";
        } else if (focused ? (like ? highlighted : !selected) : (highlighted && like)) {
            alpha = (!focused || like) ? 0.3 : 0.12;
            name = (!focused || like) ? @"30% Alpha" : @"Dynamic Light Alpha";
        }
    } else if (header && focused) {
        color = nil;
        alpha = 0.12;
        name = @"Dynamic Light Alpha";
    }
    if (!_colorCustomized)
        updated->_backgroundColor = color;
    if (!_transformerCustomized) {
        updated->_backgroundColorTransformer = alpha ? [revenant_alpha_block(alpha) copy] : nil;
        updated->_backgroundTransformerName = alpha ? name : nil;
    }
    return updated;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIBackgroundConfiguration class]])
        return NO;
    UIBackgroundConfiguration *other = object;
    return _style == other->_style && _customView == other->_customView && _cornerRadius == other->_cornerRadius &&
           NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(_backgroundInsets, other->_backgroundInsets) && _edges == other->_edges &&
           (_backgroundColor == other->_backgroundColor || [_backgroundColor isEqual:other->_backgroundColor]) &&
           (_backgroundColorTransformer == other->_backgroundColorTransformer || (_backgroundTransformerName && [_backgroundTransformerName isEqual:other->_backgroundTransformerName])) &&
           (_visualEffect == other->_visualEffect || [_visualEffect isEqual:other->_visualEffect]) && (_strokeColor == other->_strokeColor || [_strokeColor isEqual:other->_strokeColor]) &&
           _strokeColorTransformer == other->_strokeColorTransformer && _strokeWidth == other->_strokeWidth && _strokeOutset == other->_strokeOutset;
}

- (NSUInteger)hash
{
    return (NSUInteger)_style ^ [_backgroundColor hash] ^ ((NSUInteger)_cornerRadius << 3) ^ ((NSUInteger)_strokeWidth << 6) ^ [_customView hash] ^ (NSUInteger)(_backgroundInsets.top * 11);
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p; Base Style = %@", [self class], self, revenant_background_style_name(_style)];
    if (_cornerRadius)
        [text appendFormat:@"; cornerRadius = %g", _cornerRadius];
    if (!NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(_backgroundInsets, NSDirectionalEdgeInsetsZero))
        [text appendFormat:@"; backgroundInsets = %@", NSStringFromDirectionalEdgeInsets(_backgroundInsets)];
    if (_edges)
        [text appendFormat:@"; edgesAddingLayoutMarginsToBackgroundInsets = %@", revenant_edges_text(_edges)];
    BOOL showsColor = _backgroundColor ? !revenant_is_clear(_backgroundColor) : YES;
    if (_backgroundColor && showsColor)
        [text appendFormat:@"; backgroundColor = %@", _backgroundColor];
    else if (showsColor)
        [text appendString:@"; backgroundColor = Inherited Tint Color"];
    if (showsColor && _backgroundColorTransformer && _backgroundTransformerName.length)
        [text appendFormat:@"; backgroundColorTransformer = %@", _backgroundTransformerName];
    else if (showsColor && _backgroundColorTransformer && !_backgroundTransformerName)
        [text appendString:@"; backgroundColorTransformer = Custom"];
    if (_visualEffect)
        [text appendFormat:@"; visualEffect = %@", _visualEffect];
    if (_strokeWidth > 0 && (!_strokeColor || !revenant_is_clear(_strokeColor))) {
        [text appendFormat:@"; strokeColor = %@", _strokeColor ?: @"Inherited Tint Color"];
        if (_strokeColorTransformer)
            [text appendString:@"; strokeColorTransformer = Custom"];
        [text appendFormat:@"; strokeWidth = %g", _strokeWidth];
        if (_strokeOutset)
            [text appendFormat:@"; strokeOutset = %g", _strokeOutset];
    }
    if (_customView)
        [text appendFormat:@"; customView = %@", _customView];
    [text appendString:@">"];
    return text;
}

@end
