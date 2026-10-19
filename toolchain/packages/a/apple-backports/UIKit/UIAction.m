#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIAction {
@private
    NSString *_identifier;
    NSString *_discoverabilityTitle;
    UIMenuElementAttributes _attributes;
    UIMenuElementState _state;
    UIActionHandler _handler;
    NSString *_subtitle;
    UIImage *_selectedImage;
    UIActionRepeatBehavior _repeatBehavior;
}

@dynamic sender, presentationSourceItem;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier handler:(UIActionHandler)handler
{
    return [[self alloc] initRevenantWithTitle:title image:image identifier:identifier handler:handler];
}

- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier handler:(UIActionHandler)handler
{
    if ((self = [super initRevenantWithTitle:title image:image])) {
        _identifier = identifier ? [identifier copy] : [@"com.apple.action.dynamic." stringByAppendingString:[NSUUID UUID].UUIDString];
        _handler = [handler copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _identifier = identifier ? [identifier copy] : [@"com.apple.action.dynamic." stringByAppendingString:[NSUUID UUID].UUIDString];
        _discoverabilityTitle = [[coder decodeObjectOfClass:[NSString class] forKey:@"discoverabilityTitle"] copy];
        _attributes = (UIMenuElementAttributes)[coder decodeIntegerForKey:@"attributes"];
        _state = (UIMenuElementState)[coder decodeIntegerForKey:@"states"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_identifier forKey:@"identifier"];
    if (_discoverabilityTitle)
        [coder encodeObject:_discoverabilityTitle forKey:@"discoverabilityTitle"];
    if (_attributes)
        [coder encodeInteger:(NSInteger)_attributes forKey:@"attributes"];
    if (_state)
        [coder encodeInteger:_state forKey:@"states"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIAction *copy = [[[self class] allocWithZone:zone] initRevenantWithTitle:self.title image:self.image identifier:_identifier handler:_handler];
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

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)discoverabilityTitle
{
    return _discoverabilityTitle;
}

- (void)setDiscoverabilityTitle:(NSString *)discoverabilityTitle
{
    _discoverabilityTitle = [discoverabilityTitle copy];
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

- (void)performWithSender:(id)sender target:(id)target
{
    [self revenant_performWithSender:sender];
}

- (void)revenant_performWithSender:(id)sender
{
    objc_setAssociatedObject(self, @selector(sender), sender, OBJC_ASSOCIATION_ASSIGN);
    if (_handler)
        _handler(self);
    objc_setAssociatedObject(self, @selector(sender), nil, OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIAction class]])
        return NO;
    NSString *other = [(UIAction *)object identifier];
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
    if (self.image)
        [text appendFormat:@"; image = %@", revenant_short_description(self.image)];
    if (_attributes)
        [text appendFormat:@"; attributes = %@", revenant_menu_attributes_text(_attributes)];
    [text appendString:@">"];
    return text;
}


- (UIActionHandler)handler
{
    return _handler;
}

- (void)setHandler:(UIActionHandler)handler
{
    _handler = [handler copy];
}

- (NSString *)subtitle
{
    return _subtitle;
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = [subtitle copy];
}

- (UIImage *)selectedImage
{
    return _selectedImage;
}

- (void)setSelectedImage:(UIImage *)selectedImage
{
    _selectedImage = selectedImage;
}

- (UIActionRepeatBehavior)repeatBehavior
{
    return _repeatBehavior;
}

- (void)setRepeatBehavior:(UIActionRepeatBehavior)repeatBehavior
{
    _repeatBehavior = repeatBehavior;
}

@end
