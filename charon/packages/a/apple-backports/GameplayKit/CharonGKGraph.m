// CharonGKGraph.m -- the geometry and the one search the pathfinding graphs of GameplayKit share.
//
// This file exports no API symbol. Every C function it defines is Charon-prefixed and internal_symbol()
// in modules/apple/backports.lua leaves those out of what a band is weighed against and out of what the
// library re-exports. It is here and not in either of the two graph objects because charon/AGENTS.md's
// trap is measured: a C function shared between backport files lives in a file that exports no API
// symbol of its own, because a file whose exports a band's release already has is left out of that band
// and the call is Undefined symbols in later bands only.

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

// Where one edge of the boundary crosses the segment, or NO. The side straddles the point's row and the
// crossing falls to the side of the point the ray is cast towards. Half-open on both ends, so a vertex
// on the ray is counted once and never twice.
static BOOL CharonGKRayCrossesSide(vector_float2 point, vector_float2 a, vector_float2 b)
{
    if ((a.y > point.y) == (b.y > point.y)) {
        return NO;
    }
    float crossing = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
    return point.x < crossing;
}

// How far the point is from the side, which is zero inside it. The nearest point on a side is its
// projection where the projection falls on the side, and the nearer end otherwise.
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

// Is a point exactly on the boundary? Its distance to the nearest side is nothing, to within the rounding a
// float coordinate can carry. This is what an obstacle graph's own corners are: they sit on the obstacle.
BOOL CharonGKPointOnBoundary(vector_float2 point, const vector_float2 *vertices, NSUInteger count);

// The slack is a float's own: a coordinate of a magnitude of 8 carries about half a millionth of a step, so
// anything closer than a hundredth of a millionth of a unit is the same point and not a neighbour of it.
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
    // The buffer is the room an agent needs around the obstacle, so the region the obstacle stands for
    // is the polygon plus a band of that width all round it. A point outside the polygon is inside the
    // region only if it is within the buffer of one of its sides.
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
        // Two segments cross when each side of the other straddles the line. A shared endpoint is not a
        // crossing: two edges meeting is what a node on the boundary of an obstacle means.
        float d1 = (to.x - from.x) * (a.y - from.y) - (to.y - from.y) * (a.x - from.x);
        float d2 = (to.x - from.x) * (b.y - from.y) - (to.y - from.y) * (b.x - from.x);
        float d3 = (b.x - a.x) * (from.y - a.y) - (b.y - a.y) * (from.x - a.x);
        float d4 = (b.x - a.x) * (to.y - a.y) - (b.y - a.y) * (to.x - a.x);
        if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
            ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
            return YES;
        }
    }
    // An end inside the buffered region without the line crossing a side is still blocked: the region
    // is wider than the polygon and an edge that ends in it cannot be walked.
    //
    // EXCEPT when the end is ON the obstacle, which is where every corner of an obstacle graph sits and is
    // the whole point of the graph. A point on the boundary is inside the even-odd count as surely as one in
    // the middle, so without this the first corner of every obstacle could never see anything at all and the
    // graph would have no edges: measured, -connectNodeUsingObstacles: on a wall at (4,-2)-(4,2) answers four
    // edges on the host and none with this rule alone. The test is the distance to the nearest side being
    // nothing at all, which is what "on the boundary" means, and a point a float's epsilon away from a side
    // is not on it.
    if (CharonGKPointOnBoundary(from, vertices, count) || CharonGKPointOnBoundary(to, vertices, count)) {
        return NO;
    }
    return CharonGKPointInPolygon(from, vertices, count, buffer) ||
           CharonGKPointInPolygon(to, vertices, count, buffer);
}

// -connectedNodes and the search score, read through the runtime. This file deliberately does not import
// <GameplayKit/GameplayKit.h>: the graph objects of the 9.0 band and the 10.0 one are separate files
// because an object holds the API of exactly one release, and a file that reached the framework's own
// headers here would carry the availability of every class they declare into an object that answers
// none of them.
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

// -costToNode:, read the same way. The node's own method is the answer for every kind of node this
// framework has: the length of the line between the two positions for a 2D or 3D node, the distance
// between two cells for a grid node, and 1 for a node that carries no position at all.
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

