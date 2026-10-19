//
//  braille-differential.m
//  The same text through the system's AXBrailleTranslator and through this port's, side by side.
//
//  Two implementations, one binary: the system's three braille classes are renamed by a macro on
//  the command line (braille-differential.sh's -include) and ours keep Apple's names, so neither
//  can answer for the other and a difference is a difference in the cells.
//
//  The host has no table of its own to give a translator unless the system installs one, so the
//  system's side is given a table built through its own -[AXBrailleTable initWithIdentifier:] -
//  the API the framework offers for exactly this - and if the system then declines to translate
//  against it, that is printed and the port's cells are shown alone, which is a measurement of
//  what the host could and could not do rather than an assumed agreement.
//

#import <Foundation/Foundation.h>
// The system's Accessibility is the host half's oracle; the port half must not see it, because
// its three braille classes are the same three names and two declarations of one class is a
// build that cannot be trusted.
#ifndef CHARON_HALF_PORT
#import <Accessibility/Accessibility.h>
#endif

// One binary cannot hold both implementations: the system's three braille classes and the port's
// have the same names by construction, and renaming either renames the system's declaration too.
// So this program is built twice - once against the system's Accessibility, once against the
// port's three classes under a suffix - and the two outputs are diffed. CHARON_HALF says which.
#ifdef CHARON_HALF_PORT
// The port's own names, renamed on the command line so they cannot collide with the system's,
// which are in the same binary only if both halves are built together - and they cannot be, which
// is the whole reason for two programs.
#import "CharonBraille.h"
#endif

static NSArray *charon_corpus(void)
{
    // The cases the standard's rules distinguish: the alphabet, capitals and runs of capitals,
    // digits and the number sign, the punctuation the tables carry, and the characters a table
    // does not cover.
    return @[ @"abcxyz", @"ABC", @"AbC dEf", @"The Quick Brown Fox",
               @"123", @"1a2b", @"0123456789", @",;:.-!?", @"don't", @"(a)*b/c",
               @"a b\tc", @"Hello, World! 42.", @"", @"xyz" ];
}

// The port's unmapped count under whichever name this half is built with.
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
