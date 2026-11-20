#import "../app/revenant_check.h"
#import <CoreText/CoreText.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach-o/dyld.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

static double mib(unsigned long long bytes)
{
    return (double)bytes / 1048576.0;
}

static void mapped(double *below, double *total, unsigned *regions)
{
    vm_address_t address = 0;
    unsigned long long low = 0, all = 0;
    unsigned count = 0;
    for (;;) {
        vm_size_t size = 0;
        struct vm_region_basic_info_64 info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        kern_return_t result = vm_region_64(mach_task_self(), &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, &object);
        if (result != KERN_SUCCESS)
            break;
        all += size;
        if (address < 0x30000000)
            low += (address + size <= 0x30000000) ? size : (0x30000000 - address);
        count++;
        address += size;
    }
    *below = mib(low);
    *total = mib(all);
    *regions = count;
}

static void report(const char *label, double milliseconds)
{
    double below, total;
    unsigned regions;
    mapped(&below, &total, &regions);
    struct task_basic_info info;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &infoCount);
    printf("fontprobe %s: %.1f ms; regions %u, %.1f MiB mapped below 0x30000000, %.1f MiB in all; task_info %s virtual %.1f MiB resident %.1f MiB\n",
           label, milliseconds, regions, below, total, result == KERN_SUCCESS ? "ok" : "failed",
           result == KERN_SUCCESS ? mib(info.virtual_size) : 0.0, result == KERN_SUCCESS ? mib(info.resident_size) : 0.0);
    fflush(stdout);
}

static void typeset(const char *label, NSString *text, CTFontRef font)
{
    mach_timebase_info_data_t base;
    mach_timebase_info(&base);
    uint64_t start = mach_absolute_time();
    CFMutableAttributedStringRef string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(string, CFRangeMake(0, 0), (__bridge CFStringRef)text);
    CFAttributedStringSetAttribute(string, CFRangeMake(0, (CFIndex)text.length), kCTFontAttributeName, font);
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(string);
    CFIndex fit = CTTypesetterSuggestLineBreak(typesetter, 0, 10000.0);
    CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(0, fit > 0 ? fit : (CFIndex)text.length));
    double width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    double milliseconds = (double)(mach_absolute_time() - start) * base.numer / base.denom / 1e6;
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    NSMutableString *described = [NSMutableString string];
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
        CFDictionaryRef attributes = CTRunGetAttributes(run);
        CTFontRef used = (CTFontRef)CFDictionaryGetValue(attributes, kCTFontAttributeName);
        CFStringRef name = used ? CTFontCopyPostScriptName(used) : NULL;
        CGGlyph glyphs[3] = {0, 0, 0};
        CFIndex count = CTRunGetGlyphCount(run);
        CTRunGetGlyphs(run, CFRangeMake(0, count < 3 ? count : 3), glyphs);
        [described appendFormat:@" [%@ x%ld g%u,%u,%u]", name ? (__bridge NSString *)name : @"?", (long)count, glyphs[0], glyphs[1], glyphs[2]];
        if (name)
            CFRelease(name);
    }
    printf("fontprobe %s: typeset width %.1f runs%s\n", label, width, [described UTF8String]);
    fflush(stdout);
    report(label, milliseconds);
    CFRelease(line);
    CFRelease(typesetter);
    CFRelease(string);
}

static NSString *text_for(const char *item)
{
    if (!strcmp(item, "latin")) return @"Hello world";
    if (!strcmp(item, "emoji")) return @"Hi \U0001F604";
    if (!strcmp(item, "cjk")) return @"你好 こんにちは 안녕";
    if (!strcmp(item, "new")) return @"Hi \U0001F972";
    if (!strcmp(item, "new2")) return @"Hi \U0001F9CC";
    if (!strcmp(item, "rare")) return @"Hi \U00020000";
    if (!strcmp(item, "math")) return @"Hi \U0001D11E";
    if (!strcmp(item, "private")) return @"Hi ";
    if (!strcmp(item, "arabic")) return @"Hi مرحبا";
    if (!strcmp(item, "thai")) return @"Hi สวัสดี";
    if (!strcmp(item, "mixed")) return @"Hello Привет \U0001F604 你好 こんにちは";
    return nil;
}

static void describe_cascade(const char *label, CTFontRef font)
{
    CFArrayRef list = CTFontCopyDefaultCascadeListForLanguages(font, NULL);
    CFIndex count = list ? CFArrayGetCount(list) : 0;
    printf("fontprobe cascade %s: %ld descriptors\n", label, (long)count);
    for (CFIndex index = 0; index < count; index++) {
        CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(list, index);
        CFStringRef name = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
        CFCharacterSetRef set = (CFCharacterSetRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontCharacterSetAttribute);
        printf("fontprobe cascade %s [%ld]: %s charset %s new-emoji %d 1F604 %d\n", label, (long)index,
               name ? [(__bridge NSString *)name UTF8String] : "?", set ? "present" : "absent",
               set ? CFCharacterSetIsLongCharacterMember(set, 0x1F972) : -1, set ? CFCharacterSetIsLongCharacterMember(set, 0x1F604) : -1);
        if (name) CFRelease(name);
        if (set) CFRelease(set);
    }
    if (list) CFRelease(list);
    CFTypeRef own = CTFontCopyAttribute(font, kCTFontCascadeListAttribute);
    printf("fontprobe cascade %s: kCTFontCascadeListAttribute on the font is %s\n", label, own ? "set" : "absent");
    if (own) CFRelease(own);
    fflush(stdout);
}

