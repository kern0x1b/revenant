#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

extern CFArrayRef CVPixelFormatDescriptionGetPixelFormatTypes(void);

extern CFDictionaryRef revenantHost_CVBufferCopyAttachments(CVBufferRef buffer, CVAttachmentMode mode);
extern CFTypeRef revenantHost_CVBufferCopyAttachment(CVBufferRef buffer, CFStringRef key, CVAttachmentMode *mode);
extern Boolean revenantHost_CVBufferHasAttachment(CVBufferRef buffer, CFStringRef key);
extern CFDictionaryRef revenantHost_CVPixelBufferCopyCreationAttributes(CVPixelBufferRef pixelBuffer);
extern CGColorSpaceRef revenantHost_CVImageBufferCreateColorSpaceFromAttachments(CFDictionaryRef attachments);
extern Boolean revenantHost_CVIsCompressedPixelFormatAvailable(OSType pixelFormatType);

static int checks = 0, same = 0, different = 0;

static void line(const char *what, const char *host, const char *port, int agrees)
{
    checks++;
    if (agrees) same++; else different++;
    printf("%-4s %-44s host=%-32s port=%s\n", agrees ? "ok" : "BAD", what, host, port);
}

static void cstr(CFStringRef s, char *out, size_t n)
{
    if (!s) { snprintf(out, n, "(null)"); return; }
    if (!CFStringGetCString(s, out, (CFIndex)n, kCFStringEncodingUTF8)) snprintf(out, n, "(unprintable)");
}

enum { kMaxKeys = 64 };
static void keys_of(CFDictionaryRef d, char *out, size_t n)
{
    if (!d) { snprintf(out, n, "(null)"); return; }
    CFIndex count = CFDictionaryGetCount(d);
    if (count > kMaxKeys) { snprintf(out, n, "(more than %d keys, not compared)", kMaxKeys); return; }
    const void *keys[kMaxKeys], *values[kMaxKeys];
    CFDictionaryGetKeysAndValues(d, keys, values);
    char one[128];
    out[0] = '\0';
    for (CFIndex i = 0; i < count; i++) {
        cstr((CFStringRef)keys[i], one, sizeof(one));
        strlcat(out, i ? "," : "", n);
        strlcat(out, one, n);
    }
}

static int same_text(const char *a, const char *b) { return strcmp(a, b) == 0; }

int main(void)
{
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, 64, 32, kCVPixelFormatType_32BGRA,
                            (CFDictionaryRef)NULL, &buffer) != kCVReturnSuccess || !buffer) {
        printf("BAD the host made no pixel buffer, so every case below would be vacuous\n");
        return 2;
    }

    CFStringRef primaries = CFSTR("ITU_R_709");
    CFStringRef transfer = CFSTR("IEC_sRGB");
    CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, primaries, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, transfer, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(buffer, kCVPixelBufferPixelFormatTypeKey, CFSTR("made-up-format"),
                          kCVAttachmentMode_ShouldPropagate);
    CFStringRef absentKey = CFSTR("NoSuchAttachmentKey");

    char hostKeys[512], portKeys[512], h[160], p[160];

    keys_of(CVBufferCopyAttachments(buffer, kCVAttachmentMode_ShouldPropagate), hostKeys, sizeof(hostKeys));
#ifdef HAVE_PORT
    keys_of(revenantHost_CVBufferCopyAttachments(buffer, kCVAttachmentMode_ShouldPropagate), portKeys, sizeof(portKeys));
    line("CVBufferCopyAttachments keys", hostKeys, portKeys, same_text(hostKeys, portKeys));
#else
    strlcpy(portKeys, hostKeys, sizeof(portKeys));
    printf("host CVBufferCopyAttachments keys: %s\n", hostKeys);
#endif
    keys_of(CVBufferCopyAttachments(buffer, kCVAttachmentMode_ShouldNotPropagate), h, sizeof(h));
    printf("     CVBufferCopyAttachments mode ShouldNotPropagate: %s\n", h);

    CVAttachmentMode hostMode = kCVAttachmentMode_ShouldNotPropagate;
    CVAttachmentMode portMode = kCVAttachmentMode_ShouldNotPropagate;
    CFTypeRef hostOne = CVBufferCopyAttachment(buffer, kCVImageBufferColorPrimariesKey, &hostMode);
    cstr((CFStringRef)hostOne, h, sizeof(h));
#ifdef HAVE_PORT
    CFTypeRef portOne = revenantHost_CVBufferCopyAttachment(buffer, kCVImageBufferColorPrimariesKey, &portMode);
    cstr((CFStringRef)portOne, p, sizeof(p));
    line("CVBufferCopyAttachment present", h, p, same_text(h, p));
    checks++;
    if (hostMode == portMode) same++; else { different++;
        printf("BAD %-44s host mode=%s port mode=%s\n", "CVBufferCopyAttachment mode out",
               hostMode ? "set" : "null", portMode ? "set" : "null"); }
