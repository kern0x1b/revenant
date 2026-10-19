#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "CharonGKGraph.h"

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
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

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

@implementation GKOctreeNode {
    GKBox _box;
    NSMutableArray *_charonEntries;
}

- (GKBox)box { return _box; }
- (void)charon_setBox:(GKBox)box { _box = box; }

- (BOOL)charon_holdsBox:(GKBox)box
{
    return _box.boxMax.x >= box.boxMin.x && _box.boxMin.x <= box.boxMax.x &&
           _box.boxMax.y >= box.boxMin.y && _box.boxMin.y <= box.boxMax.y &&
           _box.boxMax.z >= box.boxMin.z && _box.boxMin.z <= box.boxMax.z;
}

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

- (GKOctreeNode *)addElement:(id)element withPoint:(vector_float3)point
{
    if (element == nil) {
        return nil;
    }
    GKOctreeNode *node = [self charon_nodeAtSize:_charonMinimumCellSize low:point];
    NSMutableArray *filed = [[node charon_entries] mutableCopy];
    [filed addObject:[CharonGKEntry charon_entryWithElement:element low:node.box.boxMin high:node.box.boxMax
                                                          isPoint:YES]];
    [node charon_setEntries:filed];
    return node;
}

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
    [self charon_joinPairs];
}

- (void)charon_cut
{
    [_charonTriangles removeAllObjects];
    [_charonNodes removeAllObjects];
    [_charonTriangles addObjectsFromArray:CharonGKTriangulateRegion([self charon_outline], [self charon_holes])];
}

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
