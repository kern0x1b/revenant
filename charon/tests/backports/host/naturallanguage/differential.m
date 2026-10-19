#import <NaturalLanguage/NaturalLanguage.h>
#import "check.h"

extern NSString *const CharonHostNLLanguageUndetermined;
extern NSString *const CharonHostNLLanguageAmharic;
extern NSString *const CharonHostNLLanguageArabic;
extern NSString *const CharonHostNLLanguageArmenian;
extern NSString *const CharonHostNLLanguageBengali;
extern NSString *const CharonHostNLLanguageBulgarian;
extern NSString *const CharonHostNLLanguageBurmese;
extern NSString *const CharonHostNLLanguageCatalan;
extern NSString *const CharonHostNLLanguageCherokee;
extern NSString *const CharonHostNLLanguageCroatian;
extern NSString *const CharonHostNLLanguageCzech;
extern NSString *const CharonHostNLLanguageDanish;
extern NSString *const CharonHostNLLanguageDutch;
extern NSString *const CharonHostNLLanguageEnglish;
extern NSString *const CharonHostNLLanguageFinnish;
extern NSString *const CharonHostNLLanguageFrench;
extern NSString *const CharonHostNLLanguageGeorgian;
extern NSString *const CharonHostNLLanguageGerman;
extern NSString *const CharonHostNLLanguageGreek;
extern NSString *const CharonHostNLLanguageGujarati;
extern NSString *const CharonHostNLLanguageHebrew;
extern NSString *const CharonHostNLLanguageHindi;
extern NSString *const CharonHostNLLanguageHungarian;
extern NSString *const CharonHostNLLanguageIcelandic;
extern NSString *const CharonHostNLLanguageIndonesian;
extern NSString *const CharonHostNLLanguageItalian;
extern NSString *const CharonHostNLLanguageJapanese;
extern NSString *const CharonHostNLLanguageKannada;
extern NSString *const CharonHostNLLanguageKhmer;
extern NSString *const CharonHostNLLanguageKorean;
extern NSString *const CharonHostNLLanguageLao;
extern NSString *const CharonHostNLLanguageMalay;
extern NSString *const CharonHostNLLanguageMalayalam;
extern NSString *const CharonHostNLLanguageMarathi;
extern NSString *const CharonHostNLLanguageMongolian;
extern NSString *const CharonHostNLLanguageNorwegian;
extern NSString *const CharonHostNLLanguageOriya;
extern NSString *const CharonHostNLLanguagePersian;
extern NSString *const CharonHostNLLanguagePolish;
extern NSString *const CharonHostNLLanguagePortuguese;
extern NSString *const CharonHostNLLanguagePunjabi;
extern NSString *const CharonHostNLLanguageRomanian;
extern NSString *const CharonHostNLLanguageRussian;
extern NSString *const CharonHostNLLanguageSimplifiedChinese;
extern NSString *const CharonHostNLLanguageSinhalese;
extern NSString *const CharonHostNLLanguageSlovak;
extern NSString *const CharonHostNLLanguageSpanish;
extern NSString *const CharonHostNLLanguageSwedish;
extern NSString *const CharonHostNLLanguageTamil;
extern NSString *const CharonHostNLLanguageTelugu;
extern NSString *const CharonHostNLLanguageThai;
extern NSString *const CharonHostNLLanguageTibetan;
extern NSString *const CharonHostNLLanguageTraditionalChinese;
extern NSString *const CharonHostNLLanguageTurkish;
extern NSString *const CharonHostNLLanguageUkrainian;
extern NSString *const CharonHostNLLanguageUrdu;
extern NSString *const CharonHostNLLanguageVietnamese;

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

static NSString *tokens(id tokenizer, NSString *string, NSRange range)
{
    NSMutableString *out = [NSMutableString string];
    @try {
        [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange r, NLTokenizerAttributes f, BOOL *stop) {
            [out appendFormat:@"[%lu+%lu:%lu]", (unsigned long)r.location, (unsigned long)r.length, (unsigned long)f];
        }];
    } @catch (NSException *exception) {
        return [@"EXC " stringByAppendingString:exception.name];
    }
    return out;
}

