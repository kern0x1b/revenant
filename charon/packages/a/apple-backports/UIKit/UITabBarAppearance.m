#import "CharonBarAppearance.h"

static NSString *const CharonTint = @"tint";
static NSString *const CharonIndicator = @"indicator";
static NSString *const CharonPositioning = @"positioning";
static NSString *const CharonWidth = @"width";
static NSString *const CharonSpacing = @"spacing";

static void charon_require_appearance(id appearance)
{
    if (!appearance)
        [NSException raise:NSInternalInconsistencyException format:@"Use -[UITabBarItemAppearance configureWithDefaultForStyle:] to reset"];
}

@implementation UITabBarAppearance {
@private
    NSMutableDictionary *_layout;
    UITabBarItemAppearance *_stackedLayoutAppearance;
    UITabBarItemAppearance *_inlineLayoutAppearance;
    UITabBarItemAppearance *_compactInlineLayoutAppearance;
}

- (void)charon_setUp
{
    [super charon_setUp];
    _layout = [[NSMutableDictionary alloc] init];
    _stackedLayoutAppearance = [[UITabBarItemAppearance alloc] initCharonWithStyle:0];
    _inlineLayoutAppearance = [[UITabBarItemAppearance alloc] initCharonWithStyle:1];
    _compactInlineLayoutAppearance = [[UITabBarItemAppearance alloc] initCharonWithStyle:2];
    [self charon_adoptChildren];
}

- (void)charon_adoptChildren
{
    charon_adopt_child(self, _stackedLayoutAppearance);
    charon_adopt_child(self, _inlineLayoutAppearance);
    charon_adopt_child(self, _compactInlineLayoutAppearance);
}

- (void)charon_copyExtrasFrom:(UIBarAppearance *)source
{
    if (![source isKindOfClass:[UITabBarAppearance class]])
        return;
    UITabBarAppearance *other = (UITabBarAppearance *)source;
    [_layout setDictionary:other->_layout];
    _stackedLayoutAppearance = [other->_stackedLayoutAppearance copy];
    _inlineLayoutAppearance = [other->_inlineLayoutAppearance copy];
    _compactInlineLayoutAppearance = [other->_compactInlineLayoutAppearance copy];
    [self charon_adoptChildren];
}

- (void)charon_encodeExtrasWithCoder:(NSCoder *)coder
{
    [coder encodeObject:charon_plist_pack(_layout) forKey:@"layout"];
    [coder encodeObject:_stackedLayoutAppearance forKey:@"stacked"];
    [coder encodeObject:_inlineLayoutAppearance forKey:@"inline"];
    [coder encodeObject:_compactInlineLayoutAppearance forKey:@"compactInline"];
}

- (void)charon_decodeExtrasWithCoder:(NSCoder *)coder
{
    NSDictionary *classes = @{CharonTint: [UIColor class], CharonIndicator: [UIImage class], CharonPositioning: [NSNumber class], CharonWidth: [NSNumber class], CharonSpacing: [NSNumber class]};
    [_layout setDictionary:charon_sanitised(charon_plist_unpack([coder decodeObjectOfClasses:charon_plist_classes() forKey:@"layout"]), classes, nil)];
    _stackedLayoutAppearance = [coder decodeObjectOfClass:[UITabBarItemAppearance class] forKey:@"stacked"] ?: _stackedLayoutAppearance;
    _inlineLayoutAppearance = [coder decodeObjectOfClass:[UITabBarItemAppearance class] forKey:@"inline"] ?: _inlineLayoutAppearance;
    _compactInlineLayoutAppearance = [coder decodeObjectOfClass:[UITabBarItemAppearance class] forKey:@"compactInline"] ?: _compactInlineLayoutAppearance;
    [self charon_adoptChildren];
}

- (UITabBarItemAppearance *)stackedLayoutAppearance
{
    return _stackedLayoutAppearance;
}

- (void)setStackedLayoutAppearance:(UITabBarItemAppearance *)stackedLayoutAppearance
{
    charon_require_appearance(stackedLayoutAppearance);
    _stackedLayoutAppearance = [stackedLayoutAppearance copy];
    [self charon_adoptChildren];
    [self charon_notify];
}

- (UITabBarItemAppearance *)inlineLayoutAppearance
{
    return _inlineLayoutAppearance;
}

- (void)setInlineLayoutAppearance:(UITabBarItemAppearance *)inlineLayoutAppearance
{
    charon_require_appearance(inlineLayoutAppearance);
    _inlineLayoutAppearance = [inlineLayoutAppearance copy];
    [self charon_adoptChildren];
    [self charon_notify];
}