#else
    strlcpy(p, h, sizeof(p));
    printf("host CVBufferCopyAttachment present: %s (mode %s)\n", h, hostMode ? "set" : "null");
#endif
    cstr((CFStringRef)CVBufferCopyAttachment(buffer, absentKey, NULL), h, sizeof(h));
#ifdef HAVE_PORT
    cstr((CFStringRef)revenantHost_CVBufferCopyAttachment(buffer, absentKey, NULL), p, sizeof(p));
    line("CVBufferCopyAttachment absent key", h, p, same_text(h, p));
#else
    strlcpy(p, h, sizeof(p));
    printf("host CVBufferCopyAttachment absent: %s\n", h);
#endif

    {
        Boolean hostHas = CVBufferHasAttachment(buffer, kCVImageBufferColorPrimariesKey);
        Boolean hostHasNot = CVBufferHasAttachment(buffer, absentKey);
#ifdef HAVE_PORT
        Boolean portHas = revenantHost_CVBufferHasAttachment(buffer, kCVImageBufferColorPrimariesKey);
        Boolean portHasNot = revenantHost_CVBufferHasAttachment(buffer, absentKey);
        line("CVBufferHasAttachment present", hostHas ? "true" : "false", portHas ? "true" : "false",
             hostHas == portHas);
        line("CVBufferHasAttachment absent", hostHasNot ? "true" : "false", portHasNot ? "true" : "false",
             hostHasNot == portHasNot);
#else
        printf("host CVBufferHasAttachment present=%s absent=%s\n",
               hostHas ? "true" : "false", hostHasNot ? "true" : "false");
#endif
    }

    keys_of(CVPixelBufferCopyCreationAttributes(buffer), hostKeys, sizeof(hostKeys));
#ifdef HAVE_PORT
    keys_of(revenantHost_CVPixelBufferCopyCreationAttributes(buffer), portKeys, sizeof(portKeys));
    line("CVPixelBufferCopyCreationAttributes keys", hostKeys, portKeys, same_text(hostKeys, portKeys));
#else
    printf("host CVPixelBufferCopyCreationAttributes keys: %s\n", hostKeys);
#endif

    {
        CGColorSpaceRef profile = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CFDataRef icc = profile ? CGColorSpaceCopyICCData(profile) : NULL;
        const void *k1[] = { kCVImageBufferICCProfileKey };
        const void *v1[] = { icc };
        CFDictionaryRef d1 = CFDictionaryCreate(kCFAllocatorDefault, k1, v1, 1, NULL, NULL);
        CGColorSpaceRef h1 = CVImageBufferCreateColorSpaceFromAttachments(d1);
        cstr(h1 ? CGColorSpaceGetName(h1) : NULL, h, sizeof(h));
#ifdef HAVE_PORT
        CGColorSpaceRef p1 = revenantHost_CVImageBufferCreateColorSpaceFromAttachments(d1);
        cstr(p1 ? CGColorSpaceGetName(p1) : NULL, p, sizeof(p));
        line("CreateColorSpaceFromAttachments ICC", h, p, same_text(h, p));
#else
        printf("host CreateColorSpaceFromAttachments ICC: %s\n", h);
#endif
        if (d1) CFRelease(d1);
        if (icc) CFRelease(icc);

        static const char *const kTriples[][3] = {
            { "ITU_R_709", "ITU_R_709", "ITU_R_709" },
            { "ITU_R_2020", "ITU_R_2020", "ITU_R_2020" },
            { "DCI_P3", "DCI_P3", "DCI_P3" },
            { "P3_D65", "ITU_R_709", "ITU_R_709" },
            { "ITU_R_601", "SMPTE_ST_428_1", "SMPTE_ST_428_1" },
            { "nonsense", "nonsense", "nonsense" },
            { "ITU_R_709", NULL, NULL },
        };
        enum { kTripleCount = sizeof(kTriples) / sizeof(kTriples[0]) };
        for (int i = 0; i < kTripleCount; i++) {            const void *keys[3] = { kCVImageBufferColorPrimariesKey, kCVImageBufferTransferFunctionKey,
                                    kCVImageBufferYCbCrMatrixKey };
            const void *vals[3];
            int n = 0;
            for (int j = 0; j < 3; j++) {
                if (!kTriples[i][j]) continue;
                keys[n] = keys[j];
                vals[n] = CFStringCreateWithCString(kCFAllocatorDefault, kTriples[i][j], kCFStringEncodingUTF8);
                n++;
            }
            CFDictionaryRef d = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, n, NULL, NULL);
            char label[128];
            snprintf(label, sizeof(label), "CreateColorSpace %s/%s/%s", kTriples[i][0],
                     kTriples[i][1] ? kTriples[i][1] : "-", kTriples[i][2] ? kTriples[i][2] : "-");
            CGColorSpaceRef hv = CVImageBufferCreateColorSpaceFromAttachments(d);
            cstr(hv ? CGColorSpaceGetName(hv) : NULL, h, sizeof(h));
#ifdef HAVE_PORT
            CGColorSpaceRef pv = revenantHost_CVImageBufferCreateColorSpaceFromAttachments(d);
            cstr(pv ? CGColorSpaceGetName(pv) : NULL, p, sizeof(p));
            line(label, h, p, same_text(h, p));
#else
            printf("host %-44s %s\n", label, h);
#endif
            if (d) CFRelease(d);
        }

        CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, NULL, NULL);
        CGColorSpaceRef he = CVImageBufferCreateColorSpaceFromAttachments(empty);
        cstr(he ? CGColorSpaceGetName(he) : NULL, h, sizeof(h));
