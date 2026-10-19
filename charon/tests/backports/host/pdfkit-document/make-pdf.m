// A PDF made here, so both sides read the SAME file and neither side is asked about a fixture it
// cannot reproduce.  CGPDFContext is the release's own writer and is exported by both bands.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

// The three box fixtures, written as files rather than with CGPDFContext: a page that NAMES every box,
// one with no /CropBox at all, and one rotated - the three cases that decide what -boundsForBox: answers.
// Measured against the host's own -boundsForBox:, all three agree with CGPDFPageGetBoxRect, so these
// are facts the run compares rather than a rule the port has to implement.
static void draw(NSString *path, int pages, CGRect box)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[(id)kCGPDFContextTitle] = @"the port's own fixture";
    info[(id)kCGPDFContextAuthor] = @"registry-shape";
    info[(id)kCGPDFContextCreator] = @"CGPDFContext";
    // The document's Info dictionary is the context's own auxiliaryInfo argument - there is no
    // CGPDFContextSetInfo - so this is the release's writer carrying what the port's
    // -documentAttribute: will read back.
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], &box,
                                                    (__bridge CFDictionaryRef)info);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context\n");
        return;
    }
    for (int page = 1; page <= pages; page++) {
        CGPDFContextBeginPage(context, NULL);
        // A font must be SELECTED before text is shown: CGPDFContextShowTextAtPoint takes a const
        // char * (not a UniChar *), and with no font selected the page's content stream came out as the
        // bare "q Q" that BeginPage and EndPage write - the harness was comparing a fixture with no text
        // in it, and -w had hidden the deprecation notice that would have said so.
        CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        NSString *text = [NSString stringWithFormat:@"page %d", page];
        CGContextShowTextAtPoint(context, 20, box.size.height - 40, text.UTF8String, (int)text.length);
        CGPDFContextEndPage(context);
    }
    CGPDFContextClose(context);
    CGContextRelease(context);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *directory = argc > 1 ? @(argv[1]) : NSTemporaryDirectory();
        NSString *three = [directory stringByAppendingPathComponent:@"charon-fixture-3.pdf"];
        NSString *one = [directory stringByAppendingPathComponent:@"charon-fixture-1.pdf"];
        NSString *none = [directory stringByAppendingPathComponent:@"charon-fixture-0.pdf"];
        draw(three, 3, CGRectMake(0, 0, 612, 792));   // US Letter, three pages
        draw(one, 1, CGRectMake(0, 0, 200, 400));     // a box of our own, one page
        draw(none, 0, CGRectMake(0, 0, 100, 100));    // no pages at all
        // the three box fixtures come from make-box-pdfs.py, which measures every xref offset and the
        // stream's /Length from the object bytes; they are geometry-only and carry no text to find
        for (NSString *path in @[ three, one, none ])
            printf("%s %s\n", path.UTF8String,
                   [[NSFileManager defaultManager] fileExistsAtPath:path] ? "written" : "MISSING");
        // what was asked for, so the fixture check knows which pages are meant to carry text: the
        // no-pages fixture comes out of CGPDFContextClose with one page and nothing on it
        NSMutableString *manifest = [NSMutableString string];
        [manifest appendFormat:@"%@\t3\tpage N\n", three.lastPathComponent];
        [manifest appendFormat:@"%@\t1\tpage N\n", one.lastPathComponent];
        [manifest appendFormat:@"%@\t0\t\n", none.lastPathComponent];
        // the box fixtures are geometry-only: their text expectation is nothing, and saying so is not
        // the same as weakening the check on the fixtures that DO carry text
        [manifest appendFormat:@"%@\t1\tgeometry-only\n", @"box-all.pdf"];
        [manifest appendFormat:@"%@\t1\tgeometry-only\n", @"box-nocrop.pdf"];
        [manifest appendFormat:@"%@\t1\tgeometry-only\n", @"box-rotated.pdf"];
        [manifest writeToFile:[directory stringByAppendingPathComponent:@"drew.txt"]
                  atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
