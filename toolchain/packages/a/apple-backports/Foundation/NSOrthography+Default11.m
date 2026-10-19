#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <string.h>

typedef void *RevenantULocale;
typedef struct RevenantUErrorCode { int32_t number; } RevenantUErrorCode;

typedef RevenantULocale (*RevenantULocForLanguageTag)(const char *languageTag, int32_t length, RevenantULocale available, RevenantULocale *result);
typedef RevenantULocale (*RevenantULocAddLikelySubtags)(RevenantULocale loc, char *subtags, int32_t capacity, RevenantULocale *result);
typedef const char *(*RevenantULocGetName)(RevenantULocale loc, const char *key, int32_t keyLength, char *name, int32_t nameCapacity, RevenantUErrorCode *err);

static RevenantULocAddLikelySubtags revenant_icu_add_likely_subtags;
static RevenantULocGetName revenant_icu_locale_name;

static void revenant_load_icu(void)
{
    static dispatch_once_t once;
    static RevenantULocAddLikelySubtags addLikelySubtags;
    static RevenantULocGetName getName;
    dispatch_once(&once, ^{
        void *library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        addLikelySubtags = (RevenantULocAddLikelySubtags)dlsym(library, "uloc_addLikelySubtags");
        getName = (RevenantULocGetName)dlsym(library, "uloc_getName");
    });
    revenant_icu_add_likely_subtags = addLikelySubtags;
    revenant_icu_locale_name = getName;
}

static NSString *revenant_likely_script(NSString *language)
{
    revenant_load_icu();
    if (!revenant_icu_add_likely_subtags || !revenant_icu_locale_name || !language.length)
        return nil;
    const char *tag = language.UTF8String;
    char subtags[128];
    memset(subtags, 0, sizeof(subtags));
    RevenantUErrorCode error = { 0 };
    revenant_icu_add_likely_subtags((RevenantULocale)tag, subtags, (int32_t)sizeof(subtags) - 1, NULL);
    if (error.number > 0 || !subtags[0])
        return nil;
    char script[32];
    memset(script, 0, sizeof(script));
    RevenantUErrorCode nameError = { 0 };
    revenant_icu_locale_name((RevenantULocale)subtags, "script", 6, script, (int32_t)sizeof(script) - 1, &nameError);
    if (nameError.number > 0 || !script[0])
        return nil;
    return @(script);
}

@implementation NSOrthography (RevenantDefault)

+ (instancetype)defaultOrthographyForLanguage:(NSString *)language
{
    if (!language.length)
        return nil;
    NSString *script = revenant_likely_script(language);
    if (!script)
        script = language;
    return [self orthographyWithDominantScript:script
                                   languageMap:@{language: @[script]}];
}

@end
