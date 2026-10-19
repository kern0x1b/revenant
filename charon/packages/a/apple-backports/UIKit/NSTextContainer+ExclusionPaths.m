#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSTextContainer (CharonExclusionNative)
- (CGFloat)lineFragmentPadding;
- (CGSize)containerSize;
@end

typedef struct {
    CGPoint from;
    CGPoint to;
} CharonEdge;

@interface CharonEdgeList : NSObject {
@public
    NSMutableData *edges;
    CGPoint start;
    CGPoint current;
    BOOL open;
}
@end

@implementation CharonEdgeList
@end

static void charon_edge_add(CharonEdgeList *list, CGPoint to)
{
    CharonEdge edge = {list->current, to};
    [list->edges appendBytes:&edge length:sizeof edge];
    list->current = to;
}

static void charon_edge_close(CharonEdgeList *list)
{
    if (list->open && (list->current.x != list->start.x || list->current.y != list->start.y))
        charon_edge_add(list, list->start);
    list->open = NO;
}

static void charon_flatten_element(void *info, const CGPathElement *element)
{
    CharonEdgeList *list = (__bridge CharonEdgeList *)info;
    CGPoint *points = element->points;
    switch (element->type) {
    case kCGPathElementMoveToPoint:
        charon_edge_close(list);
        list->start = list->current = points[0];
        list->open = YES;
        break;
    case kCGPathElementAddLineToPoint:
        charon_edge_add(list, points[0]);
        break;
    case kCGPathElementAddQuadCurveToPoint: {
        CGPoint p0 = list->current;
        for (int step = 1; step <= 16; step++) {
            CGFloat t = step / 16.0, u = 1 - t;
            charon_edge_add(list, CGPointMake(u * u * p0.x + 2 * u * t * points[0].x + t * t * points[1].x, u * u * p0.y + 2 * u * t * points[0].y + t * t * points[1].y));
        }
        break;
    }
    case kCGPathElementAddCurveToPoint: {
        CGPoint p0 = list->current;
        for (int step = 1; step <= 16; step++) {
            CGFloat t = step / 16.0, u = 1 - t;
            charon_edge_add(list, CGPointMake(u * u * u * p0.x + 3 * u * u * t * points[0].x + 3 * u * t * t * points[1].x + t * t * t * points[2].x,
                                              u * u * u * p0.y + 3 * u * u * t * points[0].y + 3 * u * t * t * points[1].y + t * t * t * points[2].y));
        }
        break;
    }
    case kCGPathElementCloseSubpath:
        charon_edge_close(list);
        break;
    }
}

static NSData *charon_edges_of(UIBezierPath *path)
{
    CharonEdgeList *list = [[CharonEdgeList alloc] init];
    list->edges = [NSMutableData data];
    CGPathApply(path.CGPath, (__bridge void *)list, charon_flatten_element);
    charon_edge_close(list);
    return list->edges;
}

static void charon_spans_at(NSData *edges, BOOL evenOdd, CGFloat y, NSMutableArray<NSValue *> *spans)
{
    const CharonEdge *list = edges.bytes;
    NSUInteger count = edges.length / sizeof(CharonEdge);
    NSMutableArray<NSArray *> *crossings = [NSMutableArray array];
    for (NSUInteger index = 0; index < count; index++) {
        CGPoint a = list[index].from, b = list[index].to;
        if (a.y == b.y || y < MIN(a.y, b.y) || y >= MAX(a.y, b.y))
            continue;
        CGFloat x = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y);
        [crossings addObject:@[@(x), @(b.y > a.y ? 1 : -1)]];
    }
    [crossings sortUsingComparator:^NSComparisonResult(NSArray *left, NSArray *right) {
        return [left[0] compare:right[0]];
    }];
    NSInteger winding = 0;
    for (NSUInteger index = 0; index + 1 < crossings.count; index++) {
        winding += [crossings[index][1] integerValue];
        BOOL inside = evenOdd ? (index % 2 == 0) : winding != 0;
        if (inside)
            [spans addObject:[NSValue valueWithCGPoint:CGPointMake([crossings[index][0] doubleValue], [crossings[index + 1][0] doubleValue])]];
    }
}

static NSArray<NSValue *> *charon_excluded(NSArray<UIBezierPath *> *paths, CGFloat top, CGFloat bottom)
{
    NSMutableArray<NSValue *> *spans = [NSMutableArray array];
    for (UIBezierPath *path in paths) {
        NSData *edges = charon_edges_of(path);
        const CharonEdge *list = edges.bytes;
        NSUInteger count = edges.length / sizeof(CharonEdge);
        NSMutableArray<NSNumber *> *ys = [NSMutableArray arrayWithObjects:@(top + 0.001), @(bottom - 0.001), nil];
        for (NSUInteger index = 0; index < count; index++) {
            CGFloat vertices[2] = {list[index].from.y, list[index].to.y};
            for (int which = 0; which < 2; which++)
                if (vertices[which] > top && vertices[which] < bottom) {
                    [ys addObject:@(vertices[which] - 0.001)];
                    [ys addObject:@(vertices[which] + 0.001)];
                }
        }
        [ys sortUsingSelector:@selector(compare:)];
        NSMutableArray<NSNumber *> *samples = [NSMutableArray arrayWithArray:ys];
        for (NSUInteger index = 0; index + 1 < ys.count; index++)
            [samples addObject:@(([ys[index] doubleValue] + [ys[index + 1] doubleValue]) / 2)];
        for (NSNumber *y in samples)
            charon_spans_at(edges, path.usesEvenOddFillRule, y.doubleValue, spans);
    }
    return spans;
}

