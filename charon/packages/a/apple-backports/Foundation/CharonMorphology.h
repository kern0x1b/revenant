#import <Foundation/Foundation.h>

#ifdef CHARON_MORPHOLOGY_IOS17_ENUMS
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
#endif

@class NSMorphologyCustomPronoun;

FOUNDATION_EXPORT BOOL CharonCustomPronounSupportedLanguage(NSString *language);
FOUNDATION_EXPORT NSArray<NSString *> *CharonCustomPronounRequiredKeys(void);

FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionRuleAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAlternativeAttributeName;
FOUNDATION_EXPORT NSString *const NSInflectionConceptsKey;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAgreementConceptAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAgreementArgumentAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionReferentConceptAttributeName;

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
#endif
