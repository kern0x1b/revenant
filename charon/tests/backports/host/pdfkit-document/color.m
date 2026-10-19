// The PORT's PDFAppearanceCharacteristics, in a process that has a real UIColor, and nothing else.
//
// WHY THIS IS A THIRD BINARY and not part of port.m: PDFAppearanceCharacteristics' two colour members
// are UIColor, and UIColor does not exist in a macOS process - the host's own type there is NSColor.
// Mac Catalyst has both: UIKit backed by AppKit, and the CoreGraphics the port reads a PDF with, which
// is the same shape tests/backports/host/uikit2/run.sh builds against.  So this binary is the port's
// objects plus UIKit, and it prints ONLY the appearance block: the six objects and the controlType
// sweep, in the same order and the same keys host.m prints them, so run.sh can merge its answers into
// the port's map for those keys and leave every other key to the macOS port binary.
//
// The two printing helpers below are written out twice, once per binary, and that is forced rather than
// tidy: host.m includes <PDFKit/PDFKit.h> and this file includes "CharonPDFKit.h", and a translation
// unit holding both would carry two @interface PDFDocument definitions that disagree - which is the
// reason this harness is separate processes in the first place.  Their shapes stay identical on
// purpose, because run.sh compares by key and a key only one side prints is not a fact at all.
//
// What that makes comparable: the host sets NSColor red and reads it back as 1 0 0 1, and this binary
// sets UIColor red and reads it back as 1 0 0 1.  The two colour classes differ; the colour does not,
// and the four components are what each platform's own class answers.  No stand-in colour object is
// involved anywhere.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CharonPDFKit.h"
#import "CharonPDFKitColours.h"
#include <stdio.h>

// A colour, by the four components its own class answers, or "(nil)".  -getRed:green:blue:alpha: is
// on both UIColor and NSColor, so this one function is the whole of the platform difference.
static void printAppearanceColour(const char *label, const char *member, UIColor *colour)
{
    if (colour == nil) {
        printf("appearance.%s.%s=(nil)\n", label, member);
        return;
    }
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [colour getRed:&r green:&g blue:&b alpha:&a];
    printf("appearance.%s.%s=%.6f,%.6f,%.6f,%.6f\n", label, member, (double)r, (double)g, (double)b,
           (double)a);
}

// One appearance-characters object, printed under one label, in the same shape and the same order as
// host.m's function of the same name.
static void printAppearanceCharacteristics(const char *label,
                                           PDFAppearanceCharacteristics *characteristics)

{
    printf("appearance.%s.controlType=%ld\n", label, (long)characteristics.controlType);
    printf("appearance.%s.rotation=%ld\n", label, (long)characteristics.rotation);
    printAppearanceColour(label, "backgroundColor", characteristics.backgroundColor);
    printAppearanceColour(label, "borderColor", characteristics.borderColor);
    printf("appearance.%s.caption=%s\n", label,
           characteristics.caption ? characteristics.caption.UTF8String : "(nil)");
    printf("appearance.%s.rolloverCaption=%s\n", label,
           characteristics.rolloverCaption ? characteristics.rolloverCaption.UTF8String : "(nil)");
    printf("appearance.%s.downCaption=%s\n", label,
           characteristics.downCaption ? characteristics.downCaption.UTF8String : "(nil)");
    NSDictionary *keys = characteristics.appearanceCharacteristicsKeyValues;
    NSMutableArray *sorted = [[keys allKeys] mutableCopy];
    [sorted sortUsingSelector:@selector(compare:)];
    printf("appearance.%s.keys=%lu\n", label, (unsigned long)sorted.count);
    for (NSString *key in sorted) {
        id value = keys[key];
        if ([value isKindOfClass:[NSString class]]) {
            printf("appearance.%s.key.%s=%s\n", label, [key UTF8String],
                   [(NSString *)value UTF8String]);
        } else if ([value isKindOfClass:[UIColor class]]) {
            CGFloat r = 0, g = 0, b = 0, a = 0;
            [(UIColor *)value getRed:&r green:&g blue:&b alpha:&a];
            printf("appearance.%s.key.%s=%.6f,%.6f,%.6f,%.6f\n", label, [key UTF8String], (double)r,
                   (double)g, (double)b, (double)a);
        } else {
            printf("appearance.%s.key.%s=%.6f\n", label, [key UTF8String], (double)[value doubleValue]);
        }
    }
}

