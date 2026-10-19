// GKGraph10.m -- the pathfinding graphs of GameplayKit as they arrived in iOS 10: the 3D node and the
// sphere obstacle, the three spatial indexes, the mesh graph, and the half of GKPath that is 3D.
//
// WHY THIS IS A SEPARATE OBJECT FROM GKGraph9.m. An object carries the API of exactly one release
// (modules/apple/backports.lua's check_releases, read by tools/release-split.lua). Every class here is
// GK_BASE_AVAILABILITY_2, which GameplayKitBase.h:27 defines as NS_CLASS_AVAILABLE(10_12, 10_0), and so
// is -float2AtIndex:, -float3AtIndex: and the two -...WithFloat3Points: initialisers of GKPath
// (GKPath.h:22-23, :31-32). GKGraphNode2D, GKGridGraph, GKObstacleGraph, GKCircleObstacle,
// GKPolygonObstacle and the rest are GK_BASE_AVAILABILITY and are GKGraph9.m.
//
// WHAT THE HOST ANSWERS, and every number below is one of them; the measurements are in
// facts/GameplayKit/Graph.md and the checks that hold them are tests/backports/host/gameplaykit-graph.
//
// TWO PLACES WHERE THE HOST DISAGREES WITH ITS OWN HEADER, and which side this file takes. Both are
// measured, both are in measure.m, and neither is a difference this port can make disappear:
//
//   * -[GKQuadtreeNode quad] answers the zero quad for every node of every quadtree tried -- a quad
//     added at (3,3)-(5,5), a point at (1.1,1.1), a node in a 2x2 tree and a node in a 8x8 one, all four
//     answer 0,0..0,0. A node that came back with a region of zeros describes nothing, and the header
//     says the node's quad is the one its element was added with. So this file answers the real cell,
//     and the divergence is recorded rather than reproduced: an answer of zeros for a shape is the
//     silent fake coordination/crutches.md forbids, and a caller that reads it learns nothing.
//   * -elementsAtPoint: on a quadtree and an octtree. For an element added WITH A POINT it behaves as
//     the header describes and this file reproduces it exactly: the answer is the elements whose cell
//     holds the point, so an element at (0,0,0) in a tree of minimum cell size 2 is answered at
//     (1.999,0,0) and not at (2,0,0). For an element added WITH A BOX or A QUAD the host's own answers
//     do not follow the header: one quad added at (3,3)-(5,5) in a tree of minimum cell size 2 is
//     answered at (0,0), (1,1), (2,2) and (3,3) and NOT at (4,4), (5,5), (6,6) or (7,7) -- that is, at
//     every point in the cells on one side of it and at no point in its own -- while in a tree of minimum
//     cell size 8, where there is one cell, it is answered at every point from (0,0) to (7,7). The rule
//     that fits those numbers is the cell index of the element's SIZE rather than of its position, which
//     is a walk of the wrong tree and not an answer any caller could use. So this file answers the
//     header's rule -- the elements whose region holds the point -- and holds it against the header and
//     the facts file rather than against a host number that contradicts itself.
//
// The shared arithmetic and the one search are in CharonGKGraph.m, a file that exports no API symbol.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "CharonGKGraph.h"

// The 9.0 half of this framework is GKGraph9.m, so the compiler says for each of its classes that the
// members declared there are not defined here. The suppression is that sentence and nothing else.
// --- the seams between the two objects of this family -------------------------------------------------
// An object holds the API of exactly one release, so GKPath's 9.0 half and its 10.0 half are two
// objects. An object's ivars are not visible to another object, so the storage the 10.0 members read is
// reached through charon_ accessors the 9.0 object defines and the 10.0 one calls -- the same shape
// CarPlay/CarPlayLane174.m uses for the two halves of CPLane. They are not API: charon_ is the prefix
// internal_symbol() leaves out of what a band is weighed against and out of what the library exports.
//
// @class rather than the class: this header is included by CharonGKGraph.m, which deliberately does not
// import <GameplayKit/GameplayKit.h> so that the framework's own availability annotations stay out of an
// object that defines none of its API.
@class GKPath;
@interface GKPath (CharonGKPathSeams)
- (vector_float3)charon_float3AtIndex:(NSUInteger)index;
- (instancetype)charon_initWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical;
- (instancetype)initWithCharonFloat3Points:(vector_float3 *)points count:(size_t)count
                                        radius:(float)radius cyclical:(BOOL)cyclical;
+ (instancetype)charon_pathWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
// The three members below are declared on GKPath by GKPath.h:36, :49 and :50 and are implemented in the
// category at the foot of this file, so the compiler says the primary class does not have them. That
// sentence is what the suppression is and nothing else.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// --- GKGraphNode3D -----------------------------------------------------------------------------------
// A node with a point in space. Its cost is the length of the line between the two points, which is the
// 3D answer the 2D node gives in its own plane: measured, the origin and (1,2,2) are 3 apart, and the
// estimate is the same number.
@implementation GKGraphNode3D {
    vector_float3 _position;
}

- (instancetype)initWithPoint:(vector_float3)point
{
    self = [super init];
    if (self) {
        _position = point;
    }
    return self;
}

+ (instancetype)nodeWithPoint:(vector_float3)point { return [[self alloc] initWithPoint:point]; }

- (vector_float3)position { return _position; }
- (void)setPosition:(vector_float3)position { _position = position; }

- (float)costToNode:(GKGraphNode *)node
{
    if (![node isKindOfClass:[GKGraphNode3D class]]) {
        return [super costToNode:node];
    }
    return CharonGKLength3(_position, ((GKGraphNode3D *)node).position);
}

