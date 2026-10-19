#import "RevenantTextLocation.h"

@implementation RevenantTextLocation

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

- (NSComparisonResult)compare:(id<NSTextLocation>)location
{
    NSInteger other = [location respondsToSelector:@selector(offset)] ? [(RevenantTextLocation *)location offset] : 0;
    if (_offset == other)
        return NSOrderedSame;
    return _offset < other ? NSOrderedAscending : NSOrderedDescending;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[RevenantTextLocation class]])
        return NO;
    RevenantTextLocation *other = object;
    return _offset == other.offset && _textContentStorage == other.textContentStorage;
}

- (NSUInteger)hash
{
    return (NSUInteger)_offset ^ (NSUInteger)(__bridge void *)_textContentStorage * 31;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@%ld", self.textContentStorage ? @"" : @"(no document) ", (long)_offset];
}

@end