static CTFontRef font_with_cascade(const char *base, const char **cascade, int cascade_count)
{
    CFMutableArrayRef list = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    for (int index = 0; index < cascade_count; index++) {
        CFStringRef name = CFStringCreateWithCString(kCFAllocatorDefault, cascade[index], kCFStringEncodingUTF8);
        CTFontDescriptorRef item = CTFontDescriptorCreateWithNameAndSize(name, 17.0);
        CFArrayAppendValue(list, item);
        CFRelease(item);
        CFRelease(name);
    }
    CFStringRef baseName = CFStringCreateWithCString(kCFAllocatorDefault, base, kCFStringEncodingUTF8);
    CTFontDescriptorRef baseDescriptor = CTFontDescriptorCreateWithNameAndSize(baseName, 17.0);
    const void *keys[] = {kCTFontCascadeListAttribute};
    const void *values[] = {list};
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef combined = CTFontDescriptorCreateCopyWithAttributes(baseDescriptor, attributes);
    CTFontRef font = CTFontCreateWithFontDescriptor(combined, 17.0, NULL);
    CFRelease(combined);
    CFRelease(attributes);
    CFRelease(baseDescriptor);
    CFRelease(baseName);
    CFRelease(list);
    return font;
}

static CTFontRef font_with_default_cascade(BOOL freshEmoji)
{
    CTFontRef base = CTFontCreateWithName(CFSTR("HelveticaNeue"), 17.0, NULL);
    CFArrayRef defaults = CTFontCopyDefaultCascadeListForLanguages(base, NULL);
    CFMutableArrayRef list = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, defaults);
    if (freshEmoji) {
        for (CFIndex index = 0; index < CFArrayGetCount(list); index++) {
            CTFontDescriptorRef item = (CTFontDescriptorRef)CFArrayGetValueAtIndex(list, index);
            CFStringRef name = (CFStringRef)CTFontDescriptorCopyAttribute(item, kCTFontNameAttribute);
            if (name && CFEqual(name, CFSTR("AppleColorEmoji"))) {
                CTFontDescriptorRef plain = CTFontDescriptorCreateWithNameAndSize(CFSTR("AppleColorEmoji"), 17.0);
                CFMutableCharacterSetRef forced = CFCharacterSetCreateMutable(kCFAllocatorDefault);
                CFCharacterSetAddCharactersInRange(forced, CFRangeMake(0x1F300, 0x700));
                CFCharacterSetAddCharactersInRange(forced, CFRangeMake(0x1F900, 0x200));
                const void *forcedKeys[] = {kCTFontCharacterSetAttribute};
                const void *forcedValues[] = {forced};
                CFDictionaryRef forcedAttributes = CFDictionaryCreate(kCFAllocatorDefault, forcedKeys, forcedValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                CTFontDescriptorRef fresh = CTFontDescriptorCreateCopyWithAttributes(plain, forcedAttributes);
                CFRelease(forcedAttributes);
                CFRelease(forced);
                CFRelease(plain);
                CFArraySetValueAtIndex(list, index, fresh);
                CFRelease(fresh);
            }
            if (name) CFRelease(name);
        }
    }
    CTFontDescriptorRef lastResort = CTFontDescriptorCreateWithNameAndSize(CFSTR("LastResort"), 17.0);
    CFArrayAppendValue(list, lastResort);
    CFRelease(lastResort);
    CTFontDescriptorRef baseDescriptor = CTFontCopyFontDescriptor(base);
    const void *keys[] = {kCTFontCascadeListAttribute};
    const void *values[] = {list};
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef combined = CTFontDescriptorCreateCopyWithAttributes(baseDescriptor, attributes);
    CTFontRef font = CTFontCreateWithFontDescriptor(combined, 17.0, NULL);
    CFRelease(combined);
    CFRelease(attributes);
    CFRelease(baseDescriptor);
    CFRelease(list);
    CFRelease(defaults);
    CFRelease(base);
    return font;
}