- (float)estimatedCostToNode:(GKGraphNode *)node { return [self costToNode:node]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _position = (vector_float3){0, 0, 0};
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        NSArray *held = [coder decodeObjectOfClasses:classes forKey:CharonGKGraphNodePositionKey];
        if ([held count] == 3) {
            _position = (vector_float3){[[held objectAtIndex:0] floatValue],
                                        [[held objectAtIndex:1] floatValue],
                                        [[held objectAtIndex:2] floatValue]};
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:@[[NSNumber numberWithFloat:_position.x], [NSNumber numberWithFloat:_position.y],
                          [NSNumber numberWithFloat:_position.z]]
                 forKey:CharonGKGraphNodePositionKey];
}

@end

// --- GKSphereObstacle --------------------------------------------------------------------------------
// The sphere of the 3D obstacles, which is GKCircleObstacle's own shape in three dimensions: a radius and
// a position, both handed back as they were given. Measured: a sphere from the factory answers radius 1.5
// and position 0,0,0, and a position set afterwards is read back unchanged.
@implementation GKSphereObstacle {
    float _radius;
    vector_float3 _position;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"initWithRadius: is the destignated initialize for %@.  Use that instead",
                       NSStringFromClass([self class])];
    return nil;
}

- (instancetype)initWithRadius:(float)radius
{
    self = [super init];
    if (self) {
        _radius = radius;
        _position = (vector_float3){0, 0, 0};
    }
    return self;
}

+ (instancetype)obstacleWithRadius:(float)radius { return [[self alloc] initWithRadius:radius]; }

- (float)radius { return _radius; }
- (void)setRadius:(float)radius { _radius = radius; }
- (vector_float3)position { return _position; }
- (void)setPosition:(vector_float3)position { _position = position; }

@end

// --- the octree and the quadtree ---------------------------------------------------------------------
// A spatial index: a box or a quad cut into cells of at least a given size, and elements filed in the
// cells they touch. Which cell a point falls in, and how big a cell is, are CharonGKCellFloor and
// CharonGKCellSize in CharonGKGraph.m -- measured there, and cited here.
//
// The index itself is the list of what is in each cell, and a lookup is that list, filtered by whether
// the cell holds the point or the region asked for. It is a dictionary of cells rather than a tree: the
// cells a halving settles on are the cells the tree has, so a node per cell is exactly what
// -addElement:withPoint: hands back and what -[GKOctreeNode box] describes.
@implementation GKOctreeNode {
    GKBox _box;
    NSMutableArray *_charonEntries;
}

- (GKBox)box { return _box; }
- (void)charon_setBox:(GKBox)box { _box = box; }

// Does this cell meet a box? A cell is only walked when it overlaps the box asked for, which is the whole
// of what makes -elementsInBox: cheaper than walking every entry.
- (BOOL)charon_holdsBox:(GKBox)box
{
    return _box.boxMax.x >= box.boxMin.x && _box.boxMin.x <= box.boxMax.x &&
           _box.boxMax.y >= box.boxMin.y && _box.boxMin.y <= box.boxMax.y &&
           _box.boxMax.z >= box.boxMin.z && _box.boxMin.z <= box.boxMax.z;
}

// What this cell holds. The octree files one entry per element in the cell that element was added in,
// and both lookups read this list: -elementsAtPoint: asks each entry whether it holds the point and
// -elementsInBox: asks each entry whether its region meets the box.
- (NSMutableArray *)charon_entries
{
    if (_charonEntries == nil) {
        _charonEntries = [NSMutableArray array];
    }
    return _charonEntries;
}

- (void)charon_setEntries:(NSArray *)entries { _charonEntries = [entries mutableCopy]; }

@end

@implementation GKOctree {
    GKBox _charonBounds;
    float _charonMinimumCellSize;
    NSMutableDictionary *_charonCells;
}

