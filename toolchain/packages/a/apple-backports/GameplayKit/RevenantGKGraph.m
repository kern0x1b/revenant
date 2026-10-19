#import "CharonGKGraph.h"

#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>

NSString *const CharonGKSearchClosedKey = @"CharonGKSearchClosed";
NSString *const CharonGKSearchScoreKey = @"CharonGKSearchScore";
NSString *const CharonGKSearchParentKey = @"CharonGKSearchParent";
NSString *const CharonGKGraphNodesKey = @"CharonGKGraphNodes";
NSString *const CharonGKGraphNodeClassKey = @"CharonGKGraphClass";
NSString *const CharonGKGraphNodePositionKey = @"CharonGKGraphPosition";
NSString *const CharonGKObstacleVerticesKey = @"CharonGKObstacleVertices";
NSString *const CharonGKObstacleGraphObstaclesKey = @"CharonGKObstacleGraphObstacles";
NSString *const CharonGKObstacleGraphBufferKey = @"CharonGKObstacleGraphBuffer";
NSString *const CharonGKObstacleGraphLocksKey = @"CharonGKObstacleGraphLocks";

static BOOL CharonGKRayCrossesSide(vector_float2 point, vector_float2 a, vector_float2 b)
{
    if ((a.y > point.y) == (b.y > point.y)) {
        return NO;
    }
    float crossing = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
    return point.x < crossing;
}

static float CharonGKDistanceToSide(vector_float2 point, vector_float2 a, vector_float2 b)
{
    float ex = b.x - a.x;
    float ey = b.y - a.y;
    float lengthSquared = ex * ex + ey * ey;
    float t = 0;
    if (lengthSquared > 0) {
        t = ((point.x - a.x) * ex + (point.y - a.y) * ey) / lengthSquared;
        if (t < 0) {
            t = 0;
        } else if (t > 1) {
            t = 1;
        }
    }
    float dx = point.x - (a.x + t * ex);
    float dy = point.y - (a.y + t * ey);
    return (float)sqrt((double)(dx * dx + dy * dy));
}

BOOL CharonGKPointOnBoundary(vector_float2 point, const vector_float2 *vertices, NSUInteger count);

static const float CharonGKBoundarySlack = 1e-7f;

BOOL CharonGKPointOnBoundary(vector_float2 point, const vector_float2 *vertices, NSUInteger count)
{
    if (count < 3 || vertices == NULL) {
        return NO;
    }
    for (NSUInteger index = 0; index < count; index++) {
        if (CharonGKDistanceToSide(point, vertices[index], vertices[(index + 1) % count]) <=
            CharonGKBoundarySlack) {
            return YES;
        }
    }
    return NO;
}

BOOL CharonGKPointInPolygon(vector_float2 point, const vector_float2 *vertices, NSUInteger count,
                            float buffer)
{
    if (count < 3 || vertices == NULL) {
        return NO;
    }
    if (CharonGKRayCrossesSide(point, vertices[count - 1], vertices[0])) {
        BOOL inside = NO;
        for (NSUInteger index = 0; index + 1 < count; index++) {
            if (CharonGKRayCrossesSide(point, vertices[index], vertices[index + 1])) {
                inside = !inside;
            }
        }
        if (inside) {
            return YES;
        }
    }
    if (buffer > 0) {
        for (NSUInteger index = 0; index < count; index++) {
            if (CharonGKDistanceToSide(point, vertices[index], vertices[(index + 1) % count]) <= buffer) {
                return YES;
            }
        }
    }
    return NO;
}

BOOL CharonGKSegmentCrossesPolygon(vector_float2 from, vector_float2 to, const vector_float2 *vertices,
                                   NSUInteger count, float buffer)
{
    if (count < 3 || vertices == NULL) {
        return NO;
    }
    if (CharonGKPointInPolygon(from, vertices, count, buffer) &&
        CharonGKPointInPolygon(to, vertices, count, buffer)) {
        return NO;
    }
    for (NSUInteger index = 0; index < count; index++) {
        vector_float2 a = vertices[index];
        vector_float2 b = vertices[(index + 1) % count];
        float d1 = (to.x - from.x) * (a.y - from.y) - (to.y - from.y) * (a.x - from.x);
        float d2 = (to.x - from.x) * (b.y - from.y) - (to.y - from.y) * (b.x - from.x);
        float d3 = (b.x - a.x) * (from.y - a.y) - (b.y - a.y) * (from.x - a.x);
        float d4 = (b.x - a.x) * (to.y - a.y) - (b.y - a.y) * (to.x - a.x);
        if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
            ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
            return YES;
        }
    }
    if (CharonGKPointOnBoundary(from, vertices, count) || CharonGKPointOnBoundary(to, vertices, count)) {
        return NO;
    }
    return CharonGKPointInPolygon(from, vertices, count, buffer) ||
           CharonGKPointInPolygon(to, vertices, count, buffer);
}

