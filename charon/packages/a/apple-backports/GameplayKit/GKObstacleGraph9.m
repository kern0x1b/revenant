#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "CharonGKGraph.h"

@implementation GKObstacleGraph {
    float _charonBufferRadius;
    Class _charonNodeClass;
    NSMutableArray *_charonObstacles;
    NSMutableArray *_charonCorners;
    NSMutableArray *_charonOwnedCorners;
    NSMutableArray *_charonLocks;
}

- (instancetype)initWithObstacles:(NSArray *)obstacles bufferRadius:(float)bufferRadius
{
    return [self initWithObstacles:obstacles bufferRadius:bufferRadius
                        nodeClass:[GKGraphNode2D class]];
}

- (instancetype)initWithObstacles:(NSArray *)obstacles bufferRadius:(float)bufferRadius
                        nodeClass:(Class)nodeClass
{
    if (nodeClass != Nil && ![nodeClass isSubclassOfClass:[GKGraphNode2D class]]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"initWithObstacles: nodeClass does not descend from GKGraphNode2D"];
        return nil;
    }
    self = [super initWithNodes:@[]];
    if (self) {
        _charonNodeClass = nodeClass ?: [GKGraphNode2D class];
        _charonBufferRadius = bufferRadius;
        _charonObstacles = [NSMutableArray array];
        _charonCorners = [NSMutableArray array];
        _charonOwnedCorners = [NSMutableArray array];
        _charonLocks = [NSMutableArray array];
        for (id obstacle in obstacles) {
            if (obstacle != nil) {
                [_charonObstacles addObject:obstacle];
            }
        }
        [self charon_rescan];
    }
    return self;
}

+ (instancetype)graphWithObstacles:(NSArray *)obstacles bufferRadius:(float)bufferRadius
{
    return [[self alloc] initWithObstacles:obstacles bufferRadius:bufferRadius];
}

+ (instancetype)graphWithObstacles:(NSArray *)obstacles bufferRadius:(float)bufferRadius
                        nodeClass:(Class)nodeClass
{
    return [[self alloc] initWithObstacles:obstacles bufferRadius:bufferRadius nodeClass:nodeClass];
}

- (NSArray *)obstacles { return [_charonObstacles copy]; }
- (float)bufferRadius { return _charonBufferRadius; }
- (Class)classForGenericArgumentAtIndex:(NSUInteger)index { (void)index; return _charonNodeClass; }

- (NSArray *)charon_cornerNodes
{
    NSMutableArray *corners = [NSMutableArray array];
    for (NSArray *mine in _charonOwnedCorners) {
        for (CharonGKPoint2 *corner in mine) {
            id node = CharonGKPointNodeWithClass(_charonNodeClass, [corner vector]);
            if (node != nil) {
                [corners addObject:node];
            }
        }
    }
    return corners;
}

- (void)addObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        if (obstacle != nil) {
            [_charonObstacles addObject:obstacle];
        }
    }
    [self charon_rescan];
}

- (void)removeObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        [_charonObstacles removeObjectIdenticalTo:obstacle];
    }
    [self charon_rescan];
}

- (void)charon_rescan
{
    NSArray *before = [self nodes];
    for (GKGraphNode *node in before) {
        [node removeConnectionsToNodes:before bidirectional:NO];
    }
    [self removeNodes:before];
    [_charonOwnedCorners removeAllObjects];
    [_charonCorners removeAllObjects];
    [_charonCorners addObjectsFromArray:CharonGKBufferedCorners(_charonObstacles, _charonBufferRadius,
                                                                 _charonOwnedCorners)];
    NSArray *nodes = [self charon_cornerNodes];
    [self addNodes:nodes];
    [self charon_connect:nodes obstacles:_charonObstacles];
}

- (void)removeAllObstacles
{
    [_charonObstacles removeAllObjects];
    [self charon_rescan];
}

- (void)charon_connect:(NSArray *)nodes obstacles:(NSArray *)obstacles
{
    for (NSUInteger first = 0; first < [nodes count]; first++) {
        for (NSUInteger second = first + 1; second < [nodes count]; second++) {
            [self charon_join:[nodes objectAtIndex:first] to:[nodes objectAtIndex:second] obstacles:obstacles];
        }
    }
}

- (void)charon_connectNode:(GKGraphNode *)node obstacles:(NSArray *)obstacles
{
    if (node == nil) {
        return;
    }
    for (GKGraphNode *other in [self nodes]) {
        [self charon_join:node to:other obstacles:obstacles];
    }
}

