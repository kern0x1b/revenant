#import <Foundation/Foundation.h>
#import <ctype.h>

#import "RevenantMorphology.h"

typedef struct {
    const char *one;
    const char *other;
} RevenantNoun;

static const RevenantNoun RevenantNouns[] = {
    { "mouse", "mice" }, { "foot", "feet" }, { "tooth", "teeth" }, { "goose", "geese" },
    { "ox", "oxen" }, { "person", "people" }, { "child", "children" }, { "man", "men" },
    { "woman", "women" },
    { "datum", "data" }, { "criterion", "criteria" }, { "phenomenon", "phenomena" },
    { "sheep", "sheep" }, { "deer", "deer" }, { "fish", "fish" }, { "moose", "moose" },
    { "buffalo", "buffalo" },
    { "the", "the" },
};

static const RevenantNoun RevenantFToV[] = {
    { "knife", "knives" }, { "leaf", "leaves" }, { "life", "lives" }, { "wife", "wives" },
    { "half", "halves" }, { "loaf", "loaves" }, { "self", "selves" }, { "thief", "thieves" },
    { "wolf", "wolves" }, { "shelf", "shelves" }, { "calf", "calves" }, { "elf", "elves" },
    { "scarf", "scarves" },
};

static const RevenantNoun RevenantLatinPlurals[] = {
    { "cactus", "cacti" }, { "focus", "foci" }, { "nucleus", "nuclei" },
    { "data", "data" }, { "sheep", "sheep" },
};

static const char *const RevenantOToEs[] = {
    "echo", "veto", "torpedo", "volcano", "mosquito", "embargo", "tornado", "hero", "potato", "tomato",
};

static NSString *RevenantLookup(NSString *lower, const RevenantNoun *table, size_t count, BOOL plural)
{
    size_t i;
    for (i = 0; i < count; i++) {
        const char *from = plural ? table[i].one : table[i].other;
        if ([lower isEqualToString:@(from)])
            return @(plural ? table[i].other : table[i].one);
    }
    return nil;
}

static NSString *RevenantSpelling(NSString *word, NSString *replacement)
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

static NSString *RevenantPlural(NSString *word)
{
    NSString *lower = word.lowercaseString, *found;
    unichar last, before;
    size_t i;
    if ((found = RevenantLookup(lower, RevenantNouns, sizeof RevenantNouns / sizeof *RevenantNouns, YES)))
        return RevenantSpelling(word, found);
    if ((found = RevenantLookup(lower, RevenantFToV, sizeof RevenantFToV / sizeof *RevenantFToV, YES)))
        return RevenantSpelling(word, found);
    last = (unichar)tolower((unsigned char)[lower characterAtIndex:lower.length - 1]);
    before = lower.length >= 2 ? (unichar)tolower((unsigned char)[lower characterAtIndex:lower.length - 2]) : 0;
    for (i = 0; i < sizeof RevenantOToEs / sizeof *RevenantOToEs; i++)
        if ([lower isEqualToString:@(RevenantOToEs[i])])
            return RevenantSpelling(word, [lower stringByAppendingString:@"es"]);
    if ([lower hasSuffix:@"is"])
        return RevenantSpelling(word, [[lower substringToIndex:lower.length - 2] stringByAppendingString:@"es"]);
    if (last == 's' || last == 'x' || last == 'z' ||
        (last == 'h' && (before == 'c' || before == 's'))) {
        if (last == 'z' && before != 0 && strchr("aeiou", (int)before) != NULL)
            return RevenantSpelling(word, [lower stringByAppendingString:
                                         [[NSString stringWithFormat:@"%C", last] stringByAppendingString:@"es"]]);
        return RevenantSpelling(word, [lower stringByAppendingString:@"es"]);
    }
    if (last == 'y' && before != 0 && !strchr("aeiou", (int)before))
        return RevenantSpelling(word, [[lower substringToIndex:lower.length - 1] stringByAppendingString:@"ies"]);
    return RevenantSpelling(word, [lower stringByAppendingString:@"s"]);
}

static NSString *RevenantSingular(NSString *word)
{
    NSString *lower = word.lowercaseString, *found;
    if ([lower isEqualToString:@"leaves"])
        return RevenantSpelling(word, @"leave");
    if ((found = RevenantLookup(lower, RevenantLatinPlurals, sizeof RevenantLatinPlurals / sizeof *RevenantLatinPlurals, NO)))
        return RevenantSpelling(word, found);
    if ((found = RevenantLookup(lower, RevenantNouns, sizeof RevenantNouns / sizeof *RevenantNouns, NO)))
        return RevenantSpelling(word, found);
    if ((found = RevenantLookup(lower, RevenantFToV, sizeof RevenantFToV / sizeof *RevenantFToV, NO)))
        return RevenantSpelling(word, found);
    {
        static const char *const keepsItsE[] = { "houses", "shoes", "canoes", "safes", "sieves", "axes" };
        size_t i;
        for (i = 0; i < sizeof keepsItsE / sizeof *keepsItsE; i++)
            if ([lower isEqualToString:@(keepsItsE[i])])
                return RevenantSpelling(word, [lower substringToIndex:lower.length - 1]);
    }
    if ([lower hasSuffix:@"as"] || [lower hasSuffix:@"us"] || [lower hasSuffix:@"is"])
        return word;
    if (lower.length > 4 && ([lower hasSuffix:@"ises"] || [lower hasSuffix:@"yses"] || [lower hasSuffix:@"eses"]))
        return RevenantSpelling(word, [[lower substringToIndex:lower.length - 2] stringByAppendingString:@"is"]);
    if (lower.length > 4 && [lower hasSuffix:@"zzes"])
        return RevenantSpelling(word, [lower substringToIndex:lower.length - 3]);
    if (lower.length > 3 && [lower hasSuffix:@"ies"])
        return RevenantSpelling(word, [[lower substringToIndex:lower.length - 3] stringByAppendingString:@"y"]);
    if (lower.length > 2 && [lower hasSuffix:@"es"])
        return RevenantSpelling(word, [lower substringToIndex:lower.length - 2]);
    if (lower.length > 1 && [lower hasSuffix:@"s"] && ![lower hasSuffix:@"ss"])
        return RevenantSpelling(word, [lower substringToIndex:lower.length - 1]);
    return word;
}