@implementation CharonGKEntry

+ (instancetype)charon_entryWithElement:(id)element low:(vector_float3)low high:(vector_float3)high
                               isPoint:(BOOL)isPoint
{
    CharonGKEntry *entry = [[CharonGKEntry alloc] init];
    entry->charon_element = element;
    entry->charon_min = low;
    entry->charon_max = high;
    entry->charon_isPoint = isPoint;
    return entry;
}

- (BOOL)charon_holdsPoint:(vector_float3)point
{
    return point.x >= charon_min.x && point.x <= charon_max.x && point.y >= charon_min.y &&
           point.y <= charon_max.y && point.z >= charon_min.z && point.z <= charon_max.z;
}

- (BOOL)charon_meetsRange:(vector_float2)low high:(vector_float2)high
{
    return charon_min.x <= high.x && charon_max.x >= low.x && charon_min.y <= high.y &&
           charon_max.y >= low.y;
}

- (void)dealloc { charon_element = nil; }

@end

NSArray *CharonGKConnected(id node)
{
    SEL selector = NSSelectorFromString(@"connectedNodes");
    if (![node respondsToSelector:selector]) {
        return nil;
    }
    NSArray *(*answer)(id, SEL) = (NSArray *(*)(id, SEL))[node methodForSelector:selector];
    return answer(node, selector);
}

float CharonGKCostTo(id from, id to)
{
    SEL selector = NSSelectorFromString(@"costToNode:");
    if (![from respondsToSelector:selector]) {
        return INFINITY;
    }
    float (*answer)(id, SEL, id) = (float (*)(id, SEL, id))[from methodForSelector:selector];
    return answer(from, selector, to);
}

float CharonGKSearchScore(id node)
{
    NSNumber *held = objc_getAssociatedObject(node, (__bridge const void *)CharonGKSearchScoreKey);
    return held == nil ? INFINITY : [held floatValue];
}

static CharonGKTriangle3 *CharonGKTriangleOf(vector_float2 a, vector_float2 b, vector_float2 c);

float CharonGKCellSize(float minimum, float extent)
{
    if (extent <= 0 || !(minimum > 0)) {
        return extent > 0 ? extent : 0;
    }
    float size = extent;
    while (size > 0) {
        float half = size / 2;
        if (half > 0 && half >= minimum) {
            size = half;
            continue;
        }
        break;
    }
    return size > 0 ? size : extent;
}

float CharonGKCellFloor(float value, float size)
{
    if (!(size > 0)) {
        return value < 0 ? (float)floorf(value) : (float)floorf(value);
    }
    return (float)floorf(value / size) * size;
}

float CharonGKNodeSize(float cellSize)
{
    return cellSize * 2;
}

float CharonGKNodeCeiling(float edge, float limit)
{
    return edge > limit ? limit : edge;
}

float CharonGKCellCeiling(float value, float size, float limit)
{
    if (!(size > 0)) {
        return limit;
    }
    float edge = CharonGKCellFloor(value, size) + size;
    return edge > limit ? limit : edge;
}

@implementation CharonGKPoint2
+ (instancetype)pointWithX:(float)x y:(float)y
{
    CharonGKPoint2 *answer = [[CharonGKPoint2 alloc] init];
    answer->point = (vector_float2){x, y};
    return answer;
}
- (vector_float2)vector { return point; }
@end

@implementation CharonGKTriangle3
+ (instancetype)triangleAt:(vector_float2)a first:(vector_float2)b second:(vector_float2)c
{
    return CharonGKTriangleOf(a, b, c);
}
@end

@implementation CharonGKEdgePair
+ (instancetype)pairWithFirst:(NSUInteger)first second:(NSUInteger)second
{
    CharonGKEdgePair *answer = [[CharonGKEdgePair alloc] init];
    answer->first = first;
    answer->second = second;
    return answer;
}
@end

