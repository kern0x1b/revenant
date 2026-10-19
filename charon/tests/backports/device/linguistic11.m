#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "check.h"

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

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"ok";
}

static NSString *unit_enumeration(NSLinguisticTagger *tagger, NSRange range, NSLinguisticTaggerUnit unit, NSString *scheme, NSLinguisticTaggerOptions options)
{
    NSMutableString *out = [NSMutableString string];
    [tagger enumerateTagsInRange:range unit:unit scheme:scheme options:options usingBlock:^(NSLinguisticTag tag, NSRange tokenRange, BOOL *stop) {
        [out appendFormat:@"[%@ %lu+%lu]", tag ?: @"nil", (unsigned long)tokenRange.location, (unsigned long)tokenRange.length];
    }];
    return out;
}

static NSString *old_enumeration(NSLinguisticTagger *tagger, NSRange range, NSString *scheme, NSLinguisticTaggerOptions options)
{
    NSMutableString *out = [NSMutableString string];
    [tagger enumerateTagsInRange:range scheme:scheme options:options usingBlock:^(NSString *tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop) {
        [out appendFormat:@"[%@ %lu+%lu]", tag ?: @"nil", (unsigned long)tokenRange.location, (unsigned long)tokenRange.length];
    }];
    return out;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(image_of((void *)[NSLinguisticTagger instanceMethodForSelector:@selector(tokenRangeAtIndex:unit:)]), @"libFoundationBackports.dylib", "the unit methods come from the backports");
        NSString *english = @"Hello, world! It's 3 o'clock.\nSecond paragraph here. Tim Cook visited Paris.";
        NSArray *schemes = @[NSLinguisticTagSchemeTokenType, NSLinguisticTagSchemeLexicalClass, NSLinguisticTagSchemeLemma, NSLinguisticTagSchemeLanguage, NSLinguisticTagSchemeScript];
        NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:schemes options:0];
        tagger.string = english;
        for (NSString *scheme in schemes)
            CHECK_EQUAL(unit_enumeration(tagger, NSMakeRange(0, english.length), NSLinguisticTaggerUnitWord, scheme, 0), old_enumeration(tagger, NSMakeRange(0, english.length), scheme, 0), label(@"word unit %@ is the release's own word tagging", scheme));
        CHECK_EQUAL(unit_enumeration(tagger, NSMakeRange(0, english.length), NSLinguisticTaggerUnitWord, NSLinguisticTagSchemeTokenType, NSLinguisticTaggerOmitWhitespace | NSLinguisticTaggerOmitPunctuation),
                    old_enumeration(tagger, NSMakeRange(0, english.length), NSLinguisticTagSchemeTokenType, NSLinguisticTaggerOmitWhitespace | NSLinguisticTaggerOmitPunctuation), "and takes the options");
        NSRange token = NSMakeRange(0, 0), sentence = NSMakeRange(0, 0);
        NSString *tag = [tagger tagAtIndex:3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeLexicalClass tokenRange:&token];
        NSString *old = [tagger tagAtIndex:3 scheme:NSLinguisticTagSchemeLexicalClass tokenRange:&sentence sentenceRange:NULL];
        CHECK(((tag == old) || [tag isEqual:old]) && NSEqualRanges(token, sentence) && NSEqualRanges([tagger tokenRangeAtIndex:3 unit:NSLinguisticTaggerUnitWord], token), "a word tag and its token range");

        NSRange oldSentence = [tagger sentenceRangeForRange:NSMakeRange(20, 0)];
        CHECK(NSEqualRanges([tagger tokenRangeAtIndex:20 unit:NSLinguisticTaggerUnitSentence], oldSentence), "a sentence is what the release calls one");
        CHECK(NSEqualRanges([tagger tokenRangeAtIndex:20 unit:NSLinguisticTaggerUnitParagraph], [english paragraphRangeForRange:NSMakeRange(20, 0)]) && NSEqualRanges([tagger tokenRangeAtIndex:40 unit:NSLinguisticTaggerUnitParagraph], NSMakeRange(30, english.length - 30)), "a paragraph is a paragraph of the string");
        CHECK(NSEqualRanges([tagger tokenRangeAtIndex:40 unit:NSLinguisticTaggerUnitDocument], NSMakeRange(0, english.length)), "the document is the whole string");
        NSMutableArray *sentenceTokens = [NSMutableArray array];
        [tagger enumerateTagsInRange:NSMakeRange(0, english.length) unit:NSLinguisticTaggerUnitSentence scheme:NSLinguisticTagSchemeLanguage options:0 usingBlock:^(NSLinguisticTag t, NSRange r, BOOL *stop) { [sentenceTokens addObject:NSStringFromRange(r)]; }];
        NSUInteger covered = 0;
        for (NSString *r in sentenceTokens) {
            NSRange range = NSRangeFromString(r);
            CHECK(range.location == covered, label(@"the sentences follow each other at %lu", (unsigned long)covered));
            covered = NSMaxRange(range);
        }
        CHECK(covered == english.length && sentenceTokens.count >= 3, "and cover the string");
        CHECK([tagger tagAtIndex:9 unit:NSLinguisticTaggerUnitSentence scheme:NSLinguisticTagSchemeLexicalClass tokenRange:NULL] == nil, "no word scheme is answered above the word");
        CHECK_EQUAL([[NSLinguisticTagger availableTagSchemesForUnit:NSLinguisticTaggerUnitSentence language:@"en"] description], @"(\n    Language,\n    Script\n)", "the schemes above the word");
        CHECK_EQUAL([[NSLinguisticTagger availableTagSchemesForUnit:NSLinguisticTaggerUnitWord language:@"en"] description], [[NSLinguisticTagger availableTagSchemesForLanguage:@"en"] description], "and at the word");

        NSString *spanish = @"El rápido zorro marrón salta sobre el perro perezoso. Es un día muy bonito para pasear por el parque.";
        NSString *german = @"Der schnelle braune Fuchs springt über den faulen Hund. Das ist heute ein sehr schöner Tag zum Spazieren.";
        printf("languages: %s %s %s\n", [NSLinguisticTagger dominantLanguageForString:english].UTF8String ?: "nil", [NSLinguisticTagger dominantLanguageForString:spanish].UTF8String ?: "nil", [NSLinguisticTagger dominantLanguageForString:german].UTF8String ?: "nil");
        CHECK_EQUAL([NSLinguisticTagger dominantLanguageForString:english], @"en", "English is English");
        CHECK_EQUAL([NSLinguisticTagger dominantLanguageForString:spanish], @"es", "Spanish is Spanish");
        CHECK_EQUAL([NSLinguisticTagger dominantLanguageForString:german], @"de", "German is German");
        CHECK([NSLinguisticTagger dominantLanguageForString:@""] == nil, "nothing has no language");
        NSLinguisticTagger *spanishTagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeLanguage] options:0];
        spanishTagger.string = spanish;
        CHECK_EQUAL(spanishTagger.dominantLanguage, @"es", "a tagger's dominant language");
        CHECK([[[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeLanguage] options:0] dominantLanguage] == nil, "and none for no string");
        CHECK_EQUAL(unit_enumeration(spanishTagger, NSMakeRange(0, spanish.length), NSLinguisticTaggerUnitParagraph, NSLinguisticTagSchemeLanguage, 0), ([NSString stringWithFormat:@"[es 0+%lu]", (unsigned long)spanish.length]), "the language of a paragraph");
        CHECK_EQUAL(unit_enumeration(spanishTagger, NSMakeRange(0, spanish.length), NSLinguisticTaggerUnitDocument, NSLinguisticTagSchemeScript, 0), ([NSString stringWithFormat:@"[Latn 0+%lu]", (unsigned long)spanish.length]), "and the script of the document");

        NSRange range = NSMakeRange(0, 0);
        CHECK_EQUAL([NSLinguisticTagger tagForString:english atIndex:3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType orthography:nil tokenRange:&range], @"Word", "the class convenience");
        CHECK(NSEqualRanges(range, NSMakeRange(0, 5)), "with its token");
        NSArray *ranges = nil;
        NSArray *tags = [NSLinguisticTagger tagsForString:english range:NSMakeRange(0, 14) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType options:NSLinguisticTaggerOmitWhitespace orthography:nil tokenRanges:&ranges];
        CHECK_EQUAL([tags componentsJoinedByString:@","], @"Word,Punctuation,Word,Punctuation", "the class tags");
        CHECK(ranges.count == 4 && NSEqualRanges([ranges[0] rangeValue], NSMakeRange(0, 5)) && NSEqualRanges([ranges[3] rangeValue], NSMakeRange(12, 1)), "and their token ranges");
        __block int count = 0;
        [NSLinguisticTagger enumerateTagsForString:english range:NSMakeRange(0, english.length) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType options:0 orthography:nil usingBlock:^(NSLinguisticTag t, NSRange r, BOOL *stop) { if (++count == 3) *stop = YES; }];
        CHECK(count == 3, "the stop flag of the class enumeration");

        CHECK_EQUAL(raised(^{ [tagger tokenRangeAtIndex:english.length unit:NSLinguisticTaggerUnitWord]; }), @"NSRangeException: *** -[NSLinguisticTagger tokenRangeAtIndex:unit:]: Range or index out of bounds", "the end of the string is out of bounds");
        CHECK_EQUAL(raised(^{ [tagger enumerateTagsInRange:NSMakeRange(0, english.length + 5) unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType options:0 usingBlock:^(NSLinguisticTag t, NSRange r, BOOL *stop) {}]; }), @"NSRangeException: *** -[NSLinguisticTagger enumerateTagsInRange:unit:scheme:options:usingBlock:]: Range or index out of bounds", "and so is a range past it");
        CHECK_EQUAL(raised(^{ [tagger tagAtIndex:english.length + 3 unit:NSLinguisticTaggerUnitWord scheme:NSLinguisticTagSchemeTokenType tokenRange:NULL]; }), @"NSRangeException: *** -[NSLinguisticTagger tagAtIndex:unit:scheme:tokenRange:]: Range or index out of bounds", "and an index");
        NSLinguisticTagger *bare = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeTokenType] options:0];
        CHECK_EQUAL(raised(^{ [bare tokenRangeAtIndex:0 unit:NSLinguisticTaggerUnitWord]; }), @"NSRangeException: *** -[NSLinguisticTagger tokenRangeAtIndex:unit:]: Range or index out of bounds", "a tagger with no string has none of them");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
