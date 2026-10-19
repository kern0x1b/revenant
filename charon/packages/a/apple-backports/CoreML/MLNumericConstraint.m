#import <CoreML/CoreML.h>

#include "CharonMLConstraints.h"

@interface MLNumericConstraint () {
    NSNumber *_minNumber;
    NSNumber *_maxNumber;
    NSSet<NSNumber *> *_enumeratedNumbers;
}
- (instancetype)charon_initWithMinNumber:(NSNumber *)minNumber
                         maxNumber:(NSNumber *)maxNumber
                enumeratedNumbers:(NSSet<NSNumber *> *)enumeratedNumbers;
@end

@implementation MLNumericConstraint

- (instancetype)charon_initWithMinNumber:(NSNumber *)minNumber
                         maxNumber:(NSNumber *)maxNumber
                enumeratedNumbers:(NSSet<NSNumber *> *)enumeratedNumbers
{
    MLNumericConstraint *built = [super init];
    if (built != nil) {
        _minNumber = minNumber;
        _maxNumber = maxNumber;
        _enumeratedNumbers = enumeratedNumbers != nil ? [enumeratedNumbers copy] : nil;
    }
    return built;
}

- (NSNumber *)minNumber
{
    return _minNumber;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] charon_initWithMinNumber:_minNumber
                                                              maxNumber:_maxNumber
                                                     enumeratedNumbers:_enumeratedNumbers];
}


- (NSNumber *)maxNumber
{
    return _maxNumber;
}

- (NSSet<NSNumber *> *)enumeratedNumbers
{
    return _enumeratedNumbers;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _minNumber = [coder decodeObjectOfClass:[NSNumber class] forKey:@"minNumber"];
        _maxNumber = [coder decodeObjectOfClass:[NSNumber class] forKey:@"maxNumber"];
        _enumeratedNumbers = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSSet class], [NSNumber class], nil]
                                                forKey:@"enumeratedNumbers"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_minNumber forKey:@"minNumber"];
    [coder encodeObject:_maxNumber forKey:@"maxNumber"];
    [coder encodeObject:_enumeratedNumbers forKey:@"enumeratedNumbers"];
}

@end
