#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

static NSString *visible(NSString *s)
{
    if (s == nil) return @"(nil)";
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c < 0x20 || c > 0x7E) [out appendFormat:@"<%02X>", c];
        else [out appendFormat:@"%C", c];
    }
    return out;
}

static const char *const GLYPH_NAMES[] = {"p", "a", "g", "e", "space", "one"};
static const char CODES[] = "page 1";
#define CHARACTER_COUNT 6

static void reportFont(const char *label, CGFontRef font)
{
    if (font == NULL) {
        printf("    font %-5s NO FONT - no reader could open it\n", label);
        return;
    }
    int units = CGFontGetUnitsPerEm(font);
    printf("    font %-5s unitsPerEm=%d ascent=%d descent=%d  advances(1000 em):",
           label, units, CGFontGetAscent(font), CGFontGetDescent(font));
    CGGlyph glyphs[CHARACTER_COUNT];
    int advances[CHARACTER_COUNT];
    double sum = 0;
    for (size_t i = 0; i < CHARACTER_COUNT; i++) {
        glyphs[i] = CGFontGetGlyphWithGlyphName(font, (__bridge CFStringRef)@(GLYPH_NAMES[i]));
        advances[i] = -1;
    }
    bool got = CGFontGetGlyphAdvances(font, glyphs, CHARACTER_COUNT, advances);
    for (size_t i = 0; i < CHARACTER_COUNT; i++) {
        printf(" %s(g%u)=%d", GLYPH_NAMES[i], (unsigned)glyphs[i], advances[i]);
        sum += (double)advances[i] * 1000.0 / (units > 0 ? units : 1);
    }
    printf("   sum=%.4f%s\n", sum, got ? "" : "  [CGFontGetGlyphAdvances returned false]");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            if (document == nil) {
                printf("%-38s NO DOCUMENT\n", [path.lastPathComponent UTF8String]);
                continue;
            }
            printf("%s\n", [path.lastPathComponent UTF8String]);
            for (NSUInteger p = 0; p < document.pageCount; p++)
                printf("  page-%lu -string=%s length=%lu\n", (unsigned long)p,
                       visible([[document pageAtIndex:p] string]).UTF8String,
                       (unsigned long)[[document pageAtIndex:p] string].length);

            CGPDFDocumentRef raw = CGPDFDocumentCreateWithURL((__bridge CFURLRef)
                [NSURL fileURLWithPath:path]);
            CGPDFPageRef rawPage = raw ? CGPDFDocumentGetPage(raw, 1) : NULL;
            CGPDFDictionaryRef pageDict = rawPage ? CGPDFPageGetDictionary(rawPage) : NULL;
            CGPDFDictionaryRef resources = NULL, fonts = NULL, font = NULL, descriptor = NULL;
            if (pageDict != NULL)
                CGPDFDictionaryGetDictionary(pageDict, "Resources", &resources);
            if (resources != NULL)
                CGPDFDictionaryGetDictionary(resources, "Font", &fonts);
            if (fonts != NULL)
                CGPDFDictionaryGetDictionary(fonts, "F1", &font);
            if (font != NULL)
                CGPDFDictionaryGetDictionary(font, "FontDescriptor", &descriptor);


            long lastChar = 0;
            if (font != NULL)
                CGPDFDictionaryGetInteger(font, "LastChar", &lastChar);
            if (font != NULL) {
                long firstChar = 0;
                CGPDFDictionaryGetInteger(font, "FirstChar", &firstChar);
                const char *base = NULL;
                if (CGPDFDictionaryGetName(font, "BaseFont", &base) && base != NULL)
                    printf("  BaseFont=%s  FirstChar=%ld  LastChar=%ld\n", base, firstChar, lastChar);
                CGPDFArrayRef widths = NULL;
                if (CGPDFDictionaryGetArray(font, "Widths", &widths) && widths != NULL) {
                    printf("    /Widths  ");
                    double sum = 0;
                    for (size_t k = 0; k < CHARACTER_COUNT; k++) {
                        long code = (unsigned char)CODES[k];
                        size_t at = (size_t)(code - firstChar);
                        long width = 0;
                        if (at < CGPDFArrayGetCount(widths))
                            CGPDFArrayGetInteger(widths, at, &width);
                        printf(" %c=%ld", CODES[k], width);
                        sum += width;
                    }
                    printf("   sum=%.0f per 1000 em\n", sum);
                } else {
                    printf("    /Widths  NONE\n");
                }
            } else {
                printf("  no /F1 in the page's /Resources\n");
            }

            if (descriptor != NULL) {
                CGPDFStreamRef stream = NULL;
                if (CGPDFDictionaryGetStream(descriptor, "FontFile2", &stream) && stream != NULL) {
                    CFDataRef data = CGPDFStreamCopyData(stream, NULL);
                    if (data != NULL) {
                        CFDataRef flat = CFDataCreate(NULL, CFDataGetBytePtr(data),
                                                      (CFIndex)CFDataGetLength(data));
                        CGDataProviderRef provider = CGDataProviderCreateWithCFData(flat);
                        CGFontRef fontRef = provider != NULL
                            ? CGFontCreateWithDataProvider(provider) : NULL;
                        if (provider != NULL) CGDataProviderRelease(provider);
                        CFRelease(flat);
                        reportFont("prog", fontRef);
                        if (fontRef != NULL) CGFontRelease(fontRef);
                        CFRelease(data);
                    }
                } else {
                    printf("    font prog   NO /FontFile2\n");
                }
            }

            if (font != NULL) {
                const char *base = NULL;
                if (CGPDFDictionaryGetName(font, "BaseFont", &base) && base != NULL) {
                    NSString *name = @(base);
                    NSRange plus = [name rangeOfString:@"+"];
                    if (plus.location != NSNotFound && plus.location + 7 <= name.length)
                        name = [name substringFromIndex:plus.location + 7];
                    CGFontRef named = CGFontCreateWithFontName((__bridge CFStringRef)name);
                    reportFont("name", named);
                    if (named != NULL) CGFontRelease(named);
                    printf("    stripped name=%s\n", name.UTF8String);
                }
            }
            if (raw != NULL) CGPDFDocumentRelease(raw);

            static const char *const needles[] = {"p", "a", "g", "e", " ", "1", "page", "page 1"};
            PDFPage *page0 = [document pageAtIndex:0];
            PDFPage *other = document.pageCount > 1 ? [document pageAtIndex:1] : nil;
            for (size_t n = 0; n < sizeof(needles) / sizeof(needles[0]); n++) {
                NSArray<PDFSelection *> *found =
                    [document findString:@(needles[n]) withOptions:0];
                for (NSUInteger s = 0; s < found.count; s++) {
                    PDFSelection *selection = found[s];
                    CGRect b = [selection boundsForPage:page0];
                    CGRect o = other != nil ? [selection boundsForPage:other] : CGRectZero;
                    printf("    needle=%-8s [%lu] string=%-10s ranges=%lu  "
                           "bounds0=%.4f,%.4f,%.4f,%.4f  boundsOther=%.4f,%.4f,%.4f,%.4f\n",
                           needles[n], (unsigned long)s, visible(selection.string).UTF8String,
                           (unsigned long)[selection numberOfTextRangesOnPage:page0],
                           b.origin.x, b.origin.y, b.size.width, b.size.height,
                           o.origin.x, o.origin.y, o.size.width, o.size.height);
                }
                if (found.count == 0)
                    printf("    needle=%-8s NO MATCH\n", needles[n]);
            }
        }
    }
    return 0;
}
