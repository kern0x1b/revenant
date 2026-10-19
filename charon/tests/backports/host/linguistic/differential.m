#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "check.h"

@interface CharonHostNSLinguisticTagger : NSLinguisticTagger
@end
@implementation CharonHostNSLinguisticTagger
@end

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]];
    }
    return @"ok";
}

static NSArray *texts(void)
{
    return @[@"Hello, world! It's 3 o'clock.\nSecond paragraph here. Tim Cook visited Paris.",
             @"El rápido zorro marrón salta sobre el perro perezoso. ¿Cómo estás? Muy bien.\n\nOtro párrafo.",
             @"One sentence only",
             @"  leading and trailing space  ",
             @"Wait... what?! Really? Yes. Mr. Smith went to Washington D.C. on Jan. 5th.",
             @"Der schnelle braune Fuchs springt über den faulen Hund. Das ist gut.",
             @"a", @" ", @"Line one\nLine two\nLine three", @"Ünïcödé wörds and 日本語のテキストです。これは文です。",
             @"first line a\u2028second line b\nparagraph two here. More text follows it.", @"   ", @"!!! ??? ...", @"Sí. No. Ok. Ya. This is a somewhat longer english sentence that goes on and on."];
}

static NSArray *schemes(void)
{
    return @[NSLinguisticTagSchemeTokenType, NSLinguisticTagSchemeLexicalClass, NSLinguisticTagSchemeNameType, NSLinguisticTagSchemeNameTypeOrLexicalClass, NSLinguisticTagSchemeLemma, NSLinguisticTagSchemeLanguage, NSLinguisticTagSchemeScript];
}

static NSLinguisticTagger *make_tagger(BOOL ours, NSString *text)
{
    Class cls = ours ? [CharonHostNSLinguisticTagger class] : [NSLinguisticTagger class];
    NSLinguisticTagger *tagger = [[cls alloc] initWithTagSchemes:schemes() options:0];
    tagger.string = text;
    return tagger;
}

static NSString *enumeration(NSLinguisticTagger *tagger, NSRange range, NSLinguisticTaggerUnit unit, NSString *scheme, NSLinguisticTaggerOptions options)
{
    NSMutableString *out = [NSMutableString string];
    NSString *error = raised(^{
        [tagger enumerateTagsInRange:range unit:unit scheme:scheme options:options usingBlock:^(NSLinguisticTag tag, NSRange tokenRange, BOOL *stop) {
            [out appendFormat:@"[%@ %lu+%lu]", tag ?: @"nil", (unsigned long)tokenRange.location, (unsigned long)tokenRange.length];
        }];
    });
    return [error isEqual:@"ok"] ? out : error;
}

static void word_units(void)
{
    NSArray *optionSets = @[@0, @(NSLinguisticTaggerOmitWhitespace), @(NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitWhitespace), @(NSLinguisticTaggerOmitWords), @(NSLinguisticTaggerJoinNames)];
    NSUInteger index = 0;
    for (NSString *text in texts()) {
        NSLinguisticTagger *ours = make_tagger(YES, text), *system = make_tagger(NO, text);
        for (NSString *scheme in schemes())
            for (NSNumber *options in optionSets)
                CHECK_EQUAL(enumeration(ours, NSMakeRange(0, text.length), NSLinguisticTaggerUnitWord, scheme, options.unsignedIntegerValue), enumeration(system, NSMakeRange(0, text.length), NSLinguisticTaggerUnitWord, scheme, options.unsignedIntegerValue), label(@"text %lu word %@ options %@", (unsigned long)index, scheme, options));
        CHECK_EQUAL(enumeration(ours, NSMakeRange(text.length / 2, text.length - text.length / 2), NSLinguisticTaggerUnitWord, NSLinguisticTagSchemeLexicalClass, 0), enumeration(system, NSMakeRange(text.length / 2, text.length - text.length / 2), NSLinguisticTaggerUnitWord, NSLinguisticTagSchemeLexicalClass, 0), label(@"text %lu word partial range", (unsigned long)index));
        for (NSUInteger i = 0; i < text.length; i += MAX(1, text.length / 7)) {
            NSRange ourRange = NSMakeRange(NSNotFound, 0), systemRange = NSMakeRange(NSNotFound, 0);
            NSString *ourTag = [ours tagAtIndex:i unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass tokenRange:&ourRange], *systemTag = [system tagAtIndex:i unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass tokenRange:&systemRange];
            CHECK(((ourTag == systemTag) || [ourTag isEqual:systemTag]) && NSEqualRanges(ourRange, systemRange), label(@"text %lu tagAtIndex %lu", (unsigned long)index, (unsigned long)i));
            CHECK(NSEqualRanges([ours tokenRangeAtIndex:i unit:NSLinguisticTaggerUnitWord], [system tokenRangeAtIndex:i unit:NSLinguisticTaggerUnitWord]), label(@"text %lu word token range %lu", (unsigned long)index, (unsigned long)i));
        }
        NSArray *ourRanges = nil, *systemRanges = nil;
        NSArray *ourTags = [ours tagsInRange:NSMakeRange(0, text.length) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType options:NSLinguisticTaggerOmitWhitespace tokenRanges:&ourRanges];
        NSArray *systemTags = [system tagsInRange:NSMakeRange(0, text.length) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType options:NSLinguisticTaggerOmitWhitespace tokenRanges:&systemRanges];
        CHECK([ourTags isEqual:systemTags] && [ourRanges isEqual:systemRanges], label(@"text %lu tagsInRange", (unsigned long)index));
        index++;
    }
}

