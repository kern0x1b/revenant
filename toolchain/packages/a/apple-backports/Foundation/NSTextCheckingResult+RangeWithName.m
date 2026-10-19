#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>

typedef void RevenantICURegex;

enum {
    RevenantICUUnixLines = 1,
    RevenantICUCaseInsensitive = 2,
    RevenantICUComments = 4,
    RevenantICUMultiline = 8,
    RevenantICULiteral = 16,
    RevenantICUDotAll = 32,
    RevenantICUWordBoundaries = 256
};

typedef struct {
    RevenantICURegex *(*open)(const unichar *pattern, int32_t length, uint32_t flags, void *parseError, int32_t *status);
    void (*close)(RevenantICURegex *regex);
    int32_t (*groupNumberFromName)(RevenantICURegex *regex, const unichar *name, int32_t length, int32_t *status);
} RevenantICURegexFunctions;

static const RevenantICURegexFunctions *revenant_icu_regex(void)
{
    static RevenantICURegexFunctions functions;
    static BOOL loaded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        functions.open = dlsym(library, "uregex_open");
        functions.close = dlsym(library, "uregex_close");
        functions.groupNumberFromName = dlsym(library, "uregex_groupNumberFromName");
        loaded = functions.open && functions.close && functions.groupNumberFromName;
    });
    return loaded ? &functions : NULL;
}

static uint32_t revenant_icu_flags(NSRegularExpressionOptions options)
{
    uint32_t flags = 0;
    if (options & NSRegularExpressionCaseInsensitive)
        flags |= RevenantICUCaseInsensitive;
    if (options & NSRegularExpressionAllowCommentsAndWhitespace)
        flags |= RevenantICUComments;
    if (options & NSRegularExpressionIgnoreMetacharacters)
        flags |= RevenantICULiteral;
    if (options & NSRegularExpressionDotMatchesLineSeparators)
        flags |= RevenantICUDotAll;
    if (options & NSRegularExpressionAnchorsMatchLines)
        flags |= RevenantICUMultiline;
    if (options & NSRegularExpressionUseUnixLineSeparators)
        flags |= RevenantICUUnixLines;
    if (options & NSRegularExpressionUseUnicodeWordBoundaries)
        flags |= RevenantICUWordBoundaries;
    return flags;
}

static NSInteger revenant_group_number(NSRegularExpression *expression, NSString *name, const RevenantICURegexFunctions *icu)
{
    NSString *pattern = expression.pattern;
    NSUInteger length = pattern.length;
    unichar *characters = malloc((length ? length : 1) * sizeof(unichar));
    [pattern getCharacters:characters range:NSMakeRange(0, length)];
    int32_t status = 0;
    RevenantICURegex *regex = icu->open(characters, (int32_t)length, revenant_icu_flags(expression.options), NULL, &status);
    free(characters);
    if (status > 0) {
        if (regex)
            icu->close(regex);
        return NSNotFound;
    }
    NSUInteger nameLength = name.length;
    unichar *nameCharacters = malloc((nameLength ? nameLength : 1) * sizeof(unichar));
    [name getCharacters:nameCharacters range:NSMakeRange(0, nameLength)];
    int32_t number = icu->groupNumberFromName(regex, nameCharacters, (int32_t)nameLength, &status);
    free(nameCharacters);
    icu->close(regex);
    return status > 0 ? NSNotFound : number;
}

static char RevenantGroupNumbersKey;

@implementation NSTextCheckingResult (RevenantNamedCaptures)

- (NSRange)rangeWithName:(NSString *)name
{
    NSRegularExpression *expression = self.regularExpression;
    const RevenantICURegexFunctions *icu = revenant_icu_regex();
    if (!expression || !name || !icu)
        return NSMakeRange(NSNotFound, 0);
    NSNumber *number;
    @synchronized (expression) {
        NSMutableDictionary *numbers = objc_getAssociatedObject(expression, &RevenantGroupNumbersKey);
        if (!numbers) {
            numbers = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(expression, &RevenantGroupNumbersKey, numbers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        number = numbers[name];
        if (!number) {
            number = @(revenant_group_number(expression, name, icu));
            numbers[[name copy]] = number;
        }
    }
    NSInteger index = number.integerValue;
    if (index == NSNotFound || (NSUInteger)index >= self.numberOfRanges)
        return NSMakeRange(NSNotFound, 0);
    return [self rangeAtIndex:index];
}

@end