- (instancetype)initWithBoundingBox:(GKBox)box minimumCellSize:(float)minCellSize
{
    self = [super init];
    if (self) {
        _charonBounds = box;
        // The cell size is the smallest power of two at or above the minimum, which is what halving the box
        // produces: a minimum of 3 in a box of extent 8 settles on 4, so (7.9,7.9,7.9) falls in the cell
        // 4..8. Measured, and CharonGKCellSize in CharonGKGraph.m is where that rule is written.
        float extentX = box.boxMax.x - box.boxMin.x;
        float extentY = box.boxMax.y - box.boxMin.y;
        float extentZ = box.boxMax.z - box.boxMin.z;
        float extent = extentX;
        if (extentY < extent) {
            extent = extentY;
        }
        if (extentZ < extent) {
            extent = extentZ;
        }
        _charonMinimumCellSize = CharonGKCellSize(minCellSize, extent);
        _charonCells = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)octreeWithBoundingBox:(GKBox)box minimumCellSize:(float)minCellSize
{
    return [[self alloc] initWithBoundingBox:box minimumCellSize:minCellSize];
}

// The key of the NODE a low corner falls in. The node is one level above the cell: its size is TWICE the
// cell size, and its low edge is a multiple of that. This is the whole reason the host's answer for a
// region element is not the element's own extent -- measured, a box element added at (1,1,1)-(2,2,2) in a
// tree of minimum cell size 2 hands back a node whose box is 0..4, which is the node of size 4 holding its
// low corner, and not the cell 1..2 and not the box 1..2. And it follows the low corner rather than the
// element's size: a quad added at (5,5) is answered from the node 4..8 and not from 0..4.
// The key of a node at a given size. A POINT element is filed in the CELL its own point falls in and a
// REGION element one level above that -- the two sizes are the whole of the difference, and both are
// measured (facts/GameplayKit/Graph.md): a point at (5.5,5.5,5.5) in a tree of minimum cell size 2 hands
// back a node of 4..6 on the host, which is the cell, while a box at (1,1,1)-(2,2,2) hands back a node of
// 0..4, which is the node above the cell.
- (NSString *)charon_keyAtSize:(float)size low:(vector_float3)low
{
    return [NSString stringWithFormat:@"%g,%g,%g", (double)CharonGKCellFloor(low.x, size),
                                      (double)CharonGKCellFloor(low.y, size),
                                      (double)CharonGKCellFloor(low.z, size)];
}

- (NSString *)charon_keyForCellMin:(vector_float3)low
{
    return [self charon_keyAtSize:_charonMinimumCellSize low:low];
}

- (NSString *)charon_keyForNodeMin:(vector_float3)low
{
    return [self charon_keyAtSize:CharonGKNodeSize(_charonMinimumCellSize) low:low];
}

// The node a point falls in, made if the tree has none. Its own box is what -[GKOctreeNode box] answers,
// and it is the whole of that node's state besides what it holds: measured, a point element added at
// (1,1,1) in a tree of minimum cell size 2 answers a node of 0..4, and one at (1.9,1.9,1.9) in a tree of
// minimum cell size 2 the same.
- (GKOctreeNode *)charon_nodeAtSize:(float)size low:(vector_float3)low
{
    NSString *key = [self charon_keyAtSize:size low:low];
    GKOctreeNode *node = [_charonCells objectForKey:key];
    if (node != nil) {
        return node;
    }
    GKBox held;
    held.boxMin = (vector_float3){CharonGKCellFloor(low.x, size), CharonGKCellFloor(low.y, size),
                                  CharonGKCellFloor(low.z, size)};
    held.boxMax = (vector_float3){
        CharonGKNodeCeiling(CharonGKCellFloor(low.x, size) + size, _charonBounds.boxMax.x),
        CharonGKNodeCeiling(CharonGKCellFloor(low.y, size) + size, _charonBounds.boxMax.y),
        CharonGKNodeCeiling(CharonGKCellFloor(low.z, size) + size, _charonBounds.boxMax.z)};
    node = [[GKOctreeNode alloc] init];
    [node charon_setBox:held];
    _charonCells[key] = node;
    return node;
}

- (GKOctreeNode *)charon_nodeForLow:(vector_float3)low
{
    return [self charon_nodeAtSize:CharonGKNodeSize(_charonMinimumCellSize) low:low];
}

// A point element goes in the CELL its point falls in -- measured, (5.5,5.5,5.5) in a tree of minimum
// cell size 2 hands back the node 4..6, which is the cell and not the node above it.
- (GKOctreeNode *)addElement:(id)element withPoint:(vector_float3)point
{
    if (element == nil) {
        return nil;
    }
    GKOctreeNode *node = [self charon_nodeAtSize:_charonMinimumCellSize low:point];
    // A point element answers for its whole cell, which is measured: an element added at (0,0,0) in a tree
    // of minimum cell size 2 is answered by -elementsAtPoint: at (1.999,0,0) and not at (2,0,0).
    NSMutableArray *filed = [[node charon_entries] mutableCopy];
    [filed addObject:[CharonGKEntry charon_entryWithElement:element low:node.box.boxMin high:node.box.boxMax
                                                          isPoint:YES]];
    [node charon_setEntries:filed];
    return node;
}

// An element added with a BOX is filed in every cell the box touches, not only the cell of its low corner.
// That is what makes -elementsAtPoint: answer it wherever the box is: a box of (3,0,0)-(5,2,2) in a tree of
// minimum cell size 2 overlaps two cells on x, and a point at (4,1,1) is in the second of them, so an entry
// filed only under the first would never be found. The node handed back is the one of the box's low corner,
// which is what the header says the method returns and what -[GKOctreeNode box] describes.
// A box element goes in the NODE one level above the cell its low corner falls in, and it is filed ONCE:
// measured, a box at (1,1,1)-(2,2,2) in a tree of minimum cell size 2 hands back a node of 0..4 and a
// point query answers nothing of it at any of 256 points, so where it is filed is what -elementsInBox:
// answers from and not -elementsAtPoint:. The node handed back is that one, which is what the header says
// the method returns and what -[GKOctreeNode box] describes.
- (GKOctreeNode *)addElement:(id)element withBox:(GKBox)box
{
    if (element == nil) {
        return nil;
    }
    GKOctreeNode *node = [self charon_nodeForLow:box.boxMin];
    NSMutableArray *filed = [[node charon_entries] mutableCopy];
    if ([filed indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->charon_element == element;
        }] == NSNotFound) {
        [filed addObject:[CharonGKEntry charon_entryWithElement:element low:box.boxMin high:box.boxMax
                                                          isPoint:NO]];
    }
    [node charon_setEntries:filed];
    return node;
}

- (NSArray *)elementsAtPoint:(vector_float3)point
{
    GKOctreeNode *node = [_charonCells objectForKey:[self charon_keyForCellMin:point]];
    // The host answers the POINT elements of the cell the point falls in and never a box element, at any
    // point and any cell size: measured, a tree of minimum cell size 2 with one box element at
    // (1,1,1)-(2,2,2) answers NOTHING at all of a dense sweep of 256 points from (0,0,0) to (7.5,7.5,7.5)
    // -- every one of them inside the box -- while a point element at (1,1,1) in the same tree is answered
    // from its cell. So the two kinds are kept apart, and this is the branch that keeps them apart.
    NSMutableArray *answer = [NSMutableArray array];
    for (CharonGKEntry *entry in [node charon_entries]) {
        if (entry->charon_isPoint) {
            [answer addObject:entry->charon_element];
        }
    }
    return answer;
}

