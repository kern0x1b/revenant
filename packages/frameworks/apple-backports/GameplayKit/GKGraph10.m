#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "RevenantGKGraph.h"

@class GKPath;
@interface GKPath (RevenantGKPathSeams)
- (vector_float3)revenant_float3AtIndex:(NSUInteger)index;
- (instancetype)revenant_initWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical;
- (instancetype)initWithRevenantFloat3Points:(vector_float3 *)points count:(size_t)count
                                        radius:(float)radius cyclical:(BOOL)cyclical;
+ (instancetype)revenant_pathWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
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
    return RevenantGKLength3(_position, ((GKGraphNode3D *)node).position);
}

- (float)estimatedCostToNode:(GKGraphNode *)node { return [self costToNode:node]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _position = (vector_float3){0, 0, 0};
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        NSArray *held = [coder decodeObjectOfClasses:classes forKey:RevenantGKGraphNodePositionKey];
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
                 forKey:RevenantGKGraphNodePositionKey];
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
    NSMutableArray *_revenantEntries;
}

- (GKBox)box { return _box; }
- (void)revenant_setBox:(GKBox)box { _box = box; }

- (BOOL)revenant_holdsBox:(GKBox)box
{
    return _box.boxMax.x >= box.boxMin.x && _box.boxMin.x <= box.boxMax.x &&
           _box.boxMax.y >= box.boxMin.y && _box.boxMin.y <= box.boxMax.y &&
           _box.boxMax.z >= box.boxMin.z && _box.boxMin.z <= box.boxMax.z;
}

- (NSMutableArray *)revenant_entries
{
    if (_revenantEntries == nil) {
        _revenantEntries = [NSMutableArray array];
    }
    return _revenantEntries;
}

- (void)revenant_setEntries:(NSArray *)entries { _revenantEntries = [entries mutableCopy]; }

@end

@implementation GKOctree {
    GKBox _revenantBounds;
    float _revenantMinimumCellSize;
    NSMutableDictionary *_revenantCells;
}

- (instancetype)initWithBoundingBox:(GKBox)box minimumCellSize:(float)minCellSize
{
    self = [super init];
    if (self) {
        _revenantBounds = box;
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
        _revenantMinimumCellSize = RevenantGKCellSize(minCellSize, extent);
        _revenantCells = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)octreeWithBoundingBox:(GKBox)box minimumCellSize:(float)minCellSize
{
    return [[self alloc] initWithBoundingBox:box minimumCellSize:minCellSize];
}

- (NSString *)revenant_keyAtSize:(float)size low:(vector_float3)low
{
    return [NSString stringWithFormat:@"%g,%g,%g", (double)RevenantGKCellFloor(low.x, size),
                                      (double)RevenantGKCellFloor(low.y, size),
                                      (double)RevenantGKCellFloor(low.z, size)];
}

- (NSString *)revenant_keyForCellMin:(vector_float3)low
{
    return [self revenant_keyAtSize:_revenantMinimumCellSize low:low];
}

- (NSString *)revenant_keyForNodeMin:(vector_float3)low
{
    return [self revenant_keyAtSize:RevenantGKNodeSize(_revenantMinimumCellSize) low:low];
}

- (GKOctreeNode *)revenant_nodeAtSize:(float)size low:(vector_float3)low
{
    NSString *key = [self revenant_keyAtSize:size low:low];
    GKOctreeNode *node = [_revenantCells objectForKey:key];
    if (node != nil) {
        return node;
    }
    GKBox held;
    held.boxMin = (vector_float3){RevenantGKCellFloor(low.x, size), RevenantGKCellFloor(low.y, size),
                                  RevenantGKCellFloor(low.z, size)};
    held.boxMax = (vector_float3){
        RevenantGKNodeCeiling(RevenantGKCellFloor(low.x, size) + size, _revenantBounds.boxMax.x),
        RevenantGKNodeCeiling(RevenantGKCellFloor(low.y, size) + size, _revenantBounds.boxMax.y),
        RevenantGKNodeCeiling(RevenantGKCellFloor(low.z, size) + size, _revenantBounds.boxMax.z)};
    node = [[GKOctreeNode alloc] init];
    [node revenant_setBox:held];
    _revenantCells[key] = node;
    return node;
}

- (GKOctreeNode *)revenant_nodeForLow:(vector_float3)low
{
    return [self revenant_nodeAtSize:RevenantGKNodeSize(_revenantMinimumCellSize) low:low];
}

- (GKOctreeNode *)addElement:(id)element withPoint:(vector_float3)point
{
    if (element == nil) {
        return nil;
    }
    GKOctreeNode *node = [self revenant_nodeAtSize:_revenantMinimumCellSize low:point];
    NSMutableArray *filed = [[node revenant_entries] mutableCopy];
    [filed addObject:[RevenantGKEntry revenant_entryWithElement:element low:node.box.boxMin high:node.box.boxMax
                                                          isPoint:YES]];
    [node revenant_setEntries:filed];
    return node;
}

- (GKOctreeNode *)addElement:(id)element withBox:(GKBox)box
{
    if (element == nil) {
        return nil;
    }
    GKOctreeNode *node = [self revenant_nodeForLow:box.boxMin];
    NSMutableArray *filed = [[node revenant_entries] mutableCopy];
    if ([filed indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->revenant_element == element;
        }] == NSNotFound) {
        [filed addObject:[RevenantGKEntry revenant_entryWithElement:element low:box.boxMin high:box.boxMax
                                                          isPoint:NO]];
    }
    [node revenant_setEntries:filed];
    return node;
}

