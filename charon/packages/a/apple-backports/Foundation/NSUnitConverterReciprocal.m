#import <Foundation/Foundation.h>
#import "CharonDimension.h"
#import <objc/runtime.h>

@implementation CharonUnitConverterReciprocal {
@private
    double _reciprocalValue;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithReciprocalValue:(double)reciprocal
{
    if ((self = [super init]))
        _reciprocalValue = reciprocal;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSUnitConverterReciprocal cannot be decoded by non-keyed archivers"];
        return nil;
    }
    return [self initWithReciprocalValue:[coder decodeDoubleForKey:@"NS.reciprocalValue"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSUnitConverterReciprocal encoder does not allow non-keyed coding!"];
        return;
    }
    [coder encodeDouble:_reciprocalValue forKey:@"NS.reciprocalValue"];
}

- (double)reciprocalValue
{
    return _reciprocalValue;
}

- (double)baseUnitValueFromValue:(double)value
{
    return _reciprocalValue / value;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return _reciprocalValue / baseUnitValue;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[CharonUnitConverterReciprocal class]])
        return NO;
    return _reciprocalValue == [object reciprocalValue];
}

- (NSString *)description
{
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" reciprocalValue = %f", _reciprocalValue]];
}

@end

/* Foundation carries this class privately, so it exports no symbol for the band to
   re-export and a release that already has it would end up with two classes of one
   name. The name is what an archive carries, so it cannot simply be given up:
   instead the class is defined under a Charon name and the real name is registered
   for it only where the runtime does not already answer to it. */
/* an archive names the class, and an unarchiver looks it up by that name, so it
   has to answer from the moment the library loads rather than from the first time
   a converter is made */
static Class charon_registered;

__attribute__((constructor)) static void charon_register_nsunitconver(void)
{
    charon_registered = objc_getClass("NSUnitConverterReciprocal");
    if (charon_registered)
        return;
    Class made = objc_allocateClassPair([CharonUnitConverterReciprocal class], "NSUnitConverterReciprocal", 0);
    if (made)
        objc_registerClassPair(made);
    charon_registered = made ? made : [CharonUnitConverterReciprocal class];
}

Class charon_reciprocal_converter_class(void)
{
    return charon_registered ? charon_registered : [CharonUnitConverterReciprocal class];
}

NSUnitConverter *charon_reciprocal_converter(double reciprocal)
{
    return [[charon_reciprocal_converter_class() alloc] initWithReciprocalValue:reciprocal];
}
