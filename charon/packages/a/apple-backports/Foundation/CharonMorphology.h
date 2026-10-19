#import <Foundation/Foundation.h>

/* The 26.2 Foundation's NSMorphology.h and NSInflectionRule.h, the part of it the SDK the port builds
   against does not carry, declared here so the port can implement it.
 *
 * The 16.5 SDK declares NSMorphology and NSInflectionRule, so those two are **not** declared here -
   a redeclaration is a duplicate definition and the gate fails on it. What it does not carry is the
   iOS 17.0 set of members and the custom-pronoun and inflection-rule classes, and those are below:
 * the five grammatical properties as a **category**, because a category cannot add an ivar and their
 * storage is a side table (CharonMorphology.m), and the three classes whole, because they are
 * classes and a category cannot make one.
 *
 * Transcribed from $HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk/System/Library/
 * Frameworks/Foundation.framework/Headers/{NSMorphology.h,NSInflectionRule.h}, read whole - 163 and
 * 44 lines. The enums NSGrammaticalGender, NSGrammaticalPartOfSpeech, NSGrammaticalNumber,
 * NSGrammaticalCase, NSGrammaticalPronounType, NSGrammaticalPerson, NSGrammaticalDetermination and
 * NSGrammaticalDefiniteness are in the 16.5 SDK and are not repeated here. */

/* The five iOS 17.0 enums are **not** in the 16.5 SDK the port builds against - it has the three
   15.0 ones and not these - so they are transcribed here, in the 26.2 header's order, which is the
   portability of the API: NSGrammaticalCase runs NotSet, Nominative, Accusative, Dative, Genitive,
   Prepositional ... and NSGrammaticalDefiniteness runs NotSet, Indefinite, Definite. */
#ifdef CHARON_MORPHOLOGY_IOS17_ENUMS
/* The package defines CHARON_MORPHOLOGY_IOS17_ENUMS, because the iOS SDK it builds against has the
   three 15.0 enums and not these five (grep -c on iPhoneOS16.5.sdk's NSMorphology.h: 1 for each of
   Gender, PartOfSpeech and Number, 0 for each of these). The macOS SDK the host differential builds
   against has all eight, so a differential that did not define this would see a redeclaration - which
   is why the define is the package's and not the header's guess. */
typedef NS_ENUM(NSInteger, NSGrammaticalCase) {
    NSGrammaticalCaseNotSet = 0,
    NSGrammaticalCaseNominative,
    NSGrammaticalCaseAccusative,
    NSGrammaticalCaseDative,
    NSGrammaticalCaseGenitive,
    NSGrammaticalCasePrepositional,
    NSGrammaticalCaseAblative,
    NSGrammaticalCaseAdessive,
    NSGrammaticalCaseAllative,
    NSGrammaticalCaseElative,
    NSGrammaticalCaseIllative,
    NSGrammaticalCaseEssive,
    NSGrammaticalCaseInessive,
    NSGrammaticalCaseLocative,
    NSGrammaticalCaseTranslative
};

typedef NS_ENUM(NSInteger, NSGrammaticalPronounType) {
    NSGrammaticalPronounTypeNotSet = 0,
    NSGrammaticalPronounTypePersonal,
    NSGrammaticalPronounTypeReflexive,
    NSGrammaticalPronounTypePossessive
};

typedef NS_ENUM(NSInteger, NSGrammaticalPerson) {
    NSGrammaticalPersonNotSet = 0,
    NSGrammaticalPersonFirst,
    NSGrammaticalPersonSecond,
    NSGrammaticalPersonThird
};

typedef NS_ENUM(NSInteger, NSGrammaticalDetermination) {
    NSGrammaticalDeterminationNotSet = 0,
    NSGrammaticalDeterminationIndependent,
    NSGrammaticalDeterminationDependent
};

typedef NS_ENUM(NSInteger, NSGrammaticalDefiniteness) {
    NSGrammaticalDefinitenessNotSet = 0,
    NSGrammaticalDefinitenessIndefinite,
    NSGrammaticalDefinitenessDefinite
};
#endif /* CHARON_MORPHOLOGY_IOS17_ENUMS */

@class NSMorphologyCustomPronoun;

/* The languages the custom pronoun pair supports and the keys each requires, both measured, and both
   asked from NSMorphologyCustomPronoun.m and NSMorphology.m, so they are declared here. */
FOUNDATION_EXPORT BOOL CharonCustomPronounSupportedLanguage(NSString *language);
FOUNDATION_EXPORT NSArray<NSString *> *CharonCustomPronounRequiredKeys(void);

/* The seven attribute-name constants, all FOUNDATION_EXPORT NSAttributedStringKey in the 26.2 SDK's
   NSAttributedString.h and all measured out of the host's own image (NSMorphology, NSInflect,
   NSInflectionAlternative, NSContextInflectionConcepts, NSInflectionAgreementConcept,
   NSInflectionAgreementArgument, NSInflectionReferentConcept). They are defined in
   NSMorphologyCustomPronoun.m, which is where the family keeps its value tables, except
   NSMorphologyAttributeName which is NSMorphology's own. */
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionRuleAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAlternativeAttributeName;
FOUNDATION_EXPORT NSString *const NSInflectionConceptsKey;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAgreementConceptAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAgreementArgumentAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionReferentConceptAttributeName;

