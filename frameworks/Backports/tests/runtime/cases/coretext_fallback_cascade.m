#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <objc/message.h>
#import <malloc/malloc.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

static double mapped_below_mib(void)
{
    vm_address_t address = 0;
    unsigned long long low = 0;
    for (;;) {
        vm_size_t size = 0;
        struct vm_region_basic_info_64 info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        if (vm_region_64(mach_task_self(), &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, &object) != KERN_SUCCESS)
            break;
        if (address < 0x30000000)
            low += (address + size <= 0x30000000) ? size : (0x30000000 - address);
        address += size;
    }
    return (double)low / 1048576.0;
}

static NSString *describe_runs(CTLineRef line)
{
    NSMutableString *described = [NSMutableString string];
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
        CTFontRef used = (CTFontRef)CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
        CFStringRef name = used ? CTFontCopyPostScriptName(used) : NULL;
        CFIndex count = CTRunGetGlyphCount(run);
        CGGlyph glyphs[4] = {0, 0, 0, 0};
        CTRunGetGlyphs(run, CFRangeMake(0, count < 4 ? count : 4), glyphs);
        [described appendFormat:@"%@:%ld:%u,%u,%u,%u/", name ? (__bridge NSString *)name : @"?", (long)count, glyphs[0], glyphs[1], glyphs[2], glyphs[3]];
        if (name)
            CFRelease(name);
    }
    return described;
}

static NSString *typeset_runs(NSString *text, CTFontRef font, NSString **lastRun)
{
    CFMutableAttributedStringRef string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(string, CFRangeMake(0, 0), (__bridge CFStringRef)text);
    CFAttributedStringSetAttribute(string, CFRangeMake(0, (CFIndex)text.length), kCTFontAttributeName, font);
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(string);
    CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(0, (CFIndex)text.length));
    NSString *described = describe_runs(line);
    if (lastRun) {
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, CFArrayGetCount(runs) - 1);
        CTFontRef used = (CTFontRef)CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
        CFStringRef name = used ? CTFontCopyPostScriptName(used) : NULL;
        *lastRun = name ? (__bridge_transfer NSString *)name : @"?";
    }
    CFRelease(line);
    CFRelease(typesetter);
    CFRelease(string);
    return described;
}

static NSString *uncovered_text(const char *which)
{
    if (!strcmp(which, "emoji")) return @"Hi \U0001F972";
    if (!strcmp(which, "rare")) return @"Hi \U00020000";
    if (!strcmp(which, "math")) return @"Hi \U0001D11E";
    return @"Hi \U0001F595";
}

typedef CTFontRef (*SystemCreateWithName)(CFStringRef, CGFloat, const CGAffineTransform *);

static SystemCreateWithName system_create_with_name(void)
{
    void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    return (SystemCreateWithName)dlsym(coreText, "CTFontCreateWithName");
}

static CTFontRef ct_of(UIFont *font)
{
    return ((CTFontRef (*)(id, SEL))objc_msgSend)(font, @selector(ctFontRef));
}

static void result(const char *variant, const char *key, NSString *value)
{
    printf("RESULT %s %s=%s\n", variant, key, [value UTF8String]);
}

static void run_uncovered(const char *variant, CTFontRef font, const char *which)
{
    double before = mapped_below_mib();
    NSString *last = nil;
    typeset_runs(uncovered_text(which), font, &last);
    double after = mapped_below_mib();
    result(variant, "delta", [NSString stringWithFormat:@"%.1f", after - before]);
    result(variant, "run", last);
}

