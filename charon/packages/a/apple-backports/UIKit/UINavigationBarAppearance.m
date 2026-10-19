#import "CharonBarAppearance.h"

static NSString *const CharonTitle = @"title";
static NSString *const CharonLargeTitle = @"largeTitle";
static NSString *const CharonTitleOffset = @"titleOffset";

static void charon_require_appearance(id appearance)
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

- (void)charon_setUp
{
    [super charon_setUp];
    _custom = [[NSMutableDictionary alloc] init];
    _buttonAppearance = [[UIBarButtonItemAppearance alloc] initCharonWithStyle:0];
    _doneButtonAppearance = [[UIBarButtonItemAppearance alloc] initCharonWithStyle:2];
    _backButtonAppearance = [[UIBarButtonItemAppearance alloc] initCharonWithStyle:3];
    [_backButtonAppearance charon_becomeBackButtonBasedOn:_buttonAppearance];
    [self charon_adoptChildren];
    [self charon_configureTransparent];
}

- (void)charon_adoptChildren
{
    charon_adopt_child(self, _buttonAppearance);
    charon_adopt_child(self, _doneButtonAppearance);
    charon_adopt_child(self, _backButtonAppearance);
}

- (void)charon_copyExtrasFrom:(UIBarAppearance *)source
{
    if (![source isKindOfClass:[UINavigationBarAppearance class]])
        return;
    UINavigationBarAppearance *other = (UINavigationBarAppearance *)source;
    [_custom setDictionary:other->_custom];
    _buttonAppearance = [other->_buttonAppearance copy];
    _doneButtonAppearance = [other->_doneButtonAppearance copy];
    _backButtonAppearance = [other->_backButtonAppearance copy];
    [_backButtonAppearance charon_becomeBackButtonBasedOn:_buttonAppearance];
    [self charon_adoptChildren];
}

- (void)charon_encodeExtrasWithCoder:(NSCoder *)coder
{
    [coder encodeObject:charon_plist_pack(_custom) forKey:@"navigation"];
    [coder encodeObject:_buttonAppearance forKey:@"button"];
    [coder encodeObject:_doneButtonAppearance forKey:@"done"];
    [coder encodeObject:_backButtonAppearance forKey:@"back"];
}

- (void)charon_decodeExtrasWithCoder:(NSCoder *)coder
{
    NSDictionary *classes = @{CharonTitle: [NSDictionary class], CharonLargeTitle: [NSDictionary class], CharonTitleOffset: [NSArray class]};
    [_custom setDictionary:charon_sanitised(charon_plist_unpack([coder decodeObjectOfClasses:charon_plist_classes() forKey:@"navigation"]), classes, nil)];
    _buttonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"button"] ?: _buttonAppearance;
    _doneButtonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"done"] ?: _doneButtonAppearance;
    _backButtonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"back"] ?: _backButtonAppearance;
    [_backButtonAppearance charon_becomeBackButtonBasedOn:_buttonAppearance];
    [self charon_adoptChildren];
}

- (NSDictionary *)charon_titleCustom
{
    return _custom;
}

- (NSDictionary *)titleTextAttributes
{
    return charon_attributes_merge(@{NSForegroundColorAttributeName: charon_label_colour(), NSFontAttributeName: charon_font(17, UIFontWeightSemibold)}, _custom[CharonTitle]);
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    if (titleTextAttributes)
        _custom[CharonTitle] = [titleTextAttributes copy];
    else
        [_custom removeObjectForKey:CharonTitle];
    [self charon_notify];
}

- (NSDictionary *)largeTitleTextAttributes
{
    return charon_attributes_merge(@{NSForegroundColorAttributeName: charon_label_colour(), NSFontAttributeName: charon_font(34, UIFontWeightBold)}, _custom[CharonLargeTitle]);
}

- (void)setLargeTitleTextAttributes:(NSDictionary *)largeTitleTextAttributes
{
    if (largeTitleTextAttributes)
        _custom[CharonLargeTitle] = [largeTitleTextAttributes copy];
    else
        [_custom removeObjectForKey:CharonLargeTitle];
    [self charon_notify];
}

- (UIOffset)titlePositionAdjustment
{
    return charon_offset_unpack(_custom[CharonTitleOffset]);
}

