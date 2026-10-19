// host-base14.m - the STANDARD FOURTEEN's own advances, asked of this Mac's PDFKit one character at a
// time.
//
// The instrument for the boundary that decides whether -[PDFSelection boundsForPage:] can be implemented
// over a base-fourteen font at all.  A document that relies on one of the standard fourteen carries NO
// /Widths, and the metrics that answer it are normative data of PDF 1.7 Annex F - there is no API on the
// release that hands them over, and the one that looks like it does answers a DIFFERENT number:
// CGFontCreateWithFontName("Courier") gives 43.2070 for "page 1" where the host answers 43.2000.
//
// So the numbers are measured here rather than transcribed from a specification document, one character at
// a time, and the run output is the evidence the table in the port rests on.
//
// For each fixture it prints one line per printable ASCII code:
//
//     <code> <character> <x> <width>
//
// and the WIDTH is the advance at 12pt, so the table the port carries is the width over 12 and is not
// rounded on the way in - every code here is measured to four places and the port keeps them as
// thousandths of an em, which is the unit /Widths itself is written in.
#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            if (document == nil || document.pageCount == 0) {
                printf("%s NO DOCUMENT\n", [path.lastPathComponent UTF8String]);
                continue;
            }
            PDFPage *page = [document pageAtIndex:0];
            NSString *text = page.string;
            if (text.length == 0) {
                printf("%s EMPTY\n", [path.lastPathComponent UTF8String]);
                continue;
            }
            // THE WHOLE LINE FIRST, so each character's rect can be read as a difference and a fixture
            // whose whole-line rect is wrong says so once instead of ninety-five times.
            CGRect whole = [[document findString:text withOptions:0].firstObject boundsForPage:page];
            printf("%s text-len=%lu whole=%.4f,%.4f,%.4f,%.4f\n", [path.lastPathComponent UTF8String],
                   (unsigned long)text.length, whole.origin.x, whole.origin.y, whole.size.width,
                   whole.size.height);
            for (NSUInteger c = 0; c < text.length; c++) {
                NSString *needle = [text substringWithRange:NSMakeRange(c, 1)];
                NSArray<PDFSelection *> *found = [document findString:needle withOptions:0];
                if (found.count == 0) {
                    printf("%3lu NO MATCH\n", (unsigned long)[needle characterAtIndex:0]);
                    continue;
                }
                CGRect b = [found.firstObject boundsForPage:page];
                // The character's own advance: its rect's width, and its rect's x against the run's own
                // x, which is the same number the port has to reproduce.
                printf("%3lu %s x=%.4f w=%.4f\n", (unsigned long)[needle characterAtIndex:0],
                       [needle UTF8String], b.origin.x, b.size.width);
            }
        }
    }
    return 0;
}