id CharonGKPointNodeWithClass(Class nodeClass, vector_float2 point)
{
    if (nodeClass == Nil) {
        return nil;
    }
    id instance = [nodeClass alloc];
    SEL initialiser = NSSelectorFromString(@"initWithPoint:");
    if (![instance respondsToSelector:initialiser]) {
        return [instance init];
    }
    if ([nodeClass isSubclassOfClass:[GKGraphNode3D class]]) {
        id (*three)(id, SEL, vector_float3) = (id (*)(id, SEL, vector_float3))[instance
            methodForSelector:initialiser];
        return three(instance, initialiser, (vector_float3){point.x, point.y, 0});
    }
    id (*two)(id, SEL, vector_float2) = (id (*)(id, SEL, vector_float2))[instance methodForSelector:initialiser];
    return two(instance, initialiser, point);
}

NSArray *CharonGKVerticesOfObstacle(id obstacle)
{
    SEL countSelector = NSSelectorFromString(@"vertexCount");
    if (![obstacle respondsToSelector:countSelector]) {
        return nil;
    }
    NSUInteger (*answerCount)(id, SEL) = (NSUInteger (*)(id, SEL))[obstacle methodForSelector:countSelector];
    NSUInteger count = answerCount(obstacle, countSelector);
    SEL vertexSelector = NSSelectorFromString(@"vertexAtIndex:");
    vector_float2 (*answerVertex)(id, SEL, NSUInteger) =
        (vector_float2 (*)(id, SEL, NSUInteger))[obstacle methodForSelector:vertexSelector];
    NSMutableArray *vertices = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        vector_float2 vertex = answerVertex(obstacle, vertexSelector, index);
        [vertices addObject:[CharonGKPoint2 pointWithX:vertex.x y:vertex.y]];
    }
    return vertices;
}

static vector_float2 CharonGKVertexAt(NSArray *vertices, NSUInteger index)
{
    return index < [vertices count] ? [(CharonGKPoint2 *)vertices[index] vector] : (vector_float2){0, 0};
}

static vector_float2 CharonGKPushCorner(vector_float2 previous, vector_float2 here, vector_float2 next,
                                        float buffer)
{
    float incomingX = here.x - previous.x;
    float incomingY = here.y - previous.y;
    float outgoingX = next.x - here.x;
    float outgoingY = next.y - here.y;
    float incoming = (float)sqrt((double)(incomingX * incomingX + incomingY * incomingY));
    float outgoing = (float)sqrt((double)(outgoingX * outgoingX + outgoingY * outgoingY));
    if (incoming == 0 || outgoing == 0) {
        return here;
    }
    incomingX /= incoming;
    incomingY /= incoming;
    outgoingX /= outgoing;
    outgoingY /= outgoing;
    float normalAX = incomingY;
    float normalAY = -incomingX;
    float normalBX = outgoingY;
    float normalBY = -outgoingX;
    float bisectorX = normalAX + normalBX;
    float bisectorY = normalAY + normalBY;
    float bisector = (float)sqrt((double)(bisectorX * bisectorX + bisectorY * bisectorY));
    if (bisector == 0) {
        return here;
    }
    bisectorX /= bisector;
    bisectorY /= bisector;
    float cross = normalAX * normalBX + normalAY * normalBY;
    float sine = (float)sqrt((double)((1 - cross) / 2));
    if (sine <= 0) {
        return here;
    }
    return (vector_float2){here.x + bisectorX * buffer / sine, here.y + bisectorY * buffer / sine};
}

NSArray *CharonGKBufferedCorners(NSArray *obstacles, float buffer, NSMutableArray *perObstacle)
{
    NSMutableArray *corners = [NSMutableArray array];
    for (id obstacle in obstacles) {
        NSArray *vertices = CharonGKVerticesOfObstacle(obstacle);
        if (vertices == nil) {
            continue;
        }
        NSMutableArray *mine = [NSMutableArray array];
        NSUInteger count = [vertices count];
        for (NSUInteger index = 0; index < count; index++) {
            vector_float2 pushed = CharonGKPushCorner(CharonGKVertexAt(vertices, (index + count - 1) % count),
                                                     CharonGKVertexAt(vertices, index),
                                                     CharonGKVertexAt(vertices, (index + 1) % count), buffer);
            CharonGKPoint2 *box = [CharonGKPoint2 pointWithX:pushed.x y:pushed.y];
            [mine addObject:box];
            [corners addObject:box];
        }
        if (perObstacle != nil) {
            [perObstacle addObject:mine];
        }
    }
    return corners;
}

