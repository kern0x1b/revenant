#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSString *const UIPasteboardDetectionPatternProbableWebURL = @"com.apple.uikit.pasteboard-detection-pattern.probable-web-url";
NSString *const UIPasteboardDetectionPatternProbableWebSearch = @"com.apple.uikit.pasteboard-detection-pattern.probable-web-search";
NSString *const UIPasteboardDetectionPatternNumber = @"com.apple.uikit.pasteboard-detection-pattern.number";

static NSString *revenant_trimmed(NSString *text)
{
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSDictionary *revenant_detected(NSString *text, NSSet *patterns)
{
    NSString *trimmed = revenant_trimmed(text);
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    if (!trimmed.length)
        return values;
    NSNumber *number = [[[NSNumberFormatter alloc] init] numberFromString:trimmed];
    if (number) {
        if ([patterns containsObject:UIPasteboardDetectionPatternNumber])
            values[UIPasteboardDetectionPatternNumber] = number;
        return values;
    }
    if ([patterns containsObject:UIPasteboardDetectionPatternProbableWebURL]) {
        NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
        NSTextCheckingResult *match = [detector firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
        if (match && match.range.location == 0 && match.range.length == trimmed.length)
            values[UIPasteboardDetectionPatternProbableWebURL] = trimmed;
    }
    if ([patterns containsObject:UIPasteboardDetectionPatternProbableWebSearch] && !values[UIPasteboardDetectionPatternProbableWebURL])
        values[UIPasteboardDetectionPatternProbableWebSearch] = trimmed;
    return values;
}

static NSString *revenant_item_text(UIPasteboard *pasteboard, NSUInteger index)
{
    NSArray *values = [pasteboard valuesForPasteboardType:@"public.text" inItemSet:[NSIndexSet indexSetWithIndex:index]];
    return [values.firstObject isKindOfClass:[NSString class]] ? values.firstObject : nil;
}

static NSIndexSet *revenant_item_indexes(UIPasteboard *pasteboard, NSIndexSet *itemSet)
{
    if (itemSet)
        return itemSet;
    return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, pasteboard.numberOfItems)];
}

static void revenant_later(void (^completion)(void))
{
    dispatch_async(dispatch_get_main_queue(), completion);
}

@implementation UIPasteboard (RevenantDetection14)

- (void)detectPatternsForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns completionHandler:(void (^)(NSSet<UIPasteboardDetectionPattern> *, NSError *))completionHandler
{
    NSSet *found = [NSSet setWithArray:[revenant_detected(self.string, patterns) allKeys]];
    revenant_later(^{
        completionHandler(found, nil);
    });
}

- (void)detectPatternsForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns inItemSet:(NSIndexSet *)itemSet
                completionHandler:(void (^)(NSArray<NSSet<UIPasteboardDetectionPattern> *> *, NSError *))completionHandler
{
    NSIndexSet *indexes = revenant_item_indexes(self, itemSet);
    NSMutableArray *results = [NSMutableArray array];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        [results addObject:[NSSet setWithArray:[revenant_detected(revenant_item_text(self, index), patterns) allKeys]]];
    }];
    revenant_later(^{
        completionHandler(results, nil);
    });
}

- (void)detectValuesForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns completionHandler:(void (^)(NSDictionary<UIPasteboardDetectionPattern, id> *, NSError *))completionHandler
{
    NSDictionary *found = revenant_detected(self.string, patterns);
    revenant_later(^{
        completionHandler(found, nil);
    });
}

- (void)detectValuesForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns inItemSet:(NSIndexSet *)itemSet
              completionHandler:(void (^)(NSArray<NSDictionary<UIPasteboardDetectionPattern, id> *> *, NSError *))completionHandler
{
    NSIndexSet *indexes = revenant_item_indexes(self, itemSet);
    NSMutableArray *results = [NSMutableArray array];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        [results addObject:revenant_detected(revenant_item_text(self, index), patterns)];
    }];
    revenant_later(^{
        completionHandler(results, nil);
    });
}

@end
