#import "RevenantBarAppearance.h"

static NSString *const RevenantTint = @"tint";
static NSString *const RevenantIndicator = @"indicator";
static NSString *const RevenantPositioning = @"positioning";
static NSString *const RevenantWidth = @"width";
static NSString *const RevenantSpacing = @"spacing";

static void revenant_require_appearance(id appearance)
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

- (void)revenant_setUp
{
    [super revenant_setUp];
    _layout = [[NSMutableDictionary alloc] init];
    _stackedLayoutAppearance = [[UITabBarItemAppearance alloc] initRevenantWithStyle:0];
    _inlineLayoutAppearance = [[UITabBarItemAppearance alloc] initRevenantWithStyle:1];
    _compactInlineLayoutAppearance = [[UITabBarItemAppearance alloc] initRevenantWithStyle:2];
    [self revenant_adoptChildren];
}

- (void)revenant_adoptChildren
{
    revenant_adopt_child(self, _stackedLayoutAppearance);
    revenant_adopt_child(self, _inlineLayoutAppearance);
    revenant_adopt_child(self, _compactInlineLayoutAppearance);
}

- (void)revenant_copyExtrasFrom:(UIBarAppearance *)source
{
    if (![source isKindOfClass:[UITabBarAppearance class]])
        return;
    UITabBarAppearance *other = (UITabBarAppearance *)source;
    [_layout setDictionary:other->_layout];
    _stackedLayoutAppearance = [other->_stackedLayoutAppearance copy];
    _inlineLayoutAppearance = [other->_inlineLayoutAppearance copy];
    _compactInlineLayoutAppearance = [other->_compactInlineLayoutAppearance copy];
    [self revenant_adoptChildren];
}

- (void)revenant_encodeExtrasWithCoder:(NSCoder *)coder
{
    [coder encodeObject:revenant_plist_pack(_layout) forKey:@"layout"];
    [coder encodeObject:_stackedLayoutAppearance forKey:@"stacked"];
    [coder encodeObject:_inlineLayoutAppearance forKey:@"inline"];
    [coder encodeObject:_compactInlineLayoutAppearance forKey:@"compactInline"];
}

- (void)revenant_decodeExtrasWithCoder:(NSCoder *)coder
{
    NSDictionary *classes = @{RevenantTint: [UIColor class], RevenantIndicator: [UIImage class], RevenantPositioning: [NSNumber class], RevenantWidth: [NSNumber class], RevenantSpacing: [NSNumber class]};
    [_layout setDictionary:revenant_sanitised(revenant_plist_unpack([coder decodeObjectOfClasses:revenant_plist_classes() forKey:@"layout"]), classes, nil)];
    _stackedLayoutAppearance = [coder decodeObjectOfClass:[UITabBarItemAppearance class] forKey:@"stacked"] ?: _stackedLayoutAppearance;
    _inlineLayoutAppearance = [coder decodeObjectOfClass:[UITabBarItemAppearance class] forKey:@"inline"] ?: _inlineLayoutAppearance;
    _compactInlineLayoutAppearance = [coder decodeObjectOfClass:[UITabBarItemAppearance class] forKey:@"compactInline"] ?: _compactInlineLayoutAppearance;
    [self revenant_adoptChildren];
}

- (UITabBarItemAppearance *)stackedLayoutAppearance
{
    return _stackedLayoutAppearance;
}

- (void)setStackedLayoutAppearance:(UITabBarItemAppearance *)stackedLayoutAppearance
{
    revenant_require_appearance(stackedLayoutAppearance);
    _stackedLayoutAppearance = [stackedLayoutAppearance copy];
    [self revenant_adoptChildren];
    [self revenant_notify];
}

- (UITabBarItemAppearance *)inlineLayoutAppearance
{
    return _inlineLayoutAppearance;
}

- (void)setInlineLayoutAppearance:(UITabBarItemAppearance *)inlineLayoutAppearance
{
    revenant_require_appearance(inlineLayoutAppearance);
    _inlineLayoutAppearance = [inlineLayoutAppearance copy];
    [self revenant_adoptChildren];
    [self revenant_notify];
}

- (UITabBarItemAppearance *)compactInlineLayoutAppearance
{
    return _compactInlineLayoutAppearance;
}

