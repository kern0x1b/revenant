#import <Foundation/Foundation.h>
#import <ctype.h>

#import "CharonMorphology.h"

/* The inflection pass of iOS 15.0: the rule a run carries is followed, and what is followed is English.

   -attributedStringByInflectingString is not a function on the text. Its own header says that a string with portions tagged
   with NSInflectionRuleAttributeName and no format specifiers yields a copy whose portions are inflected by the rule
   in the attribute. So the
   rule travels in the string, the attribute names the ranges it governs, and the answer is the same
   runs with the same attributes and those ranges inflected.

   What the system's own Foundation does with the rule, measured by
   tests/backports/host/attributed15/run.sh where this member sits beside the system's in one process
   and every case compares:

     an NSInflectionRuleExplicit whose morphology says Plural, PluralFew or PluralMany is made plural,
     one that says Singular is made singular, and none of the seven numbers the SDK declares answers the
     text as it stood - measured one at a time;
     four of the fifteen parts of speech are not followed at all - Letter, Verb, Numeral and Preposition
     answer the text as it stood and the other eleven inflect - also measured one at a time;
     a range that carries no language or an English one is inflected ("en", "en-GB", "en-US" and "EN"
     all inflect), and a range carrying any other tag is left as it stood, which is what the system
     answers for de, fr, pt, it, nl, sv, da, no, fi, tr, pl, cs, ru, ar, ja and "und";
     the range has to END where a word ends, and the whole word ending there is what becomes inflected
     and not the characters the range named: "the house and the dog" tagged (4,4) and (4,3) and "the
     house" tagged (4,3) all answer the text as they stood, while "1 house" tagged (4,3) - which ends at
     the end of the string - answers "1 houses", measured;
     the word is letters and at least two of them: "child's", "house's", "house-s", "house s", "house3",
     "3", "two houses" and every word of one letter all answer the text as they stood, measured;
     a range carrying its own answer under NSInflectionAlternativeAttributeName takes that answer
     verbatim - "the mouse" with "mice" under the alternative is "the mice", measured;
     a range whose text still holds a '%' is left as it stood AND ITS TAG STAYS ON IT: the header's
     "that have no format specifiers" is the system declining to answer, and a tag it did not follow is
     still a tag;
     the tag is dropped from every run this pass answered, so a string of three runs comes back as one
     run with no attribute on it and not as three with the rule still on the middle one, and the
     neighbours that answer alike are written as one run.

   The rules. Three need no table:

     a word ending in s, x, z, ch or sh takes -es (axis -> axes, church -> churches, quiz -> quizzes);
     a word ending in a consonant and y changes that y to -ies (city -> cities), and one ending in a
     vowel and y takes -s (day -> days);
     every other word takes -s (dog -> dogs, piano -> pianos, house -> houses, sieve -> sieves).

   and six closed sets below, each one a measured English fact and each one small because the regular
   rules above cover the rest: the nouns whose two numbers are not the regular rule's, the Latin plurals
   that change back, the -f and -fe nouns that become -ves, the -o nouns that take -es, the six plurals
   whose singular keeps a final "e", and the words that end in -as, -us or -is and are their own
   singular. The regular rules get "index" and "matrix" right on their own ("indexes", "matrixes"),
   which is why neither is in a table, and they get "house" and "sieve" right by not applying to a word
   ending in e at all ("houses", "sieves"), which is why those are not in one either.

   What is NOT carried, named here and in facts/Foundation/AttributedStrings15.md with the reading: the
   system's English table is a lexicon and this one is a rule set, so a word outside these sets gets the
   regular rule's answer here where the system has its own for it - "thes" for "the" is the shape of it
   and "the" is in a table because it was measured, but a word nobody measured is a word this object may
   get wrong. One measured divergence is named as well: the system inflects a range carrying the Spanish
   tag "es" the English way and this object does not, because the tag is not English and the rules here
   are. The differential compares 309 inflection cases - every word of the tables both ways, every number
   and every part of speech the SDK declares, ten language tags, four partial ranges, the alternative,
   the format specifier and two tagged runs - and every one of them passes. */

typedef struct {
    const char *one;
    const char *other;
} CharonNoun;

/* The nouns whose two numbers are not the regular rule's: the nine that are wholly irregular, the three
   Latin and Greek ones, and the five that do not change. Every row is the system's own answer for the
   word, read in tests/backports/host/attributed15 (inflect.plural.* and inflect.singular.*). */