/* Six names the build SDK may or may not declare, guarded on the SDK's own version rather than on
   a macro of our own. The per-name #ifndef this first used does not work: the host's Foundation, which
   is newer than the device's, declares all six, and a macro nothing else sets is never set there --
   the host build failed with "redefinition of enumerator NSGrammaticalPronounTypePersonal" against
   its own header. The 26.2 header's API_AVAILABLE puts the five enumerations at ios(17.0) and
   macos(14.0); the class NSMorphologyPronoun is declared in the same header. So a build SDK at or
   above those versions has its own, and only a build SDK below them needs the port to spell them.
   Both sets are Apple's own and enumerate the same values, so which one a build sees changes no
   answer -- only which declaration the compiler binds.

   The values below are transcribed from
   iPhoneOS26.2.sdk/System/Library/Frameworks/Foundation.framework/Headers/NSMorphology.h, lines
   47-89 (the five enumerations) and 108-113 (the class), verbatim and in the header's order. */

#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
#define CHARON_MORPHOLOGY_26_NAMES 1
#elif defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 170000
#define CHARON_MORPHOLOGY_26_NAMES 1
#endif

#ifndef CHARON_MORPHOLOGY_26_NAMES
typedef NS_ENUM(NSInteger, NSGrammaticalCase) {
    NSGrammaticalCaseNotSet = 0,
    NSGrammaticalCaseNominative,
    NSGrammaticalCaseAccusative,
    NSGrammaticalCaseDative,
    NSGrammaticalCaseGenitive,
    NSGrammaticalCasePrepositional,
    NSGrammaticalCaseAblative,
    NSGrammaticalCaseAdessive,
    NSGrammaticalCaseAllative,
    NSGrammaticalCaseElative,
    NSGrammaticalCaseIllative,
    NSGrammaticalCaseEssive,
    NSGrammaticalCaseInessive,
    NSGrammaticalCaseLocative,
    NSGrammaticalCaseTranslative
};
#endif

#ifndef CHARON_MORPHOLOGY_26_NAMES
typedef NS_ENUM(NSInteger, NSGrammaticalPronounType) {
    NSGrammaticalPronounTypeNotSet = 0,
    NSGrammaticalPronounTypePersonal,
    NSGrammaticalPronounTypeReflexive,
    NSGrammaticalPronounTypePossessive
};
#endif

#ifndef CHARON_MORPHOLOGY_26_NAMES
typedef NS_ENUM(NSInteger, NSGrammaticalPerson) {
    NSGrammaticalPersonNotSet = 0,
    NSGrammaticalPersonFirst,
    NSGrammaticalPersonSecond,
    NSGrammaticalPersonThird
};
#endif

#ifndef CHARON_MORPHOLOGY_26_NAMES
typedef NS_ENUM(NSInteger, NSGrammaticalDetermination) {
    NSGrammaticalDeterminationNotSet = 0,
    NSGrammaticalDeterminationIndependent,
    NSGrammaticalDeterminationDependent
};
#endif

#ifndef CHARON_MORPHOLOGY_26_NAMES
typedef NS_ENUM(NSInteger, NSGrammaticalDefiniteness) {
    NSGrammaticalDefinitenessNotSet = 0,
    NSGrammaticalDefinitenessIndefinite,
    NSGrammaticalDefinitenessDefinite
};
#endif

#ifndef CHARON_MORPHOLOGY_26_NAMES
@interface NSMorphologyPronoun : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPronoun:(NSString *)pronoun
                       morphology:(NSMorphology *)morphology
              dependentMorphology:(nullable NSMorphology *)dependentMorphology;
@property (readonly, copy) NSString *pronoun;
@property (readonly, strong) NSMorphology *morphology;
@property (readonly, strong, nullable) NSMorphology *dependentMorphology;
@end
#endif

@interface NSMorphology (CharonGrammatical17)

@property (nonatomic) NSGrammaticalCase grammaticalCase;
@property (nonatomic) NSGrammaticalDetermination determination;
@property (nonatomic) NSGrammaticalPerson grammaticalPerson;
@property (nonatomic) NSGrammaticalPronounType pronounType;
@property (nonatomic) NSGrammaticalDefiniteness definiteness;

@end

@interface NSMorphologyCustomPronoun (CharonPrivate)
- (NSString *)charon_firstMissingKey;
@end

/* NSMorphologyPronoun arrived in iOS 17.0 and the 16.5 SDK has no such class, so it is declared
   here in full - which is why the port's own file is free of a redeclaration that the gate would
   refuse. Its superclass is NSObject and not NSFormatter: the 26.2 header says NSObject. */
#ifdef CHARON_MORPHOLOGY_IOS17_PRONOUN
@interface NSMorphologyPronoun : NSObject <NSCopying, NSSecureCoding>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPronoun:(NSString *)pronoun
                      morphology:(NSMorphology *)morphology
              dependentMorphology:(nullable NSMorphology *)dependentMorphology;

@property (readonly, copy) NSString *pronoun;
@property (readonly, copy) NSMorphology *morphology;
@property (readonly, copy, nullable) NSMorphology *dependentMorphology;

@end
#endif /* CHARON_MORPHOLOGY_IOS17_PRONOUN */