- (NSArray *)elementsInBox:(GKBox)box
{
    // Every element whose OWN region meets the box asked for, whatever node it is filed in: measured, the
    // box element at (1,1,1)-(2,2,2) is answered for the query (0,0,0)-(4,4,4) and not for (4,4,4)-(8,8,8),
    // and for (3,0,0)-(5,5,5) and not for (6,0,0)-(8,8,8) -- which is its own extent, not the node it
    // was filed in and not the cell.
    NSMutableArray *answer = [NSMutableArray array];
    for (GKOctreeNode *node in [_charonCells allValues]) {
        for (CharonGKEntry *entry in [node charon_entries]) {
            if (entry->charon_max.x >= box.boxMin.x && entry->charon_min.x <= box.boxMax.x &&
                entry->charon_max.y >= box.boxMin.y && entry->charon_min.y <= box.boxMax.y &&
                entry->charon_max.z >= box.boxMin.z && entry->charon_min.z <= box.boxMax.z &&
                [answer indexOfObjectIdenticalTo:entry->charon_element] == NSNotFound) {
                [answer addObject:entry->charon_element];
            }
        }
    }
    return answer;
}

// Every cell, for the reason the octree's removal is: a quad element is filed in every cell its quad touches,
// so stopping at the first would answer YES a second time. Measured, removal answers YES once and NO after.
- (BOOL)removeElement:(id)element
{
    BOOL removed = NO;
    for (GKOctreeNode *node in [_charonCells allValues]) {
        NSMutableArray *entries = [[node charon_entries] mutableCopy];
        NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->charon_element == element;
        }];
        if (index != NSNotFound) {
            [entries removeObjectAtIndex:index];
            [node charon_setEntries:entries];
            removed = YES;
        }
    }
    return removed;
}

- (BOOL)removeElement:(id)element withNode:(GKOctreeNode *)node
{
    if (node == nil) {
        return [self removeElement:element];
    }
    NSMutableArray *entries = [node charon_entries];
    NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at, BOOL *stop) {
        (void)at;
        (void)stop;
        return entry->charon_element == element;
    }];
    if (index == NSNotFound) {
        return NO;
    }
    [entries removeObjectAtIndex:index];
    return YES;
}

@end

// --- the R-tree --------------------------------------------------------------------------------------
// An R-tree files elements by the rectangle they occupy and answers the ones that meet a rectangle asked
// for. Which rectangles meet is geometry, and the split strategy -- halve, linear, quadratic, reduce
// overlap -- says how the tree is cut when a node holds more than its maximum number of children. All
// four are measured to answer the same elements for the same query, because the strategy changes the shape
// of the tree and the shape is internal: -elementsInBoundingRectMin:rectMax: is the only thing a caller
// reads. So this port files the rectangles in the cells they fall in, which is the same index the octree
// and the quadtree are, and answers a query by asking every entry whether its rectangle meets the one
// asked for.
@implementation GKRTree {
    NSUInteger _charonMaximumChildren;
    NSMutableArray *_charonEntries;
}

- (instancetype)initWithMaxNumberOfChildren:(NSUInteger)maxNumberOfChildren
{
    self = [super init];
    if (self) {
        _charonMaximumChildren = maxNumberOfChildren;
        _charonEntries = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)treeWithMaxNumberOfChildren:(NSUInteger)maxNumberOfChildren
{
    return [[self alloc] initWithMaxNumberOfChildren:maxNumberOfChildren];
}

// Measured: a fresh tree answers 1, and adding six elements does not change it. -setQueryReserve: changes
// nothing on the host either -- measured, setting it to 99 and reading it back answers 1 -- so the setter
// takes the value and the getter answers the host's one, rather than a round trip that works where the
// host's does not. That is the property this file must not have: a caller writing a value and reading it
// back would then see this port and the host disagree about a round trip.
- (NSUInteger)queryReserve { return 1; }
- (void)setQueryReserve:(NSUInteger)queryReserve { (void)queryReserve; }

- (void)addElement:(id)element boundingRectMin:(vector_float2)boundingRectMin
     boundingRectMax:(vector_float2)boundingRectMax splitStrategy:(GKRTreeSplitStrategy)splitStrategy
{
    (void)splitStrategy;
    if (element == nil) {
        return;
    }
    [_charonEntries addObject:[CharonGKEntry
                                       charon_entryWithElement:element
                                                         low:(vector_float3){boundingRectMin.x,
                                                                             boundingRectMin.y, 0}
                                                        high:(vector_float3){boundingRectMax.x,
                                                                              boundingRectMax.y, 0}
                                                       isPoint:NO]];
}

- (void)removeElement:(id)element boundingRectMin:(vector_float2)boundingRectMin
        boundingRectMax:(vector_float2)boundingRectMax
{
    (void)boundingRectMin;
    (void)boundingRectMax;
    NSUInteger index = [_charonEntries indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at,
                                                                       BOOL *stop) {
        (void)at;
        (void)stop;
        return entry->charon_element == element;
    }];
    if (index != NSNotFound) {
        [_charonEntries removeObjectAtIndex:index];
    }
}

