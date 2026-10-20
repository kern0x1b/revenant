#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

NSString *const UICommandTagShare = @"com.apple.command-tag.share";

static void revenant_require(BOOL condition, NSString *what)
{
    if (!condition)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", what];
}

@implementation UICommandAlternate {
@private
    NSString *_title;
    SEL _action;
    UIKeyModifierFlags _modifierFlags;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [super init];
}

+ (instancetype)alternateWithTitle:(NSString *)title action:(SEL)action modifierFlags:(UIKeyModifierFlags)modifierFlags
{
    UICommandAlternate *alternate = [[self alloc] init];
    alternate->_title = [title copy];
    alternate->_action = action;
    alternate->_modifierFlags = modifierFlags;
    return alternate;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]) && coder) {
        _title = [[coder decodeObjectOfClass:[NSString class] forKey:@"title"] copy];
        NSString *action = [coder decodeObjectOfClass:[NSString class] forKey:@"action"];
        _action = action ? NSSelectorFromString(action) : NULL;
        _modifierFlags = (UIKeyModifierFlags)[coder decodeIntegerForKey:@"modifierFlags"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:NSStringFromSelector(_action) forKey:@"action"];
    [coder encodeInteger:_modifierFlags forKey:@"modifierFlags"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)title
{
    return _title;
}

- (SEL)action
{
    return _action;
}

- (UIKeyModifierFlags)modifierFlags
{
    return _modifierFlags;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isKindOfClass:[UICommandAlternate class]] && [(UICommandAlternate *)object modifierFlags] == _modifierFlags;
}

- (NSUInteger)hash
{
    return (NSUInteger)_modifierFlags;
}

@end

@implementation UICommand {
@private
    SEL _action;
    id _propertyList;
    NSArray *_alternates;
    NSString *_discoverabilityTitle;
    UIMenuElementAttributes _attributes;
    UIMenuElementState _state;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)propertyList
{
    return [self commandWithTitle:title image:image action:action propertyList:propertyList alternates:@[]];
}

+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)propertyList alternates:(NSArray<UICommandAlternate *> *)alternates
{
    return [[self alloc] initRevenantWithTitle:title image:image action:action propertyList:propertyList alternates:alternates];
}

- (instancetype)init
{
    return [self initRevenantWithTitle:nil image:nil action:NULL propertyList:nil alternates:@[]];
}

- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)propertyList alternates:(NSArray *)alternates
{
    if ((self = [super initRevenantWithTitle:title image:image])) {
        _action = action;
        if (propertyList) {
            revenant_require(CFPropertyListIsValid((__bridge CFPropertyListRef)propertyList, kCFPropertyListBinaryFormat_v1_0), @"propertyListCopy");
            _propertyList = CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFPropertyListRef)propertyList, kCFPropertyListImmutable));
        }
        NSMutableIndexSet *seen = [NSMutableIndexSet indexSet];
        for (UICommandAlternate *alternate in alternates) {
            NSInteger flags = alternate.modifierFlags;
            revenant_require(flags != 0 && ![seen containsIndex:(NSUInteger)flags], @"alternateModifierFlags != 0 && ![allAlternateModifierFlags containsIndex:alternateModifierFlags]");
            [seen addIndex:(NSUInteger)flags];
        }
        _alternates = alternates ? [alternates copy] : @[];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        NSString *action = [coder decodeObjectOfClass:[NSString class] forKey:@"action"];
        _action = action ? NSSelectorFromString(action) : NULL;
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSDate class], [NSData class], nil];
        _propertyList = [coder decodeObjectOfClasses:classes forKey:@"propertyList"];
        _alternates = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [UICommandAlternate class], nil] forKey:@"alternates"] ?: @[];
        _discoverabilityTitle = [[coder decodeObjectOfClass:[NSString class] forKey:@"discoverabilityTitle"] copy];
        _attributes = (UIMenuElementAttributes)[coder decodeIntegerForKey:@"attributes"];
        _state = (UIMenuElementState)[coder decodeIntegerForKey:@"states"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:NSStringFromSelector(_action) forKey:@"action"];
    if (_propertyList)
        [coder encodeObject:_propertyList forKey:@"propertyList"];
    if (_alternates.count)
        [coder encodeObject:_alternates forKey:@"alternates"];
    if (_discoverabilityTitle)
        [coder encodeObject:_discoverabilityTitle forKey:@"discoverabilityTitle"];
    if (_attributes)
        [coder encodeInteger:(NSInteger)_attributes forKey:@"attributes"];
    if (_state)
        [coder encodeInteger:_state forKey:@"states"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UICommand *copy = [[[self class] allocWithZone:zone] initRevenantWithTitle:self.title image:self.image action:_action propertyList:_propertyList alternates:_alternates];
    copy->_discoverabilityTitle = [_discoverabilityTitle copy];
    copy->_attributes = _attributes;
    copy->_state = _state;
    return copy;
}

- (NSString *)title
{
    return [super title];
}

- (void)setTitle:(NSString *)title
{
    [self revenant_setTitle:title];
}

- (UIImage *)image
{
    return [super image];
}

- (void)setImage:(UIImage *)image
{
    [self revenant_setImage:image];
}

- (NSString *)discoverabilityTitle
{
    return _discoverabilityTitle;
}

- (void)setDiscoverabilityTitle:(NSString *)discoverabilityTitle
{
    _discoverabilityTitle = [discoverabilityTitle copy];
}

- (SEL)action
{
    return _action;
}

- (id)propertyList
{
    return _propertyList;
}

- (NSArray<UICommandAlternate *> *)alternates
{
    return _alternates;
}

- (UIMenuElementAttributes)attributes
{
    return _attributes;
}

- (void)setAttributes:(UIMenuElementAttributes)attributes
{
    _attributes = attributes;
}

- (UIMenuElementState)state
{
    return _state;
}

- (void)setState:(UIMenuElementState)state
{
    _state = state;
}

- (void)revenant_performWithSender:(id)sender target:(id)target
{
    objc_setAssociatedObject(self, @selector(sender), sender, OBJC_ASSOCIATION_ASSIGN);
    [[UIApplication sharedApplication] sendAction:_action to:target from:self forEvent:nil];
    objc_setAssociatedObject(self, @selector(sender), nil, OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UICommand class]])
        return NO;
    UICommand *other = object;
    return other->_action == _action && (other->_propertyList == _propertyList || [other->_propertyList isEqual:_propertyList]);
}

- (NSUInteger)hash
{
    return (NSUInteger)(uintptr_t)(void *)_action;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (self.title.length)
        [text appendFormat:@"; title = %@", self.title];
    if (_action)
        [text appendFormat:@"; action: %@", NSStringFromSelector(_action)];
    [text appendString:@">"];
    return text;
}

@end
