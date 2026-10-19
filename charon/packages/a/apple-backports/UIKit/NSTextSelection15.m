// NSTextSelection: one logical selection, a set of disjoint ranges and the two things that say how it behaves -
// which end the cursor is at, and what an extending operation moves by. What the header declares is in
// NSTextSelection.h of SDK 26.2; what the host's own UIKit answers is in facts/UIKit/NSTextRange15.md.
//
// A selection is a value: the host answers two separately made selections over the same ranges, affinity,
// granularity, anchor offset, logical flag and typing attributes as -isEqual:, and a set holding two of them
// holds one (M8). So equality and hashing are written out here, over the keys that were measured. The one key
// left out is -transient: the header declares it readonly and nothing sets it, so two selections on the port
// cannot differ in it and the host was never asked.

#import <UIKit/UIKit.h>

@implementation NSTextSelection {
    // The one property with a setter of its own, so its storage is written out here: a setter that also sets
    // -logical cannot be a synthesized pair, and the header says setting a secondary location makes the
    // selection not a logical one.
    id<NSTextLocation> _secondarySelectionLocation;
    // And the one property whose getter and setter do not agree, which is why it too is written out.
    NSDictionary *_typingAttributes;
}

@synthesize textRanges = _textRanges;
@synthesize affinity = _affinity;
@synthesize granularity = _granularity;
@synthesize anchorPositionOffset = _anchorPositionOffset;
@synthesize logical = _logical;

- (NSDictionary *)typingAttributes
{
    // nil until the setter has been called at all, and a dictionary from then on, which is what the host answers
    // (M6): a selection that was never given any is nil, and a selection whose setter was handed nil answers an
    // empty dictionary. So the substitution belongs in the setter and not in the getter, or a fresh selection
    // would answer a dictionary where the system answers nil.
    return _typingAttributes;
}

- (void)setTypingAttributes:(NSDictionary *)typingAttributes
{
    _typingAttributes = [typingAttributes copy] ?: @{};
}

- (instancetype)initWithRanges:(NSArray<NSTextRange *> *)textRanges
                      affinity:(NSTextSelectionAffinity)affinity
                   granularity:(NSTextSelectionGranularity)granularity
{
    if ((self = [super init])) {
        // The ranges are kept as they are given, in the order they are given, overlapping and out of order
        // included. The header's comment on this initializer says they are reordered and merged, and the host
        // does neither (M3): it is the one place the header and the system disagree in this family, and the
        // system decides, so a caller that hands over overlapping ranges gets them back overlapping.
        _textRanges = [textRanges copy] ?: @[];
        _affinity = affinity;
        _granularity = granularity;
    }
    return self;
}

- (instancetype)initWithRange:(NSTextRange *)range
                     affinity:(NSTextSelectionAffinity)affinity
                  granularity:(NSTextSelectionGranularity)granularity
{
    return [self initWithRanges:range ? @[ range ] : @[] affinity:affinity granularity:granularity];
}

- (instancetype)initWithLocation:(id<NSTextLocation>)location
                        affinity:(NSTextSelectionAffinity)affinity
{
    return [self initWithRanges:@[ [[NSTextRange alloc] initWithLocation:location] ]
                       affinity:affinity
                    granularity:NSTextSelectionGranularityCharacter];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    // As on NSTextRange, and for the same reason: the header marks this one unavailable because a selection is
    // ranges, an affinity and a granularity, and the host faults rather than answering (M9).
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ cannot be made without ranges: use -initWithRanges:affinity:granularity:",
                       NSStringFromClass([self class])];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // The header makes this a designated initialiser of its own, so it reads the archive into the storage
    // directly rather than through -initWithRanges:..., which is the other designated initialiser.
    if ((self = [super init])) {
        _textRanges = [[coder decodeObjectForKey:@"textRanges"] copy] ?: @[];
        _affinity = [coder decodeIntegerForKey:@"affinity"];
        _granularity = [coder decodeIntegerForKey:@"granularity"];
        _transient = [coder decodeBoolForKey:@"transient"];
        _anchorPositionOffset = (CGFloat)[coder decodeDoubleForKey:@"anchorPositionOffset"];
        _logical = [coder decodeBoolForKey:@"logical"];
        _secondarySelectionLocation = [coder decodeObjectForKey:@"secondarySelectionLocation"];
        // A selection that is read back has been through the setter, so its typing attributes are a dictionary
        // even when the archive held none (M6).
        _typingAttributes = [coder decodeObjectForKey:@"typingAttributes"] ?: @{};
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_textRanges forKey:@"textRanges"];
    [coder encodeInteger:_affinity forKey:@"affinity"];
    [coder encodeInteger:_granularity forKey:@"granularity"];
    [coder encodeBool:_transient forKey:@"transient"];
    [coder encodeDouble:(double)_anchorPositionOffset forKey:@"anchorPositionOffset"];
    [coder encodeBool:_logical forKey:@"logical"];
    [coder encodeObject:_secondarySelectionLocation forKey:@"secondarySelectionLocation"];
    [coder encodeObject:_typingAttributes forKey:@"typingAttributes"];
}

