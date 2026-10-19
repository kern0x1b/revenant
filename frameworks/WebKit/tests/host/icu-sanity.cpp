#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/ucal.h>
#include <unicode/uenum.h>
#include <unicode/ures.h>
#include <unicode/ucnv.h>
#include <unicode/uchar.h>

static int failures = 0;

static char knownMissing[32][64];
static int knownMissingCount = 0;

static bool isKnownMissing(const char* name)
{
    for (int i = 0; i < knownMissingCount; i++) {
        if (!strcmp(knownMissing[i], name))
            return true;
    }
    return false;
}

static int readList(const char* path, void (*visit)(const char*))
{
    FILE* file = fopen(path, "r");
    if (!file)
        return -1;
    char line[256];
    while (fgets(line, sizeof(line), file)) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] && line[0] != '#')
            visit(line);
    }
    fclose(file);
    return 0;
}

static void rememberMissing(const char* name)
{
    if (knownMissingCount < 32) {
        strncpy(knownMissing[knownMissingCount], name, 63);
        knownMissing[knownMissingCount][63] = 0;
        knownMissingCount++;
    }
}

static void report(const char* what, bool ok, const char* detail)
{
    printf("  %-26s %s%s%s\n", what, ok ? "ok" : "FAIL",
        detail && *detail ? "  " : "", detail ? detail : "");
    if (!ok)
        failures++;
}

static void checkBundle(const char* name)
{
    UErrorCode status = U_ZERO_ERROR;
    UResourceBundle* bundle = ures_openDirect(NULL, name, &status);
    report(name, U_SUCCESS(status), u_errorName(status));
    if (bundle)
        ures_close(bundle);
}

static void checkConverter(const char* name)
{
    UErrorCode status = U_ZERO_ERROR;
    UConverter* converter = ucnv_open(name, &status);
    if (status == U_AMBIGUOUS_ALIAS_WARNING)
        status = U_ZERO_ERROR;
    bool opened = U_SUCCESS(status) && converter;
    if (converter)
        ucnv_close(converter);
    if (!opened && isKnownMissing(name)) {
        printf("  %-26s absent upstream, see known-missing-encodings.txt\n", name);
        return;
    }
    report(name, opened, u_errorName(status));
}

static void checkTimeZones(void)
{
    UErrorCode status = U_ZERO_ERROR;
    UEnumeration* zones = ucal_openTimeZoneIDEnumeration(UCAL_ZONE_TYPE_CANONICAL, NULL, NULL, &status);
    if (U_FAILURE(status) || !zones) {
        report("canonical zone enum", false, u_errorName(status));
        return;
    }
    int32_t count = uenum_count(zones, &status);
    uenum_close(zones);
    char detail[64];
    snprintf(detail, sizeof(detail), "%d zones", count);
    report("canonical zone enum", count >= 400, detail);
}

int main(int argc, char** argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s <required-encodings.txt>\n", argv[0]);
        return 2;
    }

    if (argc > 2 && readList(argv[2], rememberMissing) < 0) {
        fprintf(stderr, "cannot read %s\n", argv[2]);
        return 2;
    }

    printf("resource bundles\n");
    UErrorCode status = U_ZERO_ERROR;
    UResourceBundle* root = ures_open(NULL, "root", &status);
    report("root", U_SUCCESS(status), u_errorName(status));
    if (root)
        ures_close(root);
    checkBundle("zoneinfo64");
    checkBundle("timezoneTypes");
    checkBundle("metaZones");
    checkBundle("supplementalData");

    printf("time zones\n");
    checkTimeZones();

    printf("encodings WebKit delegates to ICU\n");
    if (readList(argv[1], checkConverter) < 0) {
        fprintf(stderr, "cannot read %s\n", argv[1]);
        return 2;
    }

    printf("character properties\n");
    report("u_charType('A')", u_charType('A') == U_UPPERCASE_LETTER, "");
    report("u_charType(U+0416)", u_charType(0x0416) == U_UPPERCASE_LETTER, "");

    printf("\nicu-sanity: %s (%d failure%s)\n", failures ? "FAILED" : "PASSED",
        failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}
