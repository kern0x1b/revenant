#import <Foundation/Foundation.h>
#ifndef REVENANT_HALF_PORT
#import <Accessibility/Accessibility.h>
#endif

#ifdef REVENANT_HALF_PORT
#import "RevenantBraille.h"
#endif

static NSArray *revenant_corpus(void)
{
    return @[ @"abcxyz", @"ABC", @"AbC dEf", @"The Quick Brown Fox",
               @"123", @"1a2b", @"0123456789", @",;:.-!?", @"don't", @"(a)*b/c",
               @"a b\tc", @"Hello, World! 42.", @"", @"xyz" ];
}

#ifdef REVENANT_HALF_PORT
#define revenant_unmapped_count(result) [(result) revenant_unmappedCount]
#else
#define revenant_unmapped_count(result) (NSUInteger)0
#endif

int main(void)
{
    @autoreleasepool {
        AXBrailleTable *hostTable = [[AXBrailleTable alloc] initWithIdentifier:@"ueb1"];
        AXBrailleTranslator *host = [[AXBrailleTranslator alloc] initWithBrailleTable:hostTable];


        for (NSString *text in revenant_corpus()) {
            AXBrailleTranslationResult *result = [host translatePrintText:text];
            printf("fwd\t%s\t%s\t%lu\n", [text UTF8String],
                   [(result.resultString ?: @"(nil)") UTF8String],
                   (unsigned long)revenant_unmapped_count(result));
        }
        for (NSString *text in revenant_corpus()) {
            AXBrailleTranslationResult *cells = [host translatePrintText:text];
            AXBrailleTranslationResult *back = [host backTranslateBraille:cells.resultString ?: @""];
            printf("back\t%s\t%s\t%lu\n", [text UTF8String],
                   [(back.resultString ?: @"(nil)") UTF8String],
                   (unsigned long)revenant_unmapped_count(back));
        }
        return 0;
    }
}
