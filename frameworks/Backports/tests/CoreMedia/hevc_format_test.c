#include "hevc_format_support.h"
#include "hevc_format_cases.h"

#include <stdio.h>

typedef OSStatus (*RevenantHEVCCreate)(CFAllocatorRef, size_t, const uint8_t *const *, const size_t *, int, CFDictionaryRef, CMFormatDescriptionRef *);

#if defined(REVENANT_DEVICE)
extern OSStatus revenant_backport_create(CFAllocatorRef allocator, size_t parameterSetCount, const uint8_t *const *parameterSetPointers,
                                         const size_t *parameterSetSizes, int NALUnitHeaderLength, CFDictionaryRef extensions, CMFormatDescriptionRef *formatDescriptionOut)
    __asm__("_CMVideoFormatDescriptionCreateFromHEVCParameterSets");
#define REVENANT_BACKPORT revenant_backport_create
#else
#define REVENANT_BACKPORT __revenant_fb_CMVideoFormatDescriptionCreateFromHEVCParameterSets
extern OSStatus __revenant_fb_CMVideoFormatDescriptionCreateFromHEVCParameterSets(CFAllocatorRef allocator, size_t parameterSetCount, const uint8_t *const *parameterSetPointers,
                                                                                  const size_t *parameterSetSizes, int NALUnitHeaderLength, CFDictionaryRef extensions, CMFormatDescriptionRef *formatDescriptionOut);
#endif

static int revenant_checks;
static int revenant_failures;
static int revenant_negative;

static int revenant_expected(int ok)
{
    return revenant_negative ? !ok : ok;
}

static void revenant_check(int ok, const char *name, const char *seen)
{
    revenant_checks++;
    if (ok) {
        printf("ok %s\n", name);
    } else {
        revenant_failures++;
        printf("FAIL %s: %s\n", name, seen);
    }
    fflush(stdout);
}

static OSStatus revenant_create_case(RevenantHEVCCreate create, const RevenantHEVCCase *c, CMFormatDescriptionRef *description)
{
    const uint8_t *pointers[8];
    size_t sizes[8];
    for (size_t i = 0; i < c->count; i++) {
        pointers[i] = c->sets[i].bytes;
        sizes[i] = c->sets[i].size;
    }
    CFDictionaryRef extensions = revenant_hevc_extensions(c->extensions);
    OSStatus status = create(kCFAllocatorDefault, c->count, pointers, sizes, c->nalLength, extensions, c->nullOut ? NULL : description);
    if (extensions)
        CFRelease(extensions);
    return status;
}

static void revenant_check_case(const char *label, RevenantHEVCCreate create, const RevenantHEVCCase *c)
{
    static char name[192];
    static char seen[65536];
    CMFormatDescriptionRef description = NULL;
    OSStatus status = revenant_create_case(create, c, &description);

    snprintf(name, sizeof name, "%s %s status", label, c->name);
    snprintf(seen, sizeof seen, "status %d is not %d", (int)status, (int)c->status);
    revenant_check(revenant_expected(status == c->status), name, seen);

    if (c->status != noErr) {
        snprintf(name, sizeof name, "%s %s no description on error", label, c->name);
        revenant_check(revenant_expected(description == NULL), name, "a description was returned with an error");
    } else {
        snprintf(name, sizeof name, "%s %s description", label, c->name);
        revenant_check(revenant_expected(description != NULL), name, "no description was returned");
        if (description) {
            static char buffer[65536];
            RevenantHEVCText text;
            revenant_hevc_text_init(&text, buffer, sizeof buffer);
            revenant_hevc_describe(description, &text);
            snprintf(name, sizeof name, "%s %s format", label, c->name);
            int matches = !text.overflow && strcmp(buffer, c->dump) == 0;
            snprintf(seen, sizeof seen, "%s is not %s", buffer, c->dump);
            revenant_check(revenant_expected(matches), name, seen);
            CFRelease(description);
        }
    }
}

int main(int argc, char **argv)
{
    revenant_negative = argc > 1 && strcmp(argv[1], "--negative") == 0;
    size_t count = sizeof revenant_hevc_cases / sizeof revenant_hevc_cases[0];
    for (size_t i = 0; i < count; i++) {
#if !defined(REVENANT_DEVICE)
        revenant_check_case("real", CMVideoFormatDescriptionCreateFromHEVCParameterSets, &revenant_hevc_cases[i]);
#endif
        revenant_check_case("backport", REVENANT_BACKPORT, &revenant_hevc_cases[i]);
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    fflush(stdout);
    return revenant_failures > 0 ? 1 : 0;
}