- (void)setCompactInlineLayoutAppearance:(UITabBarItemAppearance *)compactInlineLayoutAppearance
{
    revenant_require_appearance(compactInlineLayoutAppearance);
    _compactInlineLayoutAppearance = [compactInlineLayoutAppearance copy];
    [self revenant_adoptChildren];
    [self revenant_notify];
}

- (UIColor *)selectionIndicatorTintColor
{
    return _layout[RevenantTint];
}

- (void)setSelectionIndicatorTintColor:(UIColor *)selectionIndicatorTintColor
{
    if (selectionIndicatorTintColor)
        _layout[RevenantTint] = [selectionIndicatorTintColor copy];
    else
        [_layout removeObjectForKey:RevenantTint];
    [self revenant_notify];
}

- (UIImage *)selectionIndicatorImage
{
    return _layout[RevenantIndicator];
}

- (void)setSelectionIndicatorImage:(UIImage *)selectionIndicatorImage
{
    if (selectionIndicatorImage)
        _layout[RevenantIndicator] = selectionIndicatorImage;
    else
        [_layout removeObjectForKey:RevenantIndicator];
    [self revenant_notify];
}

- (void)revenant_setNumber:(double)value key:(NSString *)key
{
    if (value != 0)
        _layout[key] = @(value);
    else
        [_layout removeObjectForKey:key];
    [self revenant_notify];
}

- (UITabBarItemPositioning)stackedItemPositioning
{
    return (UITabBarItemPositioning)[_layout[RevenantPositioning] integerValue];
}

- (void)setStackedItemPositioning:(UITabBarItemPositioning)stackedItemPositioning
{
    [self revenant_setNumber:stackedItemPositioning key:RevenantPositioning];
}

- (CGFloat)stackedItemWidth
{
    return [_layout[RevenantWidth] doubleValue];
}

- (void)setStackedItemWidth:(CGFloat)stackedItemWidth
{
    [self revenant_setNumber:stackedItemWidth key:RevenantWidth];
}

- (CGFloat)stackedItemSpacing
{
    return [_layout[RevenantSpacing] doubleValue];
}

- (void)setStackedItemSpacing:(CGFloat)stackedItemSpacing
{
    [self revenant_setNumber:stackedItemSpacing key:RevenantSpacing];
}

- (NSArray *)revenant_lines
{
    NSArray *positioning = @[@"automatic", @"fill", @"centered"];
    NSInteger mode = [_layout[RevenantPositioning] integerValue];
    NSMutableString *layout = [NSMutableString stringWithFormat:@"ItemLayout(%p): positioning=%@", _layout, mode >= 0 && mode < 3 ? positioning[mode] : [NSString stringWithFormat:@"unknown(%ld)", (long)mode]];
    if (_layout[RevenantIndicator])
        [layout appendFormat:@" selectionIndicatorImage=%@", _layout[RevenantIndicator]];
    if (_layout[RevenantTint])
        [layout appendFormat:@" selectionIndicatorTintColor=%@", _layout[RevenantTint]];
    if ([_layout[RevenantWidth] doubleValue] > 0)
        [layout appendFormat:@" itemWidth=%f", [_layout[RevenantWidth] doubleValue]];
    if ([_layout[RevenantSpacing] doubleValue] > 0)
        [layout appendFormat:@" itemSpacing=%f", [_layout[RevenantSpacing] doubleValue]];
    return [[super revenant_lines] arrayByAddingObjectsFromArray:@[
        [NSString stringWithFormat:@"StackedItemAppearance(%p): %@", _stackedLayoutAppearance, [_stackedLayoutAppearance revenant_text]],
        [NSString stringWithFormat:@"InlineItemAppearance(%p): %@", _inlineLayoutAppearance, [_inlineLayoutAppearance revenant_text]],
        [NSString stringWithFormat:@"CompactInlineItemAppearance(%p): %@", _compactInlineLayoutAppearance, [_compactInlineLayoutAppearance revenant_text]], layout]];
}

- (NSArray *)revenant_signature
{
    return [[super revenant_signature] arrayByAddingObjectsFromArray:@[self.selectionIndicatorTintColor ?: [NSNull null], self.selectionIndicatorImage ?: [NSNull null], @(self.stackedItemPositioning), @(self.stackedItemWidth), @(self.stackedItemSpacing), [_stackedLayoutAppearance revenant_signature], [_inlineLayoutAppearance revenant_signature],
                                                                     [_compactInlineLayoutAppearance revenant_signature]]];
}

@end