#ifdef HAVE_PORT
        CGColorSpaceRef pe = revenantHost_CVImageBufferCreateColorSpaceFromAttachments(empty);
        cstr(pe ? CGColorSpaceGetName(pe) : NULL, p, sizeof(p));
        line("CreateColorSpace empty dictionary", h, p, same_text(h, p));
#else
        printf("host CreateColorSpace empty dictionary: %s\n", h);
#endif
        if (empty) CFRelease(empty);

        {
            int g = 0;
            CFNumberRef gamma = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &g);
            CFStringRef p709 = CFStringCreateWithCString(kCFAllocatorDefault, "ITU_R_709", kCFStringEncodingUTF8);
            CFStringRef t709 = CFStringCreateWithCString(kCFAllocatorDefault, "ITU_R_709", kCFStringEncodingUTF8);
            const void *keys[] = { kCVImageBufferColorPrimariesKey, kCVImageBufferTransferFunctionKey,
                                   kCVImageBufferYCbCrMatrixKey, kCVImageBufferGammaLevelKey };
            const void *vals[] = { p709, t709, p709, gamma };
            CFDictionaryRef d = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 4, NULL, NULL);
            CGColorSpaceRef hv = CVImageBufferCreateColorSpaceFromAttachments(d);
            cstr(hv ? CGColorSpaceGetName(hv) : NULL, h, sizeof(h));
#ifdef HAVE_PORT
            CGColorSpaceRef pv = revenantHost_CVImageBufferCreateColorSpaceFromAttachments(d);
            cstr(pv ? CGColorSpaceGetName(pv) : NULL, p, sizeof(p));
            line("CreateColorSpace triple plus gamma", h, p, same_text(h, p));
#else
            printf("host CreateColorSpace triple plus gamma: %s\n", h);
#endif
            if (d) CFRelease(d);
            if (gamma) CFRelease(gamma);
            if (p709) CFRelease(p709);
            if (t709) CFRelease(t709);
        }
        {
            CFDataRef icc2 = CGColorSpaceCopyICCData(CGColorSpaceCreateWithName(kCGColorSpaceSRGB));
            CFStringRef p709 = CFStringCreateWithCString(kCFAllocatorDefault, "ITU_R_709", kCFStringEncodingUTF8);
            const void *keys[] = { kCVImageBufferICCProfileKey, kCVImageBufferColorPrimariesKey,
                                   kCVImageBufferTransferFunctionKey, kCVImageBufferYCbCrMatrixKey };
            const void *vals[] = { icc2, p709, p709, p709 };
            CFDictionaryRef d = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 4, NULL, NULL);
            CGColorSpaceRef hv = CVImageBufferCreateColorSpaceFromAttachments(d);
            cstr(hv ? CGColorSpaceGetName(hv) : NULL, h, sizeof(h));
#ifdef HAVE_PORT
            CGColorSpaceRef pv = revenantHost_CVImageBufferCreateColorSpaceFromAttachments(d);
            cstr(pv ? CGColorSpaceGetName(pv) : NULL, p, sizeof(p));
            line("CreateColorSpace ICC and triple", h, p, same_text(h, p));
#else
            printf("host CreateColorSpace ICC and triple: %s\n", h);