- (NSArray *)elementsAtPoint:(vector_float3)point
{
    GKOctreeNode *node = [_revenantCells objectForKey:[self revenant_keyForCellMin:point]];
    NSMutableArray *answer = [NSMutableArray array];
    for (RevenantGKEntry *entry in [node revenant_entries]) {
        if (entry->revenant_isPoint) {
            [answer addObject:entry->revenant_element];
        }
    }
    return answer;
}

- (NSArray *)elementsInBox:(GKBox)box
{
    NSMutableArray *answer = [NSMutableArray array];
    for (GKOctreeNode *node in [_revenantCells allValues]) {
        for (RevenantGKEntry *entry in [node revenant_entries]) {
            if (entry->revenant_max.x >= box.boxMin.x && entry->revenant_min.x <= box.boxMax.x &&
                entry->revenant_max.y >= box.boxMin.y && entry->revenant_min.y <= box.boxMax.y &&
                entry->revenant_max.z >= box.boxMin.z && entry->revenant_min.z <= box.boxMax.z &&
                [answer indexOfObjectIdenticalTo:entry->revenant_element] == NSNotFound) {
                [answer addObject:entry->revenant_element];
            }
        }
    }
    return answer;
}

- (BOOL)removeElement:(id)element
{
    BOOL removed = NO;
    for (GKOctreeNode *node in [_revenantCells allValues]) {
        NSMutableArray *entries = [[node revenant_entries] mutableCopy];
        NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->revenant_element == element;
        }];
        if (index != NSNotFound) {
            [entries removeObjectAtIndex:index];
            [node revenant_setEntries:entries];
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
    NSMutableArray *entries = [node revenant_entries];
    NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at, BOOL *stop) {
        (void)at;
        (void)stop;
        return entry->revenant_element == element;
    }];
    if (index == NSNotFound) {
        return NO;
    }
    [entries removeObjectAtIndex:index];
    return YES;
}

@end

@implementation GKRTree {
    NSUInteger _revenantMaximumChildren;
    NSMutableArray *_revenantEntries;
}

