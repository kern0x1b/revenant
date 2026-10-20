#import "RevenantMenus.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static void revenant_collect_selected(NSArray<UIMenuElement *> *elements, NSMutableArray<UIMenuElement *> *selected)
{
    for (UIMenuElement *element in elements) {
        if ([element isKindOfClass:[UIMenu class]])
            revenant_collect_selected([(UIMenu *)element children], selected);
        else if ([element respondsToSelector:@selector(state)] && [(UIAction *)element state] == UIMenuElementStateOn)
            [selected addObject:element];
    }
}

@implementation UIMenu {
@private
    NSString *_identifier;
    UIMenuOptions _options;
    NSArray<UIMenuElement *> *_children;
    id _forcedAutomaticSelectionDelegate;
    BOOL _forceAutomaticSelection;
    UIMenuElementSize _preferredElementSize;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (UIMenu *)menuWithTitle:(NSString *)title children:(NSArray<UIMenuElement *> *)children
{
    return [[self alloc] initRevenantWithTitle:title image:nil identifier:nil options:0 children:children];
}

+ (UIMenu *)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(UIMenuOptions)options
                 children:(NSArray<UIMenuElement *> *)children
{
    return [[self alloc] initRevenantWithTitle:title image:image identifier:identifier options:options children:children];
}

- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(UIMenuOptions)options
                            children:(NSArray<UIMenuElement *> *)children
{
    for (id child in children) {
        if (![child isKindOfClass:[UIMenuElement class]])
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: unrecognized selector sent to instance %p", [child class], @"_acceptMenuVisit:leafVisit:", child];
    }
    if ((self = [super initRevenantWithTitle:title image:image])) {
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
    UIMenu *copy = [[[self class] allocWithZone:zone] initRevenantWithTitle:self.title image:self.image identifier:_identifier options:_options children:children];
    [self revenant_carryTo:copy];
    return copy;
}

- (void)revenant_carryTo:(UIMenu *)menu
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

- (NSArray<UIMenuElement *> *)selectedElements
{
    NSMutableArray<UIMenuElement *> *selected = [NSMutableArray array];
    revenant_collect_selected(_children, selected);
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
    UIMenu *menu = [[[self class] alloc] initRevenantWithTitle:self.title image:self.image identifier:_identifier options:_options children:newChildren ?: _children];
    [self revenant_carryTo:menu];
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
        [text appendFormat:@"; image = %@", revenant_short_description(self.image)];
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


- (id)forcedAutomaticSelectionDelegate
{
    return _forcedAutomaticSelectionDelegate;
}

- (void)setForcedAutomaticSelectionDelegate:(id)forcedAutomaticSelectionDelegate
{
    _forcedAutomaticSelectionDelegate = forcedAutomaticSelectionDelegate;
}


- (BOOL)forceAutomaticSelection
{
    return _forceAutomaticSelection;
}

- (void)setForceAutomaticSelection:(BOOL)forceAutomaticSelection
{
    _forceAutomaticSelection = forceAutomaticSelection;
}

@end