// ---- PDFAnnotation's three colours and its font, in the same keys host.m prints them in ---------
//
// Written out a second time, like the two helpers above and for the same reason: this translation unit
// includes "CharonPDFKit.h" and host.m includes <PDFKit/PDFKit.h>, and a unit holding both would carry
// two @interface PDFAnnotation definitions that disagree.  Their shapes stay identical on purpose,
// because run.sh compares by key and a key only one side prints is not a fact at all.
//
// A colour is its SPACE NAME and its COMPONENTS IN THAT SPACE rather than four RGBA numbers, for the
// reason host.m's copy of this says: most of these colours are gray or CMYK, and the four-number shape
// only describes an RGB one.  Both sides read the two facts off CoreGraphics.
static void printAnnotationColour(const char *label, const char *member, CGColorRef colour)
{
    if (colour == NULL) {
        printf("%s.%s=(nil)\n", label, member);
        return;
    }
    // CGColorGetColorSpace and not colour->colorSpace: struct CGColor is an OPAQUE type in this SDK -
    // CF_BRIDGED_TYPE(id) - so its member is not readable and the accessor is the only way to the space.
    CGColorSpaceRef space = CGColorGetColorSpace(colour);
    printf("%s.%s.space=%s\n", label, member,
           space != NULL ? [(__bridge NSString *)CGColorSpaceGetName(space) UTF8String] : "(nil)");
    size_t count = CGColorGetNumberOfComponents(colour);
    NSMutableArray *parts = [NSMutableArray array];
    const CGFloat *raw = CGColorGetComponents(colour);
    for (size_t i = 0; i < count; i++)
        [parts addObject:[NSString stringWithFormat:@"%.6f", (double)raw[i]]];
    printf("%s.%s.components=%s\n", label, member,
           [[parts componentsJoinedByString:@","] UTF8String]);
    CGColorRelease(colour);
}

// The /NM of an annotation - PDF 1.7 Table 8.16's own unique-name key - or NULL when it does not carry
// one.  The same shape as host.m's copy, for the same reason: an annotation that names itself can be
// found in the output whatever has been dropped.
//
// Read off the DICTIONARY and not through -valueForAnnotationKey:, because that member is its own family
// and is not implemented: the harness must ask each side for the same BYTES, and the bytes are the
// dictionary.  The port's own CharonInternals seam is what exposes them, and both sides read a PDF string
// the same way.
static const char *charonAnnotationName(PDFAnnotation *annotation)
{
    CGPDFObjectRef found = NULL;
    if (!CGPDFDictionaryGetObject([annotation charon_CGPDFDictionary], "NM", &found) || found == NULL
        || CGPDFObjectGetType(found) != kCGPDFObjectTypeString)
        return NULL;
    CGPDFStringRef string = NULL;
    if (!CGPDFObjectGetValue(found, kCGPDFObjectTypeString, &string) || string == NULL)
        return NULL;
    CFStringRef text = CGPDFStringCopyTextString(string);
    if (text == NULL)
        return NULL;
    NSString *name = (__bridge_transfer NSString *)text;
    return name.length == 0 ? NULL : [name UTF8String];
}

