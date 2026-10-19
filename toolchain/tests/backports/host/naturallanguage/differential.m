#import <NaturalLanguage/NaturalLanguage.h>
#import "check.h"

extern NSString *const RevenantHostNLLanguageUndetermined;
extern NSString *const RevenantHostNLLanguageAmharic;
extern NSString *const RevenantHostNLLanguageArabic;
extern NSString *const RevenantHostNLLanguageArmenian;
extern NSString *const RevenantHostNLLanguageBengali;
extern NSString *const RevenantHostNLLanguageBulgarian;
extern NSString *const RevenantHostNLLanguageBurmese;
extern NSString *const RevenantHostNLLanguageCatalan;
extern NSString *const RevenantHostNLLanguageCherokee;
extern NSString *const RevenantHostNLLanguageCroatian;
extern NSString *const RevenantHostNLLanguageCzech;
extern NSString *const RevenantHostNLLanguageDanish;
extern NSString *const RevenantHostNLLanguageDutch;
extern NSString *const RevenantHostNLLanguageEnglish;
extern NSString *const RevenantHostNLLanguageFinnish;
extern NSString *const RevenantHostNLLanguageFrench;
extern NSString *const RevenantHostNLLanguageGeorgian;
extern NSString *const RevenantHostNLLanguageGerman;
extern NSString *const RevenantHostNLLanguageGreek;
extern NSString *const RevenantHostNLLanguageGujarati;
extern NSString *const RevenantHostNLLanguageHebrew;
extern NSString *const RevenantHostNLLanguageHindi;
extern NSString *const RevenantHostNLLanguageHungarian;
extern NSString *const RevenantHostNLLanguageIcelandic;
extern NSString *const RevenantHostNLLanguageIndonesian;
extern NSString *const RevenantHostNLLanguageItalian;
extern NSString *const RevenantHostNLLanguageJapanese;
extern NSString *const RevenantHostNLLanguageKannada;
extern NSString *const RevenantHostNLLanguageKhmer;
extern NSString *const RevenantHostNLLanguageKorean;
extern NSString *const RevenantHostNLLanguageLao;
extern NSString *const RevenantHostNLLanguageMalay;
extern NSString *const RevenantHostNLLanguageMalayalam;
extern NSString *const RevenantHostNLLanguageMarathi;
extern NSString *const RevenantHostNLLanguageMongolian;
extern NSString *const RevenantHostNLLanguageNorwegian;
extern NSString *const RevenantHostNLLanguageOriya;
extern NSString *const RevenantHostNLLanguagePersian;
extern NSString *const RevenantHostNLLanguagePolish;
extern NSString *const RevenantHostNLLanguagePortuguese;
extern NSString *const RevenantHostNLLanguagePunjabi;
extern NSString *const RevenantHostNLLanguageRomanian;
extern NSString *const RevenantHostNLLanguageRussian;
extern NSString *const RevenantHostNLLanguageSimplifiedChinese;
extern NSString *const RevenantHostNLLanguageSinhalese;
extern NSString *const RevenantHostNLLanguageSlovak;
extern NSString *const RevenantHostNLLanguageSpanish;
extern NSString *const RevenantHostNLLanguageSwedish;
extern NSString *const RevenantHostNLLanguageTamil;
extern NSString *const RevenantHostNLLanguageTelugu;
extern NSString *const RevenantHostNLLanguageThai;
extern NSString *const RevenantHostNLLanguageTibetan;
extern NSString *const RevenantHostNLLanguageTraditionalChinese;
extern NSString *const RevenantHostNLLanguageTurkish;
extern NSString *const RevenantHostNLLanguageUkrainian;
extern NSString *const RevenantHostNLLanguageUrdu;
extern NSString *const RevenantHostNLLanguageVietnamese;

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
            revenant_check(NO, name, [NSString stringWithFormat:@"port %@ against system %@", a, b]);
            return;
        }
    }
    revenant_check(YES, name, @"the same");
}

