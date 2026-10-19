/* reader.c: the CIFormat codes, printed one per line as "name code".
 *
 * The port's own objects are COMPILED and LINKED into this reader, so each name resolves to the code the
 * port defines and not to the host's dylib - which is the whole point: without linking them the program
 * would print Apple's numbers for a port that got every one of them wrong.  Compiled a second time with
 * -DHOST_ONLY and without those objects, the same program answers what Apple answers, so both sides are
 * read by one program and one printf and cannot disagree about how to read the other. */
#include <CoreGraphics/CoreGraphics.h>
#include <CoreImage/CIImage.h>
#include <stdio.h>

/* CIFormat is declared in CIImage.h as a CoreImage export, not in CoreImage.h. */
typedef OSType CIFormat;

extern const CIFormat kCIFormatRGBX16;
extern const CIFormat kCIFormatRGB10;
extern const CIFormat kCIFormatRGBXh;
extern const CIFormat kCIFormatRGBXf;

static const char *const names[] = {"kCIFormatRGBX16", "kCIFormatRGB10", "kCIFormatRGBXh", "kCIFormatRGBXf"};
static const CIFormat *const values[] = {&kCIFormatRGBX16, &kCIFormatRGB10, &kCIFormatRGBXh, &kCIFormatRGBXf};

int main(void) {
    for (size_t i = 0; i < sizeof names / sizeof *names; i++)
        printf("%s %lu\n", names[i], (unsigned long)*values[i]);
    return 0;
}
