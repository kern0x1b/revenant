// The one trait class of iOS 18, in a file of its own because an object carries the API of exactly one release
// and this one arrived in 18.0 while the other twenty-one did not. What a trait class is, and what every one of
// them says about itself, is in UITrait17.m and in facts/UIKit/UITrait17.md, M1; the table the definitions go
// into, and the lookups over it, are in UITraitCollection+Traits17.m.
//
// The list environment is the trait a view inside a table or a list section carries, and it decides how a dynamic
// colour resolves there, which is why it affects colour appearance and the colour appearance list names it.

#import "CharonTraits17.h"

CHARON_TRAIT(17, UITraitListEnvironment, @"ListEnvironment", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(0), YES)

@interface CharonTraitList18 : NSObject
@end

@implementation CharonTraitList18

+ (void)load
{
    charon_define_UITraitListEnvironment();
}

@end

@implementation UITraitListEnvironment

+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }

@end