// --- the cells of a spatial index ----------------------------------------------------------------------
// The cell size an index actually uses, given the minimum the caller gave and the extent of its box.
//
// The minimum is a FLOOR on the size and not the size: the tree halves, so the sizes it can settle on are the
// powers of two, and the size is the SMALLEST power of two that is at least the minimum -- capped at the
// extent, so a minimum wider than the box leaves the box as one cell. Measured over eleven minimums against
// a box of extent 8 (measure.m w1):
//
//   minimum 0.25 -> cells [1.75,2] [5.5,5.75] [7.75,8] [3.25,3.5]   size 0.25
//   minimum 0.5  -> cells [1.5,2]   [5.5,6]    [7.5,8]   [3,3.5]      size 0.5
//   minimum 1    -> cells [1,2]     [5,6]      [7,8]     [3,4]        size 1
//   minimum 1.5  -> cells [0,2]     [4,6]      [6,8]     [2,4]        size 2
//   minimum 2    -> cells [0,2]     [4,6]      [6,8]     [2,4]        size 2
//   minimum 3    -> cells [0,4]     [4,8]      [4,8]     [0,4]        size 4
//   minimum 4    -> cells [0,4]     [4,8]      [4,8]     [0,4]        size 4
//   minimum 5    -> cells [0,8]     [0,8]      [0,8]     [0,8]        size 8
//   minimum 7    -> cells [0,8]     [0,8]      [0,8]     [0,8]        size 8
//   minimum 16   -> cells [0,8]     [0,8]      [0,8]     [0,8]        size 8
//
// The four points are 1.9, 5.5, 7.9 and 3.3 on the x axis. A minimum of 0 TRAPS on the host (SIGBUS, measured),
// so it is not a case this rule has to answer; it leaves the box as one cell.
float CharonGKCellSize(float minimum, float extent)
{
    if (extent <= 0 || !(minimum > 0)) {
        return extent > 0 ? extent : 0;
    }
    // Down from the extent while half of it still stands at or above the minimum. Starting at the extent and
    // halving is what keeps the answer a power of two: the extent is 8 in every measurement above, and a box
    // of an extent that is not a power of two lands on the largest power of two below it that clears the
    // minimum, which is what halving to the extent gives.
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

// A node's far edge, never past the box it indexes.
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

// --- the geometry of the two graphs that cut a plane ----------------------------------------------------
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
    // The 3D initialiser takes a different vector, so it is called through its own signature rather than
    // the 2D one; a class that answers the 2D selector is given the 2D vector.
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
    // Every vertex of the obstacle, read through the framework's own accessor so that this file needs no
    // class declaration: the count first, then each vertex. That is what a polygon obstacle is.
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

// Push a vertex out of the polygon it belongs to by a buffer. Each vertex moves along the bisector of its
// two edges, and the two corners of an edge move along the edge, so that a buffered edge is a line parallel
// to the edge at the buffer's distance. A vertex at a reflex corner moves outwards along the bisector; a
// vertex at a convex one moves inwards for the same reason, and both move by buffer/sin(half angle).
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
    // The two edge normals, each pointing outwards from the polygon, which for a counterclockwise outline
    // is the edge turned to its left.
    float normalAX = incomingY;
    float normalAY = -incomingX;
    float normalBX = outgoingY;
    float normalBY = -outgoingX;
    // The corner's bisector, and the sine of the half angle between the edges: how far along it the corner
    // has to move for each edge to be the buffer's distance away.
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

// Is this a left turn? The ear-clipping triangulation cuts a polygon by taking a corner no other corner is
// inside the triangle of, and a corner is convex exactly when the turn at it is to the left.
static BOOL CharonGKTurnsLeft(vector_float2 a, vector_float2 b, vector_float2 c)
{
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0;
}

static BOOL CharonGKPointInsideTriangle(vector_float2 p, vector_float2 a, vector_float2 b, vector_float2 c)
{
    return CharonGKTurnsLeft(a, b, p) && CharonGKTurnsLeft(b, c, p) && CharonGKTurnsLeft(c, a, p);
}

// The triangle a corner takes off when it is clipped: the corner and its two neighbours, in the outline's
// own order. The mesh graph's -triangleAtIndex: answers the three points of one, so the box is what holds
// them rather than an NSValue over bytes -- @encode cannot describe a vector type, and -getValue:size: is
// iOS 11 while this library is carried for 6.0.
static CharonGKTriangle3 *CharonGKTriangleOf(vector_float2 a, vector_float2 b, vector_float2 c)
{
    CharonGKTriangle3 *triangle = [[CharonGKTriangle3 alloc] init];
    triangle->points[0] = (vector_float3){a.x, a.y, 0};
    triangle->points[1] = (vector_float3){b.x, b.y, 0};
    triangle->points[2] = (vector_float3){c.x, c.y, 0};
    return triangle;
}

// Triangulate one simple polygon by ear clipping, and answer the triangles in the order the ears came off
// so that a caller reading -triangleAtIndex: walks them from the outline inwards.
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
            // A polygon with no ear left is one this walk cannot cut further -- a self-touching outline, or
            // one the caller gave in the wrong winding. What is left is a fan, which is the best answer a
            // polygon with no valid ear has.
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
    // A region with holes is cut by joining each hole to the outline: a bridge from the hole's rightmost
    // corner to a visible corner of what is left. The outline is then a simple polygon with a slit, which
    // ear clipping cuts, and the bridge's two sides are the same segment so the cut stays closed.
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
        // The hole is spliced in backwards after the corner it joins, so the walk goes round the outline,
        // dives into the hole, comes back out and goes on -- a slit, not a crossing.
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
    // Every pair of corners that can see each other: the line between them meets no obstacle. The result is
    // a flat list of index pairs, which is the node list of an obstacle graph without the corners.
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

// The estimated cost of a node, read the same way -costToNode: is.
float CharonGKEstimateTo(id from, id goal)
{
    SEL selector = NSSelectorFromString(@"estimatedCostToNode:");
    if (![from respondsToSelector:selector]) {
        return 0;
    }
    float (*answer)(id, SEL, id) = (float (*)(id, SEL, id))[from methodForSelector:selector];
    return answer(from, selector, goal);
}

// What the open set is ordered by: the cost reached so far PLUS the cost estimated still to run. That is A*,
// and it is what -estimatedCostToNode: is for -- GKGraphNode.h:38-41 declares it next to -costToNode: and
// calls it the estimated heuristic cost of reaching the indicated node from this node.
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

    // The three pieces of state a pass carries, filed on the node itself as associated objects. The
    // search runs inside one call and nothing of it outlives that call, so an association is enough and
    // the framework's surface grows no name for it.
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

    // The open set is scanned for its lowest score rather than kept in a heap. A graph is a few hundred
    // nodes and the scan costs nothing next to the edges, and a heap would be a structure the release may
    // not have.
    while ([open count] > 0) {
        NSUInteger best = 0;
        float bestScore = CharonGKSearchPriority([open objectAtIndex:0], goal);
        for (NSUInteger index = 1; index < [open count]; index++) {
            float score = CharonGKSearchPriority([open objectAtIndex:index], goal);
            // A tie keeps the LATER node of the open set, and both halves of that are measured rather than
            // chosen. The ordering is A*: the cost reached so far PLUS the cost estimated still to run, which
            // is what -estimatedCostToNode: exists for. A path across a 3x2 grid from (2,3) to (4,4) has two
            // answers of the same length, and the host answers the one that goes up before it goes right --
            // which is the one whose f is lower, because at (3,3) the cell above is one step from the goal and
            // the cell to the right is two. The tie that remains -- two cells at the same f -- goes to the one
            // added last, which is what `<=` does here: measured, two nodes joined to a third and to a fourth
            // at (10,0), where the direct edge and the two-step way cost the same in total, and the host
            // answers the direct one, which was added first and then superseded by the tie rule.
            if (score <= bestScore) {
                bestScore = score;
                best = index;
            }
        }
        id current = [open objectAtIndex:best];
        // A tie on the score is broken by the order the open set holds, which is the order the edges were
        // added in -- so the grid's own connection order decides it. Measured: across a 3x2 grid the host
        // answers (2,3) (3,3) (3,4) (4,4) and not (2,3) (3,3) (4,3) (4,4), so a cell's neighbour above it
        // comes before the one to its right.
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