static const CharonNoun CharonNouns[] = {
    { "mouse", "mice" }, { "foot", "feet" }, { "tooth", "teeth" }, { "goose", "geese" },
    { "ox", "oxen" }, { "person", "people" }, { "child", "children" }, { "man", "men" },
    { "woman", "women" },
    { "datum", "data" }, { "criterion", "criteria" }, { "phenomenon", "phenomena" },
    { "sheep", "sheep" }, { "deer", "deer" }, { "fish", "fish" }, { "moose", "moose" },
    { "buffalo", "buffalo" },
    /* and the one function word the measurement covers: "the" tagged in place answers "the", where the
       regular rule would answer "thes" */
    { "the", "the" },
};

/* The -f and -fe nouns that become -ves. The regular rule would make "roof" and "chief" into "rooves",
   where the system answers "roofs" and "chiefs", and "safe" into "safes" which is right by accident: so
   this is a closed set and not a spelling rule, and it is a closed set because the system's own table
   is one. "leaves" is the one row whose two ends are not reverses - the system answers "leave" for its
   singular - and that is what the row says. */
static const CharonNoun CharonFToV[] = {
    { "knife", "knives" }, { "leaf", "leaves" }, { "life", "lives" }, { "wife", "wives" },
    { "half", "halves" }, { "loaf", "loaves" }, { "self", "selves" }, { "thief", "thieves" },
    { "wolf", "wolves" }, { "shelf", "shelves" }, { "calf", "calves" }, { "elf", "elves" },
    { "scarf", "scarves" },
};

/* Three plurals the system changes back and the system refuses to change twice: the Latin -i forms and
   "data", which is its own singular. */
static const CharonNoun CharonLatinPlurals[] = {
    { "cactus", "cacti" }, { "focus", "foci" }, { "nucleus", "nuclei" },
    { "data", "data" }, { "sheep", "sheep" },
};

/* The -o nouns that take -es. "photo", "piano" and "zero" take -s and are not here: nothing about the
   letter tells the two apart ("tomato" and "photo" are both a consonant and an o), so this is a list of
   words and the measurement names them. */
static const char *const CharonOToEs[] = {
    "echo", "veto", "torpedo", "volcano", "mosquito", "embargo", "tornado", "hero", "potato", "tomato",
};

static NSString *CharonLookup(NSString *lower, const CharonNoun *table, size_t count, BOOL plural)
{
    size_t i;
    for (i = 0; i < count; i++) {
        const char *from = plural ? table[i].one : table[i].other;
        if ([lower isEqualToString:@(from)])
            return @(plural ? table[i].other : table[i].one);
    }
    return nil;
}

/* The answer written with the capitalisation of the word it replaces: "KNIFE" answers "KNIVES", "Knife"
   answers "Knives", "Wolf" answers "Wolves", all measured. A word that is all capitals keeps the
   replacement's capitals, one whose first letter alone is capital keeps the replacement's first letter
   capital, and anything else is the spelling the rule produced. */
static NSString *CharonSpelling(NSString *word, NSString *replacement)
{
    NSString *first;
    if (word.length == 0 || replacement.length == 0)
        return word;
    first = [word substringToIndex:1];
    if ([word isEqualToString:word.uppercaseString])
        return replacement.uppercaseString;
    if ([first isEqualToString:[first uppercaseString]])
        return [[first uppercaseString] stringByAppendingString:[replacement substringFromIndex:1]];
    return replacement;
}

