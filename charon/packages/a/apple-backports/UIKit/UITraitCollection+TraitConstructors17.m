// UITraitCollection+TraitConstructors17.m - the three trait-collection constructors of iOS 17.0 that take a
// trait's VALUE rather than its trait class: +traitCollectionWithImageDynamicRange:,
// +traitCollectionWithSceneCaptureState: and +traitCollectionWithTypesettingLanguage:.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M15), and every answer here is one
// line of it:
//
//   * Each stores the value under its trait's own name and nothing else. Measured:
//     `imageDynamicRange high -> <UITraitCollection; ImageDynamicRange = 2>`,
//     `sceneCaptureState active -> <UITraitCollection; SceneCaptureState = 1>`. So the store each trait already
//     uses is the whole implementation - the same extras dictionary the older traits keep, reached through the
//     same table - and no constructor adds a store of its own.
//
//   * NONE OF THE THREE VALIDATES ITS ARGUMENT, and neither does the port. Measured: an out-of-range value is
//     stored and printed back unchanged, `dynamicRange 99 -> ImageDynamicRange = 99` and
//     `sceneCapture 99 -> SceneCaptureState = 99`, with no exception; a language that is not a language is
//     stored as given, and an NSNumber passed to the language constructor is stored as an NSNumber without a
//     word of complaint. An argument check would be the port answering something the system does not.
//
//   * A nil language sets NO trait. Measured: `nil -> holds (null)`. So the language constructor routes nil to
//     the store's own "no value" answer, which is the trait class's default, rather than storing nil as a
//     value of its own.
//
//   * The two integer constructors are the port's own +traitCollectionWithNSIntegerValue:forTrait: and the
//     language one its +traitCollectionWithObject:forTrait:, both of which the 17.0 traits object already
//     defines and which are what the older per-trait constructors of 9.0 and 10.0 are built on. A second
//     implementation of "put this value under that trait's name" would be a second copy of machinery this tree
//     already has, so each constructor here is one call to it.
//
// One .m, one release: the three rows this file carries are all 17.0. UITraitCollection+Traits17.m next to it
// also holds 18.0 and 26.0 accessors, which is a fact this file records rather than one it changes;
// release-split reads band points only, so a file holding both would pass the tool and only a reader would
// catch it, and putting the three constructors in that file would put two more releases beside them.

#import <UIKit/UIKit.h>
#import "CharonTraits17.h"

// The 16.4 build SDK has no UITrait.h, so the three enumerations these constructors take and the two trait
// classes they name come from CharonTraits17.h, which declares them behind the same __has_include the rest of
// the tree uses: on this SDK from the header, and on the newer SDK the host differential compiles against from
// the SDK's own, where redeclaring them would be a duplicate.
#if !__has_include(<UIKit/UITrait.h>)

@interface UITraitCollection (CharonTraitConstructors17)
+ (UITraitCollection *)traitCollectionWithImageDynamicRange:(UIImageDynamicRange)imageDynamicRange;
+ (UITraitCollection *)traitCollectionWithSceneCaptureState:(UISceneCaptureState)sceneCaptureState;
+ (UITraitCollection *)traitCollectionWithTypesettingLanguage:(NSString *)typesettingLanguage;
@end

#endif

@implementation UITraitCollection (CharonTraitConstructors17)

+ (UITraitCollection *)traitCollectionWithImageDynamicRange:(UIImageDynamicRange)imageDynamicRange
{
    return [self traitCollectionWithNSIntegerValue:imageDynamicRange forTrait:[UITraitImageDynamicRange class]];
}

+ (UITraitCollection *)traitCollectionWithSceneCaptureState:(UISceneCaptureState)sceneCaptureState
{
    return [self traitCollectionWithNSIntegerValue:sceneCaptureState forTrait:[UITraitSceneCaptureState class]];
}

+ (UITraitCollection *)traitCollectionWithTypesettingLanguage:(NSString *)typesettingLanguage
{
    // No argument check, measured: an NSNumber is stored as one, and a string that names no language is stored
    // as given. A nil is the one case that is not stored at all, which is the store's own nil answer - the
    // trait class's default - and is why this passes the argument straight through rather than special-casing
    // nil here.
    return [self traitCollectionWithObject:typesettingLanguage forTrait:[UITraitTypesettingLanguage class]];
}

@end