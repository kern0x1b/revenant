#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RevenantPDFKit.h"
#import "RevenantPDFKitColours.h"
#include <stdio.h>

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

static void printAnnotationColour(const char *label, const char *member, CGColorRef colour)
{
    if (colour == NULL) {
        printf("%s.%s=(nil)\n", label, member);
        return;
    }
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

static const char *revenantAnnotationName(PDFAnnotation *annotation)
{
    CGPDFObjectRef found = NULL;
    if (!CGPDFDictionaryGetObject([annotation revenant_CGPDFDictionary], "NM", &found) || found == NULL
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
        const char *name = revenantAnnotationName(page.annotations[a]);
        if (name != NULL)
            [names addObject:@(name)];
    }
    if (names.count == 0)
        return;
    printf("%s.colours.names=%s\n", fixture, [[names componentsJoinedByString:@","] UTF8String]);
    for (unsigned a = 0; a < page.annotations.count; a++) {
        PDFAnnotation *annotation = page.annotations[a];
        const char *name = revenantAnnotationName(annotation);
        if (name == NULL)
            continue;
        char label[512];
        snprintf(label, sizeof(label), "%s.colours.nm%s", fixture, name);
        CGPDFDictionaryRef dictionary = [annotation revenant_CGPDFDictionary];
        printAnnotationColour(label, "backgroundColor",
                              revenant_annotation_background_colour(dictionary));
        printAnnotationColour(label, "interiorColor",
                              revenant_annotation_interior_colour(dictionary));
        printAnnotationColour(label, "fontColor", revenant_annotation_font_colour(dictionary));
        NSString *fontName = revenant_annotation_font_name(dictionary);
        CGFloat fontSize = revenant_annotation_font_size(dictionary);
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
