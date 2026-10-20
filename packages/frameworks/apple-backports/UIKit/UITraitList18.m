#import "RevenantTraits17.h"

REVENANT_TRAIT(17, UITraitListEnvironment, @"ListEnvironment", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(0), YES)

@interface RevenantTraitList18 : NSObject
@end

@implementation RevenantTraitList18

+ (void)load
{
    revenant_define_UITraitListEnvironment();
}

@end

@implementation UITraitListEnvironment

+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }

@end
