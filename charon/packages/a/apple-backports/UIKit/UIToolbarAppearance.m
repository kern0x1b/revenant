#import "CharonBarAppearance.h"

static void charon_require_appearance(id appearance)
{
    if (!appearance)
        [NSException raise:NSInternalInconsistencyException format:@"use -[UIBarButtonItemAppearance setupDefaultAppearanceForStyle:] to reset appearance values"];
}

@implementation UIToolbarAppearance {
@private
    UIBarButtonItemAppearance *_buttonAppearance;
    UIBarButtonItemAppearance *_doneButtonAppearance;
}

- (void)charon_setUp
{
    [super charon_setUp];
    _buttonAppearance = [[UIBarButtonItemAppearance alloc] initCharonWithStyle:0];
    _doneButtonAppearance = [[UIBarButtonItemAppearance alloc] initCharonWithStyle:2];
    [self charon_adoptChildren];
}

- (void)charon_adoptChildren
{
    charon_adopt_child(self, _buttonAppearance);
    charon_adopt_child(self, _doneButtonAppearance);
}

- (void)charon_copyExtrasFrom:(UIBarAppearance *)source
{
    if (![source isKindOfClass:[UIToolbarAppearance class]])
        return;
    UIToolbarAppearance *other = (UIToolbarAppearance *)source;
    _buttonAppearance = [other->_buttonAppearance copy];
    _doneButtonAppearance = [other->_doneButtonAppearance copy];
    [self charon_adoptChildren];
}

- (void)charon_encodeExtrasWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_buttonAppearance forKey:@"button"];
    [coder encodeObject:_doneButtonAppearance forKey:@"done"];
}

- (void)charon_decodeExtrasWithCoder:(NSCoder *)coder
{
    _buttonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"button"] ?: _buttonAppearance;
    _doneButtonAppearance = [coder decodeObjectOfClass:[UIBarButtonItemAppearance class] forKey:@"done"] ?: _doneButtonAppearance;
    [self charon_adoptChildren];
}

- (UIBarButtonItemAppearance *)buttonAppearance
{
    return _buttonAppearance;
}

- (void)setButtonAppearance:(UIBarButtonItemAppearance *)buttonAppearance
{
    charon_require_appearance(buttonAppearance);
    _buttonAppearance = [buttonAppearance copy];
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

- (NSArray *)charon_lines
{
    return [[super charon_lines] arrayByAddingObjectsFromArray:@[[NSString stringWithFormat:@"Plain BarButtonItems(%p): %@", _buttonAppearance, [_buttonAppearance charon_text]],
                                                                 [NSString stringWithFormat:@"Prominent BarButtonItems(%p): %@", _doneButtonAppearance, [_doneButtonAppearance charon_text]]]];
}

- (NSArray *)charon_signature
{
    return [[super charon_signature] arrayByAddingObjectsFromArray:@[[_buttonAppearance charon_signature], [_doneButtonAppearance charon_signature]]];
}

@end
