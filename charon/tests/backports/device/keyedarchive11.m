#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"
#import "keyedarchive11-cases.h"
#import "keyedarchive11-expectations.h"

static NSString *image_of_method(Class class, SEL selector, BOOL classMethod)
{
    Method method = classMethod ? class_getClassMethod(class, selector) : class_getInstanceMethod(class, selector);
    if (!method)
        return @"<missing>";
    Dl_info info;
    void *implementation = (void *)method_getImplementation(method);
    if (!dladdr(implementation, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static void check_sources(void)
{
    NSString *library = @"libFoundationBackports.dylib";
    CHECK_EQUAL(image_of_method([NSKeyedArchiver class], @selector(initRequiringSecureCoding:), NO), library,
                "-[NSKeyedArchiver initRequiringSecureCoding:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSKeyedArchiver class], @selector(encodedData), NO), library,
                "-[NSKeyedArchiver encodedData] comes from the backports");
    CHECK_EQUAL(image_of_method([NSKeyedArchiver class], @selector(archivedDataWithRootObject:requiringSecureCoding:error:), YES), library,
                "+[NSKeyedArchiver archivedDataWithRootObject:requiringSecureCoding:error:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSKeyedUnarchiver class], @selector(initForReadingFromData:error:), NO), library,
                "-[NSKeyedUnarchiver initForReadingFromData:error:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSKeyedUnarchiver class], @selector(unarchivedObjectOfClass:fromData:error:), YES), library,
                "+[NSKeyedUnarchiver unarchivedObjectOfClass:fromData:error:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSKeyedUnarchiver class], @selector(unarchivedObjectOfClasses:fromData:error:), YES), library,
                "+[NSKeyedUnarchiver unarchivedObjectOfClasses:fromData:error:] comes from the backports");
}
static void check_repeated_finish(void)
{
    NSMutableData *buffer = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:buffer];
    [archiver encodeObject:@"payload" forKey:@"root"];
    [archiver finishEncoding];
    NSUInteger length = buffer.length;
    BOOL raised = NO;
    @try {
        [archiver finishEncoding];
    } @catch (NSException *exception) {
        raised = YES;
    }
    CHECK(!raised, "a second -finishEncoding does not raise");
    CHECK(buffer.length == length, "a second -finishEncoding leaves the archive alone");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_sources();
        check_repeated_finish();

        KeyedArchive11Recorder *recorder = [KeyedArchive11Recorder new];
        keyedarchive11_run(@"", recorder);

        NSData *json = [@(keyedarchive11_expectations) dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *label = [NSString stringWithFormat:@"%@ answers what the host's Foundation answers", name];
            CHECK_EQUAL(recorder.records[name], expected[name], label.UTF8String);
        }
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
