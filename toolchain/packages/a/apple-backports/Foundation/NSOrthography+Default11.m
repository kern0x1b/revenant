#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <string.h>

typedef void *CharonULocale;
typedef struct CharonUErrorCode { int32_t number; } CharonUErrorCode;

typedef CharonULocale (*CharonULocForLanguageTag)(const char *languageTag, int32_t length, CharonULocale available, CharonULocale *result);
typedef CharonULocale (*CharonULocAddLikelySubtags)(CharonULocale loc, char *subtags, int32_t capacity, CharonULocale *result);
typedef const char *(*CharonULocGetName)(CharonULocale loc, const char *key, int32_t keyLength, char *name, int32_t nameCapacity, CharonUErrorCode *err);

static CharonULocAddLikelySubtags charon_icu_add_likely_subtags;
static CharonULocGetName charon_icu_locale_name;

static void charon_load_icu(void)
{
    static dispatch_once_t once;
    static CharonULocAddLikelySubtags addLikelySubtags;
    static CharonULocGetName getName;
    dispatch_once(&once, ^{
        void *library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        addLikelySubtags = (CharonULocAddLikelySubtags)dlsym(library, "uloc_addLikelySubtags");
        getName = (CharonULocGetName)dlsym(library, "uloc_getName");
    });
    charon_icu_add_likely_subtags = addLikelySubtags;
    charon_icu_locale_name = getName;
}

static NSString *charon_likely_script(NSString *language)
{
    charon_load_icu();
    if (!charon_icu_add_likely_subtags || !charon_icu_locale_name || !language.length)
        return nil;
    const char *tag = language.UTF8String;
    char subtags[128];
    memset(subtags, 0, sizeof(subtags));
    CharonUErrorCode error = { 0 };
    charon_icu_add_likely_subtags((CharonULocale)tag, subtags, (int32_t)sizeof(subtags) - 1, NULL);
    if (error.number > 0 || !subtags[0])
        return nil;
    char script[32];
    memset(script, 0, sizeof(script));
    CharonUErrorCode nameError = { 0 };
    charon_icu_locale_name((CharonULocale)subtags, "script", 6, script, (int32_t)sizeof(script) - 1, &nameError);
    if (nameError.number > 0 || !script[0])
        return nil;
    return @(script);
}

@implementation NSOrthography (CharonDefault)

+ (instancetype)defaultOrthographyForLanguage:(NSString *)language
{
    if (!language.length)
        return nil;
    NSString *script = charon_likely_script(language);
    if (!script)
        script = language;
    return [self orthographyWithDominantScript:script
                                   languageMap:@{language: @[script]}];
}

@end