static NSString *compare_pair(CTFontRef stock, CTFontRef backport)
{
    CGAffineTransform stockMatrix = CTFontGetMatrix(stock), backportMatrix = CTFontGetMatrix(backport);
    CFStringRef stockName = CTFontCopyPostScriptName(stock), backportName = CTFontCopyPostScriptName(backport);
    BOOL same = CFEqual(stockName, backportName) && CTFontGetSize(stock) == CTFontGetSize(backport)
        && !memcmp(&stockMatrix, &backportMatrix, sizeof stockMatrix)
        && CTFontGetAscent(stock) == CTFontGetAscent(backport) && CTFontGetDescent(stock) == CTFontGetDescent(backport)
        && CTFontGetLeading(stock) == CTFontGetLeading(backport) && CTFontGetSymbolicTraits(stock) == CTFontGetSymbolicTraits(backport)
        && CTFontGetGlyphCount(stock) == CTFontGetGlyphCount(backport);
    NSString *texts[] = {@"Hello world", @"你好 こんにちは 안녕", @"Hi مرحبا", @"Hi สวัสดี", @"Hi \U0001F604", @"Hello Привет \U0001F604 你好 こんにちは", @"नमस्ते ગુજરાતી தமிழ்"};
    NSMutableString *different = [NSMutableString string];
    for (unsigned index = 0; index < sizeof texts / sizeof texts[0]; index++) {
        NSString *a = typeset_runs(texts[index], stock, NULL);
        NSString *b = typeset_runs(texts[index], backport, NULL);
        if (![a isEqualToString:b])
            [different appendFormat:@"[%u: %@ vs %@]", index, a, b];
    }
    NSString *verdict = [NSString stringWithFormat:@"%d%@", same && different.length == 0, same ? different : @" metrics differ"];
    CFRelease(stockName);
    CFRelease(backportName);
    return verdict;
}

static void compare_fonts(const char *variant, const char *name)
{
    CFStringRef fontName = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8);
    CTFontRef stock = system_create_with_name()(fontName, 17.0, NULL);
    CTFontRef backport = CTFontCreateWithName(fontName, 17.0, NULL);
    CFRelease(fontName);
    NSString *key = [NSString stringWithFormat:@"%s-%s", variant, name];
    result("identical", [key UTF8String], compare_pair(stock, backport));
    CFRelease(stock);
    CFRelease(backport);
}

static void prepare_uikit(void)
{
    (void)[UIApplication sharedApplication];
    void *graphics = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_NOW);
    void (*initialize)(void) = graphics ? dlsym(graphics, "GSInitialize") : NULL;
    if (initialize)
        initialize();
}

