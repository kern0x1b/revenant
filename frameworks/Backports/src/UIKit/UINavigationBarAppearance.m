#import "RevenantBarAppearance.h"

static NSString *const RevenantTitle = @"title";
static NSString *const RevenantLargeTitle = @"largeTitle";
static NSString *const RevenantTitleOffset = @"titleOffset";

static void revenant_require_appearance(id appearance)
{
    if (!appearance)
        [NSException raise:NSInternalInconsistencyException format:@"use -[UIBarButtonItemAppearance configureWithDefaultForStyle:] to reset appearance values"];
}

@implementation UINavigationBarAppearance {
@private
    NSMutableDictionary *_custom;
    UIBarButtonItemAppearance *_buttonAppearance;
    UIBarButtonItemAppearance *_doneButtonAppearance;
    UIBarButtonItemAppearance *_backButtonAppearance;
}

- (void)revenant_setUp
{
    [super revenant_setUp];
    _custom = [[NSMutableDictionary alloc] init];
    _buttonAppearance = [[UIBarButtonItemAppearance alloc] initRevenantWithStyle:0];
    _doneButtonAppearance = [[UIBarButtonItemAppearance alloc] initRevenantWithStyle:2];
    _backButtonAppearance = [[UIBarButtonItemAppearance alloc] initRevenantWithStyle:3];
    [_backButtonAppearance revenant_becomeBackButtonBasedOn:_buttonAppearance];
    [self revenant_adoptChildren];
    [self revenant_configureTransparent];
}

- (void)revenant_adoptChildren
{
    revenant_adopt_child(self, _buttonAppearance);
    revenant_adopt_child(self, _doneButtonAppearance);
    revenant_adopt_child(self, _backButtonAppearance);
}

- (void)revenant_copyExtrasFrom:(UIBarAppearance *)source
{
    if (![source isKindOfClass:[UINavigationBarAppearance class]])
        return;
    UINavigationBarAppearance *other = (UINavigationBarAppearance *)source;
    [_custom setDictionary:other->_custom];
    _buttonAppearance = [other->_buttonAppearance copy];
    _doneButtonAppearance = [other->_doneButtonAppearance copy];
    _backButtonAppearance = [other->_backButtonAppearance copy];
    [_backButtonAppearance revenant_becomeBackButtonBasedOn:_buttonAppearance];
    [self revenant_adoptChildren];
}

- (void)revenant_encodeExtrasWithCoder:(NSCoder *)coder
{
    [coder encodeObject:revenant_plist_pack(_custom) forKey:@"navigation"];
    [coder encodeObject:_buttonAppearance forKey:@"button"];
    [coder encodeObject:_doneButtonAppearance forKey:@"done"];
    [coder encodeObject:_backButtonAppearance forKey:@"back"];
}

- (void)revenant_decodeExtrasWithCoder:(NSCoder *)coder
{
    NSDictionary *classes = @{RevenantTitle: [NSDictionary class], RevenantLargeTitle: [NSDictionary class], RevenantTitleOffset: [NSArray class]};
    [_custom setDictionary:revenant_sanitised(revenant_plist_unpack([coder decodeObjectOfClasses:revenant_plist_classes() forKey:@"navigation"]), classes, nil)];
    _buttonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"button"] ?: _buttonAppearance;
    _doneButtonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"done"] ?: _doneButtonAppearance;
    _backButtonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"back"] ?: _backButtonAppearance;
    [_backButtonAppearance revenant_becomeBackButtonBasedOn:_buttonAppearance];
    [self revenant_adoptChildren];
}

- (NSDictionary *)revenant_titleCustom
{
    return _custom;
}

- (NSDictionary *)titleTextAttributes
{
    return revenant_attributes_merge(@{NSForegroundColorAttributeName: revenant_label_colour(), NSFontAttributeName: revenant_font(17, UIFontWeightSemibold)}, _custom[RevenantTitle]);
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    if (titleTextAttributes)
        _custom[RevenantTitle] = [titleTextAttributes copy];
    else
        [_custom removeObjectForKey:RevenantTitle];
    [self revenant_notify];
}

- (NSDictionary *)largeTitleTextAttributes
{
    return revenant_attributes_merge(@{NSForegroundColorAttributeName: revenant_label_colour(), NSFontAttributeName: revenant_font(34, UIFontWeightBold)}, _custom[RevenantLargeTitle]);
}

- (void)setLargeTitleTextAttributes:(NSDictionary *)largeTitleTextAttributes
{
    if (largeTitleTextAttributes)
        _custom[RevenantLargeTitle] = [largeTitleTextAttributes copy];
    else
        [_custom removeObjectForKey:RevenantLargeTitle];
    [self revenant_notify];
}

