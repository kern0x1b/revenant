#import <Accessibility/Accessibility.h>

@interface AXCustomContent () {
    NSAttributedString *_charon_attributedLabel;
    NSAttributedString *_charon_attributedValue;
    AXCustomContentImportance _charon_importance;
}
@end

@implementation AXCustomContent

+ (instancetype)customContentWithLabel:(NSString *)label value:(NSString *)value
{
    AXCustomContent *content = [[self alloc] init];
    content->_charon_attributedLabel = [[NSAttributedString alloc] initWithString:label];
    content->_charon_attributedValue = [[NSAttributedString alloc] initWithString:value];
    return content;
}

+ (instancetype)customContentWithAttributedLabel:(NSAttributedString *)label
                                 attributedValue:(NSAttributedString *)value
{
    AXCustomContent *content = [[self alloc] init];
    content->_charon_attributedLabel = [label copy];
    content->_charon_attributedValue = [value copy];
    return content;
}

- (NSAttributedString *)attributedLabel
{
    return _charon_attributedLabel;
}

- (NSAttributedString *)attributedValue
{
    return _charon_attributedValue;
}

- (NSString *)label
{
    return _charon_attributedLabel.string;
}

- (NSString *)value
{
    return _charon_attributedValue.string;
}

- (AXCustomContentImportance)importance
{
    return _charon_importance;
}

- (void)setImportance:(AXCustomContentImportance)importance
{
    _charon_importance = importance;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _charon_attributedLabel = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedLabel"];
        _charon_attributedValue = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedValue"];
        _charon_importance = (AXCustomContentImportance)[coder decodeIntegerForKey:@"importance"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charon_attributedLabel forKey:@"attributedLabel"];
    [coder encodeObject:_charon_attributedValue forKey:@"attributedValue"];
    [coder encodeInteger:(NSInteger)_charon_importance forKey:@"importance"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    AXCustomContent *copy = [[AXCustomContent allocWithZone:zone] init];
    copy->_charon_attributedLabel = _charon_attributedLabel;
    copy->_charon_attributedValue = _charon_attributedValue;
    copy->_charon_importance = _charon_importance;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[AXCustomContent class]]) {
        return NO;
    }
    AXCustomContent *content = (AXCustomContent *)other;
    return [_charon_attributedLabel isEqualToAttributedString:content->_charon_attributedLabel]
        && [_charon_attributedValue isEqualToAttributedString:content->_charon_attributedValue]
        && _charon_importance == content->_charon_importance;
}

- (NSUInteger)hash
{
    return ([_charon_attributedLabel hash] ^ [_charon_attributedValue hash]) ^ (NSUInteger)_charon_importance;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>: label: %@, value: %@",
            NSStringFromClass([self class]), (void *)self,
            _charon_attributedLabel.string, _charon_attributedValue.string];
}

@end