static void probe_glyphs(const char *label, CTFontRef font)
{
    UniChar single[] = {'A', 0x0378, 0xE000};
    CGGlyph glyphs[4] = {0};
    BOOL ok = CTFontGetGlyphsForCharacters(font, single, glyphs, 3);
    UniChar pairs[][2] = {{0xD83E, 0xDD72}, {0xD840, 0xDC00}, {0xD83D, 0xDE04}, {0xD834, 0xDD1E}};
    CFStringRef name = CTFontCopyPostScriptName(font);
    printf("fontprobe glyphs %s (%s): BMP all-mapped %d A=%u U+0378=%u U+E000=%u;", label, name ? [(__bridge NSString *)name UTF8String] : "?", ok, glyphs[0], glyphs[1], glyphs[2]);
    for (int index = 0; index < 4; index++) {
        CGGlyph pair[2] = {0, 0};
        BOOL mapped = CTFontGetGlyphsForCharacters(font, pairs[index], pair, 2);
        printf(" plane%d-%04X%04X=%u/%d", pairs[index][0] >= 0xD840 ? 2 : 1, pairs[index][0], pairs[index][1], pair[0], mapped);
    }
    printf("\n");
    fflush(stdout);
    if (name) CFRelease(name);
}

static void child(const char *variant)
{
    CTFontRef helvetica = CTFontCreateWithName(CFSTR("HelveticaNeue"), 17.0, NULL);
    printf("fontprobe variant %s: start\n", variant);
    report("start", 0);
    if (!strcmp(variant, "cascade")) {
        describe_cascade("HelveticaNeue", helvetica);
        CTFontRef ui = CTFontCreateUIFontForLanguage(kCTFontSystemFontType, 17.0, NULL);
        describe_cascade("system", ui);
        CFRelease(ui);
        report("after listing", 0);
    } else if (!strcmp(variant, "lrfont")) {
        CTFontRef lr = CTFontCreateWithName(CFSTR("LastResort"), 17.0, NULL);
        probe_glyphs("LastResort", lr);
        report("after LastResort glyph lookups", 0);
        CTFontRef emoji = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 17.0, NULL);
        probe_glyphs("AppleColorEmoji", emoji);
        report("after AppleColorEmoji glyph lookups", 0);
        CFRelease(lr);
        CFRelease(emoji);
    } else if (!strncmp(variant, "clf-", 4) || !strncmp(variant, "cle-", 4)) {
        CTFontRef font = font_with_default_cascade(variant[2] == 'e');
        report("after building the font", 0);
        NSString *text = text_for(variant + 4);
        if (text)
            typeset(variant + 4, text, font);
        CFRelease(font);
    } else if (!strncmp(variant, "cl-", 3)) {
        const char *last[] = {"LastResort"};
        const char *both[] = {"AppleColorEmoji", "LastResort"};
        CTFontRef font = !strncmp(variant, "cl-both", 7) ? font_with_cascade("HelveticaNeue", both, 2) : font_with_cascade("HelveticaNeue", last, 1);
        describe_cascade(variant, font);
        const char *which = strchr(variant + 3, '-') ? strchr(variant + 3, '-') + 1 : "new";
        NSString *text = text_for(which);
        if (text)
            typeset(which, text, font);
        CFRelease(font);
    } else {
        char copy[128];
        strlcpy(copy, variant, sizeof copy);
        for (char *item = strtok(copy, "+"); item; item = strtok(NULL, "+")) {
            NSString *text = text_for(item);
            if (text)
                typeset(item, text, helvetica);
            else
                printf("fontprobe: unknown %s\n", item);
        }
    }
    CFRelease(helvetica);
}

static NSString *output_path(const char *variant)
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"fontprobe-%s.txt", variant]];
}

REVENANT_CASE(coretext_fallback_probe)
{
    const char *variant = getenv("FONTPROBE_VARIANT");
    if (variant) {
        freopen([output_path(variant) UTF8String], "w", stdout);
        child(variant);
        fflush(stdout);
        return;
    }
    if (negative)
        return;
    char executable[1024];
    uint32_t size = sizeof executable;
    _NSGetExecutablePath(executable, &size);
    const char *variants[] = {"cle-new", "cle-rare", "cle-emoji", "cle-mixed", NULL};
    for (int index = 0; variants[index]; index++) {
        char flag[160];
        snprintf(flag, sizeof flag, "FONTPROBE_VARIANT=%s", variants[index]);
        int count = 0;
        while (environ[count])
            count++;
        char **env = calloc(count + 3, sizeof(char *));
        for (int i = 0; i < count; i++)
            env[i] = environ[i];
        env[count] = flag;
        env[count + 1] = (char *)"REVENANT_ONLY_CASE=coretext_fallback_probe";
        char *argv[] = {executable, NULL};
        pid_t pid = 0;
        int status = 0;
        int result = posix_spawn(&pid, executable, NULL, NULL, argv, env);
        if (result == 0)
            waitpid(pid, &status, 0);
        printf("fontprobe parent: variant %s spawn %d pid %d status %#x\n", variants[index], result, (int)pid, status);
        NSString *text = [NSString stringWithContentsOfFile:output_path(variants[index]) encoding:NSUTF8StringEncoding error:NULL];
        printf("%s", text ? [text UTF8String] : "fontprobe parent: no output file\n");
        fflush(stdout);
        free(env);
    }
}
