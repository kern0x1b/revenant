#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef struct {
    const char *language;
    unsigned mask;
} RevenantContextRow;

static const RevenantContextRow revenant_date_rows[] = {
    {"agq", 0xff0000},
    {"ast", 0xdf0000},
    {"az", 0x7d0000},
    {"ba", 0xff0000},
    {"bas", 0xeb0000},
    {"be", 0xff0000},
    {"bez", 0x550000},
    {"bg", 0xff0000},
    {"blo", 0xff0000},
    {"bm", 0xff0000},
    {"bs", 0xff0000},
    {"bua", 0xff0000},
    {"ca", 0xff0000},
    {"ce", 0xff0000},
    {"cs", 0xffff00},
    {"cv", 0xff0000},
    {"da", 0xff0000},
    {"dsb", 0xff0000},
    {"dua", 0xff0000},
    {"ee", 0xff0000},
    {"eo", 0xc30000},
    {"es", 0xffffff},
    {"et", 0x7d0000},
    {"eu", 0xff0000},
    {"ewo", 0xff0000},
    {"ff", 0xff0000},
    {"fi", 0xff0000},
    {"fo", 0xff0000},
    {"fr", 0xff00ff},
    {"fur", 0xc30000},
    {"fy", 0xc3c3c3},
    {"gd", 0x40000},
    {"gl", 0xff0000},
    {"hr", 0xffff00},
    {"hsb", 0xff0000},
    {"hu", 0x7d0000},
    {"hy", 0xff0000},
    {"ia", 0xff0000},
    {"ie", 0xff0000},
    {"is", 0xff0000},
    {"it", 0xffffff},
    {"kea", 0xc30000},
    {"kgp", 0xc3c3c3},
    {"kk", 0xef0000},
    {"kkj", 0xff0000},
    {"kl", 0xff0000},
    {"ksf", 0xff0000},
    {"ku", 0xff0000},
    {"kw", 0x550000},
    {"kxv", 0xff0000},
    {"ky", 0xcf0000},
    {"lij", 0xff0000},
    {"lmo", 0xff0000},
    {"ln", 0xff0000},
    {"lt", 0xff0000},
    {"lv", 0x3f0000},
    {"mfe", 0xff0000},
    {"mgo", 0x3c0000},
    {"mk", 0xff0000},
    {"mn", 0x50000},
    {"myv", 0xff0000},
    {"nb", 0xff0000},
    {"nl", 0xffffff},
    {"nmg", 0xff0000},
    {"nn", 0xff0000},
    {"nnh", 0xff0000},
    {"no", 0xff0000},
    {"nr", 0x410000},
    {"oc", 0xff0000},
    {"os", 0xf0000},
    {"pl", 0xff00ff},
    {"pms", 0xff0000},
    {"prg", 0xff0000},
    {"pt", 0xffc3c3},
    {"rm", 0xff0000},
    {"rn", 0x820000},
    {"ro", 0xff0000},
    {"ru", 0x7d7d7d},
    {"sah", 0xd30000},
    {"sc", 0xff0000},
    {"scn", 0xff0000},
    {"se", 0xff0000},
    {"sk", 0xffff00},
    {"sl", 0xff0000},
    {"smn", 0xff0000},
    {"sq", 0xff0000},
    {"sr", 0xff0000},
    {"ss", 0x140000},
    {"sv", 0xff0000},
    {"szl", 0xff0000},
    {"tk", 0xf0000},
    {"tok", 0xff0000},
    {"trv", 0x410000},
    {"tt", 0xff0000},
    {"uk", 0xffffff},
    {"uz", 0x4d0000},
    {"vec", 0xff0000},
    {"vi", 0xc0000},
    {"vmw", 0xff0000},
    {"yav", 0xff0000},
    {"yrl", 0xffc3c3},
    {"za", 0xff0000},
};

static char RevenantDateContextKey;
static char RevenantByteContextKey;