- (instancetype)initWithMaxNumberOfChildren:(NSUInteger)maxNumberOfChildren
{
    self = [super init];
    if (self) {
        _revenantMaximumChildren = maxNumberOfChildren;
        _revenantEntries = [NSMutableArray array];
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
    [_revenantEntries addObject:[RevenantGKEntry
                                       revenant_entryWithElement:element
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
    NSUInteger index = [_revenantEntries indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at,
                                                                       BOOL *stop) {
        (void)at;
        (void)stop;
        return entry->revenant_element == element;
    }];
    if (index != NSNotFound) {
        [_revenantEntries removeObjectAtIndex:index];
    }
}

- (NSArray *)elementsInBoundingRectMin:(vector_float2)rectMin rectMax:(vector_float2)rectMax
{
    NSMutableArray *answer = [NSMutableArray array];
    for (RevenantGKEntry *entry in _revenantEntries) {
        if (entry->revenant_min.x >= rectMin.x && entry->revenant_min.y >= rectMin.y &&
            entry->revenant_max.x <= rectMax.x && entry->revenant_max.y <= rectMax.y) {
            [answer addObject:entry->revenant_element];
        }
    }
    return answer;
}

@end

@implementation GKQuadtreeNode {
    GKQuad _quad;
    NSMutableArray *_revenantEntries;
}

- (GKQuad)quad { return _quad; }
- (void)revenant_setQuad:(GKQuad)quad { _quad = quad; }

- (NSMutableArray *)revenant_entries
{
    if (_revenantEntries == nil) {
        _revenantEntries = [NSMutableArray array];
    }
    return _revenantEntries;
}

- (void)revenant_setEntries:(NSArray *)entries { _revenantEntries = [entries mutableCopy]; }

@end

@implementation GKQuadtree {
    GKQuad _revenantBounds;
    float _revenantMinimumCellSize;
    NSMutableDictionary *_revenantCells;
}

- (instancetype)initWithBoundingQuad:(GKQuad)quad minimumCellSize:(float)minCellSize
{
    self = [super init];
    if (self) {
        _revenantBounds = quad;
        float extentX = quad.quadMax.x - quad.quadMin.x;
        float extentY = quad.quadMax.y - quad.quadMin.y;
        float extent = extentX < extentY ? extentX : extentY;
        _revenantMinimumCellSize = RevenantGKCellSize(minCellSize, extent);
        _revenantCells = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)quadtreeWithBoundingQuad:(GKQuad)quad minimumCellSize:(float)minCellSize
{
    return [[self alloc] initWithBoundingQuad:quad minimumCellSize:minCellSize];
}

- (NSString *)revenant_keyAtSize:(float)size low:(vector_float2)low
{
    return [NSString stringWithFormat:@"%g,%g", (double)RevenantGKCellFloor(low.x, size),
                                      (double)RevenantGKCellFloor(low.y, size)];
}

- (NSString *)revenant_keyForCellMin:(vector_float2)low
{
    return [self revenant_keyAtSize:_revenantMinimumCellSize low:low];
}

- (NSString *)revenant_keyForNodeMin:(vector_float2)low
{
    return [self revenant_keyAtSize:RevenantGKNodeSize(_revenantMinimumCellSize) low:low];
}

- (GKQuadtreeNode *)revenant_nodeAtSize:(float)size low:(vector_float2)low
{
    NSString *key = [self revenant_keyAtSize:size low:low];
    GKQuadtreeNode *node = [_revenantCells objectForKey:key];
    if (node != nil) {
        return node;
    }
    GKQuad held;
    held.quadMin = (vector_float2){RevenantGKCellFloor(low.x, size), RevenantGKCellFloor(low.y, size)};
    held.quadMax = (vector_float2){
        RevenantGKNodeCeiling(RevenantGKCellFloor(low.x, size) + size, _revenantBounds.quadMax.x),
        RevenantGKNodeCeiling(RevenantGKCellFloor(low.y, size) + size, _revenantBounds.quadMax.y)};
    node = [[GKQuadtreeNode alloc] init];
    [node revenant_setQuad:held];
    _revenantCells[key] = node;
    return node;
}

- (GKQuadtreeNode *)revenant_nodeForLow:(vector_float2)low
{
    return [self revenant_nodeAtSize:RevenantGKNodeSize(_revenantMinimumCellSize) low:low];
}

- (GKQuadtreeNode *)addElement:(id)element withPoint:(vector_float2)point
{
    if (element == nil) {
        return nil;
    }
    GKQuadtreeNode *node = [self revenant_nodeAtSize:_revenantMinimumCellSize low:point];
    vector_float3 low = (vector_float3){node.quad.quadMin.x, node.quad.quadMin.y, 0};
    vector_float3 high = (vector_float3){node.quad.quadMax.x, node.quad.quadMax.y, 0};
    [[node revenant_entries] addObject:[RevenantGKEntry revenant_entryWithElement:element low:low high:high
                                                                        isPoint:YES]];
    return node;
}

- (GKQuadtreeNode *)addElement:(id)element withQuad:(GKQuad)quad
{
    if (element == nil) {
        return nil;
    }
    GKQuadtreeNode *node = [self revenant_nodeForLow:quad.quadMin];
    NSMutableArray *filed = [[node revenant_entries] mutableCopy];
    if ([filed indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->revenant_element == element;
        }] == NSNotFound) {
        [filed addObject:[RevenantGKEntry
                                 revenant_entryWithElement:element
                                                   low:(vector_float3){quad.quadMin.x, quad.quadMin.y, 0}
                                                  high:(vector_float3){quad.quadMax.x, quad.quadMax.y, 0}
                                                 isPoint:NO]];
    }
    [node revenant_setEntries:filed];
    return node;
}

- (NSArray *)elementsAtPoint:(vector_float2)point
{
    GKQuadtreeNode *node = [_revenantCells objectForKey:[self revenant_keyForNodeMin:point]];
    NSMutableArray *answer = [NSMutableArray array];
    for (RevenantGKEntry *entry in [node revenant_entries]) {
        if (!entry->revenant_isPoint) {
            [answer addObject:entry->revenant_element];
        }
    }
    return answer;
}

- (NSArray *)elementsInQuad:(GKQuad)quad
{
    NSMutableArray *answer = [NSMutableArray array];
    for (GKQuadtreeNode *node in [_revenantCells allValues]) {
        GKQuad cell = node.quad;
        if (cell.quadMax.x < quad.quadMin.x || cell.quadMin.x > quad.quadMax.x ||
            cell.quadMax.y < quad.quadMin.y || cell.quadMin.y > quad.quadMax.y) {
            continue;
        }
        for (RevenantGKEntry *entry in [node revenant_entries]) {
            if ([answer indexOfObjectIdenticalTo:entry->revenant_element] == NSNotFound) {
                [answer addObject:entry->revenant_element];
            }
        }
    }
    return answer;
}


- (BOOL)removeElement:(id)element
{
    BOOL removed = NO;
    for (GKQuadtreeNode *node in [_revenantCells allValues]) {
        NSMutableArray *entries = [[node revenant_entries] mutableCopy];
        NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at, BOOL *stop) {
            (void)at;
            (void)stop;
            return entry->revenant_element == element;
        }];
        if (index != NSNotFound) {
            [entries removeObjectAtIndex:index];
            [node revenant_setEntries:entries];
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
    NSMutableArray *entries = [node revenant_entries];
    NSUInteger index = [entries indexOfObjectPassingTest:^BOOL(RevenantGKEntry *entry, NSUInteger at, BOOL *stop) {
        (void)at;
        (void)stop;
        return entry->revenant_element == element;
    }];
    if (index == NSNotFound) {
        return NO;
    }
    [entries removeObjectAtIndex:index];
    return YES;
}

@end

@implementation GKPath (RevenantGKPath10)

- (vector_float3)float3AtIndex:(NSUInteger)index
{
    vector_float3 held = [self revenant_float3AtIndex:index];
    return held;
}

- (vector_float2)float2AtIndex:(NSUInteger)index
{
    vector_float3 held = [self revenant_float3AtIndex:index];
    return (vector_float2){held.x, held.z};
}

- (instancetype)initWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                           cyclical:(BOOL)cyclical
{
    return [self revenant_initWithFloat3Points:points count:count radius:radius cyclical:cyclical];
}

+ (instancetype)pathWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                           cyclical:(BOOL)cyclical
{
    return [self revenant_pathWithFloat3Points:points count:count radius:radius cyclical:cyclical];
}

@end

@implementation GKMeshGraph {
    float _revenantBufferRadius;
    vector_float2 _revenantMin;
    vector_float2 _revenantMax;
    NSMutableArray *_revenantObstacles;
    GKMeshGraphTriangulationMode _revenantMode;
    Class _revenantNodeClass;
    NSMutableArray *_revenantTriangles;
    NSMutableArray *_revenantNodes;
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
        _revenantBufferRadius = bufferRadius;
        _revenantMin = min;
        _revenantMax = max;
        _revenantNodeClass = nodeClass ?: [GKGraphNode2D class];
        _revenantObstacles = [NSMutableArray array];
        _revenantMode = GKMeshGraphTriangulationModeVertices;
        _revenantTriangles = [NSMutableArray array];
        _revenantNodes = [NSMutableArray array];
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

- (NSArray *)obstacles { return [_revenantObstacles copy]; }
- (float)bufferRadius { return _revenantBufferRadius; }
- (GKMeshGraphTriangulationMode)triangulationMode { return _revenantMode; }
- (void)setTriangulationMode:(GKMeshGraphTriangulationMode)triangulationMode
{
    _revenantMode = triangulationMode;
}

- (void)addObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        if (obstacle != nil) {
            [_revenantObstacles addObject:obstacle];
        }
    }
    [self revenant_cut];
}

- (void)removeObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        [_revenantObstacles removeObjectIdenticalTo:obstacle];
    }
    [self revenant_cut];
}

