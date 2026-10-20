#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>

#import "RevenantMorphology.h"

typedef struct {
    NSGrammaticalCase case_;
    NSGrammaticalDetermination determination;
    NSGrammaticalPerson person;
    NSGrammaticalPronounType pronounType;
    NSGrammaticalDefiniteness definiteness;
} RevenantGrammatical17;

static char RevenantGrammatical17Key;

static RevenantGrammatical17 *revenant_grammatical17(NSMorphology *morphology, BOOL create)
{
    NSMutableData *boxed = objc_getAssociatedObject(morphology, &RevenantGrammatical17Key);
    if (!boxed && !create) {
        static const RevenantGrammatical17 empty;
        return (RevenantGrammatical17 *)&empty;
    }
    if (!boxed && create) {
        RevenantGrammatical17 empty;
        memset(&empty, 0, sizeof(empty));
        boxed = [NSMutableData dataWithBytes:&empty length:sizeof(empty)];
        objc_setAssociatedObject(morphology, &RevenantGrammatical17Key, boxed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return (RevenantGrammatical17 *)boxed.mutableBytes;
}


static NSArray *RevenantCustomPronounLanguages(void)
{
    static NSArray *languages;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ languages = @[@"en", @"en_US", @"en_GB"]; });
    return languages;
}

NSArray<NSString *> *RevenantCustomPronounRequiredKeys(void)
{
    static NSArray *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @[@"subjectForm", @"objectForm", @"possessiveForm", @"possessiveAdjectiveForm", @"reflexiveForm"];
    });
    return keys;
}

BOOL RevenantCustomPronounSupportedLanguage(NSString *language)
{
    return language != nil && [RevenantCustomPronounLanguages() containsObject:language];
}

@implementation NSMorphology (RevenantGrammatical17)

- (NSGrammaticalCase)grammaticalCase { return revenant_grammatical17(self, NO)->case_; }
- (void)setGrammaticalCase:(NSGrammaticalCase)value { revenant_grammatical17(self, YES)->case_ = value; }
- (NSGrammaticalDetermination)determination { return revenant_grammatical17(self, NO)->determination; }
- (void)setDetermination:(NSGrammaticalDetermination)value { revenant_grammatical17(self, YES)->determination = value; }
- (NSGrammaticalPerson)grammaticalPerson { return revenant_grammatical17(self, NO)->person; }
- (void)setGrammaticalPerson:(NSGrammaticalPerson)value { revenant_grammatical17(self, YES)->person = value; }
- (NSGrammaticalPronounType)pronounType { return revenant_grammatical17(self, NO)->pronounType; }
- (void)setPronounType:(NSGrammaticalPronounType)value { revenant_grammatical17(self, YES)->pronounType = value; }
- (NSGrammaticalDefiniteness)definiteness { return revenant_grammatical17(self, NO)->definiteness; }
- (void)setDefiniteness:(NSGrammaticalDefiniteness)value { revenant_grammatical17(self, YES)->definiteness = value; }

@end

@implementation NSMorphology
{
    NSMutableDictionary *_customPronouns;
    NSGrammaticalGender _grammaticalGender;
    NSGrammaticalPartOfSpeech _partOfSpeech;
    NSGrammaticalNumber _number;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSMorphology class]])
        return NO;
    NSMorphology *that = other;
    return _grammaticalGender == that->_grammaticalGender && _partOfSpeech == that->_partOfSpeech &&
           _number == that->_number && self.grammaticalCase == that.grammaticalCase &&
           self.determination == that.determination && self.grammaticalPerson == that.grammaticalPerson &&
           self.pronounType == that.pronounType && self.definiteness == that.definiteness;
}

- (NSUInteger)hash
{
    return (NSUInteger)_grammaticalGender ^ ((NSUInteger)_partOfSpeech << 4) ^ ((NSUInteger)_number << 8) ^
           ((NSUInteger)self.grammaticalCase << 12) ^ ((NSUInteger)self.determination << 16) ^
           ((NSUInteger)self.grammaticalPerson << 20) ^ ((NSUInteger)self.pronounType << 24) ^
           ((NSUInteger)self.definiteness << 28);
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMorphology *copy = [[[self class] allocWithZone:zone] init];
    copy->_grammaticalGender = _grammaticalGender;
    copy->_partOfSpeech = _partOfSpeech;
    copy->_number = _number;
    copy.grammaticalCase = self.grammaticalCase;
    copy.determination = self.determination;
    copy.grammaticalPerson = self.grammaticalPerson;
    copy.pronounType = self.pronounType;
    copy.definiteness = self.definiteness;
    return copy;
}

- (BOOL)isUnspecified
{
    return _grammaticalGender == 0 && _partOfSpeech == 0 && _number == 0;
}

+ (NSMorphology *)userMorphology
{
    return [[NSMorphology alloc] init];
}

- (NSMorphologyCustomPronoun *)customPronounForLanguage:(NSString *)language
{
    if (!language)
        return nil;
    return _customPronouns[language];
}