- (UIOffset)titlePositionAdjustment
{
    return revenant_offset_unpack(_custom[RevenantTitleOffset]);
}

- (void)setTitlePositionAdjustment:(UIOffset)titlePositionAdjustment
{
    if (UIOffsetEqualToOffset(titlePositionAdjustment, UIOffsetZero))
        [_custom removeObjectForKey:RevenantTitleOffset];
    else
        _custom[RevenantTitleOffset] = revenant_offset_pack(titlePositionAdjustment);
    [self revenant_notify];
}

- (UIBarButtonItemAppearance *)buttonAppearance
{
    return _buttonAppearance;
}

- (void)setButtonAppearance:(UIBarButtonItemAppearance *)buttonAppearance
{
    revenant_require_appearance(buttonAppearance);
    _buttonAppearance = [buttonAppearance copy];
    [_backButtonAppearance revenant_becomeBackButtonBasedOn:_buttonAppearance];
    [self revenant_adoptChildren];
    [self revenant_notify];
}

- (UIBarButtonItemAppearance *)doneButtonAppearance
{
    return _doneButtonAppearance;
}

- (void)setDoneButtonAppearance:(UIBarButtonItemAppearance *)doneButtonAppearance
{
    revenant_require_appearance(doneButtonAppearance);
    _doneButtonAppearance = [doneButtonAppearance copy];
    [self revenant_adoptChildren];
    [self revenant_notify];
}

- (UIBarButtonItemAppearance *)backButtonAppearance
{
    return _backButtonAppearance;
}

- (void)setBackButtonAppearance:(UIBarButtonItemAppearance *)backButtonAppearance
{
    revenant_require_appearance(backButtonAppearance);
    UIImage *image = [_backButtonAppearance revenant_backIndicator], *mask = [_backButtonAppearance revenant_backMask];
    _backButtonAppearance = [backButtonAppearance copy];
    [_backButtonAppearance revenant_setBackIndicator:image mask:mask];
    [_backButtonAppearance revenant_becomeBackButtonBasedOn:_buttonAppearance];
    [self revenant_adoptChildren];
    [self revenant_notify];
}

- (UIImage *)backIndicatorImage
{
    return [_backButtonAppearance revenant_backIndicator] && [_backButtonAppearance revenant_backMask] ? [_backButtonAppearance revenant_backIndicator] : nil;
}

- (UIImage *)backIndicatorTransitionMaskImage
{
    return [_backButtonAppearance revenant_backIndicator] && [_backButtonAppearance revenant_backMask] ? [_backButtonAppearance revenant_backMask] : nil;
}

- (void)setBackIndicatorImage:(UIImage *)backIndicatorImage transitionMaskImage:(UIImage *)backIndicatorTransitionMaskImage
{
    [_backButtonAppearance revenant_setBackIndicator:backIndicatorImage mask:backIndicatorTransitionMaskImage];
}

- (void)configureWithDefaultBackground
{
    [self revenant_configureTransparent];
}

- (NSArray *)revenant_lines
{
    NSMutableString *title = [NSMutableString stringWithFormat:@"Title(%p): titleTextAttributes=%@", _custom, revenant_attributes_text(_custom[RevenantTitle] ? self.titleTextAttributes : nil)];
    if (_custom[RevenantTitleOffset])
        [title appendFormat:@" titlePositionAdjustment=%@", revenant_offset_text(_custom[RevenantTitleOffset])];
    [title appendFormat:@" largeTitleTextAttributes=%@", revenant_attributes_text(_custom[RevenantLargeTitle] ? self.largeTitleTextAttributes : nil)];
    return [[super revenant_lines] arrayByAddingObjectsFromArray:@[title,
        [NSString stringWithFormat:@"Plain BarButtonItems(%p): %@", _buttonAppearance, [_buttonAppearance revenant_text]],
        [NSString stringWithFormat:@"Prominent BarButtonItems(%p): %@", _doneButtonAppearance, [_doneButtonAppearance revenant_text]],
        [NSString stringWithFormat:@"Back Buttons(%p): %@", _backButtonAppearance, [_backButtonAppearance revenant_text]]]];
}

- (NSArray *)revenant_signature
{
    return [[super revenant_signature] arrayByAddingObjectsFromArray:@[_custom, [_buttonAppearance revenant_signature], [_doneButtonAppearance revenant_signature], [_backButtonAppearance revenant_signature]]];
}

@end