static void child(const char *variant)
{
    if (!strncmp(variant, "uifont", 6) || !strcmp(variant, "identical") || !strcmp(variant, "inspect") || !strcmp(variant, "leak"))
        prepare_uikit();
    if (!strcmp(variant, "uifont")) {
        UIFont *font = [UIFont systemFontOfSize:17.0];
        result(variant, "step", [NSString stringWithFormat:@"font %p", font]);
        result(variant, "cftype", [NSString stringWithFormat:@"%d", CFGetTypeID((__bridge CFTypeRef)font) == CTFontGetTypeID()]);
        result(variant, "class", NSStringFromClass([font class]));
        result(variant, "uifont", [NSString stringWithFormat:@"%d", [font isKindOfClass:[UIFont class]]]);
        CFTypeRef list = CTFontCopyAttribute(((CTFontRef (*)(id, SEL))objc_msgSend)(font, @selector(ctFontRef)), kCTFontCascadeListAttribute);
        result(variant, "cascade", [NSString stringWithFormat:@"%ld", list ? (long)CFArrayGetCount((CFArrayRef)list) : -1L]);
        CFStringRef lastName = list && CFArrayGetCount((CFArrayRef)list) > 0 ? (CFStringRef)CTFontDescriptorCopyAttribute((CTFontDescriptorRef)CFArrayGetValueAtIndex((CFArrayRef)list, CFArrayGetCount((CFArrayRef)list) - 1), kCTFontNameAttribute) : NULL;
        result(variant, "cascade-last", lastName ? (__bridge NSString *)lastName : @"none");
        run_uncovered(variant, ct_of(font), "emoji");
    } else if (!strcmp(variant, "inspect")) {
        UIFont *font = [UIFont systemFontOfSize:17.0];
        for (Class cls = [font class]; cls; cls = class_getSuperclass(cls)) {
            result(variant, "class", NSStringFromClass(cls));
            unsigned count = 0;
            Ivar *ivars = class_copyIvarList(cls, &count);
            for (unsigned index = 0; index < count; index++) {
                const char *type = ivar_getTypeEncoding(ivars[index]);
                result(variant, "ivar", [NSString stringWithFormat:@"%s.%s %s", class_getName(cls), ivar_getName(ivars[index]), type ? type : "?"]);
            }
            free(ivars);
            Method *methods = class_copyMethodList(cls, &count);
            NSMutableArray *names = [NSMutableArray array];
            for (unsigned index = 0; index < count; index++) {
                NSString *name = NSStringFromSelector(method_getName(methods[index]));
                NSString *lower = [name lowercaseString];
                if ([lower rangeOfString:@"ct"].location != NSNotFound || [lower rangeOfString:@"gs"].location != NSNotFound || [lower rangeOfString:@"fontref"].location != NSNotFound || [lower rangeOfString:@"cffont"].location != NSNotFound)
                    [names addObject:name];
            }
            free(methods);
            result(variant, "methods", [NSString stringWithFormat:@"%s: %@", class_getName(cls), [names componentsJoinedByString:@" "]]);
            if (cls == [NSObject class])
                break;
        }
        const char *candidates[] = {"ctFont", "_ctFont", "_CTFont", "CTFont", "ctFontRef", "fontRef", "_fontRef", "gsFont", "_gsFont", "_font", "font", "_cfFont", "cfFont", "_fontInfo", NULL};
        for (int index = 0; candidates[index]; index++) {
            SEL selector = sel_registerName(candidates[index]);
            if ([font respondsToSelector:selector]) {
                id value = ((id (*)(id, SEL))objc_msgSend)(font, selector);
                CFTypeID type = value ? CFGetTypeID((__bridge CFTypeRef)value) : 0;
                CFStringRef description = type ? CFCopyTypeIDDescription(type) : NULL;
                result(variant, "responds", [NSString stringWithFormat:@"%s -> %p class %@ cftype %lu %@ ctfont %d", candidates[index], value, value ? NSStringFromClass([value class]) : @"nil", (unsigned long)type, description ? (__bridge NSString *)description : @"", type == CTFontGetTypeID()]);
                if (description)
                    CFRelease(description);
            }
        }
        {
            Class cls = object_getClass(font);
            void *held = *(void **)((char *)(__bridge void *)font + 0x30);
            result(variant, "layout", [NSString stringWithFormat:@"class=%s instance-size=%zu malloc-size=%zu slot30-is-ctFontRef=%d", class_getName(cls), class_getInstanceSize(cls), malloc_size((__bridge void *)font), held == (void *)ct_of(font)]);
        }
        Ivar ivar = class_getInstanceVariable([font class], "_font");
        if (ivar) {
            void *raw = (__bridge void *)object_getIvar(font, ivar);
            result(variant, "_font-ivar", [NSString stringWithFormat:@"%p", raw]);
        }
    } else if (!strcmp(variant, "uifont-named")) {
        UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:17.0];
        run_uncovered(variant, ct_of(font), "rare");
    } else if (!strcmp(variant, "uifont-bold")) {
        UIFont *font = [UIFont boldSystemFontOfSize:17.0];
        run_uncovered(variant, ct_of(font), "math");
    } else if (!strcmp(variant, "uifont-resize")) {
        UIFont *font = [[UIFont systemFontOfSize:12.0] fontWithSize:17.0];
        run_uncovered(variant, ct_of(font), "emoji");
    } else if (!strcmp(variant, "uifont-weight")) {
        UIFont *font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightLight];
        run_uncovered(variant, ct_of(font), "rare");
    } else if (!strcmp(variant, "ctname")) {
        Dl_info where;
        memset(&where, 0, sizeof where);
        dladdr((void *)&CTFontCreateWithName, &where);
        result(variant, "image", where.dli_fname ? [NSString stringWithUTF8String:where.dli_fname] : @"none");
        Dl_info copyWhere;
        memset(&copyWhere, 0, sizeof copyWhere);
        dladdr((void *)&CTFontCreateCopyWithAttributes, &copyWhere);
        result(variant, "copy-image", copyWhere.dli_fname ? [NSString stringWithUTF8String:copyWhere.dli_fname] : @"none");
        CTFontRef font = CTFontCreateWithName(CFSTR("HelveticaNeue"), 17.0, NULL);
        run_uncovered(variant, font, "math");
        CFRelease(font);
    } else if (!strcmp(variant, "ctdescriptor")) {
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize(CFSTR("HelveticaNeue"), 17.0);
        CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 17.0, NULL);
        run_uncovered(variant, font, "emoji");
        CFRelease(font);
        CFRelease(descriptor);
    } else if (!strcmp(variant, "ctcopy")) {
        CTFontRef base = CTFontCreateWithName(CFSTR("HelveticaNeue"), 17.0, NULL);
        CTFontRef font = CTFontCreateCopyWithSymbolicTraits(base, 17.0, NULL, kCTFontBoldTrait, kCTFontBoldTrait);
        run_uncovered(variant, font, "rare");
        CFRelease(font);
        CFRelease(base);
    } else if (!strcmp(variant, "ctattributes")) {
        CTFontRef base = CTFontCreateWithName(CFSTR("HelveticaNeue"), 17.0, NULL);
        CTFontRef font = CTFontCreateCopyWithAttributes(base, 21.0, NULL, NULL);
        result(variant, "size", [NSString stringWithFormat:@"%.1f", CTFontGetSize(font)]);
        run_uncovered(variant, font, "emoji");
        CFRelease(font);
        CFRelease(base);
    } else if (!strcmp(variant, "system")) {
        CTFontRef font = system_create_with_name()(CFSTR("HelveticaNeue"), 17.0, NULL);
        run_uncovered(variant, font, "emoji");
        CFRelease(font);
    } else if (!strcmp(variant, "kept")) {
        CTFontDescriptorRef emoji = CTFontDescriptorCreateWithNameAndSize(CFSTR("AppleColorEmoji"), 17.0);
        CFArrayRef list = CFArrayCreate(kCFAllocatorDefault, (const void **)&emoji, 1, &kCFTypeArrayCallBacks);
        const void *keys[] = {kCTFontCascadeListAttribute};
        const void *values[] = {list};
        CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CTFontDescriptorRef carrier = CTFontDescriptorCreateWithAttributes(attributes);
        CTFontRef base = system_create_with_name()(CFSTR("HelveticaNeue"), 17.0, NULL);
        void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
        CTFontRef (*systemCopy)(CTFontRef, CGFloat, const CGAffineTransform *, CTFontDescriptorRef) = dlsym(coreText, "CTFontCreateCopyWithAttributes");
        CTFontRef given = systemCopy(base, 17.0, NULL, carrier);
        CTFontRef font = CTFontCreateCopyWithAttributes(given, 17.0, NULL, NULL);
        CFArrayRef own = (CFArrayRef)CTFontCopyAttribute(font, kCTFontCascadeListAttribute);
        CFIndex count = own ? CFArrayGetCount(own) : -1;
        NSMutableString *names = [NSMutableString string];
        for (CFIndex index = 0; index < count; index++) {
            CFStringRef name = (CFStringRef)CTFontDescriptorCopyAttribute((CTFontDescriptorRef)CFArrayGetValueAtIndex(own, index), kCTFontNameAttribute);
            [names appendFormat:@"%@,", name ? (__bridge NSString *)name : @"?"];
            if (name)
                CFRelease(name);
        }
        result(variant, "list", names);
        run_uncovered(variant, font, "rare");
        CTFontRef again = CTFontCreateCopyWithAttributes(font, 17.0, NULL, NULL);
        CFArrayRef twice = (CFArrayRef)CTFontCopyAttribute(again, kCTFontCascadeListAttribute);
        result(variant, "again", [NSString stringWithFormat:@"%ld", twice ? (long)CFArrayGetCount(twice) : -1L]);
    } else if (!strcmp(variant, "identical")) {
        const char *names[] = {"HelveticaNeue", "HelveticaNeue-Bold", "HelveticaNeue-Italic", "Zapfino", "HiraKakuProN-W3", "AppleColorEmoji", ".HelveticaNeueUI", "Courier", NULL};
        for (int index = 0; names[index]; index++)
            compare_fonts("created", names[index]);
        UIFont *systemFont = [UIFont systemFontOfSize:17.0];
        UIFont *boldFont = [UIFont boldSystemFontOfSize:17.0];
        UIFont *italicFont = [UIFont italicSystemFontOfSize:17.0];
        UIFont *named = [UIFont fontWithName:@"HelveticaNeue" size:17.0];
        NSArray *fonts = @[systemFont, boldFont, italicFont, named];
        NSArray *labels = @[@"system", @"bold", @"italic", @"named"];
        for (NSUInteger index = 0; index < fonts.count; index++) {
            UIFont *font = fonts[index];
            CFStringRef fontName = (__bridge CFStringRef)font.fontName;
            CTFontRef stock = system_create_with_name()(fontName, font.pointSize, NULL);
            result("identical", [[NSString stringWithFormat:@"uifont-%@", labels[index]] UTF8String], compare_pair(stock, ct_of(font)));
            result("identical", [[NSString stringWithFormat:@"uifont-%@-facts", labels[index]] UTF8String],
                   [NSString stringWithFormat:@"name=%@ size=%.1f", font.fontName, font.pointSize]);
            CFRelease(stock);
        }
        result("identical", "uifont-same-instance", [NSString stringWithFormat:@"%d", [UIFont systemFontOfSize:17.0] == [UIFont systemFontOfSize:17.0]]);
        result("identical", "uifont-attributed", [NSString stringWithFormat:@"%d", [[[NSAttributedString alloc] initWithString:@"Hi" attributes:@{NSFontAttributeName: systemFont}] attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] == systemFont]);
    } else if (!strcmp(variant, "leak")) {
        CTFontRef (*systemCreate)(CFStringRef, CGFloat, const CGAffineTransform *) = system_create_with_name();
        CTFontRef stockOne = systemCreate(CFSTR("HelveticaNeue"), 17.0, NULL);
        CTFontRef backportOne = CTFontCreateWithName(CFSTR("HelveticaNeue"), 17.0, NULL);
        result(variant, "retain-stock", [NSString stringWithFormat:@"%ld", (long)CFGetRetainCount(stockOne)]);
        result(variant, "retain-backport", [NSString stringWithFormat:@"%ld", (long)CFGetRetainCount(backportOne)]);
        CFRelease(stockOne);
        CFRelease(backportOne);
        for (int round = 0; round < 2; round++) {
            for (int index = 0; index < 50; index++) {
                CFRelease(round ? CTFontCreateWithName(CFSTR("HelveticaNeue"), 5.0 + index * 0.01, NULL) : systemCreate(CFSTR("HelveticaNeue"), 5.0 + index * 0.01, NULL));
            }
        }
        for (int mode = 0; mode < 3; mode++) {
            for (int pass = 0; pass < (mode == 2 ? 2 : 1); pass++) {
                const char *label = mode == 0 ? "stock" : mode == 1 ? "backport" : pass == 0 ? "uifont" : "uifont-again";
                malloc_statistics_t before, after;
                malloc_zone_statistics(NULL, &before);
                for (int index = 0; index < 1000; index++) {
                    @autoreleasepool {
                        double size = 20.0 + index * 0.01 + mode * 100.0;
                        if (mode == 0)
                            CFRelease(systemCreate(CFSTR("HelveticaNeue"), size, NULL));
                        else if (mode == 1)
                            CFRelease(CTFontCreateWithName(CFSTR("HelveticaNeue"), size, NULL));
                        else
                            (void)[UIFont fontWithName:@"HelveticaNeue" size:size];
                    }
                }
                malloc_zone_statistics(NULL, &after);
                result(variant, [[NSString stringWithFormat:@"%s-blocks", label] UTF8String], [NSString stringWithFormat:@"%ld", (long)after.blocks_in_use - (long)before.blocks_in_use]);
                result(variant, [[NSString stringWithFormat:@"%s-bytes", label] UTF8String], [NSString stringWithFormat:@"%ld", (long)after.size_in_use - (long)before.size_in_use]);
            }
        }
    }
}

