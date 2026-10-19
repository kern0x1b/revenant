#import <Foundation/Foundation.h>
#import "CharonDimension.h"

@implementation NSDimension

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)baseUnit
{
    [NSException raise:NSInvalidArgumentException format:@"*** You must override %s in your class %s to define its base unit.",
                                                        "baseUnit", class_getName(self)];
    return nil;
}

- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter
{
    return [self initWithSpecifier:NSUIntegerMax symbol:symbol converter:converter];
}

- (instancetype)initWithSpecifier:(NSUInteger)specifier symbol:(NSString *)symbol converter:(NSUnitConverter *)converter
{
    if ((self = [super initWithSymbol:symbol])) {
        _reserved = specifier;
        _converter = [converter copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSDimension cannot be decoded by non-keyed archivers"];
        return nil;
    }
    if (!(self = [super initWithCoder:coder]))
        return nil;
    NSUInteger specifier = (NSUInteger)[coder decodeIntegerForKey:@"NS.specifier"];
    return [self initWithSpecifier:specifier symbol:self.symbol
                         converter:[coder decodeObjectOfClass:[NSUnitConverter class] forKey:@"NS.converter"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSDimension encoder does not allow non-keyed coding!"];
        return;
    }
    [coder encodeInteger:(NSInteger)_reserved forKey:@"NS.specifier"];
    [coder encodeObject:_converter forKey:@"NS.converter"];
}

- (NSUnitConverter *)converter
{
    return _converter;
}

- (NSUInteger)specifier
{
    return _reserved;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![super isEqual:object])
        return NO;
    return [_converter isEqual:[object converter]];
}

@end
