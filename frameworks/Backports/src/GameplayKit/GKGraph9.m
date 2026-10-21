#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "RevenantGKGraph.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GKGraphNode {
    NSMutableArray *_revenantEdges;
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[self class] alloc];
}

- (vector_float2)revenant_positionToCopy { return (vector_float2){0, 0}; }

- (NSMutableArray *)revenant_edges
{
    if (_revenantEdges == nil) {
        _revenantEdges = [NSMutableArray array];
    }
    return _revenantEdges;
}

- (NSArray *)connectedNodes { return [[self revenant_edges] copy]; }

- (void)revenant_setEdges:(NSArray *)edges { _revenantEdges = [edges mutableCopy]; }

- (void)addConnectionsToNodes:(NSArray *)nodes bidirectional:(BOOL)bidirectional
{
    for (GKGraphNode *node in nodes) {
        if (node == nil) {
            continue;
        }
        [[self revenant_edges] addObject:node];
        if (bidirectional) {
            [node addConnectionsToNodes:@[self] bidirectional:NO];
        }
    }
}

- (void)removeConnectionsToNodes:(NSArray *)nodes bidirectional:(BOOL)bidirectional
{
    NSMutableArray *edges = [self revenant_edges];
    for (GKGraphNode *node in nodes) {
        NSUInteger index = [edges indexOfObjectIdenticalTo:node];
        while (index != NSNotFound) {
            [edges removeObjectAtIndex:index];
            index = [edges indexOfObjectIdenticalTo:node];
        }
        if (bidirectional) {
            [node removeConnectionsToNodes:@[self] bidirectional:NO];
        }
    }
}

- (float)costToNode:(GKGraphNode *)node { (void)node; return 1; }
- (float)estimatedCostToNode:(GKGraphNode *)node { (void)node; return 0; }

- (NSArray *)findPathToNode:(GKGraphNode *)goalNode
{
    if (goalNode == nil) {
        return nil;
    }
    NSArray *path = RevenantGKFindPath([self revenant_searchableNodes], self, goalNode);
    return path == nil ? [NSArray array] : path;
}

- (NSArray *)revenant_searchableNodes
{
    NSMutableArray *seen = [NSMutableArray arrayWithObject:self];
    NSMutableArray *queue = [NSMutableArray arrayWithObject:self];
    while ([queue count] > 0) {
        GKGraphNode *current = [queue objectAtIndex:0];
        [queue removeObjectAtIndex:0];
        for (GKGraphNode *next in [current revenant_edges]) {
            if (next != nil && [seen indexOfObjectIdenticalTo:next] == NSNotFound) {
                [seen addObject:next];
                [queue addObject:next];
            }
        }
    }
    return seen;
}

- (NSArray *)findPathFromNode:(GKGraphNode *)startNode
{
    if (startNode == nil) {
        return nil;
    }
    NSArray *path = RevenantGKFindPath([self revenant_searchableNodes], startNode, self);
    return path == nil ? [NSArray array] : path;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSObject class], nil];
        NSArray *decoded = [coder decodeObjectOfClasses:classes forKey:RevenantGKGraphNodesKey];
        for (id node in decoded) {
            if ([node isKindOfClass:[GKGraphNode class]]) {
                [[self revenant_edges] addObject:node];
            }
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self revenant_edges] forKey:RevenantGKGraphNodesKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation GKGraphNode2D {
    vector_float2 _position;
}

- (instancetype)initWithPoint:(vector_float2)point
{
    self = [super init];
    if (self) {
        _position = point;
    }
    return self;
}

+ (instancetype)nodeWithPoint:(vector_float2)point { return [[self alloc] initWithPoint:point]; }

- (vector_float2)position { return _position; }
- (void)setPosition:(vector_float2)position { _position = position; }

- (vector_float2)revenant_positionToCopy { return _position; }

- (id)copyWithZone:(NSZone *)zone
{
    GKGraphNode2D *copy = [super copyWithZone:zone];
    copy->_position = _position;
    return copy;
}

- (float)costToNode:(GKGraphNode *)node
{
    if (![node isKindOfClass:[GKGraphNode2D class]]) {
        return [super costToNode:node];
    }
    return RevenantGKLength2(_position, ((GKGraphNode2D *)node).position);
}

