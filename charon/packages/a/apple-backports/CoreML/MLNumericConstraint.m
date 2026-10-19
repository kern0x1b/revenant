/* MLNumericConstraint, in a file of its own for the same reason: it is a class of its own and the
 * release that introduced it is not the one the constraints beside it arrived in.
 *
 * The bound a model's own parameter values sit in, which is how an updatable model says that a
 * learning rate is one of these numbers rather than any. This port reads no updatable model --
 * facts/CoreML/CoreML.md says why -- so no description of the port's own carries such a constraint,
 * and a parameter description answers nil for it rather than a bound of nothing.
 */
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

/* The bound a model's own parameter values sit in, which is how an updatable model says that a
 * learning rate is one of these numbers rather than any. This port reads no updatable model --
 * facts/CoreML/CoreML.md says why -- so no description of the port's own carries such a
 * constraint, and a parameter description answers nil for it rather than a bound of nothing. */
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
