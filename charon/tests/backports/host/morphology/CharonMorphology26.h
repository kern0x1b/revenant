#ifndef CHARON_MORPHOLOGY_26_H
#define CHARON_MORPHOLOGY_26_H

#import <Foundation/Foundation.h>

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