- (float)estimatedCostToNode:(GKGraphNode *)node { return [self costToNode:node]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _position = (vector_float2){0, 0};
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        NSArray *held = [coder decodeObjectOfClasses:classes forKey:RevenantGKGraphNodePositionKey];
        if ([held count] == 2) {
            _position = (vector_float2){[[held objectAtIndex:0] floatValue],
                                        [[held objectAtIndex:1] floatValue]};
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:@[[NSNumber numberWithFloat:_position.x], [NSNumber numberWithFloat:_position.y]]
                 forKey:RevenantGKGraphNodePositionKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation GKGridGraphNode {
    vector_int2 _gridPosition;
}

- (instancetype)initWithGridPosition:(vector_int2)gridPosition
{
    self = [super init];
    if (self) {
        _gridPosition = gridPosition;
    }
    return self;
}

+ (instancetype)nodeWithGridPosition:(vector_int2)gridPosition
{
    return [[self alloc] initWithGridPosition:gridPosition];
}

- (vector_int2)gridPosition { return _gridPosition; }

- (id)copyWithZone:(NSZone *)zone
{
    GKGridGraphNode *copy = [super copyWithZone:zone];
    copy->_gridPosition = _gridPosition;
    return copy;
}

- (float)costToNode:(GKGraphNode *)node
{
    if (![node isKindOfClass:[GKGridGraphNode class]]) {
        return [super costToNode:node];
    }
    return RevenantGKCellDistance(_gridPosition, ((GKGridGraphNode *)node).gridPosition);
}

- (float)estimatedCostToNode:(GKGraphNode *)node { return [self costToNode:node]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _gridPosition = (vector_int2){0, 0};
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        NSArray *held = [coder decodeObjectOfClasses:classes forKey:RevenantGKGraphNodePositionKey];
        if ([held count] == 2) {
            _gridPosition = (vector_int2){[[held objectAtIndex:0] intValue],
                                          [[held objectAtIndex:1] intValue]};
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:@[[NSNumber numberWithInt:_gridPosition.x], [NSNumber numberWithInt:_gridPosition.y]]
                 forKey:RevenantGKGraphNodePositionKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation GKGraph {
    NSMutableArray *_revenantNodes;
}

- (instancetype)initWithNodes:(NSArray *)nodes
{
    self = [super init];
    if (self) {
        _revenantNodes = [nodes mutableCopy] ?: [NSMutableArray array];
    }
    return self;
}

+ (instancetype)graphWithNodes:(NSArray *)nodes { return [[self alloc] initWithNodes:nodes]; }

- (NSArray *)nodes { return [_revenantNodes copy]; }

- (void)addNodes:(NSArray *)nodes
{
    for (GKGraphNode *node in nodes) {
        if (node != nil) {
            [_revenantNodes addObject:node];
        }
    }
}

- (void)removeNodes:(NSArray *)nodes
{
    for (GKGraphNode *node in nodes) {
        if ([_revenantNodes indexOfObjectIdenticalTo:node] == NSNotFound) {
            continue;
        }
        [_revenantNodes removeObjectIdenticalTo:node];
        for (GKGraphNode *other in [_revenantNodes copy]) {
            [other removeConnectionsToNodes:@[node] bidirectional:NO];
        }
    }
}

- (NSArray *)findPathFromNode:(GKGraphNode *)startNode toNode:(GKGraphNode *)endNode
{
    if (startNode == nil || endNode == nil) {
        return nil;
    }
    NSArray *path = RevenantGKFindPath([self revenant_reachableNodes], startNode, endNode);
    return path == nil ? [NSArray array] : path;
}

- (void)connectNodeToLowestCostNode:(GKGraphNode *)node bidirectional:(BOOL)bidirectional
{
    if (node == nil || [_revenantNodes indexOfObjectIdenticalTo:node] == NSNotFound) {
        return;
    }
    GKGraphNode *lowest = nil;
    float lowestCost = INFINITY;
    for (GKGraphNode *other in _revenantNodes) {
        float cost = [node costToNode:other];
        if (lowest == nil || cost < lowestCost) {
            lowest = other;
            lowestCost = cost;
        }
    }
    if (lowest != nil) {
        [node addConnectionsToNodes:@[lowest] bidirectional:bidirectional];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    NSArray *reached = [self revenant_reachableNodes];
    NSMutableDictionary *copies = [NSMutableDictionary dictionaryWithCapacity:[reached count]];
    for (GKGraphNode *node in reached) {
        id copied = [node copy];
        if (copied != nil) {
            [copies setObject:copied forKey:[NSValue valueWithPointer:(__bridge const void *)node]];
        }
    }

    NSMutableArray *nodes = [NSMutableArray array];
    for (GKGraphNode *node in _revenantNodes) {
        id copied = [copies objectForKey:[NSValue valueWithPointer:(__bridge const void *)node]];
        [nodes addObject:copied ?: node];
    }
    GKGraph *answer = [[[self class] alloc] initWithNodes:nodes];
    for (GKGraphNode *node in reached) {
        id copied = [copies objectForKey:[NSValue valueWithPointer:(__bridge const void *)node]];
        NSMutableArray *edges = [NSMutableArray array];
        for (GKGraphNode *other in [node revenant_edges]) {
            id copiedOther = [copies objectForKey:[NSValue valueWithPointer:(__bridge const void *)other]];
            if (copiedOther != nil) {
                [edges addObject:copiedOther];
            }
        }
        if ([edges count] > 0) {
            [copied revenant_setEdges:edges];
        }
    }
    return answer;
}

- (NSArray *)revenant_reachableNodes
{
    NSMutableArray *seen = [NSMutableArray array];
    NSMutableArray *queue = [NSMutableArray arrayWithArray:_revenantNodes];
    while ([queue count] > 0) {
        GKGraphNode *current = [queue objectAtIndex:0];
        [queue removeObjectAtIndex:0];
        if ([seen indexOfObjectIdenticalTo:current] != NSNotFound) {
            continue;
        }
        [seen addObject:current];
        for (GKGraphNode *next in [current revenant_edges]) {
            if (next != nil && [seen indexOfObjectIdenticalTo:next] == NSNotFound) {
                [queue addObject:next];
            }
        }
    }
    return seen;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _revenantNodes = [NSMutableArray array];
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSObject class], nil];
        NSArray *decoded = [coder decodeObjectOfClasses:classes forKey:RevenantGKGraphNodesKey];
        for (id node in decoded) {
            if ([node isKindOfClass:[GKGraphNode class]]) {
                [_revenantNodes addObject:node];
            }
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantNodes forKey:RevenantGKGraphNodesKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation GKGridGraph {
    vector_int2 _gridOrigin;
    NSUInteger _gridWidth;
    NSUInteger _gridHeight;
    BOOL _diagonalsAllowed;
    Class _revenantNodeClass;
    NSMutableDictionary *_revenantCells;
}

- (instancetype)initFromGridStartingAt:(vector_int2)position width:(int)width height:(int)height
                     diagonalsAllowed:(BOOL)diagonalsAllowed
{
    return [self initFromGridStartingAt:position width:width height:height
                      diagonalsAllowed:diagonalsAllowed nodeClass:[GKGridGraphNode class]];
}

- (instancetype)initFromGridStartingAt:(vector_int2)position width:(int)width height:(int)height
                     diagonalsAllowed:(BOOL)diagonalsAllowed nodeClass:(Class)nodeClass
{
    self = [super initWithNodes:@[]];
    if (self) {
        _gridOrigin = position;
        _gridWidth = width > 0 ? (NSUInteger)width : 0;
        _gridHeight = height > 0 ? (NSUInteger)height : 0;
        _diagonalsAllowed = diagonalsAllowed;
        _revenantNodeClass = nodeClass ?: [GKGridGraphNode class];
        _revenantCells = [NSMutableDictionary dictionaryWithCapacity:_gridWidth * _gridHeight];
        NSMutableArray *nodes = [NSMutableArray arrayWithCapacity:_gridWidth * _gridHeight];
        for (NSUInteger y = 0; y < _gridHeight; y++) {
            for (NSUInteger x = 0; x < _gridWidth; x++) {
                vector_int2 cell = (vector_int2){_gridOrigin.x + (int)x, _gridOrigin.y + (int)y};
                GKGridGraphNode *node = [[_revenantNodeClass alloc] initWithGridPosition:cell];
                _revenantCells[[self revenant_keyForCell:cell]] = node;
                [nodes addObject:node];
            }
        }
        [self addNodes:nodes];
        for (NSUInteger y = 0; y < _gridHeight; y++) {
            for (NSUInteger x = 0; x < _gridWidth; x++) {
                vector_int2 cell = (vector_int2){_gridOrigin.x + (int)x, _gridOrigin.y + (int)y};
                GKGridGraphNode *node = [self nodeAtGridPosition:cell];
                if (node == nil) {
                    continue;
                }
                NSMutableArray *touched = [NSMutableArray array];
                if (x + 1 < _gridWidth) {
                    [touched addObject:[self nodeAtGridPosition:(vector_int2){cell.x + 1, cell.y}]];
                }
                if (y + 1 < _gridHeight) {
                    [touched addObject:[self nodeAtGridPosition:(vector_int2){cell.x, cell.y + 1}]];
                }
                if (_diagonalsAllowed) {
                    if (y + 1 < _gridHeight && x > 0) {
                        [touched addObject:[self nodeAtGridPosition:(vector_int2){cell.x - 1, cell.y + 1}]];
                    }
                    if (x + 1 < _gridWidth && y + 1 < _gridHeight) {
                        [touched addObject:[self nodeAtGridPosition:(vector_int2){cell.x + 1, cell.y + 1}]];
                    }
                }
                NSMutableArray *real = [NSMutableArray array];
                for (GKGridGraphNode *other in touched) {
                    if (other != nil) {
                        [real addObject:other];
                    }
                }
                if ([real count] > 0) {
                    [node addConnectionsToNodes:real bidirectional:YES];
                }
            }
        }
    }
    return self;
}

+ (instancetype)graphFromGridStartingAt:(vector_int2)position width:(int)width height:(int)height
                      diagonalsAllowed:(BOOL)diagonalsAllowed
{
    return [[self alloc] initFromGridStartingAt:position width:width height:height
                              diagonalsAllowed:diagonalsAllowed];
}

+ (instancetype)graphFromGridStartingAt:(vector_int2)position width:(int)width height:(int)height
                      diagonalsAllowed:(BOOL)diagonalsAllowed nodeClass:(Class)nodeClass
{
    return [[self alloc] initFromGridStartingAt:position width:width height:height
                              diagonalsAllowed:diagonalsAllowed nodeClass:nodeClass];
}

- (NSString *)revenant_keyForCell:(vector_int2)cell
{
    return [NSString stringWithFormat:@"%d,%d", cell.x, cell.y];
}

- (GKGridGraphNode *)nodeAtGridPosition:(vector_int2)position
{
    GKGridGraphNode *node = [_revenantCells objectForKey:[self revenant_keyForCell:position]];
    if (node == nil || ![node isKindOfClass:[GKGridGraphNode class]]) {
        return nil;
    }
    return node;
}

- (vector_int2)gridOrigin { return _gridOrigin; }
- (NSUInteger)gridWidth { return _gridWidth; }
- (NSUInteger)gridHeight { return _gridHeight; }
- (BOOL)diagonalsAllowed { return _diagonalsAllowed; }

- (void)connectNodeToAdjacentNodes:(GKGridGraphNode *)node
{
    if (node == nil) {
        return;
    }
    vector_int2 cell = node.gridPosition;
    NSMutableArray *touched = [NSMutableArray array];
    vector_int2 offsets[8] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}};
    (void)offsets;
    for (int index = 0; index < 8; index++) {
        BOOL diagonal = index >= 4;
        if (diagonal && !_diagonalsAllowed) {
            continue;
        }
        GKGridGraphNode *other = [self nodeAtGridPosition:(vector_int2){cell.x + offsets[index].x,
                                                                        cell.y + offsets[index].y}];
        if (other != nil) {
            [touched addObject:other];
        }
    }
    if ([touched count] > 0) {
        [node addConnectionsToNodes:touched bidirectional:YES];
    }
}

- (Class)classForGenericArgumentAtIndex:(NSUInteger)index
{
    (void)index;
    return _revenantNodeClass;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _revenantNodeClass = [GKGridGraphNode class];
        _revenantCells = [NSMutableDictionary dictionary];
        _gridWidth = 0;
        _gridHeight = 0;
        NSInteger lowestX = 0;
        NSInteger lowestY = 0;
        BOOL first = YES;
        for (GKGraphNode *node in self.nodes) {
            if (![node isKindOfClass:[GKGridGraphNode class]]) {
                continue;
            }
            vector_int2 cell = ((GKGridGraphNode *)node).gridPosition;
            _revenantCells[[self revenant_keyForCell:cell]] = (GKGridGraphNode *)node;
            NSInteger x = cell.x;
            NSInteger y = cell.y;
            if (first) {
                lowestX = x;
                lowestY = y;
                first = NO;
            } else {
                if (x < lowestX) {
                    lowestX = x;
                }
                if (y < lowestY) {
                    lowestY = y;
                }
            }
        }
        _gridOrigin = (vector_int2){(int)lowestX, (int)lowestY};
        for (GKGraphNode *node in self.nodes) {
            if (![node isKindOfClass:[GKGridGraphNode class]]) {
                continue;
            }
            vector_int2 cell = ((GKGridGraphNode *)node).gridPosition;
            NSUInteger column = (NSUInteger)(cell.x - lowestX) + 1;
            NSUInteger row = (NSUInteger)(cell.y - lowestY) + 1;
            if (column > _gridWidth) {
                _gridWidth = column;
            }
            if (row > _gridHeight) {
                _gridHeight = row;
            }
        }
        _diagonalsAllowed = NO;
        for (GKGraphNode *node in self.nodes) {
            if (![node isKindOfClass:[GKGridGraphNode class]]) {
                continue;
            }
            vector_int2 cell = ((GKGridGraphNode *)node).gridPosition;
            for (GKGraphNode *other in [node connectedNodes]) {
                if (![other isKindOfClass:[GKGridGraphNode class]]) {
                    continue;
                }
                vector_int2 peer = ((GKGridGraphNode *)other).gridPosition;
                NSInteger dx = peer.x - cell.x;
                NSInteger dy = peer.y - cell.y;
                if ((dx != 0 && dy != 0) && (abs((int)dx) == 1) && (abs((int)dy) == 1)) {
                    _diagonalsAllowed = YES;
                }
            }
        }
    }
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation GKObstacle
@end

@implementation GKCircleObstacle {
    float _radius;
    vector_float2 _position;
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
        _position = (vector_float2){0, 0};
    }
    return self;
}

+ (instancetype)obstacleWithRadius:(float)radius { return [[self alloc] initWithRadius:radius]; }

- (float)radius { return _radius; }
- (void)setRadius:(float)radius { _radius = radius; }
- (vector_float2)position { return _position; }
- (void)setPosition:(vector_float2)position { _position = position; }

@end

@implementation GKPolygonObstacle {
    vector_float2 *_revenantVertices;
    NSUInteger _revenantVertexCount;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"initWithPoints: is the destignated initialize for %@.  Use that instead",
                       NSStringFromClass([self class])];
    return nil;
}

- (instancetype)initWithPoints:(vector_float2 *)points count:(size_t)count
{
    self = [super init];
    if (self) {
        _revenantVertexCount = count;
        if (count > 0 && points != NULL) {
            _revenantVertices = malloc(count * sizeof(vector_float2));
            if (_revenantVertices != NULL) {
                memcpy(_revenantVertices, points, count * sizeof(vector_float2));
            } else {
                _revenantVertexCount = 0;
            }
        }
    }
    return self;
}

+ (instancetype)obstacleWithPoints:(vector_float2 *)points count:(size_t)count
{
    return [[self alloc] initWithPoints:points count:count];
}

- (void)dealloc
{
    free(_revenantVertices);
}

- (NSUInteger)vertexCount { return _revenantVertexCount; }

- (vector_float2)vertexAtIndex:(NSUInteger)index
{
    if (_revenantVertices == NULL || index >= _revenantVertexCount) {
        return (vector_float2){0, 0};
    }
    return _revenantVertices[index];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
    NSArray *held = [coder decodeObjectOfClasses:classes forKey:RevenantGKObstacleVerticesKey];
    size_t count = held == nil ? 0 : [held count];
    vector_float2 *points = count > 0 ? malloc(count * sizeof(vector_float2)) : NULL;
    for (size_t index = 0; index < count; index++) {
        NSArray *pair = [held objectAtIndex:index];
        if ([pair count] == 2) {
            points[index] = (vector_float2){[[pair objectAtIndex:0] floatValue],
                                            [[pair objectAtIndex:1] floatValue]};
        } else {
            points[index] = (vector_float2){0, 0};
        }
    }
    self = [self initWithPoints:points count:count];
    free(points);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSMutableArray *held = [NSMutableArray arrayWithCapacity:_revenantVertexCount];
    for (NSUInteger index = 0; index < _revenantVertexCount; index++) {
        [held addObject:@[[NSNumber numberWithFloat:_revenantVertices[index].x],
                          [NSNumber numberWithFloat:_revenantVertices[index].y]]];
    }
    [coder encodeObject:held forKey:RevenantGKObstacleVerticesKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation GKPath {
    float _radius;
    BOOL _cyclical;
    vector_float3 *_revenantPoints3;
    vector_float2 *_revenantPoints2;
    NSUInteger _revenantPointCount;
}

- (void)revenant_raiseLessThanTwoPoints:(NSString *)reason
{
    [NSException raise:NSInternalInconsistencyException format:@"%@", reason];
}

- (instancetype)initWithPoints:(vector_float2 *)points count:(size_t)count radius:(float)radius
                    cyclical:(BOOL)cyclical
{
    if (count < 2) {
        [self revenant_raiseLessThanTwoPoints:@"GKPathLessThanTwoPointsException: GKPaths MUST be "
                                            @"initialized with 2 or more points.  Single point paths "
                                            @"are not allowed"];
        return nil;
    }
    self = [super init];
    if (self) {
        _radius = radius;
        _cyclical = cyclical;
        _revenantPointCount = count;
        _revenantPoints2 = malloc(count * sizeof(vector_float2));
        if (_revenantPoints2 == NULL) {
            _revenantPointCount = 0;
            return self;
        }
        for (size_t index = 0; index < count; index++) {
            _revenantPoints2[index] = points[index];
        }
    }
    return self;
}

+ (instancetype)pathWithPoints:(vector_float2 *)points count:(size_t)count radius:(float)radius
                    cyclical:(BOOL)cyclical
{
    return [[self alloc] initWithPoints:points count:count radius:radius cyclical:cyclical];
}

- (instancetype)initWithGraphNodes:(NSArray *)graphNodes radius:(float)radius
{
    NSUInteger count = graphNodes == nil ? 0 : [graphNodes count];
    if (count < 2) {
        [self revenant_raiseLessThanTwoPoints:@"GKPath: must be initialized with 2 or more graph nodes.  "
                                            @"Single node paths are not allowed"];
        return nil;
    }
    vector_float2 *points = malloc(count * sizeof(vector_float2));
    for (NSUInteger index = 0; index < count; index++) {
        id node = [graphNodes objectAtIndex:index];
        points[index] = [node isKindOfClass:[GKGraphNode2D class]] ? ((GKGraphNode2D *)node).position
                                                                    : (vector_float2){0, 0};
    }
    self = [self initWithPoints:points count:count radius:radius cyclical:NO];
    free(points);
    return self;
}

+ (instancetype)pathWithGraphNodes:(NSArray *)graphNodes radius:(float)radius
{
    return [[self alloc] initWithGraphNodes:graphNodes radius:radius];
}

- (float)radius { return _radius; }
- (void)setRadius:(float)radius { _radius = radius; }
- (NSUInteger)numPoints { return _revenantPointCount; }
- (BOOL)isCyclical { return _cyclical; }
- (void)setCyclical:(BOOL)cyclical { _cyclical = cyclical; }

- (vector_float2)pointAtIndex:(NSUInteger)index
{
    if (_revenantPoints2 != NULL && index < _revenantPointCount) {
        return _revenantPoints2[index];
    }
    if (_revenantPoints3 != NULL && index < _revenantPointCount) {
        vector_float3 held = _revenantPoints3[index];
        return (vector_float2){held.x, held.z};
    }
    return (vector_float2){0, 0};
}

- (vector_float3)revenant_float3AtIndex:(NSUInteger)index
{
    if (_revenantPoints3 != NULL && index < _revenantPointCount) {
        return _revenantPoints3[index];
    }
    if (_revenantPoints2 != NULL && index < _revenantPointCount) {
        return (vector_float3){_revenantPoints2[index].x, 0, _revenantPoints2[index].y};
    }
    return (vector_float3){0, 0, 0};
}

- (instancetype)revenant_initWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical
{
    return [self initWithRevenantFloat3Points:points count:count radius:radius cyclical:cyclical];
}

- (instancetype)initWithRevenantFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical
{
    if (count < 2) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"GKPathLessThanTwoPointsException: GKPaths MUST be initialized with 2 or "
                           @"more points.  Single point paths are not allowed"];
        return nil;
    }
    vector_float2 placeholders[2] = {{0, 0}, {0, 0}};
    self = [self initWithPoints:placeholders count:2 radius:radius cyclical:cyclical];
    if (self) {
        free(_revenantPoints2);
        _revenantPoints2 = NULL;
        _revenantPoints3 = malloc(count * sizeof(vector_float3));
        if (_revenantPoints3 != NULL) {
            for (size_t index = 0; index < count; index++) {
                _revenantPoints3[index] = points[index];
            }
            _revenantPointCount = count;
        } else {
            _revenantPointCount = 0;
        }
    }
    return self;
}

+ (instancetype)revenant_pathWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical
{
    return [[self alloc] initWithFloat3Points:points count:count radius:radius cyclical:cyclical];
}

- (void)dealloc
{
    free(_revenantPoints2);
    free(_revenantPoints3);
}

@end

#pragma clang diagnostic pop
