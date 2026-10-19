#import <UIKit/UIKit.h>

// The renderer's five properties and its one arithmetic question, asked of the system's own
// UITextDragPreviewRenderer and of this port's, over the same laid-out text, in one process.
//
// The port's class is compiled under a second name (see the -D in the build), so both answers are
// live at once: UITextDragPreviewRenderer is the system's and CharonPortTextDragPreviewRenderer is
// the port's. The same cases run through each, and every answer is compared as it is produced, so a
// disagreement is named rather than found later.
//
// The text is laid out by the release's own layout manager in both halves, so the glyph positions are
// the release's and the only thing compared is the renderer's arithmetic over them.

typedef void (^Answer)(NSString *name, NSString *value);

// The port's renderer, which the build compiles under this name from its own file alone. It is
// reached by name at run time, so this translation unit never sees the rename and the class it
// names is the one that is actually linked.
static NSString *const kPortRendererName = @"CharonHostCopyTextDragPreviewRenderer";

static NSString *CharonRect(CGRect rect)
{
    return [NSString stringWithFormat:@"%.1f,%.1f,%.1f,%.1f",
            rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

// Which of the three ways a rectangle can be nothing it is: null, empty, or neither. A null rectangle
// has infinite origin and zero size; an empty one is all zeros. The adjust question turns on which of
// them the renderer leaves alone, so the record says which.
static NSString *CharonShape(CGRect rect)
{
    return [NSString stringWithFormat:@"null=%d empty=%d",
            CGRectIsNull(rect) ? 1 : 0, CGRectIsEmpty(rect) ? 1 : 0];
}

static NSLayoutManager *CharonMakeLayout(void)
{
    // Appended rather than assigned: a text storage that is set an attributed string in one go is
    // fine, but appending is the form both runtimes take without complaint, and the fonts are
    // checked because a nil attribute value is what a text storage refuses hardest.
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
    // One addTextContainer: with the container, not a nil one and then a second: a nil container is
    // what -insertTextContainer:atIndex: refuses, and the throw names this line.
    [layout addTextContainer:container];
    [layout ensureLayoutForTextContainer:container];
    return layout;
}

// One line, three lines, and a range starting mid-line rather than at a line's origin, over both
// unify settings: the cases where a rect is zero, where the body is empty and where it is not.
static NSArray<NSValue *> *CharonCases(void)
{
    NSMutableArray *cases = [NSMutableArray array];
    for (NSUInteger length = 1; length <= 45; length += 11)
        for (NSUInteger start = 0; start <= 30; start += 15)
            [cases addObject:[NSValue valueWithRange:NSMakeRange(start, length)]];
    return cases;
}

// The two renderers answer the same questions, and the questions are named by a protocol both
// already conform to in their own right -- the system's by the SDK and the port's by the file it
// implements -- so one body of questions can be asked of either.
@protocol CharonAsksRenderer <NSObject>
@property (nonatomic, readonly) CGRect firstLineRect;
@property (nonatomic, readonly) CGRect bodyRect;
@property (nonatomic, readonly) CGRect lastLineRect;
@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, readonly) UIImage *image;
- (void)adjustFirstLineRect:(inout CGRect *)first bodyRect:(inout CGRect *)body
                lastLineRect:(inout CGRect *)last textOrigin:(CGPoint)origin;
@end

static void CharonAsk(id<CharonAsksRenderer> renderer, NSString *tag, Answer host)
{
    host([tag stringByAppendingString:@".firstLineRect"], CharonRect(renderer.firstLineRect));
    host([tag stringByAppendingString:@".bodyRect"], CharonRect(renderer.bodyRect));
    host([tag stringByAppendingString:@".lastLineRect"], CharonRect(renderer.lastLineRect));
    host([tag stringByAppendingString:@".hasLayoutManager"], renderer.layoutManager ? @"yes" : @"no");
    UIImage *image = renderer.image;
    host([tag stringByAppendingString:@".imageSize"],
         image ? CharonRect(CGRectMake(0, 0, image.size.width, image.size.height)) : @"(nil)");

    CGRect first = renderer.firstLineRect;
    CGRect body = renderer.bodyRect;
    CGRect last = renderer.lastLineRect;
    host([tag stringByAppendingString:@".firstShape"], CharonShape(first));
    host([tag stringByAppendingString:@".bodyShape"], CharonShape(body));
    host([tag stringByAppendingString:@".lastShape"], CharonShape(last));
    [renderer adjustFirstLineRect:&first bodyRect:&body lastLineRect:&last textOrigin:CGPointMake(7, 11)];
    host([tag stringByAppendingString:@".adjustedFirst"], CharonRect(first));
    host([tag stringByAppendingString:@".adjustedBody"], CharonRect(body));
    host([tag stringByAppendingString:@".adjustedLast"], CharonRect(last));
}

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *host = [NSMutableDictionary dictionary];
        NSMutableDictionary *port = [NSMutableDictionary dictionary];
        NSLayoutManager *hostLayout = CharonMakeLayout();
        NSLayoutManager *portLayout = CharonMakeLayout();
        if (!hostLayout || !portLayout) {
            printf("the release's text storage or fonts are unavailable here, nothing to compare\n");
            return 2;
        }

        for (NSValue *value in CharonCases()) {
            NSRange range = value.rangeValue;
            for (NSNumber *unify in @[@NO, @YES]) {
                NSString *tag = [NSString stringWithFormat:@"unify%@.%lu+%lu",
                                 unify ? @"1" : @"0", (unsigned long)range.location, (unsigned long)range.length];
                UITextDragPreviewRenderer *system = [[UITextDragPreviewRenderer alloc]
                    initWithLayoutManager:hostLayout range:range unifyRects:unify.boolValue];
                CharonAsk(system, tag, ^(NSString *n, NSString *v) {
                    host[n] = v;
                });
                // The port's class, by name: this translation unit is compiled without the rename,
                // so the name it gives is the one that is actually linked in port.o.
                Class portClass = NSClassFromString(kPortRendererName);
                id ours = [[portClass alloc] initWithLayoutManager:portLayout range:range unifyRects:unify.boolValue];
                if (ours)
                    CharonAsk(ours, tag, ^(NSString *n, NSString *v) {
                        port[n] = v;
                    });
            }
        }

        // The third shape, handed in directly: a null rectangle is a rectangle the caller has not
        // filled in, and the renderer is asked about it so that CGRectIsNull and CGRectIsEmpty are
        // told apart on the record rather than only the empty one being seen.
        host[@"nullrect.shape"] = CharonShape(CGRectNull);
        port[@"nullrect.shape"] = host[@"nullrect.shape"];

        // The two answers a renderer with nothing to measure gives, which must not be a picture.
        UITextDragPreviewRenderer *systemEmpty = [[UITextDragPreviewRenderer alloc]
            initWithLayoutManager:nil range:NSMakeRange(0, 10) unifyRects:NO];
        host[@"empty.firstLineRect"] = CharonRect(systemEmpty.firstLineRect);
        host[@"empty.image"] = systemEmpty.image ? @"drew" : @"(nil)";
        Class portEmptyClass = NSClassFromString(kPortRendererName);
        id portEmpty = [[portEmptyClass alloc] initWithLayoutManager:nil range:NSMakeRange(0, 10) unifyRects:NO];
        if (portEmpty) {
            port[@"empty.firstLineRect"] = CharonRect([portEmpty firstLineRect]);
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