static NSString *output_path(const char *variant)
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"fontcascade-%s.txt", variant]];
}

static NSMutableDictionary *results_of_children(void)
{
    static NSMutableDictionary *results;
    if (results)
        return results;
    results = [NSMutableDictionary dictionary];
    char executable[1024];
    uint32_t size = sizeof executable;
    _NSGetExecutablePath(executable, &size);
    const char *variants[] = {"uifont", "uifont-named", "uifont-bold", "uifont-resize", "uifont-weight", "ctname", "ctdescriptor", "ctcopy", "ctattributes", "system", "kept", "inspect", "identical", "leak", NULL};
    for (int index = 0; variants[index]; index++) {
        char flag[160];
        snprintf(flag, sizeof flag, "FONTCASCADE_VARIANT=%s", variants[index]);
        int count = 0;
        while (environ[count])
            count++;
        char **env = calloc(count + 3, sizeof(char *));
        for (int item = 0; item < count; item++)
            env[item] = environ[item];
        env[count] = flag;
        char *argv[] = {executable, (char *)"--cases", (char *)"coretext_fallback_cascade", NULL};
        pid_t pid = 0;
        int status = 0;
        int spawned = posix_spawn(&pid, executable, NULL, NULL, argv, env);
        if (spawned == 0)
            waitpid(pid, &status, 0);
        free(env);
        NSString *text = [NSString stringWithContentsOfFile:output_path(variants[index]) encoding:NSUTF8StringEncoding error:NULL];
        printf("cascade parent: %s spawn %d status %#x\n", variants[index], spawned, status);
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            if (![line hasPrefix:@"RESULT "])
                continue;
            printf("cascade fact: %s\n", [[line substringFromIndex:7] UTF8String]);
            NSArray *parts = [[line substringFromIndex:7] componentsSeparatedByString:@" "];
            if (parts.count < 2)
                continue;
            NSString *rest = [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@" "];
            NSRange equals = [rest rangeOfString:@"="];
            if (equals.location == NSNotFound)
                continue;
            results[[NSString stringWithFormat:@"%@.%@", parts[0], [rest substringToIndex:equals.location]]] = [rest substringFromIndex:equals.location + 1];
        }
        fflush(stdout);
    }
    return results;
}

