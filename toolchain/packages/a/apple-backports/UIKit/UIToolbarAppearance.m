#import "RevenantBarAppearance.h"

static void revenant_require_appearance(id appearance)
{
    if (!appearance)
        [NSException raise:NSInternalInconsistencyException format:@"use -[UIBarButtonItemAppearance setupDefaultAppearanceForStyle:] to reset appearance values"];
}

@implementation UIToolbarAppearance {
@private
    UIBarButtonItemAppearance *_buttonAppearance;
    UIBarButtonItemAppearance *_doneButtonAppearance;
}

- (void)revenant_setUp
{
    [super revenant_setUp];
    _buttonAppearance = [[UIBarButtonItemAppearance alloc] initRevenantWithStyle:0];
    _doneButtonAppearance = [[UIBarButtonItemAppearance alloc] initRevenantWithStyle:2];
    [self revenant_adoptChildren];
}

- (void)revenant_adoptChildren
{
    revenant_adopt_child(self, _buttonAppearance);
    revenant_adopt_child(self, _doneButtonAppearance);
}

- (void)revenant_copyExtrasFrom:(UIBarAppearance *)source
{
    if (![source isKindOfClass:[UIToolbarAppearance class]])
        return;
    UIToolbarAppearance *other = (UIToolbarAppearance *)source;
    _buttonAppearance = [other->_buttonAppearance copy];
    _doneButtonAppearance = [other->_doneButtonAppearance copy];
    [self revenant_adoptChildren];
}

- (void)revenant_encodeExtrasWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_buttonAppearance forKey:@"button"];
    [coder encodeObject:_doneButtonAppearance forKey:@"done"];
}

- (void)revenant_decodeExtrasWithCoder:(NSCoder *)coder
{
    _buttonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"button"] ?: _buttonAppearance;
    _doneButtonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"done"] ?: _doneButtonAppearance;
    [self revenant_adoptChildren];
}

- (UIBarButtonItemAppearance *)buttonAppearance
{
    return _buttonAppearance;
}

- (void)setButtonAppearance:(UIBarButtonItemAppearance *)buttonAppearance
{
    revenant_require_appearance(buttonAppearance);
    _buttonAppearance = [buttonAppearance copy];
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

- (NSArray *)revenant_lines
{
    return [[super revenant_lines] arrayByAddingObjectsFromArray:@[[NSString stringWithFormat:@"Plain BarButtonItems(%p): %@", _buttonAppearance, [_buttonAppearance revenant_text]],
                                                                 [NSString stringWithFormat:@"Prominent BarButtonItems(%p): %@", _doneButtonAppearance, [_doneButtonAppearance revenant_text]]]];
}

- (NSArray *)revenant_signature
{
    return [[super revenant_signature] arrayByAddingObjectsFromArray:@[[_buttonAppearance revenant_signature], [_doneButtonAppearance revenant_signature]]];
}

@end
