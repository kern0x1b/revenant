// GKObstacleGraph9.m -- the obstacle graph of GameplayKit as it arrived in iOS 9.
//
// WHY THIS IS AN OBJECT OF ITS OWN. An object carries the API of exactly one release (modules/apple/
// backports.lua's check_releases, read by tools/release-split.lua). GKObstacleGraph.h:15 marks the class
// GK_BASE_AVAILABILITY, which GameplayKitBase.h:26 defines as NS_CLASS_AVAILABLE(10_11, 9_0) -- so its last
// release is 9.0, while GKGraphNode3D, GKMeshGraph, GKOctree, GKQuadtree, GKRTree and GKSphereObstacle are
// GK_BASE_AVAILABILITY_2 and answer 10.0, measured by relcheck as 10.0.1. The mesh graph and the two spatial
// indexes are GKGraph10.m; the graph itself, its nodes and its obstacles are GKGraph9.m; this is the obstacle
// graph, which belongs with the first group and is its own file because the second is already full of 10.0.
//
// An obstacle graph is the visibility graph of a set of obstacles: a node at every corner an obstacle grows to,
// and an edge between two of them when the line between them meets no obstacle. That is what makes a path round
// them -- the corners are the only places a path can turn without crossing one.
//
// ONE MEASURED THING IS WORTH RECORDING RATHER THAN REPRODUCING. On the host, the nodes of an obstacle graph
// answer NaN for -position: measured, all four of a single wall's nodes, and seven of eight for two walls, at
// every buffer radius tried (0, 1 and 2), and the same for a node joined by -connectNodeUsingObstacles:. A node
// that cannot say where it is describes nothing, and a path walked through the graph would be walked through
// points that are not numbers. So this port places the corners the visibility graph is built over -- the
// obstacle's own vertices, pushed out by the buffer radius -- and the node list answers those. The node COUNT
// is the host's and it is well defined: one node per vertex of every obstacle, so a wall given as four points
// answers four nodes and two walls answer eight.

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
    // The header bounds the node class: GKObstacleGraph.h:15 declares the class as GKGraphNode2D, and the host
    // refuses any other with NSInternalInconsistencyException and the reason "initWithObstacles: nodeClass
    // does not descend from GKGraphNode2D" (measured). So a class that is not one is refused here with the
    // host's own reason rather than silently ignored.
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

// One node per corner of each obstacle, and the buffer decides how far out each corner stands: the corners are
// pushed out by the radius rather than left where the obstacle gave them, because the region an agent may not
// walk into is the obstacle plus that radius. The host answers the same COUNT for every buffer and NaN for
// every position at every buffer, so there is no host number for where they stand and the header's own rule is
// what places them.
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

// Adding an obstacle re-scans the whole graph, so the scan REPLACES the node list rather than adding to it:
// measured, a graph of one obstacle answers four nodes, and after a second obstacle is added it answers
// EIGHT -- four and four, not six. The old nodes and their edges go first, so that a re-scan after a removal
// leaves no edge to a node that is gone.
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

// The scan: the corners of the obstacles now in the graph become nodes, and the pairs that can see each other
// become edges.
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

// Join two nodes when the line between them meets no obstacle, and add one edge per pair.
- (void)charon_connect:(NSArray *)nodes obstacles:(NSArray *)obstacles
{
    for (NSUInteger first = 0; first < [nodes count]; first++) {
        for (NSUInteger second = first + 1; second < [nodes count]; second++) {
            [self charon_join:[nodes objectAtIndex:first] to:[nodes objectAtIndex:second] obstacles:obstacles];
        }
    }
}

// One node against every node of the graph, which is the pairing -connectNodeUsingObstacles: needs and
// -charon_connect: cannot do: the node it is given is the caller's, not one of a pair in the graph's own list.
- (void)charon_connectNode:(GKGraphNode *)node obstacles:(NSArray *)obstacles
{
    if (node == nil) {
        return;
    }
    for (GKGraphNode *other in [self nodes]) {
        [self charon_join:node to:other obstacles:obstacles];
    }
}

// The test itself: is the line between two nodes free of every obstacle? This is what a visibility graph is,
// and it is what -connectNodeUsingObstacles: is named for.
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

// Join a node of the caller's own to every node of the graph it can see. The node is not in the graph -- a
// caller places an agent and asks for its edges -- so the pairing is the node against the graph's own nodes,
// which is what makes this different from -charon_connect: above.
- (void)connectNodeUsingObstacles:(GKGraphNode *)node
{
    [self charon_connectNode:node obstacles:_charonObstacles];
}

// With the obstacles named left out of the test, so the edges over them are kept: GKObstacleGraph.h:19 says
// "connect the node to the nodes it has line of sight to, ignoring the listed obstacles".
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

// And with the buffer dropped for the obstacles named, which is what this method's name says: those corners
// stand where the obstacle gives them rather than pushed out by the radius.
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

// The corners of one obstacle, which is what -nodesForObstacle: answers: the nodes the scan made for that
// obstacle, in the order the obstacle's own vertices were given.
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

// A locked connection is one the search may not walk, whatever the edges say. The pair is kept and the edges
// are removed, so that unlocking puts them back: measured, locking a pair makes
// -isConnectionLockedFromNode:toNode: answer YES and unlocking it answers NO.
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