- (NSArray *)revenant_outline
{
    vector_float2 corners[4] = {{_revenantMin.x, _revenantMax.y},
                                {_revenantMax.x, _revenantMin.y},
                                {_revenantMax.x, _revenantMax.y},
                                {_revenantMin.x, _revenantMin.y}};
    NSMutableArray *outline = [NSMutableArray arrayWithCapacity:4];
    for (int index = 0; index < 4; index++) {
        [outline addObject:[RevenantGKPoint2 pointWithX:corners[index].x y:corners[index].y]];
    }
    return outline;
}

- (NSArray *)revenant_holes
{
    NSMutableArray *holes = [NSMutableArray array];
    for (id obstacle in _revenantObstacles) {
        NSArray *vertices = RevenantGKVerticesOfObstacle(obstacle);
        if (vertices == nil || [vertices count] < 3) {
            continue;
        }
        NSArray *grown = RevenantGKBufferedCorners(@[obstacle], _revenantBufferRadius, nil);
        if ([grown count] >= 3) {
            [holes addObject:grown];
        }
    }
    return holes;
}

- (void)triangulate
{
    [self revenant_cut];
    NSMutableArray *all = [NSMutableArray array];
    if ((_revenantMode & GKMeshGraphTriangulationModeVertices) != 0) {
        [self revenant_addNodesAtVertices];
        [all addObjectsFromArray:_revenantNodes];
    }
    if ((_revenantMode & GKMeshGraphTriangulationModeCenters) != 0) {
        [self revenant_addNodesAtCentres];
        [all addObjectsFromArray:_revenantNodes];
    }
    if ((_revenantMode & GKMeshGraphTriangulationModeEdgeMidpoints) != 0) {
        [self revenant_addNodesAtEdgeMidpoints];
        [all addObjectsFromArray:_revenantNodes];
    }
    [self removeNodes:self.nodes];
    _revenantNodes = all;
    [self addNodes:_revenantNodes];
    [self revenant_joinPairs];
}

