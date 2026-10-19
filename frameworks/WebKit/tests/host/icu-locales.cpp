#include <stdio.h>
#include <string.h>
#include <unicode/ureldatefmt.h>
#include <unicode/unum.h>
#include <unicode/udat.h>
#include <unicode/ustring.h>

static int failures = 0;

static bool formatsRelativeTime(const char* locale, char* out, size_t outSize)
{
    UErrorCode status = U_ZERO_ERROR;
    URelativeDateTimeFormatter* formatter = ureldatefmt_open(locale, NULL,
        UDAT_STYLE_LONG, UDISPCTX_CAPITALIZATION_NONE, &status);
    if (U_FAILURE(status))
        return false;
    char16_t buffer[128];
    int32_t length = ureldatefmt_format(formatter, -2.0, UDAT_REL_UNIT_HOUR, buffer, 128, &status);
    ureldatefmt_close(formatter);
    if (U_FAILURE(status) || length <= 0)
        return false;
    u_austrncpy(out, buffer, (int32_t)(outSize - 1));
    out[outSize - 1] = 0;
    return true;
}

static bool formatsNumber(const char* locale, char* out, size_t outSize)
{
    UErrorCode status = U_ZERO_ERROR;
    UNumberFormat* formatter = unum_open(UNUM_DECIMAL, NULL, 0, locale, NULL, &status);
    if (U_FAILURE(status))
        return false;
    char16_t buffer[64];
    int32_t length = unum_formatDouble(formatter, 1234567.89, buffer, 64, NULL, &status);
    unum_close(formatter);
    if (U_FAILURE(status) || length <= 0)
        return false;
    u_austrncpy(out, buffer, (int32_t)(outSize - 1));
    out[outSize - 1] = 0;
    return true;
}

static void test(const char* locale)
{
    char relative[160] = { 0 };
    char number[80] = { 0 };
    bool relativeOk = formatsRelativeTime(locale, relative, sizeof(relative));
    bool numberOk = formatsNumber(locale, number, sizeof(number));

    bool looksEnglish = relativeOk && strstr(relative, "hours ago");
    bool wrongLanguage = looksEnglish && strcmp(locale, "en");

    if (!relativeOk || !numberOk || wrongLanguage) {
        printf("%-6s FAIL  rel=%-24s num=%s%s\n", locale,
            relativeOk ? relative : "(none)", numberOk ? number : "(none)",
            wrongLanguage ? "  [fell back to English]" : "");
        failures++;
        return;
    }
    printf("%-6s ok    rel=%-24s num=%s\n", locale, relative, number);
}

int main(void)
{
    const char* locales[] = { "en", "ru", "uk", "de", "fr", "es", "pt", "it", "pl", "nl",
        "tr", "ar", "he", "fa", "zh", "ja", "ko", "hi", "th", "vi", "id", "cs", "sk", "hu",
        "ro", "bg", "sr", "hr", "el", "sv", "da", "fi", "ka", "hy", "az", "kk", "be" };
    for (unsigned i = 0; i < sizeof(locales) / sizeof(*locales); i++)
        test(locales[i]);
    printf("\n%s: %d failure(s) of %zu locales\n", failures ? "FAILED" : "PASSED",
        failures, sizeof(locales) / sizeof(*locales));
    return failures ? 1 : 0;
}