static unsigned revenant_context_mask(NSLocale *locale)
{
    NSString *language = [locale objectForKey:NSLocaleLanguageCode];
    if (!language)
        return 0;
    const char *wanted = language.UTF8String;
    for (size_t index = 0; index < sizeof revenant_date_rows / sizeof *revenant_date_rows; index++) {
        if (strcmp(revenant_date_rows[index].language, wanted) == 0)
            return revenant_date_rows[index].mask;
    }
    return 0;
}

static NSInteger revenant_first_field(NSString *pattern)
{
    if (!pattern.length)
        return -1;
    unichar letter = [pattern characterAtIndex:0];
    NSUInteger run = 1;
    while (run < pattern.length && [pattern characterAtIndex:run] == letter)
        run++;
    switch (letter) {
    case 'E':
    case 'e':
        return run == 4 ? 0 : (run >= 1 && run <= 3 ? 1 : -1);
    case 'M':
        return run == 4 ? 2 : (run == 3 ? 3 : -1);
    case 'L':
        return run == 4 ? 4 : (run == 3 ? 5 : -1);
    case 'c':
        return run == 4 ? 6 : (run == 3 ? 7 : -1);
    default:
        return -1;
    }
}

static NSString *revenant_capitalized(NSString *text)
{
    if (!text.length)
        return text;
    NSRange first = [text rangeOfComposedCharacterSequenceAtIndex:0];
    return [[[text substringWithRange:first] capitalizedString] stringByAppendingString:[text substringFromIndex:NSMaxRange(first)]];
}

NSString *revenant_date_context(NSString *text, NSString *pattern, NSLocale *locale, NSFormattingContext context);

NSString *revenant_date_context(NSString *text, NSString *pattern, NSLocale *locale, NSFormattingContext context)
{
    NSInteger slot;
    switch (context) {
    case NSFormattingContextStandalone:
        slot = 0;
        break;
    case NSFormattingContextListItem:
        slot = 1;
        break;
    case NSFormattingContextBeginningOfSentence:
        slot = 2;
        break;
    default:
        return text;
    }
    NSInteger field = revenant_first_field(pattern);
    if (field < 0 || !(revenant_context_mask(locale) & (1u << (slot * 8 + field))))
        return text;
    return revenant_capitalized(text);
}

static IMP RevenantReleaseStringFromDate;

static NSString *revenant_date_string(id formatter, SEL command, NSDate *date)
{
    NSDateFormatter *self_ = formatter;
    NSString *text = ((NSString * (*)(id, SEL, NSDate *))RevenantReleaseStringFromDate)(formatter, command, date);
    NSNumber *context = objc_getAssociatedObject(self_, &RevenantDateContextKey);
    if (!text || !context)
        return text;
    return revenant_date_context(text, self_.dateFormat, self_.locale, (NSFormattingContext)context.integerValue);
}

@interface RevenantFormattingContextInstaller : NSObject
@end

@implementation RevenantFormattingContextInstaller

+ (void)load
{
    Class formatter = [NSDateFormatter class];
    Method release = class_getInstanceMethod(formatter, NSSelectorFromString(@"stringFromDate:"));
    if (!release || class_getInstanceMethod(formatter, NSSelectorFromString(@"formattingContext")))
        return;
    RevenantReleaseStringFromDate = method_getImplementation(release);
    class_replaceMethod(formatter, method_getName(release), (IMP)revenant_date_string, method_getTypeEncoding(release));
}

@end

@implementation NSDateFormatter (RevenantFormattingContext8)

- (NSFormattingContext)formattingContext
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantDateContextKey);
    return (NSFormattingContext)(stored ? stored.integerValue : NSFormattingContextUnknown);
}

- (void)setFormattingContext:(NSFormattingContext)context
{
    objc_setAssociatedObject(self, &RevenantDateContextKey, @(context), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation NSByteCountFormatter (RevenantFormattingContext8)

- (NSFormattingContext)formattingContext
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantByteContextKey);
    return (NSFormattingContext)(stored ? stored.integerValue : NSFormattingContextUnknown);
}

- (void)setFormattingContext:(NSFormattingContext)context
{
    objc_setAssociatedObject(self, &RevenantByteContextKey, @(context), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