static void printAnnotationColourFacts(const char *fixture, PDFPage *page)
{
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned a = 0; a < page.annotations.count; a++) {
        const char *name = charonAnnotationName(page.annotations[a]);
        if (name != NULL)
            [names addObject:@(name)];
    }
    if (names.count == 0)
        return;
    printf("%s.colours.names=%s\n", fixture, [[names componentsJoinedByString:@","] UTF8String]);
    for (unsigned a = 0; a < page.annotations.count; a++) {
        PDFAnnotation *annotation = page.annotations[a];
        const char *name = charonAnnotationName(annotation);
        if (name == NULL)
            continue;
        char label[512];
        snprintf(label, sizeof(label), "%s.colours.nm%s", fixture, name);
        // THE SEAM, CALLED DIRECTLY, and not -[PDFAnnotation backgroundColor] and its three neighbours -
        // and the reason is in CharonPDFKitColours.h's own comment: the platform's PDFKit loads in this
        // binary and its PDFAnnotationUtilities category REPLACES the port's four selectors, so a
        // differential written against the selectors would compare Apple's PDFKit with Apple's PDFKit.
        // CGPDFDictionaryGetObject on the same dictionary the port read is the same BYTES on both sides,
        // and no selector is dispatched anywhere below, so nothing a later image loads can take this over.
        CGPDFDictionaryRef dictionary = [annotation charon_CGPDFDictionary];
        printAnnotationColour(label, "backgroundColor",
                              charon_annotation_background_colour(dictionary));
        printAnnotationColour(label, "interiorColor",
                              charon_annotation_interior_colour(dictionary));
        printAnnotationColour(label, "fontColor", charon_annotation_font_colour(dictionary));
        NSString *fontName = charon_annotation_font_name(dictionary);
        CGFloat fontSize = charon_annotation_font_size(dictionary);
        // and the same wrapping the port's own -font does, so that what is compared is the NAME and the
        // SIZE the derivation chose and not the two platforms' font classes
        UIFont *font = [UIFont fontWithName:fontName size:fontSize];
        if (font == nil) {
            printf("%s.font.name=%s\n", label, [fontName UTF8String]);
            printf("%s.font.size=%.6f\n", label, (double)fontSize);
        } else {
            printf("%s.font.name=%s\n", label, [font.fontName UTF8String]);
            printf("%s.font.size=%.6f\n", label, (double)font.pointSize);
        }
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        printf("side=portcolor\n");
        printAppearanceCharacteristics("fresh", [[PDFAppearanceCharacteristics alloc] init]);        {
            PDFAppearanceCharacteristics *only = [[PDFAppearanceCharacteristics alloc] init];
            only.caption = @"cap";
            printAppearanceCharacteristics("captionOnly", only);
            PDFAppearanceCharacteristics *cleared = [[PDFAppearanceCharacteristics alloc] init];
            cleared.caption = @"cap";
            cleared.backgroundColor = [UIColor redColor];
            cleared.caption = nil;
            cleared.backgroundColor = nil;
            printAppearanceCharacteristics("cleared", cleared);
            PDFAppearanceCharacteristics *empty = [[PDFAppearanceCharacteristics alloc] init];
            empty.caption = @"";
            empty.downCaption = @"";
            printAppearanceCharacteristics("empty", empty);
            PDFAppearanceCharacteristics *negative = [[PDFAppearanceCharacteristics alloc] init];
            negative.rotation = -90;
            printAppearanceCharacteristics("negative", negative);
            for (long control = -1; control <= 3; control++) {
                PDFAppearanceCharacteristics *probe =
                    [[PDFAppearanceCharacteristics alloc] init];
                probe.controlType = (PDFWidgetControlType)control;
                printf("appearance.controlType%ld.read=%ld\n", control, (long)probe.controlType);
                printf("appearance.controlType%ld.keys=%lu\n", control,
                       (unsigned long)probe.appearanceCharacteristicsKeyValues.count);
            }
            PDFAppearanceCharacteristics *full = [[PDFAppearanceCharacteristics alloc] init];
            full.controlType = kPDFWidgetCheckBoxControl;
            full.backgroundColor = [UIColor redColor];
            full.borderColor = [UIColor blueColor];
            full.rotation = 90;
            full.caption = @"cap";
            full.rolloverCaption = @"roll";
            full.downCaption = @"down";
            printAppearanceCharacteristics("full", full);
        }
        // and then PDFAnnotation's own three colours and its font, over the SAME fixtures the other two
        // binaries are given and in the same order, so the keys this prints are the keys host.m printed.
        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            const char *name = strrchr(argv[i], '/');
            name = name ? name + 1 : argv[i];
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            if (document == nil || document.pageCount == 0)
                continue;
            printAnnotationColourFacts(name, [document pageAtIndex:0]);
        }
    }
    return 0;
}