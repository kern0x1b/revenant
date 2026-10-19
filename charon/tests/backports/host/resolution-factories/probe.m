#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

static const char *appleName(const char *runtime)
{
    size_t prefix = strlen(PREFIX);
    return strncmp(runtime, PREFIX, prefix) == 0 ? runtime + prefix : runtime;
}

static BOOL measured(const char *runtime)
{
    size_t prefix = strlen(PREFIX);
    if (strncmp(runtime, PREFIX, prefix) != 0) return NO;
    const char *name = runtime + prefix;
    size_t length = strlen(name);
    return strncmp(name, "IN", 2) == 0 && length > strlen("ResolutionResult") &&
           strcmp(name + length - strlen("ResolutionResult"), "ResolutionResult") == 0;
}

static BOOL factoryName(const char *selector)
{
    static const char *prefixes[] = { "successWith", "disambiguationWith", "confirmationRequiredWith", "needsValue",
                                      "notRequired", "unsupported", NULL };
    for (int i = 0; prefixes[i]; i++) {
        if (strncmp(selector, prefixes[i], strlen(prefixes[i])) == 0) return YES;
    }
    return NO;
}

static void reader(id result, NSString *name, NSMutableString *out)
{
    if (![result respondsToSelector:NSSelectorFromString(name)]) {
        [out appendFormat:@" %@=absent", name];
        return;
    }
    id value = [result valueForKey:name];
    if (!value) {
        [out appendFormat:@" %@=nil", name];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        [out appendFormat:@" %@=%ld", name, (long)[value integerValue]];
    } else if ([value isKindOfClass:[NSArray class]]) {
        [out appendFormat:@" %@=array%lu", name, (unsigned long)[value count]];
    } else {
        [out appendFormat:@" %@=%s", name, appleName(class_getName([value class]))];
    }
}

static void measure(Class cls, const char *appleClass)
{
    unsigned int count = 0;
    Method *methods = class_copyMethodList(object_getClass(cls), &count);
    for (unsigned int i = 0; i < count; i++) {
        SEL selector = method_getName(methods[i]);
        const char *name = sel_getName(selector);
        if (!factoryName(name)) continue;
        NSMethodSignature *signature = [cls methodSignatureForSelector:selector];
        if (!signature || strcmp([signature methodReturnType], "@") != 0) continue;
        NSUInteger arguments = [signature numberOfArguments];
        BOOL skip = NO;
        for (NSUInteger a = 2; a < arguments; a++) {
            const char *type = [signature getArgumentTypeAtIndex:a];
            if (type[0] != '@' && type[0] != 'q' && type[0] != 'l' && type[0] != 'i' && type[0] != 'Q' &&
                type[0] != 'L' && type[0] != 'I' && type[0] != 's' && type[0] != 'S' && type[0] != 'c' &&
                type[0] != 'C' && type[0] != 'B' && type[0] != 'd' && type[0] != 'f') {
                skip = YES;
            }
        }
        if (skip) {
            printf("%s %s skipped: a struct argument\n", appleClass, name);
            continue;
        }
        for (int pass = 0; pass < 2; pass++) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:cls];
            [invocation setSelector:selector];
            NSMutableString *argText = [NSMutableString string];
            for (NSUInteger a = 2; a < arguments; a++) {
                const char *type = [signature getArgumentTypeAtIndex:a];
                NSString *keyword = [NSString stringWithUTF8String:name];
                NSArray *parts = [keyword componentsSeparatedByString:@":"];
                NSString *part = (a - 2 < parts.count) ? parts[a - 2] : @"";
                if (type[0] == '@') {
                    id value = nil;
                    if (pass == 1 && [part rangeOfString:@"Disambiguate"].location != NSNotFound) {
                        value = @[];
                    }
                    [invocation setArgument:&value atIndex:a];
                    [argText appendFormat:@" %s", value ? "[]" : "nil"];
                } else if (type[0] == 'd') {
                    double value = 1.0;
                    [invocation setArgument:&value atIndex:a];
                    [argText appendString:@" 1.0"];
                } else if (type[0] == 'f') {
                    float value = 1.0f;
                    [invocation setArgument:&value atIndex:a];
                    [argText appendString:@" 1.0"];
                } else {
                    long long value = 1;
                    [invocation setArgument:&value atIndex:a];
                    [argText appendString:@" 1"];
                }
            }
            [invocation invoke];
            id result = nil;
            [invocation getReturnValue:&result];
            NSMutableString *line = [NSMutableString stringWithFormat:@"%s %s pass=%s args=[%@ ] ->", appleClass, name,
                                     pass == 0 ? "nil" : "empty", argText];
            if (!result) {
                [line appendString:@" nil"];
            } else {
                [line appendFormat:@" %s", appleName(class_getName([result class]))];
                reader(result, @"resolutionResultCode", line);
                reader(result, @"itemToConfirm", line);
                reader(result, @"unsupportedReason", line);
                reader(result, @"confirmationReason", line);
                reader(result, @"disambiguationItems", line);
            }
            printf("%s\n", [line UTF8String]);
        }
    }
    free(methods);
}

static void charon_stalled(int signal_number)
{
    (void)signal_number;
    static const char message[] = "TIMEOUT: a factory of this class did not return in 20 seconds\n";
    write(STDOUT_FILENO, message, sizeof message - 1);
    _exit(124);
}

int main(int argc, const char *argv[])
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        if (argc < 2) {
            unsigned int total = 0;
            Class *classes = objc_copyClassList(&total);
            for (unsigned int i = 0; i < total; i++) {
                const char *runtime = class_getName(classes[i]);
                if (measured(runtime)) printf("%s\n", appleName(runtime));
            }
            free(classes);
            return 0;
        }
        const char *apple = argv[1];
        NSString *runtime = [NSString stringWithFormat:@"%s%s", PREFIX, apple];
        Class cls = NSClassFromString(runtime);
        if (!cls) {
            printf("%s missing\n", apple);
            return 2;
        }
        signal(SIGALRM, charon_stalled);
        alarm(20);
        measure(cls, apple);
        alarm(0);
    }
    return 0;
}