static NSString *RevenantLanguage(NSAttributedString *source, NSRange range)
{
    id tag = [source attribute:NSLanguageIdentifierAttributeName atIndex:range.location effectiveRange:NULL];
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    NSMutableString *subtag = [NSMutableString string];
    NSUInteger i;
    if (![tag isKindOfClass:[NSString class]])
        return nil;

    for (i = 0; i < [(NSString *)tag length]; i++) {
        unichar c = [(NSString *)tag characterAtIndex:i];
        if (![letters characterIsMember:c])
            break;
        [subtag appendFormat:@"%C", c];
    }
    return subtag.length ? subtag : nil;
}

static BOOL RevenantWordAt(NSAttributedString *source, NSRange range, NSRange *word, NSCharacterSet *letters)
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

static NSString *RevenantFollow(NSAttributedString *source, NSRange range, id rule, NSRange *whole)
{
    NSMorphology *morphology;
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    NSString *word;
    NSInteger partOfSpeech;
    if (![rule isKindOfClass:[NSInflectionRuleExplicit class]])
        return nil;
    morphology = [(NSInflectionRuleExplicit *)rule morphology];
    partOfSpeech = morphology.partOfSpeech;
    if (partOfSpeech == NSGrammaticalPartOfSpeechLetter || partOfSpeech == NSGrammaticalPartOfSpeechVerb ||
        partOfSpeech == NSGrammaticalPartOfSpeechNumeral || partOfSpeech == NSGrammaticalPartOfSpeechPreposition)
        return nil;
    {
        NSString *language = RevenantLanguage(source, range);
        if (language && [language caseInsensitiveCompare:@"en"] != NSOrderedSame)
            return nil;
        if (!RevenantWordAt(source, range, whole, letters))
            return nil;
    }
    if ([[source.string substringWithRange:range] rangeOfString:@"%"].location != NSNotFound)
        return nil;
    word = [source.string substringWithRange:*whole];
    if (word.length < 2)
        return nil;
    {
        NSUInteger i;
        for (i = 0; i < word.length; i++)
            if (![letters characterIsMember:[word characterAtIndex:i]])
                return nil;
    }
    if (morphology.number == NSGrammaticalNumberSingular)
        return RevenantSingular(word);
    if (morphology.number == NSGrammaticalNumberPlural || morphology.number == NSGrammaticalNumberPluralFew ||
        morphology.number == NSGrammaticalNumberPluralMany)
        return RevenantPlural(word);
    return nil;
}

@interface RevenantInflectedRun : NSObject
@property (nonatomic) NSRange range;
@property (nonatomic, copy) NSString *text;
@end

@implementation RevenantInflectedRun
@synthesize range = _range;
@synthesize text = _text;
@end

@implementation NSAttributedString (RevenantInflection15)

- (NSAttributedString *)attributedStringByInflectingString
{
    NSMutableAttributedString *result = [self mutableCopy];
    NSMutableArray<RevenantInflectedRun *> *answered = [NSMutableArray array];
    [self enumerateAttributesInRange:NSMakeRange(0, self.length) options:0
                          usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSAttributedString *alternative = attributes[NSInflectionAlternativeAttributeName];
        id rule = attributes[NSInflectionRuleAttributeName];
        NSRange tagged = range;
        if (rule)
            [self attribute:NSInflectionRuleAttributeName atIndex:range.location effectiveRange:&tagged];
        NSRange whole = tagged;
        NSString *answer;
        if ([alternative isKindOfClass:[NSAttributedString class]]) {
            answer = [alternative string];
        } else {
            answer = RevenantFollow(self, tagged, rule, &whole);
        }
        if (!answer)
            return;
        {
            RevenantInflectedRun *run = [[RevenantInflectedRun alloc] init];
            run.range = whole;
            run.text = answer;
            [answered addObject:run];
        }
    }];
    for (NSInteger i = (NSInteger)answered.count - 1; i >= 0; i--) {
        RevenantInflectedRun *run = answered[(NSUInteger)i];
        [result replaceCharactersInRange:run.range
                      withAttributedString:[[NSAttributedString alloc] initWithString:run.text
                                                                           attributes:[self attributesAtIndex:run.range.location
                                                                                                  effectiveRange:NULL]]];
    }
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