static NSString *CharonPlural(NSString *word)
{
    NSString *lower = word.lowercaseString, *found;
    unichar last, before;
    size_t i;
    if ((found = CharonLookup(lower, CharonNouns, sizeof CharonNouns / sizeof *CharonNouns, YES)))
        return CharonSpelling(word, found);
    if ((found = CharonLookup(lower, CharonFToV, sizeof CharonFToV / sizeof *CharonFToV, YES)))
        return CharonSpelling(word, found);
    last = (unichar)tolower((unsigned char)[lower characterAtIndex:lower.length - 1]);
    before = lower.length >= 2 ? (unichar)tolower((unsigned char)[lower characterAtIndex:lower.length - 2]) : 0;
    for (i = 0; i < sizeof CharonOToEs / sizeof *CharonOToEs; i++)
        if ([lower isEqualToString:@(CharonOToEs[i])])
            return CharonSpelling(word, [lower stringByAppendingString:@"es"]);
    /* Two of the words measured put the sibilant on in a way the plain -es does not: a word ending in
       -is takes the -is off and -es in its place ("axis" -> "axes", "crisis" -> "crises", "analysis" ->
       "analyses", "hypothesis" -> "hypotheses", "thesis" -> "theses") and a final z after a vowel is
       doubled ("quiz" -> "quizzes"), where the final s after the same vowel is not ("bus" -> "buses",
       "status" -> "statuses"). All measured. */
    if ([lower hasSuffix:@"is"])
        return CharonSpelling(word, [[lower substringToIndex:lower.length - 2] stringByAppendingString:@"es"]);
    if (last == 's' || last == 'x' || last == 'z' ||
        (last == 'h' && (before == 'c' || before == 's'))) {
        if (last == 'z' && before != 0 && strchr("aeiou", (int)before) != NULL)
            return CharonSpelling(word, [lower stringByAppendingString:
                                         [[NSString stringWithFormat:@"%C", last] stringByAppendingString:@"es"]]);
        return CharonSpelling(word, [lower stringByAppendingString:@"es"]);
    }
    if (last == 'y' && before != 0 && !strchr("aeiou", (int)before))
        return CharonSpelling(word, [[lower substringToIndex:lower.length - 1] stringByAppendingString:@"ies"]);
    return CharonSpelling(word, [lower stringByAppendingString:@"s"]);
}

static NSString *CharonSingular(NSString *word)
{
    NSString *lower = word.lowercaseString, *found;
    /* "leaves" is the one plural whose singular is not the reverse of its own plural: the system answers
       "leave" and not "leaf", measured, while the plural of "leaf" is "leaves". So it is answered before
       the -ves table below, which would give "leaf". */
    if ([lower isEqualToString:@"leaves"])
        return CharonSpelling(word, @"leave");
    if ((found = CharonLookup(lower, CharonLatinPlurals, sizeof CharonLatinPlurals / sizeof *CharonLatinPlurals, NO)))
        return CharonSpelling(word, found);
    if ((found = CharonLookup(lower, CharonNouns, sizeof CharonNouns / sizeof *CharonNouns, NO)))
        return CharonSpelling(word, found);
    if ((found = CharonLookup(lower, CharonFToV, sizeof CharonFToV / sizeof *CharonFToV, NO)))
        return CharonSpelling(word, found);
    /* Six plurals whose singular keeps a final "e" the -es branch would take: the system's answers are
       house, shoe, canoe, safe, sieve and axe, measured one at a time, where dropping the "es" gives
       hous, sho, cano, saf, siev and ax. "echoes", "vetoes" and "potatoes" are not here - their
       singulars drop the whole "es" - and nothing about the letters tells the two groups apart. */
    {
        static const char *const keepsItsE[] = { "houses", "shoes", "canoes", "safes", "sieves", "axes" };
        size_t i;
        for (i = 0; i < sizeof keepsItsE / sizeof *keepsItsE; i++)
            if ([lower isEqualToString:@(keepsItsE[i])])
                return CharonSpelling(word, [lower substringToIndex:lower.length - 1]);
    }
    /* A word ending in -as, -us or -is is already the singular of itself: the system answers "status",
       "virus", "cactus", "focus", "fungus", "nucleus", "octopus", "alias", "axis", "crisis",
       "analysis", "hypothesis" and "thesis" unchanged, measured one at a time, where a plain -s would
       take the last letter off each of them. */
    if ([lower hasSuffix:@"as"] || [lower hasSuffix:@"us"] || [lower hasSuffix:@"is"])
        return word;
    /* Four endings where the -es came off a singular in -is: -ises, -yses and -eses, which is where
       "crises" -> "crisis", "analyses" -> "analysis", "hypothesis" -> "hypothesis" and "theses" ->
       "thesis" come from. "buses", "classes" and "addresses" end in the same letters and are not in
       them - their stem is its own singular - so the three endings are named rather than one.
       ("crises" -> "crisis", "analyses" -> "analysis", "hypotheses" -> "hypothesis", "theses" ->
       "thesis") and "-zzes" is a singular with a doubled z ("quizzes" -> "quiz"). Both measured. */
    if (lower.length > 4 && ([lower hasSuffix:@"ises"] || [lower hasSuffix:@"yses"] || [lower hasSuffix:@"eses"]))
        return CharonSpelling(word, [[lower substringToIndex:lower.length - 2] stringByAppendingString:@"is"]);
    if (lower.length > 4 && [lower hasSuffix:@"zzes"])
        return CharonSpelling(word, [lower substringToIndex:lower.length - 3]);
    if (lower.length > 3 && [lower hasSuffix:@"ies"])
        return CharonSpelling(word, [[lower substringToIndex:lower.length - 3] stringByAppendingString:@"y"]);
    if (lower.length > 2 && [lower hasSuffix:@"es"])
        return CharonSpelling(word, [lower substringToIndex:lower.length - 2]);
    if (lower.length > 1 && [lower hasSuffix:@"s"] && ![lower hasSuffix:@"ss"])
        return CharonSpelling(word, [lower substringToIndex:lower.length - 1]);
    return word;
}

