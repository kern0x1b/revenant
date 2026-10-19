#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../device/suitedefaults-cases.h"

void host_attach_prefixed(const char *prefix);

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        NSString *name = [NSString stringWithFormat:@"charon.suite.%@", [[NSUUID UUID] UUIDString]];
        NSString *portName = [name stringByAppendingString:@".port"];
        NSMutableArray *system = [NSMutableArray array], *port = [NSMutableArray array];
        suite_run(^{ return [[NSUserDefaults alloc] initWithSuiteName:name]; }, ^(NSString *n, NSString *v) { [system addObject:@[n, v]]; });
        suite_run(^{
            NSUserDefaults *d = [NSUserDefaults alloc];
            CFRetain((__bridge CFTypeRef)d);
            return ((NSUserDefaults * (*)(id, SEL, id))objc_msgSend)(d, NSSelectorFromString(@"initCharonHostWithSuiteName:"), portName);
        }, ^(NSString *n, NSString *v) { [port addObject:@[n, v]]; });
        int checks = 0, failures = 0;
        NSMutableString *header = [NSMutableString stringWithString:@"static const char *const suitedefaults_expectations[] = {\n"];
        for (NSUInteger index = 0; index < system.count; index++) {
            checks++;
            NSString *a = system[index][1], *b = index < port.count ? port[index][1] : @"(missing)";
            if ([a isEqual:b]) {
                printf("ok   %s: %s\n", [system[index][0] UTF8String], a.UTF8String);
            } else {
                failures++;
                printf("FAIL %s: the system answers %s, the backport answers %s\n", [system[index][0] UTF8String], a.UTF8String, b.UTF8String);
            }
            NSString *escaped = [[[a stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
            [header appendFormat:@"    \"%@\",\n", escaped];
        }
        [header appendString:@"};\n"];
        NSUserDefaults *standard = [NSUserDefaults standardUserDefaults];
        [standard removePersistentDomainForName:name];
        [standard removePersistentDomainForName:portName];
        if (!failures && getenv("SUITE_EXPECTATIONS"))
            [header writeToFile:@(getenv("SUITE_EXPECTATIONS")) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("checks=%d failures=%d\n", checks, failures);
        return failures;
    }
}