static double value_of(NSDictionary *results, NSString *key)
{
    NSString *text = results[key];
    return text ? [text doubleValue] : 1e9;
}

REVENANT_CASE(coretext_fallback_cascade)
{
    const char *variant = getenv("FONTCASCADE_VARIANT");
    if (variant) {
        if (negative)
            return;
        freopen([output_path(variant) UTF8String], "w", stdout);
        setvbuf(stdout, NULL, _IONBF, 0);
        printf("RESULT %s step=child started\n", variant);
        child(variant);
        fflush(stdout);
        return;
    }
    NSDictionary *results = results_of_children();
    BOOL flip = (BOOL)negative;
    NSArray *creators = @[@"uifont", @"uifont-named", @"uifont-bold", @"uifont-resize", @"uifont-weight", @"ctname", @"ctdescriptor", @"ctcopy", @"ctattributes", @"kept"];
    for (NSString *creator in creators) {
        double delta = value_of(results, [creator stringByAppendingString:@".delta"]);
        revenant_expect_true([NSString stringWithFormat:@"a font from %@ lays out a code point no font covers with under 8 MiB more mapped below 0x30000000", creator],
                             (delta < 8.0) != flip, [NSString stringWithFormat:@"%.1f MiB", delta]);
        NSString *run = results[[creator stringByAppendingString:@".run"]];
        revenant_expect_true([NSString stringWithFormat:@"a font from %@ ends the cascade in LastResort", creator],
                             [run isEqualToString:@"LastResort"] != flip, run);
    }
    revenant_expect_true(@"the app's CTFontCreateWithName binds to libCoreTextBackports, not to CoreText",
                         [results[@"ctname.image"] hasSuffix:@"/libCoreTextBackports.dylib"] != flip, results[@"ctname.image"]);
    revenant_expect_true(@"the app's CTFontCreateCopyWithAttributes binds to libCoreTextBackports, not to CoreText",
                         [results[@"ctname.copy-image"] hasSuffix:@"/libCoreTextBackports.dylib"] != flip, results[@"ctname.copy-image"]);
    double walk = value_of(results, @"system.delta");
    revenant_expect_true(@"the system's own creator still walks the whole font database for that code point",
                         (walk > 100.0) != flip, [NSString stringWithFormat:@"%.1f MiB", walk]);
    revenant_expect_true(@"the system font is a UIFont that hands out its CTFont", [results[@"uifont.uifont"] isEqualToString:@"1"] != flip, results[@"uifont.uifont"]);
    revenant_expect_true(@"a font from UIFont carries the default cascade followed by LastResort",
                         ([results[@"uifont.cascade"] integerValue] > 1 && [results[@"uifont.cascade-last"] isEqualToString:@"LastResort"]) != flip,
                         [NSString stringWithFormat:@"%@ descriptors, last %@", results[@"uifont.cascade"], results[@"uifont.cascade-last"]]);
    revenant_expect_true(@"a cascade list the caller gave is kept and LastResort is appended",
                         [results[@"kept.list"] isEqualToString:@"AppleColorEmoji,LastResort,"] != flip, results[@"kept.list"]);
    revenant_expect_true(@"a font that already ends in LastResort is not extended again",
                         [results[@"kept.again"] isEqualToString:@"2"] != flip, results[@"kept.again"]);
    revenant_expect_true(@"a copy at another size has that size", [results[@"ctattributes.size"] isEqualToString:@"21.0"] != flip, results[@"ctattributes.size"]);
    revenant_expect_true(@"the system font is a UICFFont and not a CTFont (the layout the UIKit swap relies on)",
                         ([results[@"uifont.class"] isEqualToString:@"UICFFont"] && [results[@"uifont.cftype"] isEqualToString:@"0"]) != flip,
                         [NSString stringWithFormat:@"%@ cftype %@", results[@"uifont.class"], results[@"uifont.cftype"]]);
    revenant_expect_true(@"the UICFFont holds the CTFont that -ctFontRef returns at offset 0x30 (class and size read from the process)",
                         [results[@"inspect.layout"] isEqualToString:@"class=UICFFont instance-size=4 malloc-size=64 slot30-is-ctFontRef=1"] != flip, results[@"inspect.layout"]);
    NSDictionary *expected = @{@"system": @"name=.HelveticaNeueUI size=17.0", @"bold": @"name=.HelveticaNeueUI-Bold size=17.0",
                               @"italic": @"name=.HelveticaNeueUI-Italic size=17.0", @"named": @"name=HelveticaNeue size=17.0"};
    for (NSString *label in expected) {
        NSString *facts = results[[NSString stringWithFormat:@"identical.uifont-%@-facts", label]];
        revenant_expect_true([NSString stringWithFormat:@"the %@ UIFont has the name and size the system's creator gives", label],
                             [facts isEqualToString:expected[label]] != flip, facts);
        NSString *same = results[[NSString stringWithFormat:@"identical.uifont-%@", label]];
        revenant_expect_true([NSString stringWithFormat:@"the CTFont inside the %@ UIFont equals the system's font made by the same name and size: name, size, matrix, metrics and the runs for Latin, CJK, Arabic, Thai, Indic and emoji", label],
                             [same isEqualToString:@"1"] != flip, same);
    }
    revenant_expect_true(@"a UIFont creator still returns the same instance for the same arguments",
                         [results[@"identical.uifont-same-instance"] isEqualToString:@"1"] != flip, results[@"identical.uifont-same-instance"]);
    revenant_expect_true(@"a UIFont put in an attributed string is the object read back",
                         [results[@"identical.uifont-attributed"] isEqualToString:@"1"] != flip, results[@"identical.uifont-attributed"]);
    revenant_expect_true(@"a font from the backport creator is held once, as the system's is",
                         [results[@"leak.retain-backport"] isEqualToString:results[@"leak.retain-stock"]] != flip,
                         [NSString stringWithFormat:@"backport %@, system %@", results[@"leak.retain-backport"], results[@"leak.retain-stock"]]);
    double stockBytes = value_of(results, @"leak.stock-bytes");
    for (NSString *mode in @[@"backport", @"uifont-again"]) {
        double bytes = value_of(results, [NSString stringWithFormat:@"leak.%@-bytes", mode]);
        double blocks = value_of(results, [NSString stringWithFormat:@"leak.%@-blocks", mode]);
        revenant_expect_true([NSString stringWithFormat:@"1000 fonts from %@ creators leave no more heap behind than the system's (%.0f bytes, %.0f blocks; system %.0f bytes)", mode, bytes, blocks, stockBytes],
                             (bytes <= stockBytes + 16384.0) != flip, [NSString stringWithFormat:@"%.0f bytes", bytes]);
    }
    revenant_expect_true(@"1000 UIFonts of new sizes leave a bounded heap behind (the UIFonts UIKit keeps and the cascaded CTFont each holds)",
                         (value_of(results, @"leak.uifont-bytes") < 786432.0) != flip, results[@"leak.uifont-bytes"]);
    NSMutableArray *differences = [NSMutableArray array];
    for (NSString *key in results) {
        if ([key hasPrefix:@"identical.created-"] && ![results[key] isEqualToString:@"1"])
            [differences addObject:[NSString stringWithFormat:@"%@ %@", key, results[key]]];
    }
    revenant_expect_true(@"fonts from the creators match the system's: name, size, matrix, metrics, and the fonts and glyphs picked for Latin, CJK, Arabic, Thai, Indic and emoji text",
                         (differences.count == 0 && results[@"identical.created-HelveticaNeue"] != nil) != flip, [differences componentsJoinedByString:@"; "]);
}
