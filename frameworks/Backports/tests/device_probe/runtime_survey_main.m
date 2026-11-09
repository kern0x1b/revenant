#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static BOOL revenant_contains(const char *text, const char *needle)
{
    return !needle || !*needle || strcasestr(text, needle) != NULL;
}

static void revenant_classes(const char *classPattern, const char *methodPattern)
{
    unsigned count = 0;
    Class *classes = objc_copyClassList(&count);
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned index = 0; index < count; index++) {
        const char *name = class_getName(classes[index]);
        if (revenant_contains(name, classPattern))
            [names addObject:@(name)];
    }
    free(classes);
    [names sortUsingSelector:@selector(compare:)];
    for (NSString *name in names) {
        Class cls = objc_getClass(name.UTF8String);
        BOOL printed = NO;
        for (int meta = 0; meta < 2; meta++) {
            Class target = meta ? object_getClass(cls) : cls;
            unsigned methods = 0;
            Method *list = class_copyMethodList(target, &methods);
            for (unsigned method = 0; method < methods; method++) {
                const char *selector = sel_getName(method_getName(list[method]));
                if (!revenant_contains(selector, methodPattern))
                    continue;
                if (!printed) {
                    Class parent = class_getSuperclass(cls);
                    printf("%s : %s\n", name.UTF8String, parent ? class_getName(parent) : "-");
                    printed = YES;
                }
                printf("  %c%s  %s\n", meta ? '+' : '-', selector, method_getTypeEncoding(list[method]));
            }
            free(list);
        }
        if (methodPattern && *methodPattern) {
            unsigned ivars = 0;
            Ivar *list = class_copyIvarList(cls, &ivars);
            for (unsigned ivar = 0; ivar < ivars; ivar++) {
                const char *ivarName = ivar_getName(list[ivar]);
                if (revenant_contains(ivarName, methodPattern)) {
                    if (!printed) {
                        printf("%s\n", name.UTF8String);
                        printed = YES;
                    }
                    printf("  ivar %s  %s\n", ivarName, ivar_getTypeEncoding(list[ivar]));
                }
            }
            free(list);
        }
    }
}

static void revenant_symbols(int count, char **names)
{
    for (int index = 0; index < count; index++)
        printf("%s %s\n", names[index], dlsym(RTLD_DEFAULT, names[index]) ? "present" : "absent");
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc < 3) {
        fprintf(stderr, "usage: %s classes CLASSPATTERN [METHODPATTERN] | symbols NAME...\n", argv[0]);
        return 2;
    }
    @autoreleasepool {
        dlopen("/System/Library/PrivateFrameworks/MediaToolbox.framework/MediaToolbox", RTLD_NOW);
        dlopen("/System/Library/PrivateFrameworks/Celestial.framework/Celestial", RTLD_NOW);
        dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_NOW);
        if (strcmp(argv[1], "classes") == 0)
            revenant_classes(argv[2], argc > 3 ? argv[3] : "");
        else if (strcmp(argv[1], "symbols") == 0)
            revenant_symbols(argc - 2, argv + 2);
    }
    return 0;
}
