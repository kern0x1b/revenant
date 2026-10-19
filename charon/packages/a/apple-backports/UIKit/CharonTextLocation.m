// CharonTextLocation.m - the port's own NSTextLocation. See CharonTextLocation.h for why it holds the
// document as well as the offset.
#import "CharonTextLocation.h"

@implementation CharonTextLocation

@synthesize textContentStorage = _textContentStorage;
@synthesize offset = _offset;

+ (instancetype)locationWithTextContentStorage:(NSTextContentStorage *)textContentStorage offset:(NSInteger)offset
{
    return [[self alloc] initWithTextContentStorage:textContentStorage offset:offset];
}

- (instancetype)initWithTextContentStorage:(NSTextContentStorage *)textContentStorage offset:(NSInteger)offset
{
    if ((self = [super init])) {
        _textContentStorage = textContentStorage;
        _offset = offset;
    }
    return self;
}

// The whole of NSTextLocation: the ordering of this place against another, which is the ordering of the two
// offsets. A location of another document has no order against this one, and the protocol has no way to say
// so, so the answer is the ordering of the two offsets and the storage's own -offsetFromLocation:toLocation: is
// what refuses the pair before a comparison is asked for. Ordering two locations that are not of one document
// is a question with no answer, and answering it with the offsets is the least of the three answers that are
// not a refusal.
- (NSComparisonResult)compare:(id<NSTextLocation>)location
{
    NSInteger other = [location respondsToSelector:@selector(offset)] ? [(CharonTextLocation *)location offset] : 0;
    if (_offset == other)
        return NSOrderedSame;
    return _offset < other ? NSOrderedAscending : NSOrderedDescending;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[CharonTextLocation class]])
        return NO;
    CharonTextLocation *other = object;
    return _offset == other.offset && _textContentStorage == other.textContentStorage;
}

- (NSUInteger)hash
{
    return (NSUInteger)_offset ^ (NSUInteger)(__bridge void *)_textContentStorage * 31;
}

// A location prints as its offset and the document it is in, which is what a range's description shows and the
// only thing about a place that is worth printing.
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@%ld", self.textContentStorage ? @"" : @"(no document) ", (long)_offset];
}

@end