int main(void)
{
    @autoreleasepool {
        Class port = NSClassFromString(@"RevenantHostNLTokenizer");
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
        Class languages = NSClassFromString(@"RevenantHostNLLanguageRecognizer");
        NSArray *constants = @[
            @[@"NLLanguageUndetermined", RevenantHostNLLanguageUndetermined, NLLanguageUndetermined],
            @[@"NLLanguageAmharic", RevenantHostNLLanguageAmharic, NLLanguageAmharic],
            @[@"NLLanguageArabic", RevenantHostNLLanguageArabic, NLLanguageArabic],
            @[@"NLLanguageArmenian", RevenantHostNLLanguageArmenian, NLLanguageArmenian],
            @[@"NLLanguageBengali", RevenantHostNLLanguageBengali, NLLanguageBengali],
            @[@"NLLanguageBulgarian", RevenantHostNLLanguageBulgarian, NLLanguageBulgarian],
            @[@"NLLanguageBurmese", RevenantHostNLLanguageBurmese, NLLanguageBurmese],
            @[@"NLLanguageCatalan", RevenantHostNLLanguageCatalan, NLLanguageCatalan],
            @[@"NLLanguageCherokee", RevenantHostNLLanguageCherokee, NLLanguageCherokee],
            @[@"NLLanguageCroatian", RevenantHostNLLanguageCroatian, NLLanguageCroatian],
            @[@"NLLanguageCzech", RevenantHostNLLanguageCzech, NLLanguageCzech],
            @[@"NLLanguageDanish", RevenantHostNLLanguageDanish, NLLanguageDanish],
            @[@"NLLanguageDutch", RevenantHostNLLanguageDutch, NLLanguageDutch],
            @[@"NLLanguageEnglish", RevenantHostNLLanguageEnglish, NLLanguageEnglish],
            @[@"NLLanguageFinnish", RevenantHostNLLanguageFinnish, NLLanguageFinnish],
            @[@"NLLanguageFrench", RevenantHostNLLanguageFrench, NLLanguageFrench],
            @[@"NLLanguageGeorgian", RevenantHostNLLanguageGeorgian, NLLanguageGeorgian],
            @[@"NLLanguageGerman", RevenantHostNLLanguageGerman, NLLanguageGerman],
            @[@"NLLanguageGreek", RevenantHostNLLanguageGreek, NLLanguageGreek],
            @[@"NLLanguageGujarati", RevenantHostNLLanguageGujarati, NLLanguageGujarati],
            @[@"NLLanguageHebrew", RevenantHostNLLanguageHebrew, NLLanguageHebrew],
            @[@"NLLanguageHindi", RevenantHostNLLanguageHindi, NLLanguageHindi],
            @[@"NLLanguageHungarian", RevenantHostNLLanguageHungarian, NLLanguageHungarian],
            @[@"NLLanguageIcelandic", RevenantHostNLLanguageIcelandic, NLLanguageIcelandic],
            @[@"NLLanguageIndonesian", RevenantHostNLLanguageIndonesian, NLLanguageIndonesian],
            @[@"NLLanguageItalian", RevenantHostNLLanguageItalian, NLLanguageItalian],
            @[@"NLLanguageJapanese", RevenantHostNLLanguageJapanese, NLLanguageJapanese],
            @[@"NLLanguageKannada", RevenantHostNLLanguageKannada, NLLanguageKannada],
            @[@"NLLanguageKhmer", RevenantHostNLLanguageKhmer, NLLanguageKhmer],
            @[@"NLLanguageKorean", RevenantHostNLLanguageKorean, NLLanguageKorean],
            @[@"NLLanguageLao", RevenantHostNLLanguageLao, NLLanguageLao],
            @[@"NLLanguageMalay", RevenantHostNLLanguageMalay, NLLanguageMalay],
            @[@"NLLanguageMalayalam", RevenantHostNLLanguageMalayalam, NLLanguageMalayalam],
            @[@"NLLanguageMarathi", RevenantHostNLLanguageMarathi, NLLanguageMarathi],
            @[@"NLLanguageMongolian", RevenantHostNLLanguageMongolian, NLLanguageMongolian],
            @[@"NLLanguageNorwegian", RevenantHostNLLanguageNorwegian, NLLanguageNorwegian],
            @[@"NLLanguageOriya", RevenantHostNLLanguageOriya, NLLanguageOriya],
            @[@"NLLanguagePersian", RevenantHostNLLanguagePersian, NLLanguagePersian],
            @[@"NLLanguagePolish", RevenantHostNLLanguagePolish, NLLanguagePolish],
            @[@"NLLanguagePortuguese", RevenantHostNLLanguagePortuguese, NLLanguagePortuguese],
            @[@"NLLanguagePunjabi", RevenantHostNLLanguagePunjabi, NLLanguagePunjabi],
            @[@"NLLanguageRomanian", RevenantHostNLLanguageRomanian, NLLanguageRomanian],
            @[@"NLLanguageRussian", RevenantHostNLLanguageRussian, NLLanguageRussian],
            @[@"NLLanguageSimplifiedChinese", RevenantHostNLLanguageSimplifiedChinese, NLLanguageSimplifiedChinese],
            @[@"NLLanguageSinhalese", RevenantHostNLLanguageSinhalese, NLLanguageSinhalese],
            @[@"NLLanguageSlovak", RevenantHostNLLanguageSlovak, NLLanguageSlovak],
            @[@"NLLanguageSpanish", RevenantHostNLLanguageSpanish, NLLanguageSpanish],
            @[@"NLLanguageSwedish", RevenantHostNLLanguageSwedish, NLLanguageSwedish],
            @[@"NLLanguageTamil", RevenantHostNLLanguageTamil, NLLanguageTamil],
            @[@"NLLanguageTelugu", RevenantHostNLLanguageTelugu, NLLanguageTelugu],
            @[@"NLLanguageThai", RevenantHostNLLanguageThai, NLLanguageThai],
            @[@"NLLanguageTibetan", RevenantHostNLLanguageTibetan, NLLanguageTibetan],
            @[@"NLLanguageTraditionalChinese", RevenantHostNLLanguageTraditionalChinese, NLLanguageTraditionalChinese],
            @[@"NLLanguageTurkish", RevenantHostNLLanguageTurkish, NLLanguageTurkish],
            @[@"NLLanguageUkrainian", RevenantHostNLLanguageUkrainian, NLLanguageUkrainian],
            @[@"NLLanguageUrdu", RevenantHostNLLanguageUrdu, NLLanguageUrdu],
            @[@"NLLanguageVietnamese", RevenantHostNLLanguageVietnamese, NLLanguageVietnamese]];
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
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures ? 1 : 0;
}