static BOOL CharonGKTurnsLeft(vector_float2 a, vector_float2 b, vector_float2 c)
{
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0;
}

static BOOL CharonGKPointInsideTriangle(vector_float2 p, vector_float2 a, vector_float2 b, vector_float2 c)
{
    return CharonGKTurnsLeft(a, b, p) && CharonGKTurnsLeft(b, c, p) && CharonGKTurnsLeft(c, a, p);
}

static CharonGKTriangle3 *CharonGKTriangleOf(vector_float2 a, vector_float2 b, vector_float2 c)
{
    CharonGKTriangle3 *triangle = [[CharonGKTriangle3 alloc] init];
    triangle->points[0] = (vector_float3){a.x, a.y, 0};
    triangle->points[1] = (vector_float3){b.x, b.y, 0};
    triangle->points[2] = (vector_float3){c.x, c.y, 0};
    return triangle;
}

static NSArray *CharonGKEarClip(NSArray *outline)
{
    NSMutableArray *remaining = [outline mutableCopy];
    NSMutableArray *triangles = [NSMutableArray array];
    NSUInteger guard = [remaining count] * [remaining count] + 16;
    while ([remaining count] > 2 && guard-- > 0) {
        BOOL clipped = NO;
        NSUInteger count = [remaining count];
        for (NSUInteger index = 0; index < count; index++) {
            vector_float2 previous = CharonGKVertexAt(remaining, (index + count - 1) % count);
            vector_float2 here = CharonGKVertexAt(remaining, index);
            vector_float2 next = CharonGKVertexAt(remaining, (index + 1) % count);
            if (!CharonGKTurnsLeft(previous, here, next)) {
                continue;
            }
            BOOL empty = YES;
            for (NSUInteger other = 0; other < count && empty; other++) {
                if (other == (index + count - 1) % count || other == index || other == (index + 1) % count) {
                    continue;
                }
                if (CharonGKPointInsideTriangle(CharonGKVertexAt(remaining, other), previous, here, next)) {
                    empty = NO;
                }
            }
            if (!empty) {
                continue;
            }
            [triangles addObject:CharonGKTriangleOf(previous, here, next)];
            [remaining removeObjectAtIndex:index];
            clipped = YES;
            break;
        }
        if (!clipped) {
            NSUInteger last = [remaining count] - 1;
            for (NSUInteger index = 1; index + 1 <= last; index++) {
                [triangles addObject:CharonGKTriangleOf(CharonGKVertexAt(remaining, 0),
                                                        CharonGKVertexAt(remaining, index),
                                                        CharonGKVertexAt(remaining, index + 1))];
            }
            break;
        }
    }
    return triangles;
}

NSArray *CharonGKTriangulateRegion(NSArray *outline, NSArray *holes)
{
    NSMutableArray *ring = [outline mutableCopy];
    for (NSArray *hole in holes) {
        if ([hole count] < 3) {
            continue;
        }
        NSUInteger best = 0;
        vector_float2 bestCorner = CharonGKVertexAt(hole, 0);
        for (NSUInteger index = 1; index < [hole count]; index++) {
            vector_float2 corner = CharonGKVertexAt(hole, index);
            if (corner.x > bestCorner.x) {
                bestCorner = corner;
                best = index;
            }
        }
        NSUInteger target = NSNotFound;
        float shortest = INFINITY;
        for (NSUInteger index = 0; index < [ring count]; index++) {
            vector_float2 corner = CharonGKVertexAt(ring, index);
            if (corner.x < bestCorner.x) {
                continue;
            }
            float distance = CharonGKLength2(corner, bestCorner);
            if (distance < shortest) {
                shortest = distance;
                target = index;
            }
        }
        if (target == NSNotFound) {
            target = 0;
        }
        NSMutableArray *spliced = [NSMutableArray array];
        for (NSUInteger index = 0; index <= target; index++) {
            [spliced addObject:[ring objectAtIndex:index]];
        }
        for (NSUInteger step = 0; step < [hole count]; step++) {
            [spliced addObject:[hole objectAtIndex:(best + step) % [hole count]]];
        }
        [spliced addObject:[hole objectAtIndex:best]];
        for (NSUInteger index = target + 1; index < [ring count]; index++) {
            [spliced addObject:[ring objectAtIndex:index]];
        }
        ring = spliced;
    }
    return CharonGKEarClip(ring);
}