#endif
            if (d) CFRelease(d);
            if (icc2) CFRelease(icc2);
            if (p709) CFRelease(p709);
        }
    }

    {
        static const OSType kAsked[] = {
            kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_32ARGB, kCVPixelFormatType_OneComponent8,
            'avc1', 'hvc1', 'hev1', 'ap4h', 'apcn', 'apcs', 'ap4a', 'apco', 'apch', 'apcv',
            'ap2n', 'ap2v', 'dvh ', 'jpe ', 'png ', 'rle ', 'mjpg', 'raw ', 'bp64', 'bp16',
            '2vuy', 'v308', 'v410', 'r210', '4444', 'zzzz',
        };
        enum { kAskedCount = sizeof(kAsked) / sizeof(kAsked[0]) };
        int hostYes = 0, ruleMatches = 0, mismatches = 0;
        for (int i = 0; i < kAskedCount; i++) {
            OSType fmt = kAsked[i];
            Boolean host = CVIsCompressedPixelFormatAvailable(fmt);
            CFDictionaryRef description = CVPixelFormatDescriptionCreateWithPixelFormatType(NULL, fmt);
            CFTypeRef codec = description ? CFDictionaryGetValue(description, kCVPixelFormatCodecType) : NULL;
            Boolean hasDescription = description != NULL;
            Boolean rule = hasDescription && codec != NULL;
            char label[64];
            snprintf(label, sizeof(label), "compressed '%c%c%c%c'",
                     (char)(fmt >> 24), (char)(fmt >> 16), (char)(fmt >> 8), (char)fmt);
            if (host) hostYes++;
            if ((host != 0) == rule) ruleMatches++;
            else { mismatches++;
                printf("     rule disagrees: %s host=%s codec=%s\n", label,
                       host ? "true" : "false", codec ? "yes" : "no"); }
#ifdef HAVE_PORT
            Boolean port = revenantHost_CVIsCompressedPixelFormatAvailable(fmt);
            line(label, host ? "true" : "false", port ? "true" : "false", host == port);
#else
            printf("host %-44s %s (codec=%s, rule=%s)\n", label, host ? "true" : "false",
                   codec ? "yes" : "no", rule ? "true" : "false");
#endif
            if (description) CFRelease(description);
        }
        printf("     compressed: asked=%d host_yes=%d rule_matches_host=%d rule_disagreements=%d\n",
               kAskedCount, hostYes, ruleMatches, mismatches);

        {
            CFArrayRef all = CVPixelFormatDescriptionGetPixelFormatTypes();
            CFIndex total = all ? CFArrayGetCount(all) : 0;
            int yes = 0, no = 0, agree = 0, agreeCodec = 0, agreeAmp = 0, disagree = 0;
            int withCodec = 0, noCodec = 0, unknown = 0, ampDisagree = 0;
            for (CFIndex i = 0; i < total; i++) {
                SInt32 code = 0;
                CFNumberGetValue((CFNumberRef)CFArrayGetValueAtIndex(all, i), kCFNumberSInt32Type, &code);
                OSType fmt = (OSType)code;
                Boolean host = CVIsCompressedPixelFormatAvailable(fmt);
                CFDictionaryRef d = CVPixelFormatDescriptionCreateWithPixelFormatType(NULL, fmt);
                if (!d) { unknown++; continue; }
                CFTypeRef codec = CFDictionaryGetValue(d, kCVPixelFormatCodecType);
                if (codec) withCodec++; else noCodec++;
                Boolean ruleCodec = codec != NULL;
                Boolean ruleAmp = ((fmt >> 24) & 0xff) == '&';
                if (host) yes++; else no++;
                if ((host != 0) == ruleCodec) agreeCodec++;
                if ((host != 0) == ruleAmp) agreeAmp++;
                else if (ampDisagree < 6)
                    printf("     '&' rule disagrees: '%c%c%c%c' host=%s\n",
                           (char)(fmt >> 24), (char)(fmt >> 16), (char)(fmt >> 8), (char)fmt,
                           host ? "true" : "false"), ampDisagree++;
                if ((host != 0) == ruleCodec) agree++; else {
                    disagree++;
                    if (disagree <= 20)
                        printf("     registered disagreement: '%c%c%c%c' host=%s codec=%s amp=%s\n",
                               (char)(fmt >> 24), (char)(fmt >> 16), (char)(fmt >> 8), (char)fmt,
                               host ? "true" : "false", codec ? "yes" : "no", ruleAmp ? "yes" : "no");
                }
                CFRelease(d);
            }
            printf("     registered: total=%ld no_description=%d host_yes=%d host_no=%d "
                   "descriptions_with_codec=%d without=%d\n", (long)total, unknown, yes, no,
                   withCodec, noCodec);
            printf("     rule by codec type: agrees=%d of %ld, disagrees=%d\n", agreeCodec, (long)total, total - agreeCodec);
            printf("     rule by '&' FourCC:   agrees=%d of %ld, disagrees=%d\n", agreeAmp, (long)total, total - agreeAmp);
        }
    }

    printf("functions: checks=%d same=%d different=%d\n", checks, same, different);
    return different == 0 ? 0 : 1;
}
