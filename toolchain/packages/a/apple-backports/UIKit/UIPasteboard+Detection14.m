#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSString *const UIPasteboardDetectionPatternProbableWebURL = @"com.apple.uikit.pasteboard-detection-pattern.probable-web-url";
NSString *const UIPasteboardDetectionPatternProbableWebSearch = @"com.apple.uikit.pasteboard-detection-pattern.probable-web-search";
NSString *const UIPasteboardDetectionPatternNumber = @"com.apple.uikit.pasteboard-detection-pattern.number";

static void charon_say(void)
{
    charon_menus_say_once(@"pasteboard-detection", @"UIPasteboard pattern detection: iOS 6 has no classifier for what a pasteboard holds, so the detection methods answer that no pattern was found");
}

static void charon_later(void (^completion)(void))
{
    dispatch_async(dispatch_get_main_queue(), completion);
}

@implementation UIPasteboard (CharonDetection14)

- (void)detectPatternsForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns completionHandler:(void (^)(NSSet<UIPasteboardDetectionPattern> *, NSError *))completionHandler
{
    charon_say();
    charon_later(^{
        completionHandler([NSSet set], nil);
    });
}

- (void)detectPatternsForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns inItemSet:(NSIndexSet *)itemSet
                completionHandler:(void (^)(NSArray<NSSet<UIPasteboardDetectionPattern> *> *, NSError *))completionHandler
{
    charon_say();
    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger index = 0; index < (itemSet ? itemSet.count : (NSUInteger)self.numberOfItems); index++)
        [results addObject:[NSSet set]];
    charon_later(^{
        completionHandler(results, nil);
    });
}

- (void)detectValuesForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns completionHandler:(void (^)(NSDictionary<UIPasteboardDetectionPattern, id> *, NSError *))completionHandler
{
    charon_say();
    charon_later(^{
        completionHandler(@{}, nil);
    });
}

- (void)detectValuesForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns inItemSet:(NSIndexSet *)itemSet
              completionHandler:(void (^)(NSArray<NSDictionary<UIPasteboardDetectionPattern, id> *> *, NSError *))completionHandler
{
    charon_say();
    NSMutableArray *results = [NSMutableArray array];
    for (NSUInteger index = 0; index < (itemSet ? itemSet.count : (NSUInteger)self.numberOfItems); index++)
        [results addObject:@{}];
    charon_later(^{
        completionHandler(results, nil);
    });
}

@end
