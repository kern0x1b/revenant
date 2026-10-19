//
//  harness.m
//  The runtime of the generated call test, in as many words as its header.
//

#import "harness.h"

#import <fcntl.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <sys/wait.h>
#import <unistd.h>

struct CharonCallLog {
    NSMutableDictionary *instances;   // the object each class's own case made, by name
};

static int charon_call_fd = -1;
static NSString *charon_call_path;

void CharonCallOpen(const char *path)
{
    charon_call_path = [NSString stringWithUTF8String:path];
    charon_call_fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
}

void CharonCallClose(void)
{
    if (charon_call_fd >= 0) {
        close(charon_call_fd);
        charon_call_fd = -1;
    }
}

// One line, appended to the shared file: a child writes its own and the parent reads them all
// back, so neither needs the other's memory and the file is the digest the two runs compare.
static void charon_call_say(NSString *line)
{
    if (charon_call_fd >= 0) {
        NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        write(charon_call_fd, [data bytes], [data length]);
    }
}

CharonCallLog *CharonCallLogCreate(void)
{
    CharonCallLog *log = calloc(1, sizeof(CharonCallLog));
    log->instances = [[NSMutableDictionary alloc] init];
    return log;
}

Class CharonCallClass(CharonCallLog *log, NSString *name)
{
    Class cls = NSClassFromString(name);
    charon_call_say(cls ? [NSString stringWithFormat:@"present %@", name]
                        : [NSString stringWithFormat:@"missing %@", name]);
    (void)log;
    return cls;
}

id CharonCallInstance(CharonCallLog *log, Class cls)
{
    id remembered = [log->instances objectForKey:NSStringFromClass(cls)];
    return remembered ? remembered : [cls alloc];
}

void CharonCallRemember(CharonCallLog *log, Class cls, id instance)
{
    if (instance) {
        // Keyed by the class's name, not by the Class itself: a Class is not an NSCopying key,
        // and the name is what the report prints anyway.
        [log->instances setObject:instance forKey:NSStringFromClass(cls)];
    }
}

BOOL CharonCallSelector(CharonCallLog *log, Class cls, id receiver, SEL selector)
{
    (void)log;
    NSString *label = [NSString stringWithFormat:@"%@ %@", NSStringFromClass(cls),
                       NSStringFromSelector(selector)];
    if ([receiver respondsToSelector:selector]) {
        charon_call_say([NSString stringWithFormat:@"answered %@", label]);
        return YES;
    }
    charon_call_say([NSString stringWithFormat:@"missing %@", label]);
    return NO;
}

static NSString *charon_call_describe(id value)
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

void CharonCallNoted(CharonCallLog *log, Class cls, SEL selector, id value)
{
    (void)log;
    charon_call_say([NSString stringWithFormat:@"answered %@ %@ -> %@", NSStringFromClass(cls),
                     NSStringFromSelector(selector), charon_call_describe(value)]);
}

void CharonCallRaised(CharonCallLog *log, Class cls, SEL selector, NSException *raised)
{
    (void)log;
    charon_call_say([NSString stringWithFormat:@"refused %@ %@ raised %@: %@", NSStringFromClass(cls),
                     NSStringFromSelector(selector), [raised name],
                     [raised reason] ? [raised reason] : @""]);
}

void CharonCallProperty(CharonCallLog *log, Class cls, id object, NSString *name,
                        NSString *getter, NSString *setter)
{
    SEL reading = NSSelectorFromString(getter);
    SEL writing = setter ? NSSelectorFromString(setter) : NULL;
    if (!CharonCallSelector(log, cls, object, reading)) {
        return;
    }
    __unsafe_unretained id value = ((id (*)(id, SEL))objc_msgSend)(object, reading);
    charon_call_say([NSString stringWithFormat:@"answered %@ -%@ -> %@", NSStringFromClass(cls),
                     name, charon_call_describe(value)]);
    if (writing && [object respondsToSelector:writing]) {
        // A writable property is written and read back, which the getter-only half of a test
        // never touches: a setter that stores nothing answers its getter with nil forever.
        ((void (*)(id, SEL, id))objc_msgSend)(object, writing, nil);
        __unsafe_unretained id after = ((id (*)(id, SEL))objc_msgSend)(object, reading);
        charon_call_say([NSString stringWithFormat:@"answered %@ -%@= -> %@", NSStringFromClass(cls),
                         getter, charon_call_describe(after)]);
    }
}

int CharonCallIsolated(const char *label, void (*run)(CharonCallLog *), CharonCallLog *log)
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
        charon_call_say([NSString stringWithFormat:@"crashed %s (status %d)", label, status]);
    }
    return status;
}

unsigned CharonCallReport(NSString *title)
{
    CharonCallClose();
    NSString *text = [NSString stringWithContentsOfFile:charon_call_path encoding:NSUTF8StringEncoding
                                                 error:NULL] ?: @"";
    NSMutableArray *missing = [NSMutableArray array];
    NSMutableArray *crashed = [NSMutableArray array];
    NSMutableSet *present = [NSMutableSet set];
    unsigned checks = 0, refused = 0;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"present "]) {
            // A count of classes, not of lookups: the class case looks its class up and so does
            // every one of its members, and the number of the former is what a reader wants.
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
