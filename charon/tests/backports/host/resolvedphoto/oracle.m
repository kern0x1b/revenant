#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include <string.h>

// AVCaptureResolvedPhotoSettings of the port (built under the name CharonHostAVCaptureResolvedPhotoSettings) against
// the host's own class: every member the SDK the package builds with declares (read from its header by run.sh, one
// selector per line in the file given as argument 1) is answered by the port with the host's type encoding, and the
// port holds no ivar the compiler synthesized for a header property, the sign of a member answered by a zero nobody
// wrote. Values are not compared here: the host's class is made only by a capture, and a capture on the host needs a
// camera and its permission; tests/backports/device/photooutput10.m holds the values to real captures.

static int checks, failures;

static void check(BOOL passed, NSString *what)
{
    checks++;
    if (!passed)
        failures++;
    printf("%s %s\n", passed ? "ok  " : "FAIL", what.UTF8String);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: oracle <declared-selectors>\n");
            return 2;
        }
        Class system = [AVCaptureResolvedPhotoSettings class];
        Class ours = NSClassFromString(@"CharonHostAVCaptureResolvedPhotoSettings");
        check(system != Nil && ours != Nil && system != ours, @"the host's class and the port's are both here, apart");
        NSString *list = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:NULL];
        NSMutableArray *declared = [NSMutableArray array];
        for (NSString *line in [list componentsSeparatedByString:@"\n"])
            if (line.length)
                [declared addObject:line];
        check(declared.count > 0, [NSString stringWithFormat:@"the SDK header declares %lu members", (unsigned long)declared.count]);

        for (NSString *name in declared) {
            SEL selector = NSSelectorFromString(name);
            Method host = class_getInstanceMethod(system, selector), port = class_getInstanceMethod(ours, selector);
            if (!host) {
                printf("note %s: the host's class does not answer it\n", name.UTF8String);
                check(port != NULL, [NSString stringWithFormat:@"%@ is answered by the port", name]);
                continue;
            }
            const char *hostTypes = method_getTypeEncoding(host), *portTypes = port ? method_getTypeEncoding(port) : "";
            check(port != NULL && strcmp(hostTypes, portTypes) == 0,
                  [NSString stringWithFormat:@"%@ is answered by the port as by the host: %s / %s", name, hostTypes, portTypes]);
        }

        // Every property the host's class has that the SDK header declares: the port answers it too.
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(system, &count);
        for (unsigned int i = 0; i < count; i++) {
            const char *attribute = property_copyAttributeValue(properties[i], "G");
            NSString *getter = attribute ? @(attribute) : @(property_getName(properties[i]));
            free((void *)attribute);
            if (![declared containsObject:getter]) {
                printf("note %s: a property of the host's class that the SDK header does not declare\n", getter.UTF8String);
                continue;
            }
            check([ours instancesRespondToSelector:NSSelectorFromString(getter)], [NSString stringWithFormat:@"the host's property %@ is the port's too", getter]);
        }
        free(properties);

        // No ivar the compiler synthesized for a declared property: its getter would answer a zero.
        unsigned int ivars = 0;
        Ivar *list_ = class_copyIvarList(ours, &ivars);
        for (unsigned int i = 0; i < ivars; i++) {
            NSString *ivar = @(ivar_getName(list_[i]));
            if (![ivar hasPrefix:@"_"])
                continue;
            NSString *bare = [ivar substringFromIndex:1];
            NSString *getter = [@"is" stringByAppendingString:[[bare substringToIndex:1].uppercaseString stringByAppendingString:[bare substringFromIndex:1]]];
            BOOL synthesized = [declared containsObject:bare] || [declared containsObject:getter];
            BOOL own = [ivar hasPrefix:@"_charon"] || [ivar isEqualToString:@"_internal"];
            if (!synthesized && !own) {
                // A property of the host's newer SDK, synthesized in this host build only: the package's SDK does not
                // declare it, so the package build has no such ivar.
                printf("note the port's ivar %s is synthesized for a property the SDK header does not declare\n", ivar.UTF8String);
                continue;
            }
            check(!synthesized, [NSString stringWithFormat:@"the port's ivar %@ is its own, not one synthesized for a declared property", ivar]);
        }
        free(list_);
        printf("%d checks, %d failed\n", checks, failures);
    }
    return failures ? 1 : 0;
}
