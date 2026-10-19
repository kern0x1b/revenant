#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

static void drawLines(NSString *path, CGRect box, const char *const *lines, int count, CGFloat top)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[(id)kCGPDFContextTitle] = @"conforming-writer three-line fixture";
    info[(id)kCGPDFContextCreator] = @"CGPDFContext";
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],
                                                    &box, (__bridge CFDictionaryRef)info);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context for %s\n", path.UTF8String);
        return;
    }
    CGPDFContextBeginPage(context, NULL);
    CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    for (int i = 0; i < count; i++) {
        CGFloat y = top - 20.0 * i;
        CGContextShowTextAtPoint(context, 20, y, lines[i], (int)strlen(lines[i]));
    }
    CGPDFContextEndPage(context);
    CGPDFContextClose(context);
    CGContextRelease(context);
}

static void drawPair(NSString *path, CGRect box, const char *first, const char *second, CGFloat y0,
                      CGFloat y1)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[(id)kCGPDFContextCreator] = @"CGPDFContext";
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],
                                                    &box, (__bridge CFDictionaryRef)info);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context for %s\n", path.UTF8String);
        return;
    }
    CGPDFContextBeginPage(context, NULL);
    CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextShowTextAtPoint(context, 20, y0, first, (int)strlen(first));
    CGContextShowTextAtPoint(context, 20, y1, second, (int)strlen(second));
    CGPDFContextEndPage(context);
    CGPDFContextClose(context);
    CGContextRelease(context);
}

static void drawPerPage(NSString *path, CGRect box, const char *const *texts, int pages, CGFloat y)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[(id)kCGPDFContextTitle] = @"conforming-writer per-page fixture";
    info[(id)kCGPDFContextCreator] = @"CGPDFContext";
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],
                                                    &box, (__bridge CFDictionaryRef)info);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context for %s\n", path.UTF8String);
        return;
    }
    for (int page = 0; page < pages; page++) {
        CGPDFContextBeginPage(context, NULL);
        CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        CGContextShowTextAtPoint(context, 20, y, texts[page], (int)strlen(texts[page]));
        CGPDFContextEndPage(context);
    }
    CGPDFContextClose(context);
    CGContextRelease(context);
}

static void draw(NSString *path, int pages, CGRect box, const char *text, CGFloat y)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[(id)kCGPDFContextTitle] = @"conforming-writer fixture";
    info[(id)kCGPDFContextAuthor] = @"make-text-fixture";
    info[(id)kCGPDFContextCreator] = @"CGPDFContext";
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],
                                                    &box, (__bridge CFDictionaryRef)info);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context for %s\n", path.UTF8String);
        return;
    }
    for (int page = 1; page <= pages; page++) {
        CGPDFContextBeginPage(context, NULL);
        CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        NSString *shown = pages > 1 ? [NSString stringWithFormat:@"page %d", page] : @(text);
        CGContextShowTextAtPoint(context, 20, y, shown.UTF8String, (int)shown.length);
        CGPDFContextEndPage(context);
    }
    CGPDFContextClose(context);
    CGContextRelease(context);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *directory = argc > 1 ? @(argv[1]) : NSTemporaryDirectory();

        CGRect small = CGRectMake(0, 0, 200, 400);
        NSString *one = [directory stringByAppendingPathComponent:@"cgfixture-1.pdf"];
        draw(one, 1, small, "page 1", 360);
        CGRect large = CGRectMake(0, 0, 612, 792);
        NSString *three = [directory stringByAppendingPathComponent:@"cgfixture-3.pdf"];
        draw(three, 3, large, "page 1", 752);
        NSString *bare = [directory stringByAppendingPathComponent:@"cgfixture-bare.pdf"];
        draw(bare, 1, small, "", 360);

        static const char *const lines[] = {"shared one", "shared two", "third line"};
        CGRect lines_box = CGRectMake(0, 0, 300, 400);
        NSString *lines_pdf = [directory stringByAppendingPathComponent:@"cgfixture-lines.pdf"];
        drawLines(lines_pdf, lines_box, lines, 3, 360);

        CGRect pair_box = CGRectMake(0, 0, 300, 400);
        NSString *down = [directory stringByAppendingPathComponent:@"cgfixture-pair-down.pdf"];
        drawPair(down, pair_box, "alpha", "beta", 360, 340);
        NSString *same = [directory stringByAppendingPathComponent:@"cgfixture-pair-same.pdf"];
        drawPair(same, pair_box, "alpha", "beta", 360, 360);
        NSString *up = [directory stringByAppendingPathComponent:@"cgfixture-pair-up.pdf"];
        drawPair(up, pair_box, "alpha", "beta", 340, 360);

        static const char *const words[] = {"zero alpha bravo charlie alpha alpha"};
        NSString *words_pdf = [directory stringByAppendingPathComponent:@"cgfixture-words.pdf"];
        drawLines(words_pdf, lines_box, words, 1, 360);

        static const char *const gap[] = {"alpha  bravo"};
        NSString *gap_pdf = [directory stringByAppendingPathComponent:@"cgfixture-gap.pdf"];
        drawLines(gap_pdf, lines_box, gap, 1, 360);

        static const char *const lines2[] = {"one two", "three four", "five six"};
        NSString *lines2_pdf = [directory stringByAppendingPathComponent:@"cgfixture-lines2.pdf"];
        drawLines(lines2_pdf, lines_box, lines2, 3, 360);

        static const char *const tail[] = {"alpha ", "bravo"};
        NSString *tail_pdf = [directory stringByAppendingPathComponent:@"cgfixture-tail.pdf"];
        drawLines(tail_pdf, lines_box, tail, 2, 360);

        static const char *const cross[] = {"alpha bravo", "charlie delta"};
        NSString *cross_pdf = [directory stringByAppendingPathComponent:@"cgfixture-cross.pdf"];
        drawPerPage(cross_pdf, lines_box, cross, 2, 360);

        static const char *const blank[] = {"alpha", "", "bravo"};
        NSString *blank_pdf = [directory stringByAppendingPathComponent:@"cgfixture-blank.pdf"];
        drawLines(blank_pdf, lines_box, blank, 3, 360);

        static const char *const withBreak[] = {"alpha\nbravo"};
        NSString *inline_pdf = [directory stringByAppendingPathComponent:@"cgfixture-inline.pdf"];
        drawLines(inline_pdf, lines_box, withBreak, 1, 360);

        static const char *const lead[] = {" alpha bravo ", "charlie "};
        NSString *lead_pdf = [directory stringByAppendingPathComponent:@"cgfixture-lead.pdf"];
        drawLines(lead_pdf, lines_box, lead, 2, 360);

        NSString *tailpair_pdf = [directory stringByAppendingPathComponent:@"cgfixture-tailpair.pdf"];
        drawPair(tailpair_pdf, lines_box, "alpha ", "beta", 360, 360);

        static const char *const tabs[] = {"alpha\tbravo", "alpha\t\tbravo"};
        NSString *tab_pdf = [directory stringByAppendingPathComponent:@"cgfixture-tab.pdf"];
        drawLines(tab_pdf, lines_box, tabs, 2, 360);

        for (NSString *p in @[one, three, bare, lines_pdf, down, same, up, words_pdf, gap_pdf,
                              lines2_pdf, tail_pdf, cross_pdf, blank_pdf, inline_pdf, lead_pdf,
                              tailpair_pdf, tab_pdf])
            printf("  wrote %s\n", [p.lastPathComponent UTF8String]);
    }
    return 0;
}
