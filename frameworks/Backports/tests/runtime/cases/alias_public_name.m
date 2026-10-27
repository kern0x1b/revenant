#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

REVENANT_CASE(alias_public_name)
{
    NSArray<NSString *> *names = @[@"NSDateInterval", @"NSDimension", @"NSISO8601DateFormatter", @"NSMeasurement",
                                   @"NSOrderedCollectionChange", @"NSOrderedCollectionDifference", @"NSPresentationIntent",
                                   @"NSURLComponents", @"NSURLQueryItem", @"NSURLSessionWebSocketMessage",
                                   @"NSUnitConverterLinear", @"UIFontMetrics"];
    for (NSString *name in names) {
        Class registered = objc_getClass(name.UTF8String);
        NSUInteger count = revenant_registered_count(name.UTF8String);
        BOOL once = registered != Nil && count == 1 && [NSStringFromClass(registered) isEqualToString:name];
        revenant_expect_true([NSString stringWithFormat:@"iOS 6 registers %@ once, under its public name", name],
                             once != (BOOL)negative,
                             [NSString stringWithFormat:@"registered %@, classes named %@: %lu", registered ? @"yes" : @"no", name, (unsigned long)count]);
    }
    revenant_expect_true(@"[NSURLComponents class] is the registered public class",
                         ([NSURLComponents class] == objc_getClass("NSURLComponents")) != (BOOL)negative, @"");
    revenant_expect_true(@"[NSURLQueryItem class] is the registered public class",
                         ([NSURLQueryItem class] == objc_getClass("NSURLQueryItem")) != (BOOL)negative, @"");
}
