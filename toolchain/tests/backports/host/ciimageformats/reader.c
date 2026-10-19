#include <CoreGraphics/CoreGraphics.h>
#include <CoreImage/CIImage.h>
#include <stdio.h>

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