- (void)revenant_cut
{
    [_revenantTriangles removeAllObjects];
    [_revenantNodes removeAllObjects];
    [_revenantTriangles addObjectsFromArray:RevenantGKTriangulateRegion([self revenant_outline], [self revenant_holes])];
}

- (void)revenant_addNodeAt:(vector_float2)point
{
    for (GKGraphNode2D *node in _revenantNodes) {
        if (node.position.x == point.x && node.position.y == point.y) {
            return;
        }
    }
    id node = RevenantGKPointNodeWithClass(_revenantNodeClass, point);
    if (node != nil) {
        [_revenantNodes addObject:node];
    }
}

- (void)revenant_addNodesAtVertices
{
    [_revenantNodes removeAllObjects];
    for (RevenantGKTriangle3 *triangle in _revenantTriangles) {
        for (int index = 0; index < 3; index++) {
            vector_float3 corner = triangle->points[index];
            [self revenant_addNodeAt:(vector_float2){corner.x, corner.y}];
        }
    }
}

- (void)revenant_addNodesAtCentres
{
    [_revenantNodes removeAllObjects];
    for (RevenantGKTriangle3 *triangle in _revenantTriangles) {
        float x = (triangle->points[0].x + triangle->points[1].x + triangle->points[2].x) / 3.0f;
        float y = (triangle->points[0].y + triangle->points[1].y + triangle->points[2].y) / 3.0f;
        [self revenant_addNodeAt:(vector_float2){x, y}];
    }
}