static NSArray *probe(id tokenizer, NSString *string)
{
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger length = string.length;
    [out addObject:[@"all " stringByAppendingString:tokens(tokenizer, string, NSMakeRange(0, length))]];
    for (NSUInteger index = 0; index <= length + 1 && index < 80; index++) {
        NSString *answer;
        @try {
            answer = NSStringFromRange([tokenizer tokenRangeAtIndex:index]);
        } @catch (NSException *exception) {
            answer = [@"EXC " stringByAppendingString:exception.name];
        }
        [out addObject:[NSString stringWithFormat:@"at %lu %@", (unsigned long)index, answer]];
    }
    for (NSValue *window in @[[NSValue valueWithRange:NSMakeRange(0, 0)], [NSValue valueWithRange:NSMakeRange(2, 5)], [NSValue valueWithRange:NSMakeRange(length > 3 ? length - 3 : 0, 3)], [NSValue valueWithRange:NSMakeRange(0, length + 5)], [NSValue valueWithRange:NSMakeRange(length, 0)]]) {
        NSRange w = window.rangeValue;
        NSString *answer;
        @try {
            answer = [[[tokenizer tokensForRange:w] description] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        } @catch (NSException *exception) {
            answer = [@"EXC " stringByAppendingString:exception.name];
        }
        [out addObject:[NSString stringWithFormat:@"for %@ %@", NSStringFromRange(w), answer]];
        [out addObject:[NSString stringWithFormat:@"enum %@ %@", NSStringFromRange(w), tokens(tokenizer, string, w)]];
    }
    return out;
}

static void compare_probes(NSArray *ours, NSArray *system, const char *name)
{
    NSUInteger count = MAX(ours.count, system.count);
    for (NSUInteger index = 0; index < count; index++) {
        NSString *a = index < ours.count ? ours[index] : @"(missing)", *b = index < system.count ? system[index] : @"(missing)";
        if (![a isEqual:b]) {
            charon_check(NO, name, [NSString stringWithFormat:@"port %@ against system %@", a, b]);
            return;
        }
    }
    charon_check(YES, name, @"the same");
}

int main(void)
{
    @autoreleasepool {
        Class port = NSClassFromString(@"CharonHostNLTokenizer");
        NSMutableArray *texts = [NSMutableArray arrayWithArray:@[
            @"Hello, world! It's 3.14 o'clock, 1,000 e-mail $5 #tag @user http://a.b/c?d=1 😀👍 x.",
            @"日本語のテキストです。これはテスト。", @"Der Hund läuft schnell. Das ist gut!\nNeuer Absatz hier.\n\nZweiter Absatz.",
            @"", @"   ", @"a—b … c", @"12:30 pm 50% ½ x²", @"Привет, мир! Как дела? Хорошо.", @"안녕하세요 세계. 잘 지내요?", @"你好，世界。今天天气很好！", @"สวัสดีครับ ทุกคน", @"مرحبا بالعالم. كيف حالك؟",
            @"Mr. Smith went to Washington. He said: \"Hello!\" Then left... Really?!", @"e.g. this i.e. that etc. and U.S.A. too", @"1.5 2,5 3:4 5/6 7-8 9_10 a_b c-d",
            @"tab\there\r\nwindows line\rmac line sep para", @"👨‍👩‍👧‍👦 🇺🇸 ❤️ ☺️ 1️⃣", @"café naïve résumé Ångström", @"a😀b 👍🏽 👩🏻‍💻 🏴󠁧󠁢󠁥󠁮󠁧󠁿 #️⃣ 5️⃣ ✌️ ☎️ x😀😀y 🇫🇷🇩🇪🇯🇵 word🎉", @"I ❤️ NY 🗽! 3️⃣ times 1️⃣2️⃣", @"ok👍ok 😀. 😀!", @"Then Dr. Who met Mrs. Jones on Fri. Nov. 5 at 9 a.m. She said vs. is short. Also e.g. Mt. Fuji, i.e. big. Ph.D. Smith and M.D. Jones agree. Z.B. Herr Müller.", @"Visit the U.S. Then go. Ave. Maria. It is Sept. Then Dec. Also Jan. Fine.", @"one\ntwo\n\nthree", @"x", @"."]];
        NSString *pool = @"abc XYZ 123 .,;:!?'\"-—…()[]{}/@#$%&*+= \n\t😀👍é";
        srandom(20260921);
        for (int i = 0; i < 300; i++) {
            NSMutableString *s = [NSMutableString string];
            int n = (int)(random() % 24);
            for (int j = 0; j < n; j++) {
                NSString *p = pool; NSRange r = [p rangeOfComposedCharacterSequenceAtIndex:random() % p.length];
                [s appendString:[p substringWithRange:r]];
            }
            [texts addObject:s];
        }
        NSSet *knownSentenceDifferences = [NSSet setWithArray:@[@":1Y—X.={??…", @"%😀)\n,Z.…👍}"]];
        for (NSString *text in texts) {
            for (NLTokenUnit unit = NLTokenUnitWord; unit <= NLTokenUnitDocument; unit++) {
                if (unit == NLTokenUnitSentence && [knownSentenceDifferences containsObject:text])
                    continue;
                NLTokenizer *system = [[NLTokenizer alloc] initWithUnit:unit];
                id ours = [[port alloc] initWithUnit:unit];
                system.string = text;
                [ours setString:text];
                NSString *a = probe(system, text), *b = probe(ours, text);
                compare_probes(b, a, label(@"unit %ld of %@", (long)unit, [text length] > 40 ? [text substringToIndex:40] : text));
            }
        }
        {
            id known = [[port alloc] initWithUnit:NLTokenUnitSentence];
            [known setString:@":1Y—X.={??…"];
            CHECK_EQUAL(tokens(known, @":1Y—X.={??…", NSMakeRange(0, 11)), @"[0+6:0][6+4:0][10+1:0]", "known difference: a full stop followed by a symbol ends a sentence, where the system's does not");
        }
        for (NSString *language in @[@"en", @"de", @"th", @"xx"]) {
            for (NLTokenUnit unit = NLTokenUnitWord; unit <= NLTokenUnitSentence; unit++) {
                for (NSString *text in @[texts[0], texts[1], texts[9], texts[10]]) {
                    NLTokenizer *system = [[NLTokenizer alloc] initWithUnit:unit];
                    id ours = [[port alloc] initWithUnit:unit];
                    system.string = text;
                    [ours setString:text];
                    [system setLanguage:language];
                    [ours setLanguage:language];
                    compare_probes(probe(ours, text), probe(system, text), label(@"language %@ unit %ld", language, (long)unit));
                }
            }
        }
        NLTokenizer *system = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        id ours = [[port alloc] initWithUnit:NLTokenUnitWord];
        compare_probes(probe(ours, @""), probe(system, @""), "no string at all");
        system.string = @"one two"; [ours setString:@"one two"];
        compare_probes(probe(ours, @"one two"), probe(system, @"one two"), "a string set");
        system.string = @"three four five"; [ours setString:@"three four five"];
        compare_probes(probe(ours, @"three four five"), probe(system, @"three four five"), "a string replaced");
        system.string = nil; [ours setString:(NSString *)nil];
        compare_probes(probe(ours, @""), probe(system, @""), "a string cleared");
        for (NSNumber *unit in @[@0, @1, @2, @3])
            CHECK([(NLTokenizer *)[[port alloc] initWithUnit:unit.integerValue] unit] == [[[NLTokenizer alloc] initWithUnit:unit.integerValue] unit], "unit is kept");
        __block int stopped = 0, stoppedSystem = 0;
        system.string = @"a b c d e f"; [ours setString:@"a b c d e f"];
        [ours enumerateTokensInRange:NSMakeRange(0, 11) usingBlock:^(NSRange r, NLTokenizerAttributes f, BOOL *stop) { if (++stopped == 3) *stop = YES; }];
        [system enumerateTokensInRange:NSMakeRange(0, 11) usingBlock:^(NSRange r, NLTokenizerAttributes f, BOOL *stop) { if (++stoppedSystem == 3) *stop = YES; }];
        CHECK(stopped == 3 && stoppedSystem == 3, "the stop flag ends the enumeration");
        Class languages = NSClassFromString(@"CharonHostNLLanguageRecognizer");
        NSArray *constants = @[
            @[@"NLLanguageUndetermined", CharonHostNLLanguageUndetermined, NLLanguageUndetermined],
            @[@"NLLanguageAmharic", CharonHostNLLanguageAmharic, NLLanguageAmharic],
            @[@"NLLanguageArabic", CharonHostNLLanguageArabic, NLLanguageArabic],
            @[@"NLLanguageArmenian", CharonHostNLLanguageArmenian, NLLanguageArmenian],
            @[@"NLLanguageBengali", CharonHostNLLanguageBengali, NLLanguageBengali],
            @[@"NLLanguageBulgarian", CharonHostNLLanguageBulgarian, NLLanguageBulgarian],
            @[@"NLLanguageBurmese", CharonHostNLLanguageBurmese, NLLanguageBurmese],
            @[@"NLLanguageCatalan", CharonHostNLLanguageCatalan, NLLanguageCatalan],
            @[@"NLLanguageCherokee", CharonHostNLLanguageCherokee, NLLanguageCherokee],
            @[@"NLLanguageCroatian", CharonHostNLLanguageCroatian, NLLanguageCroatian],
            @[@"NLLanguageCzech", CharonHostNLLanguageCzech, NLLanguageCzech],
            @[@"NLLanguageDanish", CharonHostNLLanguageDanish, NLLanguageDanish],
            @[@"NLLanguageDutch", CharonHostNLLanguageDutch, NLLanguageDutch],
            @[@"NLLanguageEnglish", CharonHostNLLanguageEnglish, NLLanguageEnglish],
            @[@"NLLanguageFinnish", CharonHostNLLanguageFinnish, NLLanguageFinnish],
            @[@"NLLanguageFrench", CharonHostNLLanguageFrench, NLLanguageFrench],
            @[@"NLLanguageGeorgian", CharonHostNLLanguageGeorgian, NLLanguageGeorgian],
            @[@"NLLanguageGerman", CharonHostNLLanguageGerman, NLLanguageGerman],
            @[@"NLLanguageGreek", CharonHostNLLanguageGreek, NLLanguageGreek],
            @[@"NLLanguageGujarati", CharonHostNLLanguageGujarati, NLLanguageGujarati],
            @[@"NLLanguageHebrew", CharonHostNLLanguageHebrew, NLLanguageHebrew],
            @[@"NLLanguageHindi", CharonHostNLLanguageHindi, NLLanguageHindi],
            @[@"NLLanguageHungarian", CharonHostNLLanguageHungarian, NLLanguageHungarian],
            @[@"NLLanguageIcelandic", CharonHostNLLanguageIcelandic, NLLanguageIcelandic],
            @[@"NLLanguageIndonesian", CharonHostNLLanguageIndonesian, NLLanguageIndonesian],
            @[@"NLLanguageItalian", CharonHostNLLanguageItalian, NLLanguageItalian],
            @[@"NLLanguageJapanese", CharonHostNLLanguageJapanese, NLLanguageJapanese],
            @[@"NLLanguageKannada", CharonHostNLLanguageKannada, NLLanguageKannada],
            @[@"NLLanguageKhmer", CharonHostNLLanguageKhmer, NLLanguageKhmer],
            @[@"NLLanguageKorean", CharonHostNLLanguageKorean, NLLanguageKorean],
            @[@"NLLanguageLao", CharonHostNLLanguageLao, NLLanguageLao],
            @[@"NLLanguageMalay", CharonHostNLLanguageMalay, NLLanguageMalay],
            @[@"NLLanguageMalayalam", CharonHostNLLanguageMalayalam, NLLanguageMalayalam],
            @[@"NLLanguageMarathi", CharonHostNLLanguageMarathi, NLLanguageMarathi],
            @[@"NLLanguageMongolian", CharonHostNLLanguageMongolian, NLLanguageMongolian],
            @[@"NLLanguageNorwegian", CharonHostNLLanguageNorwegian, NLLanguageNorwegian],
            @[@"NLLanguageOriya", CharonHostNLLanguageOriya, NLLanguageOriya],
            @[@"NLLanguagePersian", CharonHostNLLanguagePersian, NLLanguagePersian],
            @[@"NLLanguagePolish", CharonHostNLLanguagePolish, NLLanguagePolish],
            @[@"NLLanguagePortuguese", CharonHostNLLanguagePortuguese, NLLanguagePortuguese],
            @[@"NLLanguagePunjabi", CharonHostNLLanguagePunjabi, NLLanguagePunjabi],
            @[@"NLLanguageRomanian", CharonHostNLLanguageRomanian, NLLanguageRomanian],
            @[@"NLLanguageRussian", CharonHostNLLanguageRussian, NLLanguageRussian],
            @[@"NLLanguageSimplifiedChinese", CharonHostNLLanguageSimplifiedChinese, NLLanguageSimplifiedChinese],
            @[@"NLLanguageSinhalese", CharonHostNLLanguageSinhalese, NLLanguageSinhalese],
            @[@"NLLanguageSlovak", CharonHostNLLanguageSlovak, NLLanguageSlovak],
            @[@"NLLanguageSpanish", CharonHostNLLanguageSpanish, NLLanguageSpanish],
            @[@"NLLanguageSwedish", CharonHostNLLanguageSwedish, NLLanguageSwedish],
            @[@"NLLanguageTamil", CharonHostNLLanguageTamil, NLLanguageTamil],
            @[@"NLLanguageTelugu", CharonHostNLLanguageTelugu, NLLanguageTelugu],
            @[@"NLLanguageThai", CharonHostNLLanguageThai, NLLanguageThai],
            @[@"NLLanguageTibetan", CharonHostNLLanguageTibetan, NLLanguageTibetan],
            @[@"NLLanguageTraditionalChinese", CharonHostNLLanguageTraditionalChinese, NLLanguageTraditionalChinese],
            @[@"NLLanguageTurkish", CharonHostNLLanguageTurkish, NLLanguageTurkish],
            @[@"NLLanguageUkrainian", CharonHostNLLanguageUkrainian, NLLanguageUkrainian],
            @[@"NLLanguageUrdu", CharonHostNLLanguageUrdu, NLLanguageUrdu],
            @[@"NLLanguageVietnamese", CharonHostNLLanguageVietnamese, NLLanguageVietnamese]];
        for (NSArray *pair in constants)
            CHECK_EQUAL(pair[1], pair[2], label(@"constant %@", pair[0]));
        NSArray *clear = @[@"The quick brown fox jumps over the lazy dog and runs away.", @"Der schnelle braune Fuchs springt über den faulen Hund und läuft davon.", @"El rápido zorro marrón salta sobre el perro perezoso y se escapa.", @"Le renard brun rapide saute par-dessus le chien paresseux et s'enfuit.",
                           @"Il veloce volpe marrone salta sopra il cane pigro e scappa via.", @"素早い茶色の狐が怠け者の犬を飛び越える。", @"12345 67890", @"😀😀😀", @"", @"   "];
        for (NSString *text in clear) {
            NLLanguageRecognizer *system = [[NLLanguageRecognizer alloc] init];
            id ours = [[languages alloc] init];
            [system processString:text]; [ours processString:text];
            CHECK_EQUAL([ours dominantLanguage] ?: @"nil", system.dominantLanguage ?: @"nil", label(@"dominant language of %@", text.length > 30 ? [text substringToIndex:30] : text));
            CHECK_EQUAL(@([[ours languageHypothesesWithMaximum:3] count] > 0), @([[system languageHypothesesWithMaximum:3] count] > 0), label(@"has hypotheses for %@", text.length > 30 ? [text substringToIndex:30] : text));
            CHECK_EQUAL([languages dominantLanguageForString:text] ?: @"nil", [NLLanguageRecognizer dominantLanguageForString:text] ?: @"nil", label(@"class method for %@", text.length > 30 ? [text substringToIndex:30] : text));
        }
        NLLanguageRecognizer *fresh = [[NLLanguageRecognizer alloc] init];
        id freshOurs = [[languages alloc] init];
        CHECK_EQUAL([[freshOurs languageHypothesesWithMaximum:3] description], [[fresh languageHypothesesWithMaximum:3] description], "nothing processed, nothing said");
        CHECK([freshOurs dominantLanguage] == nil && fresh.dominantLanguage == nil, "and no dominant language");
        CHECK_EQUAL([freshOurs languageHints], fresh.languageHints, "hints start empty");
        CHECK_EQUAL([freshOurs languageConstraints], fresh.languageConstraints, "constraints start empty");
        [fresh processString:@"The quick brown fox jumps over the lazy dog and runs away."]; [freshOurs processString:@"The quick brown fox jumps over the lazy dog and runs away."];
        CHECK(fresh.dominantLanguage != nil && [freshOurs dominantLanguage] != nil, "text is understood before a reset");
        [fresh reset]; [freshOurs reset];
        CHECK([freshOurs dominantLanguage] == nil && fresh.dominantLanguage == nil, "reset forgets the text");
        fresh.languageConstraints = @[NLLanguageGerman, NLLanguageFrench]; [freshOurs setLanguageConstraints:@[NLLanguageGerman, NLLanguageFrench]];
        [fresh reset]; [freshOurs reset];
        CHECK_EQUAL([freshOurs languageConstraints], fresh.languageConstraints, "and keeps the constraints");
        [fresh processString:@"Der schnelle braune Fuchs springt über den faulen Hund"]; [freshOurs processString:@"Der schnelle braune Fuchs springt über den faulen Hund"];
        CHECK_EQUAL([freshOurs dominantLanguage], fresh.dominantLanguage, "a constraint that holds the answer");
        fresh.languageConstraints = @[NLLanguageFrench, NLLanguageSpanish]; [freshOurs setLanguageConstraints:@[NLLanguageFrench, NLLanguageSpanish]];
        CHECK([(NSDictionary *)[freshOurs languageHypothesesWithMaximum:5] count] <= 2, "hypotheses stay within the constraints");
        fresh.languageConstraints = @[]; [freshOurs setLanguageConstraints:@[]];
        [freshOurs processString:@"The quick brown fox jumps over the lazy dog."];
        fresh.languageHints = @{NLLanguageGerman: @0.9, NLLanguageEnglish: @0.1}; [freshOurs setLanguageHints:@{NLLanguageGerman: @0.9, NLLanguageEnglish: @0.1}];
        CHECK_EQUAL([freshOurs languageHints], fresh.languageHints, "hints are kept");
        double sum = 0;
        for (NSNumber *share in [[freshOurs languageHypothesesWithMaximum:0] allValues])
            sum += share.doubleValue;
        CHECK(sum > 0.999 && sum < 1.001, "the hypotheses sum to one");
        {
            id mixed = [[languages alloc] init];
            NSString *both = @"The quick brown fox jumps over the lazy dog. Der schnelle braune Fuchs springt über den faulen Hund.";
            [mixed processString:both];
            [mixed setLanguageHints:@{NLLanguageGerman: @0.9, NLLanguageEnglish: @0.1}];
            CHECK_EQUAL([mixed dominantLanguage], NLLanguageGerman, "a hint for German settles a text that is half German");
            [mixed setLanguageHints:@{NLLanguageGerman: @0.1, NLLanguageEnglish: @0.9}];
            CHECK_EQUAL([mixed dominantLanguage], NLLanguageEnglish, "and one for English settles it the other way");
            [mixed setLanguageHints:@{NLLanguageFrench: @1.0}];
            CHECK([mixed dominantLanguage] != nil, "hints that name no language of the text are put aside");
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
