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
