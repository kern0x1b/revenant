#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSDimension (RevenantSpecifier)
- (instancetype)initWithSpecifier:(NSUInteger)specifier symbol:(NSString *)symbol converter:(NSUnitConverter *)converter;
@property (readonly) NSUInteger specifier;
@end

@interface RevenantUnitConverterReciprocal : NSUnitConverter <NSSecureCoding>
- (instancetype)initWithReciprocalValue:(double)reciprocal;
@property (readonly) double reciprocalValue;
@end

Class revenant_reciprocal_converter_class(void);
NSUnitConverter *revenant_reciprocal_converter(double reciprocal);
