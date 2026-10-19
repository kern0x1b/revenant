//
//  CharonAXCustomContent.m
//  Accessibility
//
//  `AXCustomContent` of iOS 14.0: the class the port's own SDK of 16.4 declares in AXCustomContent.h,
//  built here because the release has no Accessibility at all. The declaration is not transcribed -
//  the SDK's own header is what an application compiles against and what places this object, and
//  CharonAccessibility.h's header comment is about the six headers 16.4 lacks, of which this is not
//  one.
//
//  **What the class is.** A piece of content an accessibility object would otherwise have to fold into
//  one long label: a name for it, the content, and how eagerly the user wants to hear it. An
//  application builds it and hands it to the system through `AXCustomContentProvider`; the
//  assistive technology decides when to speak it. This release runs no assistive technology, so the
//  deciding half is not here and the class is the container: the value the application built is the
//  value it reads back, unchanged.
//
//  **One attributed pair is the storage, and the two plain strings are read out of it.** That is not
//  a choice, it is what the host does, and it is the only model that explains all four properties at
//  once (measured on the host's own Accessibility.framework by
//  `tests/backports/host/accessibilitymath/`):
//
//  * `+customContentWithLabel:value:` builds an attributed string from each plain string, and
//    `attributedLabel`/`attributedValue` answer those (their class is NSConcreteAttributedString and
//    their `.string` is the string that was passed in);
//  * `+customContentWithAttributedLabel:attributedValue:` keeps the attributed strings it was given,
//    and `label`/`value` answer `.string` of them - the *same* NSString object, not an equal one
//    (measured: `label == attributedLabel.string` is true on the host).
//
//  Storing four values would have to invent a rule for keeping two spellings in step, and every
//  measurement above says there is only one value. `importance` is the one member with a default,
//  and the header names it: `AXCustomContentImportanceDefault`, which is 0 because it is the first
//  case of an NS_ENUM. The host answers 0 for a fresh content and 1 after `High` is set (measured).
//

#import <Accessibility/Accessibility.h>

// The two attributed strings, and the one number. Nothing else: label, value, attributedLabel and
// attributedValue are four spellings of the two values, and the header's two factories are the two
// ways of being given them.
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

// The plain spellings are the attributed ones' own string, which is what makes the two factories give
// four properties rather than two, and what the host answers. `.string` of a stored attributed string
// is the string inside it, so nothing is copied here and a caller gets the same object the host hands
// out - measured on the host, `label == attributedLabel.string`.
- (NSString *)label
{
    return _charon_attributedLabel.string;
}

- (NSString *)value
{
    return _charon_attributedValue.string;
}

// `assign`, as the header declares it: the property carries the enumeration's own number and nothing
// else, and the default is the header's named default, which is the zero an unset ivar already holds.
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
        // The two attributed strings and the enumeration number, under the class's own coding keys.
        // `decodeObjectOfClass:` is the secure-coding spellings, and a content that arrives without
        // one of them decodes it as nil, which is what a content built by neither factory would have
        // answered anyway.
        _charon_attributedLabel = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedLabel"];
        _charon_attributedValue = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedValue"];
        _charon_importance = (AXCustomContentImportance)[coder decodeIntegerForKey:@"importance"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // Both strings, always: the header's four properties are four spellings of two values, and a
    // content that is copied is copied whole. The number is written under the same name the
    // enumeration gives it, so a content at the default and one at High do not archive alike - which
    // is what the host does, measured: importance survives a secure round trip at High and at the
    // default.
    [coder encodeObject:_charon_attributedLabel forKey:@"attributedLabel"];
    [coder encodeObject:_charon_attributedValue forKey:@"attributedValue"];
    [coder encodeInteger:(NSInteger)_charon_importance forKey:@"importance"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // The two attributed strings are copied, the enumeration number is carried: a copy is a content of
    // the same kind with the same two values. The host's copy compares equal to its original (measured)
    // and shares the very attributed string with it, so this one shares too rather than making a
    // second attributed string for a value nobody changed.
    AXCustomContent *copy = [[AXCustomContent allocWithZone:zone] init];
    copy->_charon_attributedLabel = _charon_attributedLabel;
    copy->_charon_attributedValue = _charon_attributedValue;
    copy->_charon_importance = _charon_importance;
    return copy;
}

// Equality is by content and not by identity, which is what the host does (measured: a copy and the
// original compare equal, and a coding round trip compares equal to what went in). A content is the
// same content when it is the same kind, names the same thing, says the same value and asks for the
// same urgency - the last of the four because a content the user wants spoken immediately is not
// interchangeable with one they want on demand, and a collection holding both has to be able to say
// so.
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
    // Equal contents have equal hashes, which is the only promise NSObject makes about them, and it
    // is made from the same four values - the two attributed strings' own hashes over their whole
    // length, so an attribute on one of them counts, because it is part of what the content is.
    return ([_charon_attributedLabel hash] ^ [_charon_attributedValue hash]) ^ (NSUInteger)_charon_importance;
}

// The system's own description with the two values appended, which is what the host prints:
// `<AXCustomContent: 0x...>: label: Orientation, value: Portrait` (measured on the host's own
// Accessibility.framework).
//
// The class and the address are spelled out rather than taken from `%@` on self, and that is not a
// style choice: `-description` on self calls itself, and the case that reads this segfaults on the
// second level of it. The host's format is reproduced literally - `NSStringFromClass` for the name, the
// object's own address for the pointer - so the text after `>: ` is the system's own and this does not
// invent a spelling of its own. The number is not in the output because the host's is not in its own,
// and a description that named an importance the system does not print would be a claim the system does
// not make.
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>: label: %@, value: %@",
            NSStringFromClass([self class]), (void *)self,
            _charon_attributedLabel.string, _charon_attributedValue.string];
}

@end
