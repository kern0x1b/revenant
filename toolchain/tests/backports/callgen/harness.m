#import "harness.h"

#import <fcntl.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <sys/wait.h>
#import <unistd.h>

struct RevenantCallLog {
    NSMutableDictionary *instances;
};

static int revenant_call_fd = -1;
static NSString *revenant_call_path;

void RevenantCallOpen(const char *path)
{
    revenant_call_path = [NSString stringWithUTF8String:path];
    revenant_call_fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
}

void RevenantCallClose(void)
{
    if (revenant_call_fd >= 0) {
        close(revenant_call_fd);
        revenant_call_fd = -1;
    }
}

static void revenant_call_say(NSString *line)
{
    if (revenant_call_fd >= 0) {
        NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        write(revenant_call_fd, [data bytes], [data length]);
    }
}

RevenantCallLog *RevenantCallLogCreate(void)
{
    RevenantCallLog *log = calloc(1, sizeof(RevenantCallLog));
    log->instances = [[NSMutableDictionary alloc] init];
    return log;
}

Class RevenantCallClass(RevenantCallLog *log, NSString *name)
{
    Class cls = NSClassFromString(name);
    revenant_call_say(cls ? [NSString stringWithFormat:@"present %@", name]
                        : [NSString stringWithFormat:@"missing %@", name]);
    (void)log;
    return cls;
}

id RevenantCallInstance(RevenantCallLog *log, Class cls)
{
    id remembered = [log->instances objectForKey:NSStringFromClass(cls)];
    return remembered ? remembered : [cls alloc];
}

void RevenantCallRemember(RevenantCallLog *log, Class cls, id instance)
{
    if (instance) {
        [log->instances setObject:instance forKey:NSStringFromClass(cls)];
    }
}

BOOL RevenantCallSelector(RevenantCallLog *log, Class cls, id receiver, SEL selector)
{
    (void)log;
    NSString *label = [NSString stringWithFormat:@"%@ %@", NSStringFromClass(cls),
                       NSStringFromSelector(selector)];
    if ([receiver respondsToSelector:selector]) {
        revenant_call_say([NSString stringWithFormat:@"answered %@", label]);
        return YES;
    }
    revenant_call_say([NSString stringWithFormat:@"missing %@", label]);
    return NO;
}

static NSString *revenant_call_describe(id value)
{
    if (!value) {
        return @"nil";
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"\"%@\"", value];
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSSet class]] ||
        [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSOrderedSet class]]) {
        return [NSString stringWithFormat:@"%lu item(s)", (unsigned long)[value count]];
    }
    if ([value isKindOfClass:[NSData class]]) {
        return [NSString stringWithFormat:@"%lu byte(s)", (unsigned long)[(NSData *)value length]];
    }
    return [NSString stringWithFormat:@"<%@>", NSStringFromClass([value class])];
}

void RevenantCallNoted(RevenantCallLog *log, Class cls, SEL selector, id value)
{
    (void)log;
    revenant_call_say([NSString stringWithFormat:@"answered %@ %@ -> %@", NSStringFromClass(cls),
                     NSStringFromSelector(selector), revenant_call_describe(value)]);
}

void RevenantCallRaised(RevenantCallLog *log, Class cls, SEL selector, NSException *raised)
{
    (void)log;
    revenant_call_say([NSString stringWithFormat:@"refused %@ %@ raised %@: %@", NSStringFromClass(cls),
                     NSStringFromSelector(selector), [raised name],
                     [raised reason] ? [raised reason] : @""]);
}

void RevenantCallProperty(RevenantCallLog *log, Class cls, id object, NSString *name,
                        NSString *getter, NSString *setter)
{
    SEL reading = NSSelectorFromString(getter);
    SEL writing = setter ? NSSelectorFromString(setter) : NULL;
    if (!RevenantCallSelector(log, cls, object, reading)) {
        return;
    }
    __unsafe_unretained id value = ((id (*)(id, SEL))objc_msgSend)(object, reading);
    revenant_call_say([NSString stringWithFormat:@"answered %@ -%@ -> %@", NSStringFromClass(cls),
                     name, revenant_call_describe(value)]);
    if (writing && [object respondsToSelector:writing]) {
        ((void (*)(id, SEL, id))objc_msgSend)(object, writing, nil);
        __unsafe_unretained id after = ((id (*)(id, SEL))objc_msgSend)(object, reading);
        revenant_call_say([NSString stringWithFormat:@"answered %@ -%@= -> %@", NSStringFromClass(cls),
                         getter, revenant_call_describe(after)]);
    }
}

int RevenantCallIsolated(const char *label, void (*run)(RevenantCallLog *), RevenantCallLog *log)
{
    fflush(NULL);
    pid_t child = fork();
    if (child == 0) {
        run(log);
        fflush(NULL);
        _exit(0);
    }
    if (child < 0) {
        run(log);
        return 0;
    }
    int status = 0;
    waitpid(child, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        revenant_call_say([NSString stringWithFormat:@"crashed %s (status %d)", label, status]);
    }
    return status;
}

unsigned RevenantCallReport(NSString *title)
{
    RevenantCallClose();
    NSString *text = [NSString stringWithContentsOfFile:revenant_call_path encoding:NSUTF8StringEncoding
                                                 error:NULL] ?: @"";
    NSMutableArray *missing = [NSMutableArray array];
    NSMutableArray *crashed = [NSMutableArray array];
    NSMutableSet *present = [NSMutableSet set];
    unsigned checks = 0, refused = 0;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"present "]) {
            [present addObject:[line substringFromIndex:8]];
        } else if ([line hasPrefix:@"missing "]) {
            [missing addObject:[line substringFromIndex:8]];
        } else if ([line hasPrefix:@"answered "]) {
            checks++;
        } else if ([line hasPrefix:@"refused "]) {
            checks++;
            refused++;
        } else if ([line hasPrefix:@"crashed "]) {
            [crashed addObject:[line substringFromIndex:8]];
        }
    }
    printf("%s: %lu distinct classes present, %u member checks (%u refused the neutral value), "
           "%lu not answered, %lu crashed\n",
           [title UTF8String], (unsigned long)present.count, checks, refused,
           (unsigned long)missing.count, (unsigned long)crashed.count);
    for (NSString *entry in crashed) {
        printf("  CRASHED %s\n", [entry UTF8String]);
    }
    for (NSString *entry in missing) {
        printf("  NOT ANSWERED %s\n", [entry UTF8String]);
    }
    return (missing.count || crashed.count) ? 1u : 0u;
}
