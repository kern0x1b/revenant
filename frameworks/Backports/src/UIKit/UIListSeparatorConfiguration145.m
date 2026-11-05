#import <UIKit/UIKit.h>
#import "RevenantLists.h"

static UIColor *revenant_separator_colour(void)
{
    return revenant_semantic_color(RevenantSemanticColorSeparator);
}

static BOOL revenant_same_insets(NSDirectionalEdgeInsets a, NSDirectionalEdgeInsets b)
{
    return a.top == b.top && a.leading == b.leading && a.bottom == b.bottom && a.trailing == b.trailing;
}

@implementation UIListSeparatorConfiguration {
@private
    UICollectionLayoutListAppearance _listAppearance;
    UIListSeparatorVisibility _topVisibility;
    UIListSeparatorVisibility _bottomVisibility;
    NSDirectionalEdgeInsets _topInsets;
    NSDirectionalEdgeInsets _bottomInsets;
    UIColor *_color;
}

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

- (id)copyWithZone:(NSZone *)zone
{
    UIListSeparatorConfiguration *copy = [[UIListSeparatorConfiguration allocWithZone:zone] initWithListAppearance:_listAppearance];
    copy.topSeparatorVisibility = _topVisibility;
    copy.bottomSeparatorVisibility = _bottomVisibility;
    copy.topSeparatorInsets = _topInsets;
    copy.bottomSeparatorInsets = _bottomInsets;
    copy.color = _color;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIListSeparatorConfiguration class]])
        return NO;
    UIListSeparatorConfiguration *that = other;
    return _topVisibility == that->_topVisibility && _bottomVisibility == that->_bottomVisibility
        && revenant_same_insets(_topInsets, that->_topInsets) && revenant_same_insets(_bottomInsets, that->_bottomInsets)
        && (_color == that->_color || [_color isEqual:that->_color]);
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)_topVisibility;
    hash = hash * 31 + (NSUInteger)_bottomVisibility;
    hash = hash * 31 + (NSUInteger)_topInsets.leading;
    hash = hash * 31 + (NSUInteger)_bottomInsets.leading;
    hash = hash * 31 + _color.hash;
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
