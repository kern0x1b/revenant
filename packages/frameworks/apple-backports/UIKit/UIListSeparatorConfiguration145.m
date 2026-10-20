#import <UIKit/UIKit.h>
#import "RevenantLists.h"

static UIColor *revenant_separator_colour(void)
{
    return revenant_semantic_color(RevenantSemanticColorSeparator);
}

static UIColor *revenant_multiple_selection_separator_colour(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return revenant_separator_colour();
    }];
}

@implementation UIListSeparatorConfiguration {
@private
    UICollectionLayoutListAppearance _listAppearance;
    UIListSeparatorVisibility _topVisibility;
    UIListSeparatorVisibility _bottomVisibility;
    NSDirectionalEdgeInsets _topInsets;
    NSDirectionalEdgeInsets _bottomInsets;
    UIColor *_color;
    UIColor *_multipleSelectionColor;
}

@dynamic visualEffect;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithListAppearance:(UICollectionLayoutListAppearance)listAppearance
{
    if ((self = [super init])) {
        _listAppearance = listAppearance;
        _topVisibility = UIListSeparatorVisibilityAutomatic;
        _bottomVisibility = UIListSeparatorVisibilityAutomatic;
        _topInsets = UIListSeparatorAutomaticInsets;
        _bottomInsets = UIListSeparatorAutomaticInsets;
        _color = revenant_separator_colour();
        _multipleSelectionColor = revenant_multiple_selection_separator_colour();
    }
    return self;
}

- (UIListSeparatorVisibility)topSeparatorVisibility { return _topVisibility; }
- (void)setTopSeparatorVisibility:(UIListSeparatorVisibility)visibility { _topVisibility = visibility; }
- (UIListSeparatorVisibility)bottomSeparatorVisibility { return _bottomVisibility; }
- (void)setBottomSeparatorVisibility:(UIListSeparatorVisibility)visibility { _bottomVisibility = visibility; }
- (NSDirectionalEdgeInsets)topSeparatorInsets { return _topInsets; }
- (void)setTopSeparatorInsets:(NSDirectionalEdgeInsets)insets { _topInsets = insets; }
- (NSDirectionalEdgeInsets)bottomSeparatorInsets { return _bottomInsets; }
- (void)setBottomSeparatorInsets:(NSDirectionalEdgeInsets)insets { _bottomInsets = insets; }
- (UIColor *)color { return _color; }
- (void)setColor:(UIColor *)color { _color = color; }
- (UIColor *)multipleSelectionColor { return _multipleSelectionColor; }
- (void)setMultipleSelectionColor:(UIColor *)color { _multipleSelectionColor = color; }

- (id)copyWithZone:(NSZone *)zone
{
    UIListSeparatorConfiguration *copy = [[UIListSeparatorConfiguration allocWithZone:zone] initWithListAppearance:_listAppearance];
    copy.topSeparatorVisibility = _topVisibility;
    copy.bottomSeparatorVisibility = _bottomVisibility;
    copy.topSeparatorInsets = _topInsets;
    copy.bottomSeparatorInsets = _bottomInsets;
    copy.color = _color;
    copy.multipleSelectionColor = _multipleSelectionColor;
    if ([copy respondsToSelector:@selector(revenant_takeVisualEffectFrom:)])
        [copy revenant_takeVisualEffectFrom:self];
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIListSeparatorConfiguration class]])
        return NO;
    UIListSeparatorConfiguration *that = other;
    if (_topVisibility != that->_topVisibility || _bottomVisibility != that->_bottomVisibility)
        return NO;
    const NSDirectionalEdgeInsets *top = &_topInsets, *topOther = &that->_topInsets;
    if (top->leading != topOther->leading || top->top != topOther->top ||
        top->bottom != topOther->bottom || top->trailing != topOther->trailing)
        return NO;
    const NSDirectionalEdgeInsets *bottom = &_bottomInsets, *bottomOther = &that->_bottomInsets;
    if (bottom->leading != bottomOther->leading || bottom->top != bottomOther->top ||
        bottom->bottom != bottomOther->bottom || bottom->trailing != bottomOther->trailing)
        return NO;
    if (_color != that->_color && ![_color isEqual:that->_color])
        return NO;
    if (_multipleSelectionColor != that->_multipleSelectionColor && ![_multipleSelectionColor isEqual:that->_multipleSelectionColor])
        return NO;
    if ([self respondsToSelector:@selector(revenant_visualEffectIsEqualTo:)])
        return [self revenant_visualEffectIsEqualTo:that];
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)_topVisibility;
    hash = hash * 31 + (NSUInteger)_bottomVisibility;
    hash = hash * 31 + (NSUInteger)_bottomInsets.leading;
    hash = hash * 31 + (NSUInteger)_bottomInsets.top;
    hash = hash * 31 + (NSUInteger)_bottomInsets.bottom;
    hash = hash * 31 + (NSUInteger)_bottomInsets.trailing;
    hash = hash * 31 + _color.hash;
    hash = hash * 31 + _multipleSelectionColor.hash;
    return hash;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_topVisibility forKey:@"topSepVisibility"];
    [coder encodeInteger:_bottomVisibility forKey:@"bottomSepVisibility"];
    [coder encodeObject:[NSValue valueWithBytes:&_topInsets objCType:@encode(NSDirectionalEdgeInsets)]
                forKey:@"topSepInsets"];
    [coder encodeObject:[NSValue valueWithBytes:&_bottomInsets objCType:@encode(NSDirectionalEdgeInsets)]
                forKey:@"insets"];
    [coder encodeObject:_color forKey:@"color"];
    [coder encodeObject:_multipleSelectionColor forKey:@"multiSelectColor"];
    if ([self respondsToSelector:@selector(revenant_encodeVisualEffectWithCoder:)])
        [self revenant_encodeVisualEffectWithCoder:coder];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initWithListAppearance:(UICollectionLayoutListAppearance)0])) {
        _topVisibility = (UIListSeparatorVisibility)[coder decodeIntegerForKey:@"topSepVisibility"];
        _bottomVisibility = (UIListSeparatorVisibility)[coder decodeIntegerForKey:@"bottomSepVisibility"];
        NSValue *top = [coder decodeObjectOfClass:[NSValue class] forKey:@"topSepInsets"];
        if (top)
            [top getValue:&_topInsets];
        NSValue *bottom = [coder decodeObjectOfClass:[NSValue class] forKey:@"insets"];
        if (bottom)
            [bottom getValue:&_bottomInsets];
        UIColor *color = [coder decodeObjectOfClass:[UIColor class] forKey:@"color"];
        if (color)
            _color = color;
        UIColor *multiple = [coder decodeObjectOfClass:[UIColor class] forKey:@"multiSelectColor"];
        if (multiple)
            _multipleSelectionColor = multiple;
        if ([self respondsToSelector:@selector(revenant_decodeVisualEffectWithCoder:)])
            [self revenant_decodeVisualEffectWithCoder:coder];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UIListSeparatorConfiguration %p visibility: {top: %ld, bottom: %ld}, bottom insets: {l: %g, t: %g}>",
                                      self, (long)_topVisibility, (long)_bottomVisibility,
                                      (double)_bottomInsets.leading, (double)_bottomInsets.top];
}

@end