NSArray *CharonGKVisibilityEdges(NSArray *corners, NSArray *obstacles, float buffer)
{
    NSMutableArray *edges = [NSMutableArray array];
    NSUInteger count = [corners count];
    for (NSUInteger first = 0; first < count; first++) {
        vector_float2 from = CharonGKVertexAt(corners, first);
        for (NSUInteger second = first + 1; second < count; second++) {
            vector_float2 to = CharonGKVertexAt(corners, second);
            if (from.x == to.x && from.y == to.y) {
                continue;
            }
            BOOL blocked = NO;
            for (id obstacle in obstacles) {
                NSArray *vertices = CharonGKVerticesOfObstacle(obstacle);
                if (vertices == nil || [vertices count] < 3) {
                    continue;
                }
                if (CharonGKSegmentCrossesPolygon(from, to, NULL, 0, buffer)) {
                    blocked = YES;
                    break;
                }
                vector_float2 held[64];
                NSUInteger vertexCount = [vertices count] < 64 ? [vertices count] : 64;
                for (NSUInteger index = 0; index < vertexCount; index++) {
                    held[index] = CharonGKVertexAt(vertices, index);
                }
                if (CharonGKSegmentCrossesPolygon(from, to, held, vertexCount, buffer)) {
                    blocked = YES;
                    break;
                }
            }
            if (!blocked) {
                [edges addObject:[CharonGKEdgePair pairWithFirst:(NSUInteger)first second:(NSUInteger)second]];
            }
        }
    }
    return edges;
}

float CharonGKEstimateTo(id from, id goal)
{
    SEL selector = NSSelectorFromString(@"estimatedCostToNode:");
    if (![from respondsToSelector:selector]) {
        return 0;
    }
    float (*answer)(id, SEL, id) = (float (*)(id, SEL, id))[from methodForSelector:selector];
    return answer(from, selector, goal);
}

static float CharonGKSearchPriority(id node, id goal)
{
    return CharonGKSearchScore(node) + CharonGKEstimateTo(node, goal);
}

NSArray *CharonGKFindPath(NSArray *nodes, id start, id goal)
{
    if (start == nil || goal == nil) {
        return nil;
    }
    if (start == goal) {
        return @[start];
    }

    for (id node in nodes) {
        objc_setAssociatedObject(node, (__bridge const void *)CharonGKSearchClosedKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(node, (__bridge const void *)CharonGKSearchScoreKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(node, (__bridge const void *)CharonGKSearchParentKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    NSMutableArray *open = [NSMutableArray array];
    NSMutableSet *closed = [NSMutableSet set];
    objc_setAssociatedObject(start, (__bridge const void *)CharonGKSearchScoreKey,
                             [NSNumber numberWithFloat:0], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [open addObject:start];

    while ([open count] > 0) {
        NSUInteger best = 0;
        float bestScore = CharonGKSearchPriority([open objectAtIndex:0], goal);
        for (NSUInteger index = 1; index < [open count]; index++) {
            float score = CharonGKSearchPriority([open objectAtIndex:index], goal);
            if (score <= bestScore) {
                bestScore = score;
                best = index;
            }
        }
        id current = [open objectAtIndex:best];
        [open removeObjectAtIndex:best];
        if (current == goal) {
            NSMutableArray *path = [NSMutableArray arrayWithObject:current];
            id step = current;
            while (step != start) {
                step = objc_getAssociatedObject(step, (__bridge const void *)CharonGKSearchParentKey);
                if (step == nil) {
                    break;
                }
                [path insertObject:step atIndex:0];
            }
            return path;
        }
        [closed addObject:current];

        for (id next in CharonGKConnected(current)) {
            if ([closed containsObject:next]) {
                continue;
            }
            float reached = CharonGKSearchScore(current) + CharonGKCostTo(current, next);
            float held = CharonGKSearchScore(next);
            if (held == INFINITY || reached < held) {
                objc_setAssociatedObject(next, (__bridge const void *)CharonGKSearchScoreKey,
                                         [NSNumber numberWithFloat:reached],
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(next, (__bridge const void *)CharonGKSearchParentKey, current,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (![open containsObject:next]) {
                    [open addObject:next];
                }
            }
        }
    }
    return nil;
}