static NSArray<NSValue *> *charon_free_intervals(NSArray<NSValue *> *spans, CGFloat left, CGFloat right)
{
    NSArray<NSValue *> *sorted = [spans sortedArrayUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
        return a.CGPointValue.x < b.CGPointValue.x ? NSOrderedAscending : (a.CGPointValue.x > b.CGPointValue.x ? NSOrderedDescending : NSOrderedSame);
    }];
    NSMutableArray<NSValue *> *free = [NSMutableArray array];
    CGFloat cursor = left;
    for (NSValue *value in sorted) {
        CGPoint span = value.CGPointValue;
        if (span.y <= cursor)
            continue;
        if (span.x > cursor)
            [free addObject:[NSValue valueWithCGPoint:CGPointMake(cursor, MIN(span.x, right))]];
        cursor = MAX(cursor, span.y);
        if (cursor >= right)
            break;
    }
    if (cursor < right)
        [free addObject:[NSValue valueWithCGPoint:CGPointMake(cursor, right)]];
    NSMutableArray<NSValue *> *usable = [NSMutableArray array];
    for (NSValue *value in free)
        if (value.CGPointValue.y - value.CGPointValue.x > 0)
            [usable addObject:value];
    return usable;
}

@interface CharonExclusionInstaller : NSObject
@end

@implementation CharonExclusionInstaller

+ (void)load
{
    // NSTextContainer is TextKit's, from iOS 7, so a band below it links this object with the class
    // symbol weak and NULL - the 4.3 gate names _OBJC_CLASS_$_NSTextContainer among the weak imports
    // the release it is checked against does not export. +load runs whatever the runtime has, so
    // messaging a NULL class here is a NULL send before the program starts. The class is looked up
    // once and the answer for a release that has no TextKit is the one the release itself gives: it
    // lays out its line fragments from the text container's own rectangle, which is what an NSTextContainer
    // without exclusion paths already does, and this installer has nothing to install onto.
    Class container = NSClassFromString(@"NSTextContainer");
    if (!container)
        return;
    SEL selector = @selector(lineFragmentRectForProposedRect:sweepDirection:movementDirection:remainingRect:);
    Method method = class_getInstanceMethod(container, selector);
    if (!method || [container instancesRespondToSelector:@selector(exclusionPaths)])
        return;
    CGRect (*original)(id, SEL, CGRect, NSUInteger, NSUInteger, CGRect *) = (CGRect (*)(id, SEL, CGRect, NSUInteger, NSUInteger, CGRect *))method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^CGRect(NSTextContainer *self_, CGRect proposed, NSUInteger sweep, NSUInteger movement, CGRect *remaining) {
        NSArray<UIBezierPath *> *paths = [self_ exclusionPaths];
        if (!paths.count)
            return original(self_, selector, proposed, sweep, movement, remaining);
        CGRect nativeRemaining = CGRectZero;
        CGRect rect = original(self_, selector, proposed, sweep, movement, &nativeRemaining);
        if (CGRectIsEmpty(rect) || CGRectIsNull(rect)) {
            if (remaining)
                *remaining = nativeRemaining;
            return rect;
        }
        CGFloat height = rect.size.height;
        CGFloat containerHeight = [self_ containerSize].height;
        CGFloat minimum = MAX(2 * [self_ lineFragmentPadding] + 1, height);
        CGFloat containerWidth = [self_ containerSize].width;
        BOOL newLine = movement == 3 && proposed.origin.x <= 0.5 && proposed.size.width >= containerWidth - 0.5;
        NSMutableArray<NSNumber *> *tops = [NSMutableArray arrayWithObject:@(rect.origin.y)];
        if (newLine) {
            NSMutableArray<NSNumber *> *bottoms = [NSMutableArray array];
            for (UIBezierPath *path in paths) {
                CGRect bounds = CGPathGetBoundingBox(path.CGPath);
                if (CGRectGetMaxY(bounds) > rect.origin.y)
                    [bottoms addObject:@(CGRectGetMaxY(bounds))];
            }
            [bottoms sortUsingSelector:@selector(compare:)];
            [tops addObjectsFromArray:bottoms];
        }
        for (NSNumber *top in tops) {
            CGFloat y = top.doubleValue;
            if (containerHeight > 0 && y + height > containerHeight + 0.001)
                break;
            NSArray<NSValue *> *free = charon_free_intervals(charon_excluded(paths, y, y + height), CGRectGetMinX(rect), CGRectGetMaxX(rect));
            NSValue *chosen = nil;
            for (NSValue *candidate in (sweep == 0 ? free.reverseObjectEnumerator.allObjects : free)) {
                if (candidate.CGPointValue.y - candidate.CGPointValue.x >= minimum) {
                    chosen = candidate;
                    break;
                }
            }
            if (!chosen)
                continue;
            CGPoint interval = chosen.CGPointValue;
            CGRect result = CGRectMake(interval.x, y, interval.y - interval.x, height);
            CGRect rest = sweep == 0 ? CGRectMake(CGRectGetMinX(rect), y, interval.x - CGRectGetMinX(rect), height) : CGRectMake(interval.y, y, CGRectGetMaxX(rect) - interval.y, height);
            if (remaining)
                *remaining = rest.size.width > 0 ? rest : nativeRemaining;
            return result;
        }
        if (remaining)
            *remaining = CGRectZero;
        return CGRectZero;
    }));
}

@end