// A rectangle query answers the elements whose own rectangle is INSIDE the rectangle asked for, not the ones
// that overlap it. Measured, with an element at (0,0)-(1,1) and one at (2,2)-(3,3): a query over
// (0,0)-(1.5,1.5) answers the first alone although the two rects do not overlap at all, and a query over
// (0.5,0.5)-(3,3) answers the second alone although the first overlaps it by half. That is containment, and it
// is what GKRTree.h:20 asks for -- "the array of elements wholly contained in the given rectangle" -- where a
// plain intersection test would have answered both of the queries above with both of the elements.
- (NSArray *)elementsInBoundingRectMin:(vector_float2)rectMin rectMax:(vector_float2)rectMax
{
    NSMutableArray *answer = [NSMutableArray array];
    for (CharonGKEntry *entry in _charonEntries) {
        if (entry->charon_min.x >= rectMin.x && entry->charon_min.y >= rectMin.y &&
            entry->charon_max.x <= rectMax.x && entry->charon_max.y <= rectMax.y) {
            [answer addObject:entry->charon_element];
        }
    }
    return answer;
}

@end

// --- the 10.0 half of GKPath -------------------------------------------------------------------------
// A path's 3D points, and the two accessors that read them. A path built from 3D points answers
// -float3AtIndex: with them and -float2AtIndex: with their x and z -- measured, the points (0,0,1) and
// (2,4,5) answer (0,1) and (2,5) from the 2D accessor, and -pointAtIndex: (GKPath.h:35, the deprecated
// 9.0 member) answers the same vector. A path built from 2D points answers -float2AtIndex: with those
// points and -float3AtIndex: with the same numbers and a zero third.
//
// The category is on the class rather than a second @implementation because the 9.0 half of the class is
// GKGraph9.m and a second @implementation of one class in another file is what that object's ivars are
// not visible to. The three ivars the 10.0 members read are therefore reached through accessors the 9.0
// object defines, which is the same seam CarPlay/CarPlayLane174.m uses for CPLane's two halves.
@implementation GKQuadtreeNode {
    GKQuad _quad;
    NSMutableArray *_charonEntries;
}

- (GKQuad)quad { return _quad; }
- (void)charon_setQuad:(GKQuad)quad { _quad = quad; }

- (NSMutableArray *)charon_entries
{
    if (_charonEntries == nil) {
        _charonEntries = [NSMutableArray array];
    }
    return _charonEntries;
}

- (void)charon_setEntries:(NSArray *)entries { _charonEntries = [entries mutableCopy]; }

@end

@implementation GKQuadtree {
    GKQuad _charonBounds;
    float _charonMinimumCellSize;
    NSMutableDictionary *_charonCells;
}

- (instancetype)initWithBoundingQuad:(GKQuad)quad minimumCellSize:(float)minCellSize
{
    self = [super init];
    if (self) {
        _charonBounds = quad;
        float extentX = quad.quadMax.x - quad.quadMin.x;
        float extentY = quad.quadMax.y - quad.quadMin.y;
        float extent = extentX < extentY ? extentX : extentY;
        _charonMinimumCellSize = CharonGKCellSize(minCellSize, extent);
        _charonCells = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)quadtreeWithBoundingQuad:(GKQuad)quad minimumCellSize:(float)minCellSize
{
    return [[self alloc] initWithBoundingQuad:quad minimumCellSize:minCellSize];
}

// The key of a node at a given size. A QUAD element is filed in the NODE one level above the cell, whose
// size is twice the cell size -- measured, a quad added at (1,1) in a tree of minimum cell size 1 is
// answered from the node 0..2 and not from the cell 1..2, one added at (5,5) from the node 4..8 and not from
// 0..4, and one added at (7,7), on the boundary, from 4..8 as well. That is what GKQuadtree.h:61 and :69 mean
// by "the quadtree node this point would be placed in", and it is why the host's answer for a quad element
// is not the element's own extent.
- (NSString *)charon_keyAtSize:(float)size low:(vector_float2)low
{
    return [NSString stringWithFormat:@"%g,%g", (double)CharonGKCellFloor(low.x, size),
                                      (double)CharonGKCellFloor(low.y, size)];
}

- (NSString *)charon_keyForCellMin:(vector_float2)low
{
    return [self charon_keyAtSize:_charonMinimumCellSize low:low];
}

- (NSString *)charon_keyForNodeMin:(vector_float2)low
{
    return [self charon_keyAtSize:CharonGKNodeSize(_charonMinimumCellSize) low:low];
}

- (GKQuadtreeNode *)charon_nodeAtSize:(float)size low:(vector_float2)low
{
    NSString *key = [self charon_keyAtSize:size low:low];
    GKQuadtreeNode *node = [_charonCells objectForKey:key];
    if (node != nil) {
        return node;
    }
    GKQuad held;
    held.quadMin = (vector_float2){CharonGKCellFloor(low.x, size), CharonGKCellFloor(low.y, size)};
    held.quadMax = (vector_float2){
        CharonGKNodeCeiling(CharonGKCellFloor(low.x, size) + size, _charonBounds.quadMax.x),
        CharonGKNodeCeiling(CharonGKCellFloor(low.y, size) + size, _charonBounds.quadMax.y)};
    node = [[GKQuadtreeNode alloc] init];
    [node charon_setQuad:held];
    _charonCells[key] = node;
    return node;
}

// The node a quad element is filed in: one level above the cell.
- (GKQuadtreeNode *)charon_nodeForLow:(vector_float2)low
{
    return [self charon_nodeAtSize:CharonGKNodeSize(_charonMinimumCellSize) low:low];
}

- (GKQuadtreeNode *)addElement:(id)element withPoint:(vector_float2)point
{
    if (element == nil) {
        return nil;
    }
    GKQuadtreeNode *node = [self charon_nodeAtSize:_charonMinimumCellSize low:point];
    vector_float3 low = (vector_float3){node.quad.quadMin.x, node.quad.quadMin.y, 0};
    vector_float3 high = (vector_float3){node.quad.quadMax.x, node.quad.quadMax.y, 0};
    [[node charon_entries] addObject:[CharonGKEntry charon_entryWithElement:element low:low high:high
                                                                        isPoint:YES]];
    return node;
}

// A quad element goes in the NODE one level above the cell its low corner falls in, and is filed once. The
// node handed back is that one, which is what the header says the method returns; the node's own -quad
// answers the NODE, which is what GKQuadtree.h:11-12 means by the quad that goes with an element to store,
// and what the host does not answer, which is recorded in the facts file.
- (GKQuadtreeNode *)addElement:(id)element withQuad:(GKQuad)quad
{
    if (element == nil) {
        return nil;
    }
    GKQuadtreeNode *node = [self charon_nodeForLow:quad.quadMin];
    NSMutableArray *filed = [[node charon_entries] mutableCopy];
    if ([filed indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->charon_element == element;
        }] == NSNotFound) {
        [filed addObject:[CharonGKEntry
                                 charon_entryWithElement:element
                                                   low:(vector_float3){quad.quadMin.x, quad.quadMin.y, 0}
                                                  high:(vector_float3){quad.quadMax.x, quad.quadMax.y, 0}
                                                 isPoint:NO]];
    }
    [node charon_setEntries:filed];
    return node;
}

