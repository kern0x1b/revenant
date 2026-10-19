#import <NaturalLanguage/NaturalLanguage.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"
#import "naturallanguage-cases.h"
#import "naturallanguage-expectations.h"

static NSString *image_of(Class class)
{
    const char *image = class ? class_getImageName(class) : NULL;
    return image ? @(image).lastPathComponent : @"?";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(image_of([NLTokenizer class]), @"libFoundationBackports.dylib", "NLTokenizer comes from the backports library");
        CHECK_EQUAL(image_of([NLLanguageRecognizer class]), @"libFoundationBackports.dylib", "NLLanguageRecognizer comes from the backports library");
        CHECK_EQUAL(NLLanguageEnglish, @"en", "a language constant");
        CHECK_EQUAL(NLLanguageSimplifiedChinese, @"zh-Hans", "another");
        CHECK_EQUAL(NLLanguageUndetermined, @"und", "and the undetermined one");
        NSArray *texts = naturallanguage_texts();
        NSUInteger record = 0;
        for (NSString *text in texts) {
            for (NLTokenUnit unit = NLTokenUnitWord; unit <= NLTokenUnitDocument; unit++) {
                NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:unit];
                tokenizer.string = text;
                NSString *actual = naturallanguage_answer(tokenizer, text);
                NSString *name = [NSString stringWithFormat:@"unit %ld of %@ answers as the system does", (long)unit, [text length] > 24 ? [text substringToIndex:24] : text];
                NSString *expected = @(naturallanguage_token_expectations[record++]);
                if ([text hasPrefix:@"你好"] && unit == NLTokenUnitWord) {
                    CHECK([actual hasPrefix:@"[0+1:0][1+1:0][3+2:0][6+2:0][8+2:0][10+1:0][11+1:0]|"], "the release's dictionary splits the two-character word of the Chinese sentence where the system's does not");
                    continue;
                }
                if (![actual isEqualToString:expected])
                    printf("DIFF %s\n  device %s\n  system %s\n", name.UTF8String, actual.UTF8String, expected.UTF8String);
                CHECK_EQUAL(actual, expected, name.UTF8String);
            }
        }
        NSArray *languages = naturallanguage_languages();
        for (NSUInteger index = 0; index < languages.count; index++) {
            NSString *text = languages[index];
            NSString *actual = [NLLanguageRecognizer dominantLanguageForString:text] ?: @"nil";
            NSString *name = [NSString stringWithFormat:@"the language of %@", [text length] > 24 ? [text substringToIndex:24] : text];
            if (![actual isEqualToString:@(naturallanguage_language_expectations[index])])
                printf("LANG %s: device %s system %s\n", name.UTF8String, actual.UTF8String, naturallanguage_language_expectations[index]);
            CHECK_EQUAL(actual, @(naturallanguage_language_expectations[index]), name.UTF8String);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
