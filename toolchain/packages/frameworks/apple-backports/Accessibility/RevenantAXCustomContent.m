#import <Accessibility/Accessibility.h>

@interface AXCustomContent () {
    NSAttributedString *_revenant_attributedLabel;
    NSAttributedString *_revenant_attributedValue;
    AXCustomContentImportance _revenant_importance;
}
@end

@implementation AXCustomContent

+ (instancetype)customContentWithLabel:(NSString *)label value:(NSString *)value
{
    AXCustomContent *content = [[self alloc] init];
    content->_revenant_attributedLabel = [[NSAttributedString alloc] initWithString:label];
    content->_revenant_attributedValue = [[NSAttributedString alloc] initWithString:value];
    return content;
}

+ (instancetype)customContentWithAttributedLabel:(NSAttributedString *)label
                                 attributedValue:(NSAttributedString *)value
{
    AXCustomContent *content = [[self alloc] init];
    content->_revenant_attributedLabel = [label copy];
    content->_revenant_attributedValue = [value copy];
    return content;
}

- (NSAttributedString *)attributedLabel
{
    return _revenant_attributedLabel;
}

- (NSAttributedString *)attributedValue
{
    return _revenant_attributedValue;
}

- (NSString *)label
{
    return _revenant_attributedLabel.string;
}

- (NSString *)value
{
    return _revenant_attributedValue.string;
}

- (AXCustomContentImportance)importance
{
    return _revenant_importance;
}

- (void)setImportance:(AXCustomContentImportance)importance
{
    _revenant_importance = importance;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _revenant_attributedLabel = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedLabel"];
        _revenant_attributedValue = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedValue"];
        _revenant_importance = (AXCustomContentImportance)[coder decodeIntegerForKey:@"importance"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenant_attributedLabel forKey:@"attributedLabel"];
    [coder encodeObject:_revenant_attributedValue forKey:@"attributedValue"];
    [coder encodeInteger:(NSInteger)_revenant_importance forKey:@"importance"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    AXCustomContent *copy = [[AXCustomContent allocWithZone:zone] init];
    copy->_revenant_attributedLabel = _revenant_attributedLabel;
    copy->_revenant_attributedValue = _revenant_attributedValue;
    copy->_revenant_importance = _revenant_importance;
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
    return [_revenant_attributedLabel isEqualToAttributedString:content->_revenant_attributedLabel]
        && [_revenant_attributedValue isEqualToAttributedString:content->_revenant_attributedValue]
        && _revenant_importance == content->_revenant_importance;
}

- (NSUInteger)hash
{
    return ([_revenant_attributedLabel hash] ^ [_revenant_attributedValue hash]) ^ (NSUInteger)_revenant_importance;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>: label: %@, value: %@",
            NSStringFromClass([self class]), (void *)self,
            _revenant_attributedLabel.string, _revenant_attributedValue.string];
}

@end
