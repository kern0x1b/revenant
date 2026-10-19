/* CharonMorphology26.h - the 26.2 Foundation's NSMorphology.h and NSInflectionRule.h, transcribed.
 *
 * The CommandLineTools SDK's own headers declare an NSMorphology without most of the 26.2 members and
 * none of the 17.0 ones, so a host differential declares them here - on a category of the SDK's class,
 * never a rename, because the class under test is the *host's* and the two must be the same object.
 * This is the same pattern tests/backports/host/prefix_selectors.py uses on the port's own side.
 *
 * Transcribed from $HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk/System/Library/
 * Frameworks/Foundation.framework/Headers/{NSMorphology.h,NSInflectionRule.h}, both of which are 163 and
 * 44 lines and both of which are read whole - the enums, the two class interfaces, the two categories on
 * NSMorphology, and the constant, which the 26.2 SDK declares in NSAttributedString.h and not here.
 *
 * API_DEPRECATED, NS_REFINED_FOR_SWIFT and NS_UNAVAILABLE are left off deliberately: the differential
 * wants to *call* what the header marks unavailable and to *not* warn about what it marks deprecated,
 * and both are compile-time only.
 */

#ifndef CHARON_MORPHOLOGY_26_H
#define CHARON_MORPHOLOGY_26_H

#import <Foundation/Foundation.h>

/* The eight grammatical enums are in the CommandLineTools SDK, so they are not transcribed here; the
   26.2 header's own values for them are the SDK's, and a differential that needs to check a value
   against the 26.2 spelling reads it from the header in sdk-26.2. What the SDK lacks is the 17.0 set of
   members and the custom-pronoun and inflection interfaces, and those are the categories below. */

/* The 26.2 SDK declares this in NSAttributedString.h. */
FOUNDATION_EXPORT NSAttributedStringKey const NSMorphologyAttributeName;

@class NSMorphologyCustomPronoun;

@interface NSMorphology (Charon26)

@property (nonatomic) NSGrammaticalGender grammaticalGender;
@property (nonatomic) NSGrammaticalPartOfSpeech partOfSpeech;
@property (nonatomic) NSGrammaticalNumber number;
@property (nonatomic) NSGrammaticalCase grammaticalCase;
@property (nonatomic) NSGrammaticalDetermination determination;
@property (nonatomic) NSGrammaticalPerson grammaticalPerson;
@property (nonatomic) NSGrammaticalPronounType pronounType;
@property (nonatomic) NSGrammaticalDefiniteness definiteness;

- (nullable NSMorphologyCustomPronoun *)customPronounForLanguage:(NSString *)language;
- (BOOL)setCustomPronoun:(nullable NSMorphologyCustomPronoun *)features forLanguage:(NSString *)language error:(NSError **)error;

@property (readonly, getter=isUnspecified) BOOL unspecified;
@property (class, readonly) NSMorphology *userMorphology;

@end

@interface NSMorphologyCustomPronoun (Charon26)

+ (BOOL)isSupportedForLanguage:(NSString *)language;
+ (NSArray<NSString *> *)requiredKeysForLanguage:(NSString *)language;

@property(nullable, copy, nonatomic) NSString *subjectForm;
@property(nullable, copy, nonatomic) NSString *objectForm;
@property(nullable, copy, nonatomic) NSString *possessiveForm;
@property(nullable, copy, nonatomic) NSString *possessiveAdjectiveForm;
@property(nullable, copy, nonatomic) NSString *reflexiveForm;

@end

@interface NSMorphologyPronoun (Charon26)

- (instancetype)initWithPronoun:(NSString *)pronoun
                      morphology:(NSMorphology *)morphology
              dependentMorphology:(nullable NSMorphology *)dependentMorphology;

@property (readonly, copy) NSString *pronoun;
@property (readonly, copy) NSMorphology *morphology;
@property (readonly, copy, nullable) NSMorphology *dependentMorphology;

@end

@interface NSInflectionRule (Charon26)

@property (class, readonly) NSInflectionRule *automaticRule;
+ (BOOL)canInflectLanguage:(NSString *)language;
@property (class, readonly) BOOL canInflectPreferredLocalization;

@end

@interface NSInflectionRuleExplicit (Charon26)

- (instancetype)initWithMorphology:(NSMorphology *)morphology;
@property (readonly, copy) NSMorphology *morphology;

@end

#endif