- (void)revenant_addNodesAtEdgeMidpoints
{
    [_revenantNodes removeAllObjects];
    for (RevenantGKTriangle3 *triangle in _revenantTriangles) {
        for (int index = 0; index < 3; index++) {
            vector_float3 from = triangle->points[index];
            vector_float3 to = triangle->points[(index + 1) % 3];
            [self revenant_addNodeAt:(vector_float2){(from.x + to.x) / 2.0f, (from.y + to.y) / 2.0f}];
        }
    }
}

- (void)revenant_joinPairs
{
    NSArray *nodes = _revenantNodes;
    for (NSUInteger first = 0; first < [nodes count]; first++) {
        for (NSUInteger second = first + 1; second < [nodes count]; second++) {
            GKGraphNode *from = [nodes objectAtIndex:first];
            GKGraphNode *to = [nodes objectAtIndex:second];
            if (![from isKindOfClass:[GKGraphNode2D class]] || ![to isKindOfClass:[GKGraphNode2D class]]) {
                continue;
            }
            vector_float2 line[2] = {[(GKGraphNode2D *)from position], [(GKGraphNode2D *)to position]};
            BOOL blocked = NO;
            for (id obstacle in _revenantObstacles) {
                NSArray *vertices = RevenantGKVerticesOfObstacle(obstacle);
                if ([vertices count] < 3) {
                    continue;
                }
                vector_float2 held[64];
                NSUInteger count = [vertices count] < 64 ? [vertices count] : 64;
                for (NSUInteger index = 0; index < count; index++) {
                    held[index] = [(RevenantGKPoint2 *)[vertices objectAtIndex:index] vector];
                }
                if (RevenantGKSegmentCrossesPolygon(line[0], line[1], held, count, _revenantBufferRadius)) {
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
    if (node == nil || [_revenantNodes indexOfObjectIdenticalTo:node] == NSNotFound) {
        return;
    }
    [self revenant_joinPairs];
}

- (NSUInteger)triangleCount { return [_revenantTriangles count]; }

- (GKTriangle)triangleAtIndex:(NSUInteger)index
{
    GKTriangle answer;
    for (int corner = 0; corner < 3; corner++) {
        answer.points[corner] = (vector_float3){0, 0, 0};
    }
    if (index >= [_revenantTriangles count]) {
        return answer;
    }
    RevenantGKTriangle3 *triangle = [_revenantTriangles objectAtIndex:index];
    for (int corner = 0; corner < 3; corner++) {
        answer.points[corner] = triangle->points[corner];
    }
    return answer;
}

- (Class)classForGenericArgumentAtIndex:(NSUInteger)index
{
    (void)index;
    return _revenantNodeClass;
}

@end

#pragma clang diagnostic pop