- (void)charon_join:(GKGraphNode *)from to:(GKGraphNode *)to obstacles:(NSArray *)obstacles
{
    if (from == nil || to == nil || from == to) {
        return;
    }
    if (![from isKindOfClass:[GKGraphNode2D class]] || ![to isKindOfClass:[GKGraphNode2D class]]) {
        return;
    }
    vector_float2 line[2] = {[(GKGraphNode2D *)from position], [(GKGraphNode2D *)to position]};
    for (id obstacle in obstacles) {
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
            return;
        }
    }
    [from addConnectionsToNodes:@[to] bidirectional:YES];
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
{
    [self charon_connectNode:node obstacles:_charonObstacles];
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
            ignoringObstacles:(NSArray *)obstaclesToIgnore
{
    NSMutableArray *kept = [NSMutableArray array];
    for (id obstacle in _charonObstacles) {
        if ([obstaclesToIgnore indexOfObjectIdenticalTo:obstacle] == NSNotFound) {
            [kept addObject:obstacle];
        }
    }
    [self charon_connectNode:node obstacles:kept];
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
    ignoringBufferRadiusOfObstacles:(NSArray *)obstaclesBufferRadiusToIgnore
{
    NSMutableArray *corners = [NSMutableArray array];
    for (NSUInteger index = 0; index < _charonObstacles.count; index++) {
        id obstacle = [_charonObstacles objectAtIndex:index];
        BOOL named = [obstaclesBufferRadiusToIgnore indexOfObjectIdenticalTo:obstacle] != NSNotFound;
        NSArray *vertices = CharonGKVerticesOfObstacle(obstacle);
        if (vertices == nil || [vertices count] < 3) {
            continue;
        }
        for (CharonGKPoint2 *corner in CharonGKBufferedCorners(@[obstacle], named ? 0 : _charonBufferRadius,
                                                               nil)) {
            id cornerNode = CharonGKPointNodeWithClass(_charonNodeClass, [corner vector]);
            if (cornerNode != nil) {
                [corners addObject:cornerNode];
            }
        }
    }
    for (id corner in corners) {
        [self charon_join:node to:corner obstacles:_charonObstacles];
    }
}

- (NSArray *)nodesForObstacle:(GKPolygonObstacle *)obstacle
{
    NSUInteger index = [_charonObstacles indexOfObjectIdenticalTo:obstacle];
    if (index == NSNotFound || index >= [_charonOwnedCorners count]) {
        return [NSArray array];
    }
    NSArray *mine = [_charonOwnedCorners objectAtIndex:index];
    NSMutableArray *answer = [NSMutableArray arrayWithCapacity:[mine count]];
    NSUInteger at = 0;
    for (NSUInteger corner = 0; corner < [_charonOwnedCorners count]; corner++) {
        NSUInteger width = [[_charonOwnedCorners objectAtIndex:corner] count];
        if (corner == index) {
            for (NSUInteger offset = 0; offset < width; offset++) {
                NSUInteger node = at + offset;
                if (node < [self nodes].count) {
                    [answer addObject:[self nodes][node]];
                }
            }
            break;
        }
        at += width;
    }
    return answer;
}

- (void)lockConnectionFromNode:(GKGraphNode *)startNode toNode:(GKGraphNode *)endNode
{
    if (startNode == nil || endNode == nil) {
        return;
    }
    NSString *pair = [NSString stringWithFormat:@"%p,%p", (__bridge void *)startNode,
                                                (__bridge void *)endNode];
    if ([_charonLocks indexOfObject:pair] == NSNotFound) {
        [_charonLocks addObject:pair];
    }
    [startNode removeConnectionsToNodes:@[endNode] bidirectional:YES];
}

- (void)unlockConnectionFromNode:(GKGraphNode *)startNode toNode:(GKGraphNode *)endNode
{
    if (startNode == nil || endNode == nil) {
        return;
    }
    NSString *pair = [NSString stringWithFormat:@"%p,%p", (__bridge void *)startNode,
                                                (__bridge void *)endNode];
    [_charonLocks removeObject:pair];
    [startNode addConnectionsToNodes:@[endNode] bidirectional:YES];
}

- (BOOL)isConnectionLockedFromNode:(GKGraphNode *)startNode toNode:(GKGraphNode *)endNode
{
    NSString *pair = [NSString stringWithFormat:@"%p,%p", (__bridge void *)startNode,
                                                (__bridge void *)endNode];
    return [_charonLocks indexOfObject:pair] != NSNotFound;
}

@end
