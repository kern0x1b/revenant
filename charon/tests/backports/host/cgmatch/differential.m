#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

CGColorRef CharonHostCGColorCreateCopyByMatchingToColorSpace(CGColorSpaceRef, CGColorRenderingIntent, CGColorRef, CFDictionaryRef);

static long checks, different;

static void compare(const char *what, CGColorRef host, CGColorRef port)
{
    checks++;
    BOOL same = (host == NULL) == (port == NULL);
    if (same && host) {
        same = CGColorGetNumberOfComponents(host) == CGColorGetNumberOfComponents(port)
            && CGColorSpaceGetModel(CGColorGetColorSpace(host)) == CGColorSpaceGetModel(CGColorGetColorSpace(port));
        for (size_t i = 0; same && i < CGColorGetNumberOfComponents(host); i++)
            same = CGColorGetComponents(host)[i] == CGColorGetComponents(port)[i];
        same = same && CFGetRetainCount(port) == CFGetRetainCount(host);
    }
    if (!same && different++ < 20)
        printf("%s: host and port differ\n", what);
    if (host)
        CGColorRelease(host);
    if (port)
        CGColorRelease(port);
}

// CGColorCreateCopyByMatchingToColorSpace of the port, over the release's private colour transform,
// against the host's, component for component, over sources and targets of every model the device
// has and the rendering intents.
int main(void)
{
    @autoreleasepool {
        CGColorSpaceRef targets[] = {CGColorSpaceCreateDeviceGray(), CGColorSpaceCreateDeviceRGB(), CGColorSpaceCreateDeviceCMYK(),
                                     CGColorSpaceCreateWithName(kCGColorSpaceSRGB), CGColorSpaceCreateWithName(kCGColorSpaceGenericGray),
                                     CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3), CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB)};
        CGColorSpaceRef sources[] = {targets[0], targets[1], targets[2], targets[3]};
        CGColorRenderingIntent intents[] = {kCGRenderingIntentDefault, kCGRenderingIntentAbsoluteColorimetric, kCGRenderingIntentRelativeColorimetric,
                                            kCGRenderingIntentPerceptual, kCGRenderingIntentSaturation};
        srandom(11);
        for (int n = 0; n < 400; n++) {
            CGColorSpaceRef source = sources[n % 4];
            CGFloat components[5];
            size_t count = CGColorSpaceGetNumberOfComponents(source);
            for (size_t i = 0; i <= count; i++)
                components[i] = (random() % 1001) / 1000.0;
            CGColorRef colour = CGColorCreate(source, components);
            for (size_t t = 0; t < sizeof targets / sizeof *targets; t++) {
                CGColorRenderingIntent intent = intents[random() % 5];
                char what[96];
                snprintf(what, sizeof what, "colour %d of model %d to target %zu, intent %d", n, CGColorSpaceGetModel(source), t, intent);
                compare(what, CGColorCreateCopyByMatchingToColorSpace(targets[t], intent, colour, NULL),
                        CharonHostCGColorCreateCopyByMatchingToColorSpace(targets[t], intent, colour, NULL));
            }
            CGColorRelease(colour);
        }
        CGFloat red[] = {1, 0, 0, 1};
        CGColorRef colour = CGColorCreate(targets[1], red);
        compare("NULL space", CGColorCreateCopyByMatchingToColorSpace(NULL, kCGRenderingIntentDefault, colour, NULL),
                CharonHostCGColorCreateCopyByMatchingToColorSpace(NULL, kCGRenderingIntentDefault, colour, NULL));
        compare("NULL colour", CGColorCreateCopyByMatchingToColorSpace(targets[0], kCGRenderingIntentDefault, NULL, NULL),
                CharonHostCGColorCreateCopyByMatchingToColorSpace(targets[0], kCGRenderingIntentDefault, NULL, NULL));
        CGColorSpaceRef pattern = CGColorSpaceCreatePattern(NULL);
        compare("to a pattern space", CGColorCreateCopyByMatchingToColorSpace(pattern, kCGRenderingIntentDefault, colour, NULL),
                CharonHostCGColorCreateCopyByMatchingToColorSpace(pattern, kCGRenderingIntentDefault, colour, NULL));
        printf("cgmatch: %ld checks, %ld different\n", checks, different);
        return different ? 1 : 0;
    }
}