- (void)setTitlePositionAdjustment:(UIOffset)titlePositionAdjustment
{
    if (UIOffsetEqualToOffset(titlePositionAdjustment, UIOffsetZero))
        [_custom removeObjectForKey:CharonTitleOffset];
    else
        _custom[CharonTitleOffset] = charon_offset_pack(titlePositionAdjustment);
    [self charon_notify];
}

- (UIBarButtonItemAppearance *)buttonAppearance
{
    return _buttonAppearance;
}

- (void)setButtonAppearance:(UIBarButtonItemAppearance *)buttonAppearance
{
    charon_require_appearance(buttonAppearance);
    _buttonAppearance = [buttonAppearance copy];
    [_backButtonAppearance charon_becomeBackButtonBasedOn:_buttonAppearance];
    [self charon_adoptChildren];
    [self charon_notify];
}

- (UIBarButtonItemAppearance *)doneButtonAppearance
{
    return _doneButtonAppearance;
}

- (void)setDoneButtonAppearance:(UIBarButtonItemAppearance *)doneButtonAppearance
{
    charon_require_appearance(doneButtonAppearance);
    _doneButtonAppearance = [doneButtonAppearance copy];
    [self charon_adoptChildren];
    [self charon_notify];
}

- (UIBarButtonItemAppearance *)backButtonAppearance
{
    return _backButtonAppearance;
}

- (void)setBackButtonAppearance:(UIBarButtonItemAppearance *)backButtonAppearance
{
    charon_require_appearance(backButtonAppearance);
    UIImage *image = [_backButtonAppearance charon_backIndicator], *mask = [_backButtonAppearance charon_backMask];
    _backButtonAppearance = [backButtonAppearance copy];
    [_backButtonAppearance charon_setBackIndicator:image mask:mask];
    [_backButtonAppearance charon_becomeBackButtonBasedOn:_buttonAppearance];
    [self charon_adoptChildren];
    [self charon_notify];
}

- (UIImage *)backIndicatorImage
{
    return [_backButtonAppearance charon_backIndicator] && [_backButtonAppearance charon_backMask] ? [_backButtonAppearance charon_backIndicator] : nil;
}

- (UIImage *)backIndicatorTransitionMaskImage
{
    return [_backButtonAppearance charon_backIndicator] && [_backButtonAppearance charon_backMask] ? [_backButtonAppearance charon_backMask] : nil;
}

- (void)setBackIndicatorImage:(UIImage *)backIndicatorImage transitionMaskImage:(UIImage *)backIndicatorTransitionMaskImage
{
    [_backButtonAppearance charon_setBackIndicator:backIndicatorImage mask:backIndicatorTransitionMaskImage];
}

- (void)configureWithDefaultBackground
{
    [self charon_configureTransparent];
}

- (NSArray *)charon_lines
{
    NSMutableString *title = [NSMutableString stringWithFormat:@"Title(%p): titleTextAttributes=%@", _custom, charon_attributes_text(_custom[CharonTitle] ? self.titleTextAttributes : nil)];
    if (_custom[CharonTitleOffset])
        [title appendFormat:@" titlePositionAdjustment=%@", charon_offset_text(_custom[CharonTitleOffset])];
    [title appendFormat:@" largeTitleTextAttributes=%@", charon_attributes_text(_custom[CharonLargeTitle] ? self.largeTitleTextAttributes : nil)];
    return [[super charon_lines] arrayByAddingObjectsFromArray:@[title,
        [NSString stringWithFormat:@"Plain BarButtonItems(%p): %@", _buttonAppearance, [_buttonAppearance charon_text]],
        [NSString stringWithFormat:@"Prominent BarButtonItems(%p): %@", _doneButtonAppearance, [_doneButtonAppearance charon_text]],
        [NSString stringWithFormat:@"Back Buttons(%p): %@", _backButtonAppearance, [_backButtonAppearance charon_text]]]];
}

- (NSArray *)charon_signature
{
    return [[super charon_signature] arrayByAddingObjectsFromArray:@[_custom, [_buttonAppearance charon_signature], [_doneButtonAppearance charon_signature], [_backButtonAppearance charon_signature]]];
}

@end