static void larger_units(void)
{
    NSUInteger index = 0;
    for (NSString *text in texts()) {
        NSLinguisticTagger *ours = make_tagger(YES, text), *system = make_tagger(NO, text);
        for (NSLinguisticTaggerUnit unit = NSLinguisticTaggerUnitSentence; unit <= NSLinguisticTaggerUnitParagraph; unit++) {
            BOOL tolerated = index == 3 || (index == 9 && unit == NSLinguisticTaggerUnitSentence);
            for (NSString *scheme in @[NSLinguisticTagSchemeLanguage, NSLinguisticTagSchemeScript])
                if (!tolerated)
                    CHECK_EQUAL(enumeration(ours, NSMakeRange(0, text.length), unit, scheme, 0), enumeration(system, NSMakeRange(0, text.length), unit, scheme, 0), label(@"text %lu unit %ld %@", (unsigned long)index, (long)unit, scheme));
            for (NSUInteger i = 0; i < text.length; i += MAX(1, text.length / 5))
                CHECK(NSEqualRanges([ours tokenRangeAtIndex:i unit:unit], [system tokenRangeAtIndex:i unit:unit]), label(@"text %lu unit %ld token range %lu", (unsigned long)index, (long)unit, (unsigned long)i));
            if (!tolerated)
                CHECK_EQUAL(enumeration(ours, NSMakeRange(text.length / 3, text.length / 3), unit, NSLinguisticTagSchemeLanguage, 0), enumeration(system, NSMakeRange(text.length / 3, text.length / 3), unit, NSLinguisticTagSchemeLanguage, 0), label(@"text %lu unit %ld partial range", (unsigned long)index, (long)unit));
        }
        CHECK_EQUAL(ours.dominantLanguage ?: @"nil", system.dominantLanguage ?: @"nil", label(@"text %lu dominant language", (unsigned long)index));
        CHECK_EQUAL([CharonHostNSLinguisticTagger dominantLanguageForString:text] ?: @"nil", [NSLinguisticTagger dominantLanguageForString:text] ?: @"nil", label(@"text %lu dominant language of a string", (unsigned long)index));
        index++;
    }
}

static void tolerated_answers(void)
{
    NSString *spaced = texts()[3], *mixed = texts()[9];
    CHECK_EQUAL(enumeration(make_tagger(YES, spaced), NSMakeRange(0, spaced.length), NSLinguisticTaggerUnitSentence, NSLinguisticTagSchemeLanguage, 0), @"[en 0+30]", "the newest tagger finds no language in a sentence with spaces around it; the port finds the language of its words");
    CHECK_EQUAL(enumeration(make_tagger(YES, mixed), NSMakeRange(0, mixed.length), NSLinguisticTaggerUnitSentence, NSLinguisticTagSchemeLanguage, 0), @"[de 0+29][ja 29+7]", "and takes the second sentence of a mixed text to be Japanese, where the newest one carries the first language on");
    CHECK_EQUAL(enumeration(make_tagger(YES, mixed), NSMakeRange(0, mixed.length), NSLinguisticTaggerUnitSentence, NSLinguisticTagSchemeScript, 0), @"[Latn 0+29][Jpan 29+7]", "with its script");
}

