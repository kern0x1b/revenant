/* descriptor.m - MTLArgumentDescriptor (iOS 11.0), compared member by member with Apple's own object.
 *
 * Four snapshots are compared, as in the other descriptor cases: a fresh descriptor, one with every member set away
 * from its default, a copy of that one, and the set one after the copy was taken (the copy must not share). Equality
 * and the hash are compared the same way. A disagreement names the member and both values.
 *
 * THE VALIDATOR IS COMPARED IN CHILD PROCESSES. Apple's validator aborts the process on a data type or access it does
 * not accept, so each value is tried in a fork of this process, on Apple's object and on the port's, and the exit
 * status of the two must agree for every value from 0 to 255 (data type) and 0 to 4 (access). A child that aborted is
 * not a failure of this case, it is the answer.
 *
 * NO DEVICE IS CREATED. An argument descriptor asks a device nothing.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <sys/wait.h>
#include <unistd.h>

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static NSDictionary *snapshot(MTLArgumentDescriptor *d)
{
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"dataType"] = [NSString stringWithFormat:@"%ld", (long)d.dataType];
    s[@"index"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.index];
    s[@"arrayLength"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.arrayLength];
    s[@"access"] = [NSString stringWithFormat:@"%ld", (long)d.access];
    s[@"textureType"] = [NSString stringWithFormat:@"%ld", (long)d.textureType];
    s[@"constantBlockAlignment"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.constantBlockAlignment];
    return s;
}

/* Sets every member away from its default. */
static void setEverything(MTLArgumentDescriptor *d)
{
    d.dataType = MTLDataTypeTexture;
    d.index = 3;
    d.arrayLength = 4;
    d.access = MTLBindingAccessReadWrite;
    d.textureType = MTLTextureType2DArray;
    d.constantBlockAlignment = 16;
}

static void compareSides(MTLArgumentDescriptor *apple, MTLArgumentDescriptor *port, NSString *moment)
{
    NSDictionary *a = snapshot(apple), *p = snapshot(port);
    int same = [a isEqualToDictionary:p];
    check(same, ([NSString stringWithFormat:@"%@: the port's members read as Apple's", moment]));
    if (!same) {
        for (NSString *key in [a.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if (![a[key] isEqualToString:p[key]])
                printf("       %s: apple %s, port %s\n", [key UTF8String], [a[key] UTF8String], [p[key] UTF8String]);
        }
    }
}

/* Runs the block in a child process; returns the child's status (0 for a clean exit, the signal number for a crash). */
static int inChild(void (^block)(void))
{
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        freopen("/dev/null", "w", stderr);
        @autoreleasepool { block(); }
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    return WIFEXITED(st) ? 0 : WTERMSIG(st);
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class portClass = NSClassFromString(@"CharonHostMTLArgumentDescriptor");
        check(portClass != nil, @"the port's class is built in this process");
        if (!portClass)
            return 1;

        printf("fresh descriptors (the class method and new)\n");
        compareSides([MTLArgumentDescriptor argumentDescriptor], [portClass argumentDescriptor], @"fresh");
        compareSides([[MTLArgumentDescriptor alloc] init], [[portClass alloc] init], @"new");

        printf("every member set away from its default\n");
        MTLArgumentDescriptor *apple = [MTLArgumentDescriptor argumentDescriptor];
        MTLArgumentDescriptor *port = [portClass argumentDescriptor];
        setEverything(apple);
        setEverything(port);
        compareSides(apple, port, @"set");

        printf("a copy of the set descriptor\n");
        MTLArgumentDescriptor *appleCopy = [apple copy];
        MTLArgumentDescriptor *portCopy = [port copy];
        compareSides(appleCopy, portCopy, @"copy");
        check([portCopy isEqual:port] && [port isEqual:portCopy] && [port hash] == [portCopy hash],
              @"port: a copy is equal to its original, and hashes the same");
        check([appleCopy isEqual:apple] && [apple isEqual:appleCopy], @"apple: a copy is equal to its original (the rule the port follows)");
        check(![port isEqual:[portClass argumentDescriptor]], @"port: a set descriptor is not equal to a fresh one");
        check(![apple isEqual:[MTLArgumentDescriptor argumentDescriptor]], @"apple: a set descriptor is not equal to a fresh one");

        printf("the copy does not share with the original\n");
        apple.index = 9;
        port.index = 9;
        compareSides(appleCopy, portCopy, @"copy after the original changed");
        check(![portCopy isEqual:port], @"port: the copy keeps its own index once the original changed");

        printf("the data types and accesses each side accepts, in child processes (Apple's aborts on the rest)\n");
        int disagree = 0, accessDisagree = 0;
        for (NSUInteger v = 0; v <= 255; v++) {
            int appleStatus = inChild(^{ MTLArgumentDescriptor *a = [MTLArgumentDescriptor argumentDescriptor]; a.dataType = (MTLDataType)v; });
            int portStatus = inChild(^{ MTLArgumentDescriptor *p = [portClass argumentDescriptor]; p.dataType = (MTLDataType)v; });
            if ((appleStatus == 0) != (portStatus == 0)) {
                printf("       dataType %lu: apple status %d, port status %d\n", (unsigned long)v, appleStatus, portStatus);
                disagree++;
            }
        }
        check(disagree == 0, @"dataType: the port accepts and refuses the same values as Apple, from 0 to 255");
        for (NSUInteger v = 0; v <= 4; v++) {
            int appleStatus = inChild(^{ MTLArgumentDescriptor *a = [MTLArgumentDescriptor argumentDescriptor]; a.access = (MTLBindingAccess)v; });
            int portStatus = inChild(^{ MTLArgumentDescriptor *p = [portClass argumentDescriptor]; p.access = (MTLBindingAccess)v; });
            if ((appleStatus == 0) != (portStatus == 0)) {
                printf("       access %lu: apple status %d, port status %d\n", (unsigned long)v, appleStatus, portStatus);
                accessDisagree++;
            }
        }
        check(accessDisagree == 0, @"access: the port accepts and refuses the same values as Apple, from 0 to 4");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
