#import <UIKit/UIKit.h>

typedef void (^Answer)(NSString *name, NSString *value);

static NSString *const kPortRendererName = @"RevenantHostCopyTextDragPreviewRenderer";

static NSString *RevenantRect(CGRect rect)
{
    return [NSString stringWithFormat:@"%.1f,%.1f,%.1f,%.1f",
            rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

static NSString *RevenantShape(CGRect rect)
{
    return [NSString stringWithFormat:@"null=%d empty=%d",
            CGRectIsNull(rect) ? 1 : 0, CGRectIsEmpty(rect) ? 1 : 0];
}

static NSLayoutManager *RevenantMakeLayout(void)
{
    UIFont *body = [UIFont systemFontOfSize:14];
    UIFont *bold = [UIFont boldSystemFontOfSize:20];
    if (!body || !bold)
        return nil;
    NSTextStorage *storage = [[NSTextStorage alloc] init];
    [storage appendAttributedString:[[NSAttributedString alloc]
        initWithString:@"the quick brown fox jumps over the lazy dog and keeps on running for a while"
             attributes:@{NSFontAttributeName: body}]];
    NSUInteger length = MIN((NSUInteger)24, [storage length]);
    if (length)
        [storage addAttribute:NSFontAttributeName value:bold range:NSMakeRange(20, length)];
    if (!storage.length)
        return nil;
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(200, 1000)];
    container.lineFragmentPadding = 5;
    NSLayoutManager *layout = [[NSLayoutManager alloc] init];
    [layout addTextContainer:container];
    [layout ensureLayoutForTextContainer:container];
    return layout;
}

static NSArray<NSValue *> *RevenantCases(void)
{
    NSMutableArray *cases = [NSMutableArray array];
    for (NSUInteger length = 1; length <= 45; length += 11)
        for (NSUInteger start = 0; start <= 30; start += 15)
            [cases addObject:[NSValue valueWithRange:NSMakeRange(start, length)]];
    return cases;
}

@protocol RevenantAsksRenderer <NSObject>
@property (nonatomic, readonly) CGRect firstLineRect;
@property (nonatomic, readonly) CGRect bodyRect;
@property (nonatomic, readonly) CGRect lastLineRect;
@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, readonly) UIImage *image;
- (void)adjustFirstLineRect:(inout CGRect *)first bodyRect:(inout CGRect *)body
                lastLineRect:(inout CGRect *)last textOrigin:(CGPoint)origin;
@end

static void RevenantAsk(id<RevenantAsksRenderer> renderer, NSString *tag, Answer host)
{
    host([tag stringByAppendingString:@".firstLineRect"], RevenantRect(renderer.firstLineRect));
    host([tag stringByAppendingString:@".bodyRect"], RevenantRect(renderer.bodyRect));
    host([tag stringByAppendingString:@".lastLineRect"], RevenantRect(renderer.lastLineRect));
    host([tag stringByAppendingString:@".hasLayoutManager"], renderer.layoutManager ? @"yes" : @"no");
    UIImage *image = renderer.image;
    host([tag stringByAppendingString:@".imageSize"],
         image ? RevenantRect(CGRectMake(0, 0, image.size.width, image.size.height)) : @"(nil)");

    CGRect first = renderer.firstLineRect;
    CGRect body = renderer.bodyRect;
    CGRect last = renderer.lastLineRect;
    host([tag stringByAppendingString:@".firstShape"], RevenantShape(first));
    host([tag stringByAppendingString:@".bodyShape"], RevenantShape(body));
    host([tag stringByAppendingString:@".lastShape"], RevenantShape(last));
    [renderer adjustFirstLineRect:&first bodyRect:&body lastLineRect:&last textOrigin:CGPointMake(7, 11)];
    host([tag stringByAppendingString:@".adjustedFirst"], RevenantRect(first));
    host([tag stringByAppendingString:@".adjustedBody"], RevenantRect(body));
    host([tag stringByAppendingString:@".adjustedLast"], RevenantRect(last));
}

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *host = [NSMutableDictionary dictionary];
        NSMutableDictionary *port = [NSMutableDictionary dictionary];
        NSLayoutManager *hostLayout = RevenantMakeLayout();
        NSLayoutManager *portLayout = RevenantMakeLayout();
        if (!hostLayout || !portLayout) {
            printf("the release's text storage or fonts are unavailable here, nothing to compare\n");
            return 2;
        }

        for (NSValue *value in RevenantCases()) {
            NSRange range = value.rangeValue;
            for (NSNumber *unify in @[@NO, @YES]) {
                NSString *tag = [NSString stringWithFormat:@"unify%@.%lu+%lu",
                                 unify ? @"1" : @"0", (unsigned long)range.location, (unsigned long)range.length];
                UITextDragPreviewRenderer *system = [[UITextDragPreviewRenderer alloc]
                    initWithLayoutManager:hostLayout range:range unifyRects:unify.boolValue];
                RevenantAsk(system, tag, ^(NSString *n, NSString *v) {
                    host[n] = v;
                });
                Class portClass = NSClassFromString(kPortRendererName);
                id ours = [[portClass alloc] initWithLayoutManager:portLayout range:range unifyRects:unify.boolValue];
                if (ours)
                    RevenantAsk(ours, tag, ^(NSString *n, NSString *v) {
                        port[n] = v;
                    });
            }
        }

        host[@"nullrect.shape"] = RevenantShape(CGRectNull);
        port[@"nullrect.shape"] = host[@"nullrect.shape"];

        UITextDragPreviewRenderer *systemEmpty = [[UITextDragPreviewRenderer alloc]
            initWithLayoutManager:nil range:NSMakeRange(0, 10) unifyRects:NO];
        host[@"empty.firstLineRect"] = RevenantRect(systemEmpty.firstLineRect);
        host[@"empty.image"] = systemEmpty.image ? @"drew" : @"(nil)";
        Class portEmptyClass = NSClassFromString(kPortRendererName);
        id portEmpty = [[portEmptyClass alloc] initWithLayoutManager:nil range:NSMakeRange(0, 10) unifyRects:NO];
        if (portEmpty) {
            port[@"empty.firstLineRect"] = RevenantRect([portEmpty firstLineRect]);
            port[@"empty.image"] = [portEmpty image] ? @"drew" : @"(nil)";
        }

        NSUInteger compared = 0, differing = 0;
        NSArray<NSString *> *names = [[host allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *name in names) {
            compared++;
            NSString *h = [host[name] description];
            NSString *p = [port[name] description];
            if (![h isEqualToString:p]) {
                differing++;
                printf("DIFFER %-34s system %-26s port %s\n",
                       name.UTF8String, h.UTF8String, p.UTF8String);
            }
        }
        printf("compared %lu, differing %lu\n", (unsigned long)compared, (unsigned long)differing);
        for (NSString *name in names)
            printf("%s\t%s\n", name.UTF8String, [[host[name] description] UTF8String]);
        return differing ? 1 : 0;
    }
}
