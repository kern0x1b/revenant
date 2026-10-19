#import <NaturalLanguage/NaturalLanguage.h>
#import "naturallanguage-cases.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableString *out = [NSMutableString stringWithString:@"static const char *const naturallanguage_token_expectations[] = {\n"];
        for (NSString *text in naturallanguage_texts()) {
            for (NLTokenUnit unit = NLTokenUnitWord; unit <= NLTokenUnitDocument; unit++) {
                NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:unit];
                tokenizer.string = text;
                NSString *answer = naturallanguage_answer(tokenizer, text);
                answer = [answer stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
                [out appendFormat:@"    \"%@\",\n", answer];
            }
        }
        [out appendString:@"};\n\nstatic const char *const naturallanguage_language_expectations[] = {\n"];
        for (NSString *text in naturallanguage_languages())
            [out appendFormat:@"    \"%@\",\n", [NLLanguageRecognizer dominantLanguageForString:text] ?: @"nil"];
        [out appendString:@"};\n"];
        [out writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
