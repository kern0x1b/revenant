#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSDimension (CharonSpecifier)
- (instancetype)initWithSpecifier:(NSUInteger)specifier symbol:(NSString *)symbol converter:(NSUnitConverter *)converter;
@property (readonly) NSUInteger specifier;
@end

@interface CharonUnitConverterReciprocal : NSUnitConverter <NSSecureCoding>
- (instancetype)initWithReciprocalValue:(double)reciprocal;
@property (readonly) double reciprocalValue;
@end

Class charon_reciprocal_converter_class(void);
NSUnitConverter *charon_reciprocal_converter(double reciprocal);
