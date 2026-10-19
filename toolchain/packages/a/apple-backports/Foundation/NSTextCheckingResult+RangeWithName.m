#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>

typedef void CharonICURegex;

enum {
    CharonICUUnixLines = 1,
    CharonICUCaseInsensitive = 2,
    CharonICUComments = 4,
    CharonICUMultiline = 8,
    CharonICULiteral = 16,
    CharonICUDotAll = 32,
    CharonICUWordBoundaries = 256
};

typedef struct {
    CharonICURegex *(*open)(const unichar *pattern, int32_t length, uint32_t flags, void *parseError, int32_t *status);
    void (*close)(CharonICURegex *regex);
    int32_t (*groupNumberFromName)(CharonICURegex *regex, const unichar *name, int32_t length, int32_t *status);
} CharonICURegexFunctions;

static const CharonICURegexFunctions *charon_icu_regex(void)
{
    static CharonICURegexFunctions functions;
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

static uint32_t charon_icu_flags(NSRegularExpressionOptions options)
{
    uint32_t flags = 0;
    if (options & NSRegularExpressionCaseInsensitive)
        flags |= CharonICUCaseInsensitive;
    if (options & NSRegularExpressionAllowCommentsAndWhitespace)
        flags |= CharonICUComments;
    if (options & NSRegularExpressionIgnoreMetacharacters)
        flags |= CharonICULiteral;
    if (options & NSRegularExpressionDotMatchesLineSeparators)
        flags |= CharonICUDotAll;
    if (options & NSRegularExpressionAnchorsMatchLines)
        flags |= CharonICUMultiline;
    if (options & NSRegularExpressionUseUnixLineSeparators)
        flags |= CharonICUUnixLines;
    if (options & NSRegularExpressionUseUnicodeWordBoundaries)
        flags |= CharonICUWordBoundaries;
    return flags;
}

static NSInteger charon_group_number(NSRegularExpression *expression, NSString *name, const CharonICURegexFunctions *icu)
{
    NSString *pattern = expression.pattern;
    NSUInteger length = pattern.length;
    unichar *characters = malloc((length ? length : 1) * sizeof(unichar));
    [pattern getCharacters:characters range:NSMakeRange(0, length)];
    int32_t status = 0;
    CharonICURegex *regex = icu->open(characters, (int32_t)length, charon_icu_flags(expression.options), NULL, &status);
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

static char CharonGroupNumbersKey;

@implementation NSTextCheckingResult (CharonNamedCaptures)

- (NSRange)rangeWithName:(NSString *)name
{
    NSRegularExpression *expression = self.regularExpression;
    const CharonICURegexFunctions *icu = charon_icu_regex();
    if (!expression || !name || !icu)
        return NSMakeRange(NSNotFound, 0);
    NSNumber *number;
    @synchronized (expression) {
        NSMutableDictionary *numbers = objc_getAssociatedObject(expression, &CharonGroupNumbersKey);
        if (!numbers) {
            numbers = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(expression, &CharonGroupNumbersKey, numbers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        number = numbers[name];
        if (!number) {
            number = @(charon_group_number(expression, name, icu));
            numbers[[name copy]] = number;
        }
    }
    NSInteger index = number.integerValue;
    if (index == NSNotFound || (NSUInteger)index >= self.numberOfRanges)
        return NSMakeRange(NSNotFound, 0);
    return [self rangeAtIndex:index];
}

@end
