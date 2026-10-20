#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "RevenantGKGraph.h"

@implementation GKObstacleGraph {
    float _revenantBufferRadius;
    Class _revenantNodeClass;
    NSMutableArray *_revenantObstacles;
    NSMutableArray *_revenantCorners;
    NSMutableArray *_revenantOwnedCorners;
    NSMutableArray *_revenantLocks;
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
        _revenantNodeClass = nodeClass ?: [GKGraphNode2D class];
        _revenantBufferRadius = bufferRadius;
        _revenantObstacles = [NSMutableArray array];
        _revenantCorners = [NSMutableArray array];
        _revenantOwnedCorners = [NSMutableArray array];
        _revenantLocks = [NSMutableArray array];
        for (id obstacle in obstacles) {
            if (obstacle != nil) {
                [_revenantObstacles addObject:obstacle];
            }
        }
        [self revenant_rescan];
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

- (NSArray *)obstacles { return [_revenantObstacles copy]; }
- (float)bufferRadius { return _revenantBufferRadius; }
- (Class)classForGenericArgumentAtIndex:(NSUInteger)index { (void)index; return _revenantNodeClass; }

- (NSArray *)revenant_cornerNodes
{
    NSMutableArray *corners = [NSMutableArray array];
    for (NSArray *mine in _revenantOwnedCorners) {
        for (RevenantGKPoint2 *corner in mine) {
            id node = RevenantGKPointNodeWithClass(_revenantNodeClass, [corner vector]);
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
            [_revenantObstacles addObject:obstacle];
        }
    }
    [self revenant_rescan];
}

- (void)removeObstacles:(NSArray *)obstacles
{
    for (id obstacle in obstacles) {
        [_revenantObstacles removeObjectIdenticalTo:obstacle];
    }
    [self revenant_rescan];
}

- (void)revenant_rescan
{
    NSArray *before = [self nodes];
    for (GKGraphNode *node in before) {
        [node removeConnectionsToNodes:before bidirectional:NO];
    }
    [self removeNodes:before];
    [_revenantOwnedCorners removeAllObjects];
    [_revenantCorners removeAllObjects];
    [_revenantCorners addObjectsFromArray:RevenantGKBufferedCorners(_revenantObstacles, _revenantBufferRadius,
                                                                 _revenantOwnedCorners)];
    NSArray *nodes = [self revenant_cornerNodes];
    [self addNodes:nodes];
    [self revenant_connect:nodes obstacles:_revenantObstacles];
}

- (void)removeAllObstacles
{
    [_revenantObstacles removeAllObjects];
    [self revenant_rescan];
}

- (void)revenant_connect:(NSArray *)nodes obstacles:(NSArray *)obstacles
{
    for (NSUInteger first = 0; first < [nodes count]; first++) {
        for (NSUInteger second = first + 1; second < [nodes count]; second++) {
            [self revenant_join:[nodes objectAtIndex:first] to:[nodes objectAtIndex:second] obstacles:obstacles];
        }
    }
}

- (void)revenant_connectNode:(GKGraphNode *)node obstacles:(NSArray *)obstacles
{
    if (node == nil) {
        return;
    }
    for (GKGraphNode *other in [self nodes]) {
        [self revenant_join:node to:other obstacles:obstacles];
    }
}

- (void)revenant_join:(GKGraphNode *)from to:(GKGraphNode *)to obstacles:(NSArray *)obstacles
{
    if (from == nil || to == nil || from == to) {
        return;
    }
    if (![from isKindOfClass:[GKGraphNode2D class]] || ![to isKindOfClass:[GKGraphNode2D class]]) {
        return;
    }
    vector_float2 line[2] = {[(GKGraphNode2D *)from position], [(GKGraphNode2D *)to position]};
    for (id obstacle in obstacles) {
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
            return;
        }
    }
    [from addConnectionsToNodes:@[to] bidirectional:YES];
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
{
    [self revenant_connectNode:node obstacles:_revenantObstacles];
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
            ignoringObstacles:(NSArray *)obstaclesToIgnore
{
    NSMutableArray *kept = [NSMutableArray array];
    for (id obstacle in _revenantObstacles) {
        if ([obstaclesToIgnore indexOfObjectIdenticalTo:obstacle] == NSNotFound) {
            [kept addObject:obstacle];
        }
    }
    [self revenant_connectNode:node obstacles:kept];
}

- (void)connectNodeUsingObstacles:(GKGraphNode *)node
    ignoringBufferRadiusOfObstacles:(NSArray *)obstaclesBufferRadiusToIgnore
{
    NSMutableArray *corners = [NSMutableArray array];
    for (NSUInteger index = 0; index < _revenantObstacles.count; index++) {
        id obstacle = [_revenantObstacles objectAtIndex:index];
        BOOL named = [obstaclesBufferRadiusToIgnore indexOfObjectIdenticalTo:obstacle] != NSNotFound;
        NSArray *vertices = RevenantGKVerticesOfObstacle(obstacle);
        if (vertices == nil || [vertices count] < 3) {
            continue;
        }
        for (RevenantGKPoint2 *corner in RevenantGKBufferedCorners(@[obstacle], named ? 0 : _revenantBufferRadius,
                                                               nil)) {
            id cornerNode = RevenantGKPointNodeWithClass(_revenantNodeClass, [corner vector]);
            if (cornerNode != nil) {
                [corners addObject:cornerNode];
            }
        }
    }
    for (id corner in corners) {
        [self revenant_join:node to:corner obstacles:_revenantObstacles];
    }
}

- (NSArray *)nodesForObstacle:(GKPolygonObstacle *)obstacle
{
    NSUInteger index = [_revenantObstacles indexOfObjectIdenticalTo:obstacle];
    if (index == NSNotFound || index >= [_revenantOwnedCorners count]) {
        return [NSArray array];
    }
    NSArray *mine = [_revenantOwnedCorners objectAtIndex:index];
    NSMutableArray *answer = [NSMutableArray arrayWithCapacity:[mine count]];
    NSUInteger at = 0;
    for (NSUInteger corner = 0; corner < [_revenantOwnedCorners count]; corner++) {
        NSUInteger width = [[_revenantOwnedCorners objectAtIndex:corner] count];
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
    if ([_revenantLocks indexOfObject:pair] == NSNotFound) {
        [_revenantLocks addObject:pair];
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
    [_revenantLocks removeObject:pair];
    [startNode addConnectionsToNodes:@[endNode] bidirectional:YES];
}

- (BOOL)isConnectionLockedFromNode:(GKGraphNode *)startNode toNode:(GKGraphNode *)endNode
{
    NSString *pair = [NSString stringWithFormat:@"%p,%p", (__bridge void *)startNode,
                                                (__bridge void *)endNode];
    return [_revenantLocks indexOfObject:pair] != NSNotFound;
}

@end
