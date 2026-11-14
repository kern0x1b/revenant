#import "check.h"
#import "../revenant_alias.h"

REVENANT_ALIAS_STATE(ProbeAlias, NSObject,
    int _value;
)

REVENANT_ALIAS_ADOPTS(ProbeAlias, NSCopying, NSSecureCoding)

@implementation REVENANT_ALIAS_CLASS(ProbeAlias) (Probe)

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class declared = objc_getClass("RevenantProbeAlias");
    Class alias = objc_getClass("ProbeAlias");
    revenant_check(declared != Nil, "the class the source declares is registered", @"Nil");
    revenant_check(alias != Nil, "the alias is registered under the SDK's name", @"Nil");
    Protocol *asked = revenant_negative ? @protocol(NSFastEnumeration) : @protocol(NSCopying);
    revenant_check(class_conformsToProtocol(declared, asked), "the declared class adopts NSCopying", @"no");
    revenant_check(class_conformsToProtocol(alias, asked), "the alias adopts NSCopying for class_conformsToProtocol, which does not look at superclasses", @"no");
    revenant_check(class_conformsToProtocol(alias, @protocol(NSSecureCoding)), "the alias adopts NSSecureCoding for class_conformsToProtocol", @"no");
    revenant_check([alias conformsToProtocol:@protocol(NSCopying)], "the alias adopts NSCopying for conformsToProtocol:", @"no");
    id instance = [[alias alloc] init];
    revenant_check([instance conformsToProtocol:@protocol(NSCopying)], "an instance of the alias conforms to NSCopying", @"no");
    revenant_check(!class_conformsToProtocol(alias, @protocol(NSFastEnumeration)), "the alias adopts only what the source lists", @"it adopts NSFastEnumeration");
    return revenant_finish();
}