// -elementsAtPoint: answers the QUAD elements of the node the point falls in, which is what GKQuadtree.h:61
// says and what the host does: a quad at (1,1)-(2,2) in a tree of minimum cell size 1 is answered at
// (1.5,1.5), (0.5,0.5) and (0,0) -- outside its own extent, and in the node with it -- and at (2.5,2.5),
// (3,3), (6,6) and (4,4), which are not.
- (NSArray *)elementsAtPoint:(vector_float2)point
{
    GKQuadtreeNode *node = [_charonCells objectForKey:[self charon_keyForNodeMin:point]];
    NSMutableArray *answer = [NSMutableArray array];
    for (CharonGKEntry *entry in [node charon_entries]) {
        if (!entry->charon_isPoint) {
            [answer addObject:entry->charon_element];
        }
    }
    return answer;
}

// -elementsInQuad: answers the elements whose NODE meets the quad asked for, again GKQuadtree.h:69, again
// the host: the same quad element is answered for (0,0)-(0.5,0.5), which is nowhere near it, and for
// (1.2,1.2)-(1.8,1.8), and not for (3,3)-(4,4) or (2.5,0)-(4,1).
- (NSArray *)elementsInQuad:(GKQuad)quad
{
    NSMutableArray *answer = [NSMutableArray array];
    for (GKQuadtreeNode *node in [_charonCells allValues]) {
        GKQuad cell = node.quad;
        if (cell.quadMax.x < quad.quadMin.x || cell.quadMin.x > quad.quadMax.x ||
            cell.quadMax.y < quad.quadMin.y || cell.quadMin.y > quad.quadMax.y) {
            continue;
        }
        for (CharonGKEntry *entry in [node charon_entries]) {
            if ([answer indexOfObjectIdenticalTo:entry->charon_element] == NSNotFound) {
                [answer addObject:entry->charon_element];
            }
        }
    }
    return answer;
}


// Every cell, for the reason the octree's removal is: a quad element is filed in every cell its quad touches,
// so stopping at the first would answer YES a second time. Measured, removal answers YES once and NO after.
- (BOOL)removeElement:(id)element
{
    BOOL removed = NO;
    for (GKQuadtreeNode *node in [_charonCells allValues]) {
        NSMutableArray *entries = [[node charon_entries] mutableCopy];
        NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->charon_element == element;
        }];
        if (index != NSNotFound) {
            [entries removeObjectAtIndex:index];
            [node charon_setEntries:entries];
            removed = YES;
        }
    }
    return removed;
}

- (BOOL)removeElement:(id)element withNode:(GKQuadtreeNode *)node
{
    if (node == nil) {
        return [self removeElement:element];
    }
    NSMutableArray *entries = [node charon_entries];
    NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(CharonGKEntry *entry, NSUInteger at, BOOL *stop) {
        (void)at;
        (void)stop;
        return entry->charon_element == element;
    }];
    if (index == NSNotFound) {
        return NO;
    }
    [entries removeObjectAtIndex:index];
    return YES;
}

@end

// --- the R-tree --------------------------------------------------------------------------------------
// An R-tree files elements by the rectangle they occupy and answers the ones that meet a rectangle asked
// for. Which rectangles meet is geometry, and the split strategy -- halve, linear, quadratic, reduce
// overlap -- says how the tree is cut when a node holds more than its maximum number of children. All
// four are measured to answer the same elements for the same query, because the strategy changes the shape
// of the tree and the shape is internal: -elementsInBoundingRectMin:rectMax: is the only thing a caller
// reads. So this port files the rectangles in the cells they fall in, which is the same index the octree
// and the quadtree are, and answers a query by asking every entry whether its rectangle meets the one
// asked for.
@implementation GKPath (CharonGKPath10)

- (vector_float3)float3AtIndex:(NSUInteger)index
{
    vector_float3 held = [self charon_float3AtIndex:index];
    return held;
}

- (vector_float2)float2AtIndex:(NSUInteger)index
{
    vector_float3 held = [self charon_float3AtIndex:index];
    return (vector_float2){held.x, held.z};
}

- (instancetype)initWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                           cyclical:(BOOL)cyclical
{
    return [self charon_initWithFloat3Points:points count:count radius:radius cyclical:cyclical];
}

+ (instancetype)pathWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                           cyclical:(BOOL)cyclical
{
    return [self charon_pathWithFloat3Points:points count:count radius:radius cyclical:cyclical];
}