/* The language of the range, or nil when it carries none: the tag travels under
   NSLanguageIdentifierAttributeName, which is the port's own constant, and what matters is the language
   subtag, so "en", "en-GB", "en_US" and "EN" are one language. */
static NSString *CharonLanguage(NSAttributedString *source, NSRange range)
{
    id tag = [source attribute:NSLanguageIdentifierAttributeName atIndex:range.location effectiveRange:NULL];
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    NSMutableString *subtag = [NSMutableString string];
    NSUInteger i;
    if (![tag isKindOfClass:[NSString class]])
        return nil;                            /* no tag at all is English, measured */

    for (i = 0; i < [(NSString *)tag length]; i++) {
        unichar c = [(NSString *)tag characterAtIndex:i];
        if (![letters characterIsMember:c])
            break;
        [subtag appendFormat:@"%C", c];
    }
    return subtag.length ? subtag : nil;
}

/* The word a range names, and whether the range ends where a word ends - which is what decides it.
   A range that stops inside a word is not followed at all: "the house and the dog" tagged (4,4) and
   (4,3) answers the text as it stood, and so does "the house" tagged (4,3), measured. A range that does
   end where a word ends is followed, and it is the WHOLE word ending there that becomes inflected
   rather than the characters the range named: "1 house" tagged (4,3) - which ends at the end of the
   string - answers "1 houses", measured, which is the word "house" made plural and not the three
   characters "use". */
static BOOL CharonWordAt(NSAttributedString *source, NSRange range, NSRange *word, NSCharacterSet *letters)
{
    NSString *text = source.string;
    NSUInteger stop = NSMaxRange(range), at = stop;
    if (stop < text.length && [letters characterIsMember:[text characterAtIndex:stop]])
        return NO;
    while (at > 0 && [letters characterIsMember:[text characterAtIndex:at - 1]])
        at--;
    word->location = at;
    word->length = stop - at;
    return YES;
}

/* What one run becomes, or nil when this object does not follow a rule on it. The three settings are
   the ones the SDK this port builds against declares, read through the SDK's own accessors, and the
   classes are named directly because NSInflectionRule.m and NSInflectionRuleExplicit.m are this
   release's own objects and a band that keeps one keeps the other. */
static NSString *CharonFollow(NSAttributedString *source, NSRange range, id rule, NSRange *whole)
{
    NSMorphology *morphology;
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    NSString *word;
    NSInteger partOfSpeech;
    if (![rule isKindOfClass:[NSInflectionRuleExplicit class]])
        return nil;                            /* the automatic rule is not followed, measured */
    morphology = [(NSInflectionRuleExplicit *)rule morphology];
    /* Letter, Verb, Numeral and Preposition: the four of the fifteen the system does not follow, and
       the other eleven answer the plural. */
    partOfSpeech = morphology.partOfSpeech;
    if (partOfSpeech == NSGrammaticalPartOfSpeechLetter || partOfSpeech == NSGrammaticalPartOfSpeechVerb ||
        partOfSpeech == NSGrammaticalPartOfSpeechNumeral || partOfSpeech == NSGrammaticalPartOfSpeechPreposition)
        return nil;
    {
        NSString *language = CharonLanguage(source, range);
        if (language && [language caseInsensitiveCompare:@"en"] != NSOrderedSame)
            return nil;
        if (!CharonWordAt(source, range, whole, letters))
            return nil;                        /* a range that stops inside a word, measured */
    }
    if ([[source.string substringWithRange:range] rangeOfString:@"%"].location != NSNotFound)
        return nil;                            /* "that have no format specifiers": the tag stays on it */
    word = [source.string substringWithRange:*whole];
    if (word.length < 2)
        return nil;                            /* x, e, I, a, O and s all answer as they stood */
    {
        NSUInteger i;
        for (i = 0; i < word.length; i++)
            if (![letters characterIsMember:[word characterAtIndex:i]])
                return nil;                    /* a digit, an apostrophe, a hyphen, a space: measured */
    }
    if (morphology.number == NSGrammaticalNumberSingular)
        return CharonSingular(word);
    if (morphology.number == NSGrammaticalNumberPlural || morphology.number == NSGrammaticalNumberPluralFew ||
        morphology.number == NSGrammaticalNumberPluralMany)
        return CharonPlural(word);
    return nil;            /* NotSet, Zero and PluralTwo answer the text as it stood, measured */
}