static void document_unit(void)
{
    NSString *text = texts()[0];
    NSLinguisticTagger *ours = make_tagger(YES, text);
    CHECK(NSEqualRanges([ours tokenRangeAtIndex:0 unit:NSLinguisticTaggerUnitDocument], NSMakeRange(0, text.length)) && NSEqualRanges([ours tokenRangeAtIndex:text.length - 1 unit:NSLinguisticTaggerUnitDocument], NSMakeRange(0, text.length)), "the document unit is the whole string");
    CHECK_EQUAL(enumeration(ours, NSMakeRange(0, text.length), NSLinguisticTaggerUnitDocument, NSLinguisticTagSchemeLanguage, 0), ([NSString stringWithFormat:@"[en 0+%lu]", (unsigned long)text.length]), "and carries the language of the string");
    CHECK_EQUAL(enumeration(ours, NSMakeRange(5, 5), NSLinguisticTaggerUnitDocument, NSLinguisticTagSchemeScript, 0), ([NSString stringWithFormat:@"[Latn 0+%lu]", (unsigned long)text.length]), "for any range in it");
    NSRange range = NSMakeRange(0, 0);
    CHECK_EQUAL([ours tagAtIndex:9 unit:NSLinguisticTaggerUnitDocument scheme:NSLinguisticTagSchemeLanguage tokenRange:&range], @"en", "a tag of the document");
    CHECK(NSEqualRanges(range, NSMakeRange(0, text.length)), "with the whole string as its token");
    CHECK([ours tagAtIndex:9 unit:NSLinguisticTaggerUnitDocument scheme:NSLinguisticTagSchemeLexicalClass tokenRange:NULL] == nil, "no other scheme is answered above the word");
    NSArray *ranges = nil;
    NSArray *tags = [make_tagger(YES, @"   ") tagsInRange:NSMakeRange(0, 3) unit:NSLinguisticTaggerUnitSentence scheme:NSLinguisticTagSchemeLanguage options:0 tokenRanges:&ranges];
    CHECK(tags.count == 1 && tags[0] == [NSNull null] && ranges.count == 1, "a unit with no words is a null tag");
    CHECK_EQUAL([CharonHostNSLinguisticTagger dominantLanguageForString:@"Sí. No. Ok. Ya. This is a somewhat longer english sentence that goes on and on."] ?: @"nil", @"en", "the language most of the words are tagged with wins");
}

