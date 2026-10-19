#import <UIKit/UIKit.h>

@implementation NSTextSelection {
    id<NSTextLocation> _secondarySelectionLocation;
    NSDictionary *_typingAttributes;
}

@synthesize textRanges = _textRanges;
@synthesize affinity = _affinity;
@synthesize granularity = _granularity;
@synthesize anchorPositionOffset = _anchorPositionOffset;
@synthesize logical = _logical;

- (NSDictionary *)typingAttributes
{
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
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ cannot be made without ranges: use -initWithRanges:affinity:granularity:",
                       NSStringFromClass([self class])];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _textRanges = [[coder decodeObjectForKey:@"textRanges"] copy] ?: @[];
        _affinity = [coder decodeIntegerForKey:@"affinity"];
        _granularity = [coder decodeIntegerForKey:@"granularity"];
        _transient = [coder decodeBoolForKey:@"transient"];
        _anchorPositionOffset = (CGFloat)[coder decodeDoubleForKey:@"anchorPositionOffset"];
        _logical = [coder decodeBoolForKey:@"logical"];
        _secondarySelectionLocation = [coder decodeObjectForKey:@"secondarySelectionLocation"];
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
    copy->_transient = _transient;
    copy->_anchorPositionOffset = _anchorPositionOffset;
    copy->_logical = _logical;
    copy->_secondarySelectionLocation = _secondarySelectionLocation;
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
    NSUInteger hash = (NSUInteger)_affinity * 31 + (NSUInteger)_granularity;
    hash = hash * 31 + (_logical ? 2u : 0u);
    hash = hash * 31 + (NSUInteger)_anchorPositionOffset;
    hash = hash * 31 + _typingAttributes.hash;
    hash = hash * 31 + _secondarySelectionLocation.hash;
    for (NSTextRange *range in _textRanges)
        hash = hash * 31 + range.hash;
    return hash;
}

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