- (BOOL)setCustomPronoun:(NSMorphologyCustomPronoun *)features forLanguage:(NSString *)language error:(NSError **)error
{
    if (!features) {
        [_customPronouns removeObjectForKey:language];
        return YES;
    }
    NSString *missing = nil;
    if (!RevenantCustomPronounSupportedLanguage(language)) {
        missing = @"self";
    } else if ((missing = [features revenant_firstMissingKey]) != nil) {
    }
    if (missing) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:1024
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The value \xe2\x80\x9c%@\xe2\x80\x9d is invalid.",
                                                                                         missing]}];
        return NO;
    }
    if (!_customPronouns)
        _customPronouns = [NSMutableDictionary dictionary];
    _customPronouns[language] = [features copy];
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_grammaticalGender forKey:@"grammaticalGender"];
    [coder encodeInteger:_partOfSpeech forKey:@"partOfSpeech"];
    [coder encodeInteger:_number forKey:@"number"];
    [coder encodeInteger:self.grammaticalCase forKey:@"grammaticalCase"];
    [coder encodeInteger:self.determination forKey:@"determination"];
    [coder encodeInteger:self.grammaticalPerson forKey:@"grammaticalPerson"];
    [coder encodeInteger:self.pronounType forKey:@"pronounType"];
    [coder encodeInteger:self.definiteness forKey:@"definiteness"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _grammaticalGender = [coder decodeIntegerForKey:@"grammaticalGender"];
    _partOfSpeech = [coder decodeIntegerForKey:@"partOfSpeech"];
    _number = [coder decodeIntegerForKey:@"number"];
    self.grammaticalCase = (NSGrammaticalCase)[coder decodeIntegerForKey:@"grammaticalCase"];
    self.determination = (NSGrammaticalDetermination)[coder decodeIntegerForKey:@"determination"];
    self.grammaticalPerson = (NSGrammaticalPerson)[coder decodeIntegerForKey:@"grammaticalPerson"];
    self.pronounType = (NSGrammaticalPronounType)[coder decodeIntegerForKey:@"pronounType"];
    self.definiteness = (NSGrammaticalDefiniteness)[coder decodeIntegerForKey:@"definiteness"];
    return self;
}

static NSString *revenant_grammatical(NSString *enumName, NSString *const *names, NSUInteger count, NSInteger value)
{
    if (value >= 0 && (NSUInteger)value < count)
        return names[value];
    return [NSString stringWithFormat:@"(%@)(%ld)", enumName, (long)value];
}

- (NSString *)description
{
    static NSString *const genders[] = {@"NotSet", @"Feminine", @"Masculine", @"Neuter"};
    static NSString *const numbers[] = {@"NotSet", @"Singular", @"Zero", @"Plural", @"PluralTwo", @"PluralFew", @"PluralMany"};
    static NSString *const parts[] = {@"NotSet", @"Determiner", @"Pronoun", @"Letter", @"Adverb", @"Particle",
                                       @"Adjective", @"Adposition", @"Verb", @"Noun", @"Conjunction", @"Numeral", @"Interjection"};
    static NSString *const cases[] = {@"NotSet", @"Nominative", @"Accusative", @"Dative", @"Genitive", @"Prepositional", @"Ablative",
                                      @"Adessive", @"Allative", @"Elative", @"Illative", @"Essive", @"Inessive", @"Locative",
                                      @"Translative"};
    static NSString *const definiteness[] = {@"NotSet", @"Indefinite", @"Definite"};
    static NSString *const determination[] = {@"NotSet", @"Independent", @"Dependent"};
    static NSString *const persons[] = {@"NotSet", @"First", @"Second", @"Third"};
    static NSString *const pronounTypes[] = {@"NotSet", @"Personal", @"Reflexive", @"Possessive"};
    return [NSString stringWithFormat:@"<%@: %p> { grammaticalGender = %@, number = %@, partOfSpeech = %@, "
                                      @"case = %@, definiteness = %@, determination = %@, grammaticalPerson = %@, "
                                      @"pronounType = %@, customPronouns = %@ }",
                                      [NSString stringWithUTF8String:"NSMorphology"], self,
                                      revenant_grammatical(@"NSGrammaticalGender", genders, 4, _grammaticalGender),
                                      revenant_grammatical(@"NSGrammaticalNumber", numbers, 7, _number),
                                      revenant_grammatical(@"NSGrammaticalPartOfSpeech", parts,
                                                        sizeof(parts) / sizeof(*parts), _partOfSpeech),
                                      revenant_grammatical(@"NSGrammaticalCase", cases, sizeof(cases) / sizeof(*cases),
                                                        self.grammaticalCase),
                                      revenant_grammatical(@"NSGrammaticalDefiniteness", definiteness, 3, self.definiteness),
                                      revenant_grammatical(@"NSGrammaticalDetermination", determination, 3, self.determination),
                                      revenant_grammatical(@"NSGrammaticalPerson", persons, 4, self.grammaticalPerson),
                                      revenant_grammatical(@"NSGrammaticalPronounType", pronounTypes, 4, self.pronounType),
                                      _customPronouns ? [_customPronouns description] : @"(null)"];
}

@end
