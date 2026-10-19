#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"
#import "foundation11-cases.h"
#import "foundation11-expectations.h"

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

static NSString *image_of_pointer_name(void)
{
    Dl_info info;
    if (!dladdr((void *)&NSSecureUnarchiveFromDataTransformerName, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static void check_sources(void)
{
    NSString *library = @"libFoundationBackports.dylib";
    NSArray *instance = @[@[@"NSArray", @"writeToURL:error:"], @[@"NSArray", @"initWithContentsOfURL:error:"],
                          @[@"NSDictionary", @"writeToURL:error:"], @[@"NSDictionary", @"initWithContentsOfURL:error:"],
                          @[@"NSURLComponents", @"percentEncodedQueryItems"], @[@"NSURLComponents", @"setPercentEncodedQueryItems:"],
                          @[@"NSCoder", @"decodeValueOfObjCType:at:size:"]];
    for (NSArray *pair in instance) {
        NSString *name = [NSString stringWithFormat:@"-[%@ %@] comes from the backports", pair[0], pair[1]];
        CHECK_EQUAL(image_of_method(NSClassFromString(pair[0]), NSSelectorFromString(pair[1]), NO), library, name.UTF8String);
    }
    CHECK_EQUAL(image_of_method([NSArray class], @selector(arrayWithContentsOfURL:error:), YES), library,
                "+[NSArray arrayWithContentsOfURL:error:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSDictionary class], @selector(dictionaryWithContentsOfURL:error:), YES), library,
                "+[NSDictionary dictionaryWithContentsOfURL:error:] comes from the backports");
    CHECK_EQUAL(image_of_pointer_name(), library, "NSSecureUnarchiveFromDataTransformerName comes from the backports");
}

static void check_registration(void)
{
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];
    CHECK(transformer != nil, "the transformer is registered under its name");
    CHECK_EQUAL(NSStringFromClass([transformer class]), @"NSSecureUnarchiveFromDataTransformer", "the registered transformer is ours");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_sources();
        check_registration();

        Foundation11Recorder *recorder = [Foundation11Recorder new];
        Foundation11Implementation implementation = {.prefix = @"", .transformer = [NSSecureUnarchiveFromDataTransformer class]};
        foundation11_run(implementation, recorder);

        NSData *json = [@(foundation11_expectations) dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *label = [NSString stringWithFormat:@"%@ answers what the host's Foundation answers", name];
            CHECK_EQUAL(recorder.records[name], expected[name], label.UTF8String);
        }
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
