/* MLSequence: an ordered list of numbers or of strings, which is what a Core ML sequence is.
 *
 * A model whose input is a sequence takes one of these: the values of a word vector, the
 * frames of a clip. It is its own class and not an array because the order is all it is -- there
 * is no shape to it, and the elements are the two kinds the specification names.
 */
#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"

/* The elements, and which kind they are. The strings are the values' own copies: a sequence an
 * application holds after the prediction has gone has to still be there. */
@interface MLSequence () {
@public
    MLFeatureType _type;
    NSMutableArray<NSNumber *> *_numbers;
    NSMutableArray<NSString *> *_strings;
}
@end

@implementation MLSequence

+ (instancetype)emptySequenceWithType:(MLFeatureType)type
{
    MLSequence *sequence = [[MLSequence alloc] init];
    if (sequence == nil) {
        return nil;
    }
    sequence->_type = type;
    sequence->_numbers = [NSMutableArray array];
    sequence->_strings = [NSMutableArray array];
    return sequence;
}

+ (instancetype)sequenceWithInt64Array:(NSArray<NSNumber *> *)values
{
    MLSequence *sequence = [self emptySequenceWithType:MLFeatureTypeInt64];
    if (sequence != nil) {
        [sequence->_numbers addObjectsFromArray:values ?: @[]];
    }
    return sequence;
}

+ (instancetype)sequenceWithStringArray:(NSArray<NSString *> *)values
{
    MLSequence *sequence = [self emptySequenceWithType:MLFeatureTypeString];
    if (sequence != nil) {
        [sequence->_strings addObjectsFromArray:values ?: @[]];
    }
    return sequence;
}

- (MLFeatureType)type
{
    return _type;
}

- (NSArray<NSNumber *> *)int64Values
{
    return [_numbers copy];
}

- (NSArray<NSString *> *)stringValues
{
    return [_strings copy];
}

- (NSUInteger)count
{
    return _type == MLFeatureTypeString ? _strings.count : _numbers.count;
}

- (NSNumber *)objectAtIndexedSubscript:(NSUInteger)index
{
    if (index >= self.count) {
        return nil;
    }
    return _type == MLFeatureTypeString ? (id)[_strings objectAtIndex:index] : [_numbers objectAtIndex:index];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _type = (MLFeatureType)[[coder decodeObjectOfClass:[NSNumber class] forKey:@"type"] integerValue];
    _numbers = [[coder decodeObjectOfClass:[NSArray class] forKey:@"numbers"] mutableCopy] ?: [NSMutableArray array];
    _strings = [[coder decodeObjectOfClass:[NSArray class] forKey:@"strings"] mutableCopy] ?: [NSMutableArray array];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:@(_type) forKey:@"type"];
    [coder encodeObject:_numbers forKey:@"numbers"];
    [coder encodeObject:_strings forKey:@"strings"];
}

@end