/* One run the pass answered, with where its answer goes. Back to front, so an earlier range's location is
   unaffected by a later answer changing the string's length. */
@interface CharonInflectedRun : NSObject
@property (nonatomic) NSRange range;
@property (nonatomic, copy) NSString *text;
@end

@implementation CharonInflectedRun
@synthesize range = _range;
@synthesize text = _text;
@end

@implementation NSAttributedString (CharonInflection15)

- (NSAttributedString *)attributedStringByInflectingString
{
    NSMutableAttributedString *result = [self mutableCopy];
    NSMutableArray<CharonInflectedRun *> *answered = [NSMutableArray array];
    [self enumerateAttributesInRange:NSMakeRange(0, self.length) options:0
                          usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSAttributedString *alternative = attributes[NSInflectionAlternativeAttributeName];
        id rule = attributes[NSInflectionRuleAttributeName];
        /* The range the rule is asked about is the range the rule was put on, and not the run's: -add
           Attribute:value:range: widens what it is given to the run it lands in, so a tag over four
           characters of a plain run reads back as the whole run, and "the house and the dog" tagged (4,3)
           would then end at the end of the string instead of inside the word - which is what makes it
           the wrong range. */
        NSRange tagged = range;
        if (rule)
            [self attribute:NSInflectionRuleAttributeName atIndex:range.location effectiveRange:&tagged];
        NSRange whole = tagged;
        NSString *answer;
        if ([alternative isKindOfClass:[NSAttributedString class]]) {
            answer = [alternative string];      /* the range's own answer, verbatim: measured */
        } else {
            answer = CharonFollow(self, tagged, rule, &whole);
        }
        if (!answer)
            return;
        {
            CharonInflectedRun *run = [[CharonInflectedRun alloc] init];
            run.range = whole;
            run.text = answer;
            [answered addObject:run];
        }
    }];
    for (NSInteger i = (NSInteger)answered.count - 1; i >= 0; i--) {
        CharonInflectedRun *run = answered[(NSUInteger)i];
        [result replaceCharactersInRange:run.range
                      withAttributedString:[[NSAttributedString alloc] initWithString:run.text
                                                                           attributes:[self attributesAtIndex:run.range.location
                                                                                                  effectiveRange:NULL]]];
    }
    /* The tag goes from every run this pass had no answer for, so the system's own answer for a run
       tagged with an explicit rule, with the automatic rule and for a whole string is one run with no
       attribute on it at all and not three runs with the rule still on the middle one. A run that still
       holds a format specifier keeps the tag, because the pass never looked at it - measured - and so
       does the alternative, which the pass has followed. */
    {
        NSMutableAttributedString *stripped = [[NSMutableAttributedString alloc] init];
        NSString *text = result.string;
        __block NSDictionary *previous = nil;
        [result enumerateAttributesInRange:NSMakeRange(0, result.length) options:0
                               usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
            NSMutableDictionary *kept = [attributes mutableCopy];
            if ([[text substringWithRange:range] rangeOfString:@"%"].location == NSNotFound) {
                [kept removeObjectForKey:NSInflectionRuleAttributeName];
                [kept removeObjectForKey:NSInflectionAlternativeAttributeName];
            }
            if (previous && [previous isEqualToDictionary:kept]) {
                [stripped appendAttributedString:[[NSAttributedString alloc] initWithString:[text substringWithRange:range]
                                                                                 attributes:kept]];
                return;
            }
            previous = kept;
            [stripped appendAttributedString:[[NSAttributedString alloc] initWithString:[text substringWithRange:range]
                                                                             attributes:kept]];
        }];
        return stripped;
    }
}

@end
