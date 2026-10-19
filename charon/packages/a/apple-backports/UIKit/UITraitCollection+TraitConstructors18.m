// UITraitCollection+TraitConstructors18.m - the one member of UIKit's 18.0 band the port can answer:
// +[UITraitCollection traitCollectionWithListEnvironment:].
//
// UITraitCollection is a class this port owns rather than one the release carries: it is absent from both
// band ends (facts/UIKit/UIKit18_0.md, M1), so a member of it is a member of the port's own class and there
// is no release behaviour to be faithful to beyond the trait store the port already keeps. What 18.0 added
// to that class is the constructor for the list environment - the trait that decides how a dynamic colour
// resolves inside a table or a list section - and the port already carries that trait on both sides:
//
//   * UITraitListEnvironment is implemented (registry/UIKit/ios17traits.json, UITraitList18.m) and its row
//     carries minimum 6.0, so the class is exported in every band this file is in;
//   * -[UITraitCollection listEnvironment] is implemented by the same store's reader,
//     CHARON_TRAIT_PROPERTY([UITraitListEnvironment class], UIListEnvironment, listEnvironment,
//     setListEnvironment) at UITraitCollection+Traits17.m:239, which reaches -valueForTraitClass: ->
//     -valueForNSIntegerTrait:;
//   * +[UITraitCollection traitCollectionWithNSIntegerValue:forTrait:] is the store's own writer,
//     UITraitCollection+Traits17.m:321, and UITraitListEnvironment's own definition is an NSInteger one
//     (CHARON_TRAIT(17, UITraitListEnvironment, @"ListEnvironment", CharonTraitValueNSInteger,
//     CharonTraitHomeExtras, @(0), YES) in UITraitList18.m), so the writer's kind is this trait's kind.
//
// So the constructor is one call to the writer, and what it writes is what -listEnvironment reads and what
// the colour appearance that names the trait resolves from. A second store, or an ivar of its own, would be
// a second copy of the machinery this tree already has - and a category cannot hold an ivar anyway.
//
// NOT VALIDATED, and neither is the store: the value goes in as it arrives, the trait's default of 0 (None)
// is what an unset collection answers, and no out-of-range value is refused. That is the trait store's own
// answer, reached through the writer that UITraitCollection+TraitConstructors17.m's three constructors use
// as well - measured for those in facts/UIKit/UIKit17Absence.md, M15, where an out-of-range value is stored
// and printed back unchanged with no exception.
//
// One .m, one release: the single row this file carries is 18.0.

#import <UIKit/UIKit.h>
#import "CharonTraits17.h"

// The 16.4 build SDK the port compiles against has no UITrait.h - the trait classes reached UIKit in 17.0 -
// so the enumeration this constructor takes and the trait class it names come from CharonTraits17.h, behind
// the __has_include the rest of the tree uses: on this SDK from the header, and on the newer SDK the host
// differential compiles against from the SDK's own, where redeclaring the method would be a duplicate. The
// same guard and the same reason are in UITraitCollection+TraitConstructors17.m, the file this one continues.

#if !__has_include(<UIKit/UITrait.h>)

@interface UITraitCollection (CharonTraitConstructors18)
+ (UITraitCollection *)traitCollectionWithListEnvironment:(UIListEnvironment)listEnvironment;
@end

#endif

@implementation UITraitCollection (CharonTraitConstructors18)

+ (UITraitCollection *)traitCollectionWithListEnvironment:(UIListEnvironment)listEnvironment
{
    return [self traitCollectionWithNSIntegerValue:(NSInteger)listEnvironment forTrait:[UITraitListEnvironment class]];
}

@end