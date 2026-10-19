// differential.m - the PDF names and colour conversion keys of the Graphics objects CGPDFNames11, 12 and 16 and CGColorConversionNames1001 and 11,
// held to the host's CoreGraphics: each constant's string, and CGPDFTagTypeGetName for every value from 0 to 1000.
// The port's symbols carry the charon_host_ prefix (run.sh renames them), the host's are the framework's own.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "check.h"

#define CONSTANTS(X) \
    X(kCGPDFOutlineChildren) X(kCGPDFOutlineDestination) X(kCGPDFOutlineDestinationRect) X(kCGPDFOutlineTitle) \
    X(kCGPDFContextAccessPermissions) \
    X(kCGPDFTagPropertyActualText) X(kCGPDFTagPropertyAlternativeText) X(kCGPDFTagPropertyLanguageText) \
    X(kCGPDFTagPropertyTitleText) \
    X(kCGPDFContextCreateLinearizedPDF) X(kCGPDFContextCreatePDFA) \
    X(kCGColorConversionBlackPointCompensation) X(kCGColorConversionTRCSize) X(kCGAdaptiveMaximumBitDepth)

#define DECLARE_PORT(name) extern const CFStringRef charon_host_##name;
CONSTANTS(DECLARE_PORT)
extern const char *charon_host_CGPDFTagTypeGetName(CGPDFTagType);

static NSString *text(CFStringRef value)
{
    return value ? (__bridge NSString *)value : @"(nil)";
}

static void constants(void)
{
#define CHECK_CONSTANT(name) CHECK_EQUAL(text(charon_host_##name), text(name), "constant." #name);
    CONSTANTS(CHECK_CONSTANT)
}

/* The release's enumeration has one value past iOS 26: CGPDFTagTypeArtifact (900) is iOS 27, so the port answers NULL for it. */
static void tag_names(void)
{
    int named = 0;
    for (int value = 0; value <= 1000; value++) {
        const char *host = CGPDFTagTypeGetName((CGPDFTagType)value);
        const char *port = charon_host_CGPDFTagTypeGetName((CGPDFTagType)value);
        if (value == 900) {
            charon_check(host && strcmp(host, "/Artifact") == 0, "tagType.artifact.host", @"900");
            charon_check(port == NULL, "tagType.artifact.port", @"900");
            continue;
        }
        BOOL same = host == NULL ? port == NULL : (port && strcmp(host, port) == 0);
        charon_check(same, "tagType", [NSString stringWithFormat:@"%d: host %s, port %s", value, host ?: "(null)", port ?: "(null)"]);
        if (host)
            named++;
    }
    charon_check(named == 50, "tagType.named", [NSString stringWithFormat:@"%d names, the enumeration has 50 below iOS 27", named]);
}

int main(void)
{
    @autoreleasepool {
        constants();
        tag_names();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