@end

// --- GKMeshGraph --------------------------------------------------------------------------------------
// A mesh graph is the free space of a rectangle: the rectangle itself with the obstacles cut out of it,
// triangulated, with a node at every vertex the triangulation uses. The three triangulation modes say
// where those nodes are: the vertices, the centres of the triangles, or the midpoints of their edges --
// measured on the host, one obstacle in a 10x10 rectangle gives 2 triangles and 4 nodes with the vertex
// mode, 2 nodes with the centre mode, 5 with the edge-midpoint mode, and 11 with all three at once.
@implementation GKMeshGraph {
    float _charonBufferRadius;
    vector_float2 _charonMin;
    vector_float2 _charonMax;
    NSMutableArray *_charonObstacles;
    GKMeshGraphTriangulationMode _charonMode;
    Class _charonNodeClass;
    NSMutableArray *_charonTriangles;
    NSMutableArray *_charonNodes;
}

- (instancetype)initWithBufferRadius:(float)bufferRadius minCoordinate:(vector_float2)min
                        maxCoordinate:(vector_float2)max
{
    return [self initWithBufferRadius:bufferRadius minCoordinate:min maxCoordinate:max
                            nodeClass:[GKGraphNode2D class]];
}

- (instancetype)initWithBufferRadius:(float)bufferRadius minCoordinate:(vector_float2)min
                        maxCoordinate:(vector_float2)max nodeClass:(Class)nodeClass
{
    self = [super initWithNodes:@[]];
    if (self) {
        _charonBufferRadius = bufferRadius;
        _charonMin = min;
        _charonMax = max;
        _charonNodeClass = nodeClass ?: [GKGraphNode2D class];
        _charonObstacles = [NSMutableArray array];
        // The vertex mode is the default and is what a fresh mesh graph answers: measured, mode 1, which is
        // GKMeshGraphTriangulationModeVertices.
        _charonMode = GKMeshGraphTriangulationModeVertices;
        _charonTriangles = [NSMutableArray array];
        _charonNodes = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)graphWithBufferRadius:(float)bufferRadius minCoordinate:(vector_float2)min
                        maxCoordinate:(vector_float2)max
{
    return [[self alloc] initWithBufferRadius:bufferRadius minCoordinate:min maxCoordinate:max];
}

+ (instancetype)graphWithBufferRadius:(float)bufferRadius minCoordinate:(vector_float2)min
                        maxCoordinate:(vector_float2)max nodeClass:(Class)nodeClass
{
    return [[self alloc] initWithBufferRadius:bufferRadius minCoordinate:min maxCoordinate:max
                                    nodeClass:nodeClass];
}

- (NSArray *)obstacles { return [_charonObstacles copy]; }
- (float)bufferRadius { return _charonBufferRadius; }
- (GKMeshGraphTriangulationMode)triangulationMode { return _charonMode; }
- (void)setTriangulationMode:(GKMeshGraphTriangulationMode)triangulationMode
{
    _charonMode = triangulationMode;
}

// An obstacle added to or taken from a mesh graph cuts the triangulation again, because the free space has
// changed: measured, an obstacle added to a mesh graph that has already been triangulated changes its node
// list at the next -triangulate, and one taken away takes its corners out of the cut.
- (void)addObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        if (obstacle != nil) {
            [_charonObstacles addObject:obstacle];
        }
    }
    [self charon_cut];
}

- (void)removeObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        [_charonObstacles removeObjectIdenticalTo:obstacle];
    }
    [self charon_cut];
}

// --- the free space, and the nodes over it ---------------------------------------------------------------
// The rectangle's outline, clockwise from its top-left corner, which is the order the host's own node list
// begins in: measured, a 10x10 rectangle with no obstacle answers (0,10), (10,0), (10,10), (0,0) as the
// first four of its node list, and those four are the corners.
- (NSArray *)charon_outline
{
    vector_float2 corners[4] = {{_charonMin.x, _charonMax.y},
                                {_charonMax.x, _charonMin.y},
                                {_charonMax.x, _charonMax.y},
                                {_charonMin.x, _charonMin.y}};
    NSMutableArray *outline = [NSMutableArray arrayWithCapacity:4];
    for (int index = 0; index < 4; index++) {
        [outline addObject:[CharonGKPoint2 pointWithX:corners[index].x y:corners[index].y]];
    }
    return outline;
}

// The obstacles as holes, each grown outwards by the buffer radius. A hole of three points or more is a hole
// the triangulation can cut round; anything smaller is not a region and is left out of the cut.
- (NSArray *)charon_holes
{
    NSMutableArray *holes = [NSMutableArray array];
    for (id obstacle in _charonObstacles) {
        NSArray *vertices = CharonGKVerticesOfObstacle(obstacle);
        if (vertices == nil || [vertices count] < 3) {
            continue;
        }
        NSArray *grown = CharonGKBufferedCorners(@[obstacle], _charonBufferRadius, nil);
        if ([grown count] >= 3) {
            [holes addObject:grown];
        }
    }
    return holes;
}

