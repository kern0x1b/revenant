#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"
#import "directionaledges-cases.h"
#import "directionaledges-expectations.h"

static NSString *image_of(void *pointer)
{
    Dl_info info;
    if (!pointer || !dladdr(pointer, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static NSString *image_of_method(Class class, SEL selector, BOOL classMethod)
{
    Method method = classMethod ? class_getClassMethod(class, selector) : class_getInstanceMethod(class, selector);
    return method ? image_of((void *)method_getImplementation(method)) : @"<missing>";
}

static void check_sources(void)
{
    NSString *library = @"libUIKitBackports.dylib";
    CHECK_EQUAL(image_of((void *)&NSStringFromDirectionalEdgeInsets), library, "NSStringFromDirectionalEdgeInsets comes from the backports");
    CHECK_EQUAL(image_of((void *)&NSDirectionalEdgeInsetsFromString), library, "NSDirectionalEdgeInsetsFromString comes from the backports");
    CHECK_EQUAL(image_of((void *)&NSDirectionalEdgeInsetsZero), library, "NSDirectionalEdgeInsetsZero comes from the backports");
    CHECK_EQUAL(image_of_method([NSValue class], @selector(valueWithDirectionalEdgeInsets:), YES), library,
                "+[NSValue valueWithDirectionalEdgeInsets:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSValue class], @selector(directionalEdgeInsetsValue), NO), library,
                "-[NSValue directionalEdgeInsetsValue] comes from the backports");
    CHECK_EQUAL(image_of_method([NSCoder class], @selector(encodeDirectionalEdgeInsets:forKey:), NO), library,
                "-[NSCoder encodeDirectionalEdgeInsets:forKey:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSCoder class], @selector(decodeDirectionalEdgeInsetsForKey:), NO), library,
                "-[NSCoder decodeDirectionalEdgeInsetsForKey:] comes from the backports");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_sources();

        DirectionalEdgesRecorder *recorder = [DirectionalEdgesRecorder new];
        DirectionalEdgesImplementation implementation = {
            .prefix = @"", .zero = &NSDirectionalEdgeInsetsZero,
            .string = NSStringFromDirectionalEdgeInsets, .parse = NSDirectionalEdgeInsetsFromString};
        directionaledges_run(implementation, recorder);

        NSData *json = [@(directionaledges_expectations) dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([name hasPrefix:@"objCType."])
                continue;
            NSString *label = [NSString stringWithFormat:@"%@ answers what the host's UIKit answers", name];
            CHECK_EQUAL(recorder.records[name], expected[name], label.UTF8String);
        }
        for (NSString *name in expected)
            if ([name hasPrefix:@"objCType."])
                CHECK([recorder.records[name] hasPrefix:@"{NSDirectionalEdgeInsets="], "the value carries the structure's own encoding");
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