- (UITabBarItemAppearance *)compactInlineLayoutAppearance
{
    return _compactInlineLayoutAppearance;
}

- (void)setCompactInlineLayoutAppearance:(UITabBarItemAppearance *)compactInlineLayoutAppearance
{
    charon_require_appearance(compactInlineLayoutAppearance);
    _compactInlineLayoutAppearance = [compactInlineLayoutAppearance copy];
    [self charon_adoptChildren];
    [self charon_notify];
}

- (UIColor *)selectionIndicatorTintColor
{
    return _layout[CharonTint];
}

- (void)setSelectionIndicatorTintColor:(UIColor *)selectionIndicatorTintColor
{
    if (selectionIndicatorTintColor)
        _layout[CharonTint] = [selectionIndicatorTintColor copy];
    else
        [_layout removeObjectForKey:CharonTint];
    [self charon_notify];
}

- (UIImage *)selectionIndicatorImage
{
    return _layout[CharonIndicator];
}

- (void)setSelectionIndicatorImage:(UIImage *)selectionIndicatorImage
{
    if (selectionIndicatorImage)
        _layout[CharonIndicator] = selectionIndicatorImage;
    else
        [_layout removeObjectForKey:CharonIndicator];
    [self charon_notify];
}

- (void)charon_setNumber:(double)value key:(NSString *)key
{
    if (value != 0)
        _layout[key] = @(value);
    else
        [_layout removeObjectForKey:key];
    [self charon_notify];
}

- (UITabBarItemPositioning)stackedItemPositioning
{
    return (UITabBarItemPositioning)[_layout[CharonPositioning] integerValue];
}

- (void)setStackedItemPositioning:(UITabBarItemPositioning)stackedItemPositioning
{
    [self charon_setNumber:stackedItemPositioning key:CharonPositioning];
}

- (CGFloat)stackedItemWidth
{
    return [_layout[CharonWidth] doubleValue];
}

- (void)setStackedItemWidth:(CGFloat)stackedItemWidth
{
    [self charon_setNumber:stackedItemWidth key:CharonWidth];
}

- (CGFloat)stackedItemSpacing
{
    return [_layout[CharonSpacing] doubleValue];
}

- (void)setStackedItemSpacing:(CGFloat)stackedItemSpacing
{
    [self charon_setNumber:stackedItemSpacing key:CharonSpacing];
}

- (NSArray *)charon_lines
{
    NSArray *positioning = @[@"automatic", @"fill", @"centered"];
    NSInteger mode = [_layout[CharonPositioning] integerValue];
    NSMutableString *layout = [NSMutableString stringWithFormat:@"ItemLayout(%p): positioning=%@", _layout, mode >= 0 && mode < 3 ? positioning[mode] : [NSString stringWithFormat:@"unknown(%ld)", (long)mode]];
    if (_layout[CharonIndicator])
        [layout appendFormat:@" selectionIndicatorImage=%@", _layout[CharonIndicator]];
    if (_layout[CharonTint])
        [layout appendFormat:@" selectionIndicatorTintColor=%@", _layout[CharonTint]];
    if ([_layout[CharonWidth] doubleValue] > 0)
        [layout appendFormat:@" itemWidth=%f", [_layout[CharonWidth] doubleValue]];
    if ([_layout[CharonSpacing] doubleValue] > 0)
        [layout appendFormat:@" itemSpacing=%f", [_layout[CharonSpacing] doubleValue]];
    return [[super charon_lines] arrayByAddingObjectsFromArray:@[
        [NSString stringWithFormat:@"StackedItemAppearance(%p): %@", _stackedLayoutAppearance, [_stackedLayoutAppearance charon_text]],
        [NSString stringWithFormat:@"InlineItemAppearance(%p): %@", _inlineLayoutAppearance, [_inlineLayoutAppearance charon_text]],
        [NSString stringWithFormat:@"CompactInlineItemAppearance(%p): %@", _compactInlineLayoutAppearance, [_compactInlineLayoutAppearance charon_text]], layout]];
}

- (NSArray *)charon_signature
{
    return [[super charon_signature] arrayByAddingObjectsFromArray:@[self.selectionIndicatorTintColor ?: [NSNull null], self.selectionIndicatorImage ?: [NSNull null], @(self.stackedItemPositioning), @(self.stackedItemWidth), @(self.stackedItemSpacing), [_stackedLayoutAppearance charon_signature], [_inlineLayoutAppearance charon_signature],
                                                                     [_compactInlineLayoutAppearance charon_signature]]];
}

@end
