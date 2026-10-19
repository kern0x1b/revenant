#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <string.h>

/* The default orthography of a language, iOS 11.0.

   An orthography is a language's dominant script and the map of the languages that share it, and
   "the default orthography for a language" is that language's *likely* script -- the one CLDR's
   likely-subtags data names for it, which is how a bare language code becomes a script.

   The release already has that data and already computes with it: `uloc_addLikelySubtags` is exported
   by /usr/lib/libicucore.A.dylib in the 6.1.3 armv7 cache (measured with tools/corpus/
   cache-value.lua, which also carries the control that `uloc_getDefault` and `uloc_canonicalize` are
   there). So the port asks the release's own ICU rather than carrying a table of its own, which is
   the whole of what the modern API added: the call and the parse of its answer.

   "de" gives de_Latn_DE, so the script is the second field; a language the ICU data has no likely
   subtags for answers a null error code, and then the release's own
   +orthographyWithDominantScript:languageMap: is asked with the language itself as the script, which
   is what an unknown language is: its own name standing for a script. */

typedef void *CharonULocale;
typedef struct CharonUErrorCode { int32_t number; } CharonUErrorCode;

typedef CharonULocale (*CharonULocForLanguageTag)(const char *languageTag, int32_t length, CharonULocale available, CharonULocale *result);
typedef CharonULocale (*CharonULocAddLikelySubtags)(CharonULocale loc, char *subtags, int32_t capacity, CharonULocale *result);
typedef const char *(*CharonULocGetName)(CharonULocale loc, const char *key, int32_t keyLength, char *name, int32_t nameCapacity, CharonUErrorCode *err);

/* The release's own ICU entry points, filled in once. Declared here because the loader below
   assigns them and the parse reads them. */
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

/* The script of a language, the way CLDR's likely subtags name it, or nil when the release's ICU has
   no likely subtags for it. */
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
        script = language; /* nothing to stand for the language but its own name */
    return [self orthographyWithDominantScript:script
                                   languageMap:@{language: @[script]}];
}

@end
