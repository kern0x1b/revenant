// UIImageConfiguration+Locale17.m - the locale of iOS 17.0 on a UIImageConfiguration: the two constructors,
// the accessor pair, and the storage that keeps a locale through a copy, an equality test, an archive and an
// applying-configuration.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M14), and the measurement decided
// this file's whole shape:
//
//   * The locale is a FIELD of the configuration, not part of the trait collection. Measured: a configuration
//     built by +configurationWithTraitCollection: reads `locale=(nil)` in its own description and nil from the
//     getter, and one built by +configurationWithLocale: reads its locale and no traits. So the two are the
//     release's own two shapes rather than one shape each.
//
//   * BOTH constructors keep the other half. Measured: -configurationWithLocale: on a configuration that already
//     carries traits keeps them, and -configurationWithTraitCollection: on one that already carries a locale
//     keeps it - `traits=(UserInterfaceStyle = Dark), locale=(...)`. So neither constructor resets the other,
//     and each returns a NEW object (measured: `same? 0` both ways) except when it would change nothing.
//
//   * A configuration that sets neither is `unspecified`, the state the base class already reports, and
//     -configurationByApplyingConfiguration: from an unspecified receiver takes the locale: measured
//     `fresh applying locale one -> locale=(...), same? 0`. That reaches the field through the base class's own
//     `charon_applyFieldsOfConfiguration:` hook, which is the seam this file is built to use.
//
//   * Equality and archiving take the locale into account: measured, two configurations built from one locale
//     are equal and hash alike, +supportsSecureCoding answers YES, and a configuration written and read back
//     through NSKeyedArchiver holds its locale.
//
// Why a subclass under a category, which is the shape UIImageSymbolConfiguration.m already uses in this tree:
//
//   * The ACCESSORS and the two constructors belong to UIImageConfiguration itself - the registry rows are
//     `UIImageConfiguration.locale`, `+configurationWithLocale:` and `-configurationWithLocale:` - and a
//     category is the only shape that adds a member to a class this port already defines wholesale. A category
//     cannot add a subclass's ivar either, so the storage is one associated object per configuration, keyed by a
//     file-static address, held COPY so a locale the caller goes on mutating does not change what the
//     configuration answers.
//
//   * The five hooks that must CHAIN to the base class's own implementation cannot chain from a category.
//     Measured, not assumed: in `@implementation Base (Cat)`, `[super copyWithZone:]` resolves against NSObject,
//     not against Base, and clang says so - "no visible @interface for 'NSObject' declares the selector
//     'copyWithZone:'". So a category that overrode -copyWithZone: would answer NSObject's copy and lose the
//     traits, which is worse than not carrying the locale at all.
//
//   * So the chaining lives in a SUBCLASS, where `[super ...]` reaches UIImageConfiguration's own code, and the
//     subclass is private to this file: its name begins with Charon, so `internal_symbol` keeps it out of the
//     exports, `carried_api` keeps its members out of the registry check, and no registry row names it. The
//     constructors build one so that every configuration this file hands out is an instance whose copy, equality,
//     archive and description all carry the locale.
//
// One .m, one release: the four rows this file carries are all 17.0. UIImageConfiguration.m next to it is 13.0
// and this file does not touch it; release-split reads band points only, so a file holding both would pass the
// tool and only a reader would catch it.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonSymbols.h"

// The 16.4 build SDK's UIImageConfiguration.h stops at `traitCollection`, so the accessor pair and the instance
// constructor are written here; the guard is on the deployment maximum rather than on __has_include because the
// header EXISTS on this SDK and does not merely lack these members - which is exactly the trap
// UIContentUnavailableProperties.h's own header describes, where a header that does not exist at all is the
// test. On the newer SDK the host differential compiles against, __IPHONE_OS_VERSION_MAX_ALLOWED is at or above
// 170000 and the SDK's own declarations are used, so nothing is declared twice.
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 170000

@interface UIImageConfiguration (CharonLocale17)
@property (nonatomic, copy, nullable) NSLocale *locale;
- (instancetype)configurationWithLocale:(nullable NSLocale *)locale;
@end

// A declaration and nothing else, for the base class's own equality seam. It is defined in
// UIImageConfiguration.m, which no other file's compiler reads, and without a declaration here clang resolves
// the name against the ONLY one visible anywhere in the SDK - UIImageSymbolConfiguration.h's, whose parameter is
// the narrower UIImageSymbolConfiguration - so `[super ...]` below is a type error. Measured, not guessed. This
// is a separate category from the one above so that declaring it does not oblige this file to implement it: the
// base class does, and a subclass overrides it.
@interface UIImageConfiguration (CharonLocale17Equality)
- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration;
@end

#endif

// One address per property, declared file-static so the addresses are distinct and cannot collide with another
// translation unit's, and const so a caller cannot take one.
static const char CharonImageConfigurationLocaleKey;

static NSLocale *charon_configuration_locale(UIImageConfiguration *configuration)
{
    return objc_getAssociatedObject(configuration, &CharonImageConfigurationLocaleKey);
}