- (void)triangulate
{
    [self charon_cut];
    // Each mode replaces the node list with its own positions, and the graph's node list is the union of the
    // modes that are set. So a graph in the vertex mode answers its corners, the same graph in the centre
    // mode answers the middles of its triangles, and the same graph with all three set answers every one of
    // them: measured, one rectangle answers 4 nodes, then 2, then 5, then 11 -- and 11 is 4+2+5, because the
    // three sets of positions do not overlap.
    NSMutableArray *all = [NSMutableArray array];
    if ((_charonMode & GKMeshGraphTriangulationModeVertices) != 0) {
        [self charon_addNodesAtVertices];
        [all addObjectsFromArray:_charonNodes];
    }
    if ((_charonMode & GKMeshGraphTriangulationModeCenters) != 0) {
        [self charon_addNodesAtCentres];
        [all addObjectsFromArray:_charonNodes];
    }
    if ((_charonMode & GKMeshGraphTriangulationModeEdgeMidpoints) != 0) {
        [self charon_addNodesAtEdgeMidpoints];
        [all addObjectsFromArray:_charonNodes];
    }
    [self removeNodes:self.nodes];
    _charonNodes = all;
    [self addNodes:_charonNodes];
    // The edges of the mesh: two nodes are joined when the line between them meets no obstacle, which is the
    // same test the obstacle graph applies and the same reason.
    [self charon_joinPairs];
}

// Cut the free space into triangles and put a node at every corner of the cut.
- (void)charon_cut
{
    [_charonTriangles removeAllObjects];
    [_charonNodes removeAllObjects];
    [_charonTriangles addObjectsFromArray:CharonGKTriangulateRegion([self charon_outline], [self charon_holes])];
}

// One node per distinct position. The triangles of a triangulation share their corners, so a node per corner
// per triangle would answer the same corner three times: measured, the host answers FOUR nodes for a
// rectangle cut into two triangles, not six.
- (void)charon_addNodeAt:(vector_float2)point
{
    for (GKGraphNode2D *node in _charonNodes) {
        if (node.position.x == point.x && node.position.y == point.y) {
            return;
        }
    }
    id node = CharonGKPointNodeWithClass(_charonNodeClass, point);
    if (node != nil) {
        [_charonNodes addObject:node];
    }
}

- (void)charon_addNodesAtVertices
{
    [_charonNodes removeAllObjects];
    for (CharonGKTriangle3 *triangle in _charonTriangles) {
        for (int index = 0; index < 3; index++) {
            vector_float3 corner = triangle->points[index];
            [self charon_addNodeAt:(vector_float2){corner.x, corner.y}];
        }
    }
}

- (void)charon_addNodesAtCentres
{
    [_charonNodes removeAllObjects];
    for (CharonGKTriangle3 *triangle in _charonTriangles) {
        float x = (triangle->points[0].x + triangle->points[1].x + triangle->points[2].x) / 3.0f;
        float y = (triangle->points[0].y + triangle->points[1].y + triangle->points[2].y) / 3.0f;
        [self charon_addNodeAt:(vector_float2){x, y}];
    }
}

- (void)charon_addNodesAtEdgeMidpoints
{
    [_charonNodes removeAllObjects];
    for (CharonGKTriangle3 *triangle in _charonTriangles) {
        for (int index = 0; index < 3; index++) {
            vector_float3 from = triangle->points[index];
            vector_float3 to = triangle->points[(index + 1) % 3];
            [self charon_addNodeAt:(vector_float2){(from.x + to.x) / 2.0f, (from.y + to.y) / 2.0f}];
        }
    }
}

// The edges of the mesh: every pair of nodes whose line meets no obstacle. The test is the same one the
// obstacle graph applies and for the same reason -- an edge a path walks must not cross an obstacle, and a
// mesh graph's nodes are its own triangles' corners, so an edge between two of them is a step along the free
// space.
- (void)charon_joinPairs
{
    NSArray *nodes = _charonNodes;
    for (NSUInteger first = 0; first < [nodes count]; first++) {
        for (NSUInteger second = first + 1; second < [nodes count]; second++) {
            GKGraphNode *from = [nodes objectAtIndex:first];
            GKGraphNode *to = [nodes objectAtIndex:second];
            if (![from isKindOfClass:[GKGraphNode2D class]] || ![to isKindOfClass:[GKGraphNode2D class]]) {
                continue;
            }
            vector_float2 line[2] = {[(GKGraphNode2D *)from position], [(GKGraphNode2D *)to position]};
            BOOL blocked = NO;
            for (id obstacle in _charonObstacles) {
                NSArray *vertices = CharonGKVerticesOfObstacle(obstacle);
                if ([vertices count] < 3) {
                    continue;
                }
                vector_float2 held[64];
                NSUInteger count = [vertices count] < 64 ? [vertices count] : 64;
                for (NSUInteger index = 0; index < count; index++) {
                    held[index] = [(CharonGKPoint2 *)[vertices objectAtIndex:index] vector];
                }
                if (CharonGKSegmentCrossesPolygon(line[0], line[1], held, count, _charonBufferRadius)) {
                    blocked = YES;
                    break;
                }
            }
            if (!blocked) {
                [from addConnectionsToNodes:@[to] bidirectional:YES];
            }
        }
    }
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
{
    if (node == nil || [_charonNodes indexOfObjectIdenticalTo:node] == NSNotFound) {
        return;
    }
    [self charon_joinPairs];
}

- (NSUInteger)triangleCount { return [_charonTriangles count]; }

- (GKTriangle)triangleAtIndex:(NSUInteger)index
{
    GKTriangle answer;
    for (int corner = 0; corner < 3; corner++) {
        answer.points[corner] = (vector_float3){0, 0, 0};
    }
    if (index >= [_charonTriangles count]) {
        return answer;
    }
    CharonGKTriangle3 *triangle = [_charonTriangles objectAtIndex:index];
    for (int corner = 0; corner < 3; corner++) {
        answer.points[corner] = triangle->points[corner];
    }
    return answer;
}

- (Class)classForGenericArgumentAtIndex:(NSUInteger)index
{
    (void)index;
    return _charonNodeClass;
}

@end

#pragma clang diagnostic pop
