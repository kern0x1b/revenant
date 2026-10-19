#import <Foundation/Foundation.h>
#ifndef CHARON_HALF_PORT
#import <Accessibility/Accessibility.h>
#endif

#ifdef CHARON_HALF_PORT
#import "CharonBraille.h"
#endif

static NSArray *charon_corpus(void)
{
    return @[ @"abcxyz", @"ABC", @"AbC dEf", @"The Quick Brown Fox",
               @"123", @"1a2b", @"0123456789", @",;:.-!?", @"don't", @"(a)*b/c",
               @"a b\tc", @"Hello, World! 42.", @"", @"xyz" ];
}

#ifdef CHARON_HALF_PORT
#define charon_unmapped_count(result) [(result) charon_unmappedCount]
#else
#define charon_unmapped_count(result) (NSUInteger)0
#endif

int main(void)
{
    @autoreleasepool {
        AXBrailleTable *hostTable = [[AXBrailleTable alloc] initWithIdentifier:@"ueb1"];
        AXBrailleTranslator *host = [[AXBrailleTranslator alloc] initWithBrailleTable:hostTable];


        for (NSString *text in charon_corpus()) {
            AXBrailleTranslationResult *result = [host translatePrintText:text];
            printf("fwd\t%s\t%s\t%lu\n", [text UTF8String],
                   [(result.resultString ?: @"(nil)") UTF8String],
                   (unsigned long)charon_unmapped_count(result));
        }
        for (NSString *text in charon_corpus()) {
            AXBrailleTranslationResult *cells = [host translatePrintText:text];
            AXBrailleTranslationResult *back = [host backTranslateBraille:cells.resultString ?: @""];
            printf("back\t%s\t%s\t%lu\n", [text UTF8String],
                   [(back.resultString ?: @"(nil)") UTF8String],
                   (unsigned long)charon_unmapped_count(back));
        }
        return 0;
    }
}