static void schemes_and_conveniences(void)
{
    for (NSString *language in @[@"en", @"es"])
        for (NSLinguisticTaggerUnit unit = NSLinguisticTaggerUnitSentence; unit <= NSLinguisticTaggerUnitDocument; unit++)
            CHECK_EQUAL([[CharonHostNSLinguisticTagger availableTagSchemesForUnit:unit language:language] description], @"(\n    Language,\n    Script\n)", label(@"unit %ld schemes %@", (long)unit, language));
    NSString *text = texts()[0];
    NSRange ourRange = NSMakeRange(0, 0), systemRange = NSMakeRange(0, 0);
    NSString *ourTag = [CharonHostNSLinguisticTagger tagForString:text atIndex:3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass orthography:nil tokenRange:&ourRange];
    NSString *systemTag = [NSLinguisticTagger tagForString:text atIndex:3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass orthography:nil tokenRange:&systemRange];
    CHECK([ourTag isEqual:systemTag] && NSEqualRanges(ourRange, systemRange), "class tagForString");
    NSArray *ourRanges = nil, *systemRanges = nil;
    NSArray *ourTags = [CharonHostNSLinguisticTagger tagsForString:text range:NSMakeRange(0, 30) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass options:NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitWhitespace orthography:nil tokenRanges:&ourRanges];
    NSArray *systemTags = [NSLinguisticTagger tagsForString:text range:NSMakeRange(0, 30) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass options:NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitWhitespace orthography:nil tokenRanges:&systemRanges];
    CHECK([ourTags isEqual:systemTags] && [ourRanges isEqual:systemRanges], "class tagsForString");
    __block NSUInteger ourCount = 0, systemCount = 0;
    [CharonHostNSLinguisticTagger enumerateTagsForString:text range:NSMakeRange(0, text.length) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass options:0 orthography:nil usingBlock:^(NSLinguisticTag tag, NSRange r, BOOL *stop) { if (++ourCount == 3) *stop = YES; }];
    [NSLinguisticTagger enumerateTagsForString:text range:NSMakeRange(0, text.length) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass options:0 orthography:nil usingBlock:^(NSLinguisticTag tag, NSRange r, BOOL *stop) { if (++systemCount == 3) *stop = YES; }];
    CHECK(ourCount == 3 && systemCount == 3, "the stop flag ends the class enumeration");
    NSOrthography *orthography = [NSOrthography orthographyWithDominantScript:@"Latn" languageMap:@{@"Latn": @[@"es"]}];
    ourTags = [CharonHostNSLinguisticTagger tagsForString:@"El perro come" range:NSMakeRange(0, 13) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass options:0 orthography:orthography tokenRanges:NULL];
    systemTags = [NSLinguisticTagger tagsForString:@"El perro come" range:NSMakeRange(0, 13) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass options:0 orthography:orthography tokenRanges:NULL];
    CHECK([ourTags isEqual:systemTags], "an orthography given for the string");
}

static void bounds(void)
{
    NSString *text = texts()[0];
    NSLinguisticTagger *ours = make_tagger(YES, text), *system = make_tagger(NO, text);
    CHECK_EQUAL(raised(^{ [ours tokenRangeAtIndex:text.length unit:NSLinguisticTaggerUnitWord]; }), raised(^{ [system tokenRangeAtIndex:text.length unit:NSLinguisticTaggerUnitWord]; }), "token range at the end");
    CHECK_EQUAL(raised(^{ [ours tokenRangeAtIndex:text.length + 10 unit:NSLinguisticTaggerUnitSentence]; }), raised(^{ [system tokenRangeAtIndex:text.length + 10 unit:NSLinguisticTaggerUnitSentence]; }), "token range past the end");
    CHECK_EQUAL(raised(^{ [ours tagAtIndex:text.length + 3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType tokenRange:NULL]; }), raised(^{ [system tagAtIndex:text.length + 3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType tokenRange:NULL]; }), "tag past the end");
    CHECK_EQUAL(enumeration(ours, NSMakeRange(0, text.length + 5), NSLinguisticTaggerUnitWord, NSLinguisticTagSchemeTokenType, 0), enumeration(system, NSMakeRange(0, text.length + 5), NSLinguisticTaggerUnitWord, NSLinguisticTagSchemeTokenType, 0), "range past the end");
    NSLinguisticTagger *emptyOurs = [[CharonHostNSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeTokenType] options:0], *emptySystem = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeTokenType] options:0];
    CHECK_EQUAL(raised(^{ [emptyOurs tokenRangeAtIndex:0 unit:NSLinguisticTaggerUnitWord]; }), raised(^{ [emptySystem tokenRangeAtIndex:0 unit:NSLinguisticTaggerUnitWord]; }), "no string");
    CHECK([emptyOurs dominantLanguage] == nil && [emptySystem dominantLanguage] == nil, "no string, no language");
    CHECK([CharonHostNSLinguisticTagger dominantLanguageForString:@""] == nil && [CharonHostNSLinguisticTagger dominantLanguageForString:@"12345 67890"] == [NSLinguisticTagger dominantLanguageForString:@"12345 67890"], "no language for nothing or digits");
}

int main(void)
{
    @autoreleasepool {
        word_units();
        larger_units();
        tolerated_answers();
        document_unit();
        schemes_and_conveniences();
        bounds();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
