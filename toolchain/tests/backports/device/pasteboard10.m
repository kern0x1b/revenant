#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"
#import "pasteboard10-cases.h"
#import "pasteboard10-expectations.h"

static NSString *image_of_method(Class class, SEL selector)
{
    Method method = class_getInstanceMethod(class, selector);
    if (!method)
        return @"<missing>";
    Dl_info info;
    if (!dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static void check_sources(void)
{
    for (NSString *name in @[@"hasStrings", @"hasURLs", @"hasImages", @"hasColors"]) {
        NSString *image = image_of_method([UIPasteboard class], NSSelectorFromString(name));
        revenant_check([image isEqualToString:@"libUIKitBackports.dylib"], [NSString stringWithFormat:@"-[UIPasteboard %@] comes from the backports", name].UTF8String, image);
    }
    for (NSString *name in @[@"UIPasteboardTypeListString", @"UIPasteboardTypeListURL", @"UIPasteboardTypeListImage", @"UIPasteboardTypeListColor"]) {
        void *symbol = dlsym(RTLD_DEFAULT, name.UTF8String);
        Dl_info info;
        NSString *image = (symbol && dladdr(symbol, &info) && info.dli_fname) ? @(info.dli_fname).lastPathComponent : @"<missing>";
        revenant_check([image isEqualToString:@"UIKit"], [NSString stringWithFormat:@"%@ is the release's own", name].UTF8String, image);
        NSArray *__unsafe_unretained list = symbol ? *(NSArray *__unsafe_unretained *)symbol : nil;
        revenant_check([list isKindOfClass:[NSArray class]] && list.count > 0,
                      [NSString stringWithFormat:@"%@ is a non-empty array", name].UTF8String,
                      [NSString stringWithFormat:@"count=%lu", (unsigned long)list.count]);
        printf("  %s count=%lu%s\n", name.UTF8String, (unsigned long)list.count,
               list.count == 1 ? " (one entry: storing under the first is the only choice)" : "");
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        (void)argc;
        (void)argv;
        check_sources();
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:pasteboard10_expectations length:strlen(pasteboard10_expectations)] options:0 error:NULL];
        revenant_check([UIPasteboard generalPasteboard] != nil, "the release hands out a pasteboard at all", nil);
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        @try {
            pasteboard10_run(^(NSString *name, NSString *value) {
                records[name] = value;
            });
        } @catch (NSException *exception) {
            revenant_check(NO, "the cases run to the end", [NSString stringWithFormat:@"%@: %@ after %lu of them", exception.name, exception.reason, (unsigned long)records.count]);
        }
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *want = expected[name];
            NSString *got = records[name];
            if ([want isEqualToString:got])
                revenant_check(YES, name.UTF8String, nil);
            else
                revenant_check(NO, name.UTF8String, [NSString stringWithFormat:@"device %@, host %@", got, want]);
        }
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
