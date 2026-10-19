#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../device/appgroup-cases.h"

void host_attach_prefixed(const char *prefix);

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        NSString *realHome = NSHomeDirectory();
        NSString *home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [[NSFileManager defaultManager] createDirectoryAtPath:home withIntermediateDirectories:YES attributes:nil error:NULL];
        setenv("HOME", home.UTF8String, 1);
        setenv("CFFIXED_USER_HOME", home.UTF8String, 1);
        NSFileManager *manager = [NSFileManager defaultManager];
        int checks = 0, failures = 0;
        NSMutableString *header = [NSMutableString stringWithString:@"static const char *const appgroup_expectations[] = {\n"];
        for (NSString *identifier in APPGROUP_IDENTIFIERS) {
            NSString *system = appgroup_relative([manager containerURLForSecurityApplicationGroupIdentifier:identifier], realHome);
            NSURL *ours = ((NSURL * (*)(id, SEL, id))objc_msgSend)(manager, NSSelectorFromString(@"charonHost_containerURLForSecurityApplicationGroupIdentifier:"), identifier);
            NSString *answer = appgroup_relative(ours, home);
            checks++;
            if ([system isEqual:answer]) {
                printf("ok   %s: %s\n", identifier.UTF8String, system.UTF8String);
            } else {
                failures++;
                printf("FAIL %s: the system answers %s, the backport answers %s\n", identifier.UTF8String, system.UTF8String, answer.UTF8String);
            }
            [header appendFormat:@"    \"%@\",\n", system];
            if (ours)
                [manager removeItemAtURL:ours error:NULL];
        }
        [header appendString:@"};\n"];
        if (!failures && getenv("APPGROUP_EXPECTATIONS"))
            [header writeToFile:@(getenv("APPGROUP_EXPECTATIONS")) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("checks=%d failures=%d\n", checks, failures);
        return failures;
    }
}
