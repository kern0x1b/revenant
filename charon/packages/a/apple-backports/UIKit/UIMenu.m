#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// Adds the on elements in a list, and those in the sub-menus in it, in order.
static void charon_collect_selected(NSArray<UIMenuElement *> *elements, NSMutableArray<UIMenuElement *> *selected)
{
    for (UIMenuElement *element in elements) {
        if ([element isKindOfClass:[UIMenu class]])
            charon_collect_selected([(UIMenu *)element children], selected);
        else if ([element respondsToSelector:@selector(state)] && [(UIAction *)element state] == UIMenuElementStateOn)
            [selected addObject:element];
    }
}

@implementation UIMenu {
@private
    NSString *_identifier;
    UIMenuOptions _options;
    NSArray<UIMenuElement *> *_children;
    // The delegate a menu forces automatic selection on, which UIKit's own button machinery sets on a menu it
    // is about to show. It is a private pair - no header declares it - and the host's own UIMenu answers it, so
    // a menu this port replaces has to answer it too or the host's machinery sends it into nothing. Measured:
    // the setter holds what it is given, nil clears it, and a second set replaces it.
    id _forcedAutomaticSelectionDelegate;
    BOOL _forceAutomaticSelection;
    // The size of the menu's child elements. -1 until set, which is the host's answer for a menu nothing has sized.
    UIMenuElementSize _preferredElementSize;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (UIMenu *)menuWithTitle:(NSString *)title children:(NSArray<UIMenuElement *> *)children
{
    return [[self alloc] initCharonWithTitle:title image:nil identifier:nil options:0 children:children];
}

+ (UIMenu *)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(UIMenuOptions)options
                 children:(NSArray<UIMenuElement *> *)children
{
    return [[self alloc] initCharonWithTitle:title image:image identifier:identifier options:options children:children];
}

- (instancetype)initCharonWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(UIMenuOptions)options
                            children:(NSArray<UIMenuElement *> *)children
{
    for (id child in children) {
        if (![child isKindOfClass:[UIMenuElement class]])
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: unrecognized selector sent to instance %p", [child class], @"_acceptMenuVisit:leafVisit:", child];
    }
    if ((self = [super initCharonWithTitle:title image:image])) {
        _identifier = identifier ? [identifier copy] : [@"com.apple.menu.dynamic." stringByAppendingString:[NSUUID UUID].UUIDString];
        _options = options;
        _children = children ? [children copy] : @[];
        _preferredElementSize = -1;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _identifier = identifier ? [identifier copy] : [@"com.apple.menu.dynamic." stringByAppendingString:[NSUUID UUID].UUIDString];
        _options = (UIMenuOptions)[coder decodeIntegerForKey:@"options"];
        NSArray *children = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [UIMenuElement class], nil] forKey:@"children"];
        _children = children ? [children copy] : @[];
        _preferredElementSize = [coder containsValueForKey:@"preferredElementSize"] ? (UIMenuElementSize)[coder decodeIntegerForKey:@"preferredElementSize"] : -1;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeInteger:(NSInteger)_options forKey:@"options"];
    [coder encodeObject:_children forKey:@"children"];
    [coder encodeInteger:_preferredElementSize forKey:@"preferredElementSize"];
    [coder encodeInteger:-1 forKey:@"resolvedElementSize"];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMutableArray *children = [NSMutableArray arrayWithCapacity:_children.count];
    for (UIMenuElement *child in _children)
        [children addObject:[child copy]];
    UIMenu *copy = [[[self class] allocWithZone:zone] initCharonWithTitle:self.title image:self.image identifier:_identifier options:_options children:children];
    [self charon_carryTo:copy];
    return copy;
}

// A copy and a menu made with other children keep the size and the subtitle; measured on the host, where both survive -copy and
// -menuByReplacingChildren:.
- (void)charon_carryTo:(UIMenu *)menu
{
    menu.preferredElementSize = _preferredElementSize;
    menu.subtitle = self.subtitle;
}

- (UIMenuElementSize)preferredElementSize
{
    return _preferredElementSize;
}

- (void)setPreferredElementSize:(UIMenuElementSize)preferredElementSize
{
    _preferredElementSize = preferredElementSize;
}

// The on elements of this menu and of its sub-menus, in the order they appear. A mixed element is not selected. Only an action has
// a state, so the test is for the state, not the class; measured on the host in tests/backports/host/menu-selection.
- (NSArray<UIMenuElement *> *)selectedElements
{
    NSMutableArray<UIMenuElement *> *selected = [NSMutableArray array];
    charon_collect_selected(_children, selected);
    return selected;
}

- (NSString *)identifier
{
    return _identifier;
}

- (UIMenuOptions)options
{
    return _options;
}

- (NSArray<UIMenuElement *> *)children
{
    return _children;
}

- (UIMenu *)menuByReplacingChildren:(NSArray<UIMenuElement *> *)newChildren
{
    UIMenu *menu = [[[self class] alloc] initCharonWithTitle:self.title image:self.image identifier:_identifier options:_options children:newChildren ?: _children];
    [self charon_carryTo:menu];
    return menu;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIMenu class]])
        return NO;
    NSString *other = [(UIMenu *)object identifier];
    return _identifier == other || [_identifier isEqual:other];
}

- (NSUInteger)hash
{
    return _identifier.hash;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (self.title.length)
        [text appendFormat:@"; title = %@", self.title];
    [text appendFormat:@"; identifier = %@", _identifier];
    if (self.image)
        [text appendFormat:@"; image = %@", charon_short_description(self.image)];
    if (_options) {
        NSMutableArray *names = [NSMutableArray array];
        if (_options & UIMenuOptionsDisplayInline)
            [names addObject:@"Inline"];
        if (_options & UIMenuOptionsDestructive)
            [names addObject:@"Destructive"];
        if (_options & 32)
            [names addObject:@"SingleSelection"];
        [text appendFormat:@"; options = (%@)", [names componentsJoinedByString:@"|"]];
    }
    [text appendFormat:@"; children = <NSArray: %p>>", _children];
    return text;
}


// The host's own private pair, measured rather than guessed: -setForcedAutomaticSelectionDelegate: is declared
// on UIMenu and on no superclass, it holds the delegate it is given, nil clears it, a second set replaces it,
// and a menu that never had one answers the getter with nil.
- (id)forcedAutomaticSelectionDelegate
{
    return _forcedAutomaticSelectionDelegate;
}

- (void)setForcedAutomaticSelectionDelegate:(id)forcedAutomaticSelectionDelegate
{
    _forcedAutomaticSelectionDelegate = forcedAutomaticSelectionDelegate;
}


// The second of the same private pair, measured the same way: the host's UIMenu carries both
// -setForceAutomaticSelection: and -forceAutomaticSelection, and a menu that never had either answers the
// getter with NO. The value is what the caller set.
- (BOOL)forceAutomaticSelection
{
    return _forceAutomaticSelection;
}

- (void)setForceAutomaticSelection:(BOOL)forceAutomaticSelection
{
    _forceAutomaticSelection = forceAutomaticSelection;
}

@end