- (NSTextSelection *)textSelectionWithTextRanges:(NSArray<NSTextRange *> *)textRanges
{
    NSTextSelection *copy =
        [[[self class] alloc] initWithRanges:textRanges affinity:_affinity granularity:_granularity];
    // -transient is readonly in the header: it says whether the selection is one a drag is making, which only
    // the responder chain that is dragging knows, so there is no setter to copy through and the value is the
    // one the selection was made with.
    copy->_transient = _transient;
    copy->_anchorPositionOffset = _anchorPositionOffset;
    copy->_logical = _logical;
    // The copy carries the secondary location, and it does not go through -setSecondarySelectionLocation: to do
    // it: the host's copy of a selection that is logical and has a secondary location is still logical (M7),
    // where the setter's own side effect would have made it not.
    copy->_secondarySelectionLocation = _secondarySelectionLocation;
    // And a copy always has a dictionary, even of a selection that had none (M6).
    copy->_typingAttributes = _typingAttributes ?: @{};
    return copy;
}

- (id<NSTextLocation>)secondarySelectionLocation
{
    return _secondarySelectionLocation;
}

- (void)setSecondarySelectionLocation:(id<NSTextLocation>)secondarySelectionLocation
{
    _secondarySelectionLocation = secondarySelectionLocation;
    // The header's own side effect, and the host's answer: a selection with a secondary location is not a
    // logical one (M3). It is the setter's side effect and not the copy's, which is why the copy above assigns
    // the storage directly.
    if (secondarySelectionLocation)
        _logical = NO;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSTextSelection class]])
        return NO;
    NSTextSelection *other = object;
    if (_affinity != other.affinity || _granularity != other.granularity || _logical != other.logical ||
        _anchorPositionOffset != other.anchorPositionOffset)
        return NO;
    if (_textRanges.count != other.textRanges.count)
        return NO;
    for (NSUInteger index = 0; index < _textRanges.count; index++)
        if (![_textRanges[index] isEqualToTextRange:other.textRanges[index]])
            return NO;
    if ((_typingAttributes == nil) != (other.typingAttributes == nil))
        return NO;
    if (_typingAttributes && ![_typingAttributes isEqualToDictionary:other.typingAttributes])
        return NO;
    if (_secondarySelectionLocation == other.secondarySelectionLocation)
        return YES;
    return [_secondarySelectionLocation isEqual:other.secondarySelectionLocation];
}

- (NSUInteger)hash
{
    // Unlike NSTextRange's, the host's own hash for a selection is a function of its value (M8): two equal
    // selections hash alike and a set of two of them holds one, so this one is by value too.
    NSUInteger hash = (NSUInteger)_affinity * 31 + (NSUInteger)_granularity;
    hash = hash * 31 + (_logical ? 2u : 0u);
    hash = hash * 31 + (NSUInteger)_anchorPositionOffset;
    hash = hash * 31 + _typingAttributes.hash;
    hash = hash * 31 + _secondarySelectionLocation.hash;
    for (NSTextRange *range in _textRanges)
        hash = hash * 31 + range.hash;
    return hash;
}

// The host's own text for a selection, which names the two enumerations by their case names and then the ranges
// one to a line: "NSTextSelection:<0x...> granularity=character, affinity=downstream, textRanges=(\n    \"0...5\"\n)".
static NSString *charon_granularity_name(NSTextSelectionGranularity granularity)
{
    switch (granularity) {
    case NSTextSelectionGranularityWord:
        return @"word";
    case NSTextSelectionGranularityParagraph:
        return @"paragraph";
    case NSTextSelectionGranularityLine:
        return @"line";
    case NSTextSelectionGranularitySentence:
        return @"sentence";
    default:
        return @"character";
    }
}

static NSString *charon_affinity_name(NSTextSelectionAffinity affinity)
{
    return affinity == NSTextSelectionAffinityUpstream ? @"upstream" : @"downstream";
}

static NSString *charon_ranges_text(NSArray *ranges)
{
    // The host separates the ranges with a comma and a line each, and no comma after the last one, so a
    // selection of two ranges prints as (\n    "0...5",\n    "5...10"\n) and a selection of none as (\n).
    NSMutableString *text = [NSMutableString stringWithString:@"(\n"];
    for (NSTextRange *range in ranges) {
        [text appendFormat:@"    \"%@\"", range];
        if (range != [ranges lastObject])
            [text appendString:@","];
        [text appendString:@"\n"];
    }
    return [text stringByAppendingString:@")"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"NSTextSelection:<%p> granularity=%@, affinity=%@, textRanges=%@", self,
                                      charon_granularity_name(_granularity), charon_affinity_name(_affinity),
                                      charon_ranges_text(_textRanges)];
}

@end