static void charon_set_configuration_locale(UIImageConfiguration *configuration, NSLocale *locale)
{
    objc_setAssociatedObject(configuration, &CharonImageConfigurationLocaleKey, locale, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// The release's own copy rule, measured: a configuration set to the locale it already holds is the receiver, and
// any other change is a new object. A nil locale on a configuration that holds none is the receiver too, which
// is the same comparison with nil on both sides - and [nil isEqual: nil] is NO in this framework's measure, so
// the identity test comes first and is what makes the nil case answer the receiver rather than a copy.
static UIImageConfiguration *charon_configuration_with_locale(UIImageConfiguration *configuration, NSLocale *locale)
{
    NSLocale *held = charon_configuration_locale(configuration);
    if (locale == held || (locale && [locale isEqual:held]))
        return configuration;
    // -copy is the base class's own copy, which copies the traits and does not know about a locale because it is
    // a 13.0 object. So the copy is made here and the locale is put on the COPY, never on the receiver: the
    // release answers a new object, and a caller that keeps the original must find it unchanged.
    UIImageConfiguration *copy = [configuration copy];
    charon_set_configuration_locale(copy, locale);
    return copy;
}

// The configuration that carries a locale. Private to this file, and a subclass for the reason measured above:
// these five methods each chain to UIImageConfiguration's own implementation, and a category's `[super ...]`
// resolves against NSObject instead. A subclass's `[super ...]` reaches the class it extends.
@interface CharonLocaleConfiguration : UIImageConfiguration
@end

@implementation CharonLocaleConfiguration

- (id)copyWithZone:(NSZone *)zone
{
    UIImageConfiguration *copy = [super copyWithZone:zone];
    // The base's copy keeps the traits and asks nothing about the rest, so the locale is carried across here.
    // Measured: a configuration archived and read back holds its locale, and it reaches -copy on that path.
    charon_set_configuration_locale(copy, charon_configuration_locale(self));
    return copy;
}

- (BOOL)charon_isUnspecified
{
    return [super charon_isUnspecified] && !charon_configuration_locale(self);
}

- (void)charon_applyFieldsOfConfiguration:(UIImageConfiguration *)other
{
    [super charon_applyFieldsOfConfiguration:other];
    // Only a real locale is applied. Applying nil over nil changes nothing, and applying nil over a real locale
    // would CLEAR a field, which is not what "applying a configuration that sets no locale" means - measured on
    // the host, applying a fresh configuration to one that holds a locale leaves the locale in place.
    NSLocale *locale = charon_configuration_locale(other);
    if (locale)
        charon_set_configuration_locale(self, locale);
}

- (BOOL)isEqualToConfiguration:(UIImageConfiguration *)otherConfiguration
{
    if (![super isEqualToConfiguration:otherConfiguration])
        return NO;
    return [charon_configuration_locale(self) isEqual:charon_configuration_locale(otherConfiguration)];
}

- (NSUInteger)hash
{
    // The base's own hash already folds in the traits, so it is left alone and the locale is folded into that.
    // The host's hash is per object rather than per value (measured, M14b: two equal configurations hashed
    // differently), which is a defect a dictionary holding two equal configurations would trip over, so the
    // port keeps the value-based hash every configuration type in this tree already uses.
    return [super hash] ^ charon_configuration_locale(self).hash;
}

- (NSMutableArray<NSString *> *)charon_fieldDescriptions
{
    NSMutableArray *fields = [super charon_fieldDescriptions];
    // Measured: the host prints `locale=(...)` after the traits, and prints nothing at all when there is
    // neither - which is the bare `unspecified` the base class prints on its own.
    NSLocale *locale = charon_configuration_locale(self);
    if (locale)
        [fields addObject:[NSString stringWithFormat:@"locale=(%@)", locale]];
    return fields;
}

@end

@implementation UIImageConfiguration (CharonLocale17)

- (NSLocale *)locale
{
    return charon_configuration_locale(self);
}

- (void)setLocale:(NSLocale *)locale
{
    charon_set_configuration_locale(self, locale);
}

- (instancetype)configurationWithLocale:(NSLocale *)locale
{
    return charon_configuration_with_locale(self, locale);
}

+ (instancetype)configurationWithLocale:(NSLocale *)locale
{
    // Measured: a nil locale gives a configuration that is `unspecified` rather than one holding nil, and a real
    // one gives a configuration whose traits are empty. So the receiver starts as a fresh configuration with no
    // trait and no locale, and the locale is set only when there is one.
    CharonLocaleConfiguration *result = [[CharonLocaleConfiguration alloc] initCharonWithTraitCollection:nil];
    if (locale)
        charon_set_configuration_locale(result, locale);
    return result;
}

+ (instancetype)configurationWithTraitCollection:(UITraitCollection *)traitCollection
{
    // Measured: this constructor sets the traits and leaves the locale nil - it never inherits one, being a class
    // method with no receiver to inherit from. The base class's own INSTANCE method of the same name is the same
    // operation on a receiver and keeps whatever locale the receiver held; both go through the same copy rule,
    // so the locale of the receiver survives it. The receiver is the subclass so the configuration this returns
    // carries its locale through a copy and an archive, which a plain UIImageConfiguration would not.
    CharonLocaleConfiguration *result = [[CharonLocaleConfiguration alloc] initCharonWithTraitCollection:traitCollection];
    return result;
}

@end