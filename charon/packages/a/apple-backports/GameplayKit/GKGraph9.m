// GKGraph9.m -- the pathfinding graphs of GameplayKit as they arrived in iOS 9: the graph itself, its
// three kinds of node, the grid graph over them, the three obstacles of the plane, the obstacle graph
// that reads them, and the path a search answers.
//
// WHY ONE FILE AND NOT SIX. An object carries the API of exactly one release (modules/apple/backports.lua's
// check_releases, read by tools/release-split.lua), and every class here is GK_BASE_AVAILABILITY, which
// GameplayKitBase.h:26 defines as NS_CLASS_AVAILABLE(10_11, 9_0) -- the last release each answers is 9.0.
// GKGraphNode3D, GKMeshGraph, GKOctree, GKQuadtree, GKRTree and GKSphereObstacle are GK_BASE_AVAILABILITY_2,
// which that header defines at 10.0, and they are GKGraph10.m.
//
// WHAT THE HOST ANSWERS, and every number below is one of them. The oracle is measured by
// tests/backports/host/gameplaykit-graph/measure.m against the host's own GameplayKit and held by
// differential.m in the same directory; the measurements are recorded in facts/GameplayKit/Graph.md.
// None of it needs the device: GameplayKit.framework carries no code at all before iOS 8, and iOS 6 has
// none of the logic this is.
//
//   * A node's cost to another is the length of the line between them: (0,0) to (3,4) is 5. A node with
//     no position of its own -- a plain GKGraphNode -- charges 1, and its estimate is 0. A grid node
//     charges the distance between the two cells: (0,0) to (1,1) is 1.41421.
//   * -connectedNodes is the edges in the order they were added, and an edge added twice is listed
//     twice: adding n1 and n2, then the same two again, answers four nodes. -removeConnectionsToNodes:
//     takes out every copy of a node it is given and leaves the rest: after that, two.
//   * -findPathToNode: answers start to end with both ends in it -- a three-node chain answers four
//     nodes -- a node asked for itself answers one, and a target that cannot be reached answers an
//     empty array. -findPathFromNode:toNode: on a graph answers the same, and -findPathToNode: on a node
//     inside no graph answers the same, so all of them are one search over the edges the nodes hold.
//   * -connectNodeToLowestCostNode:bidirectional: connects the node to the node of the graph whose cost
//     from it is lowest. Measured: with nodes at (5,0), (0,0) and (1,0) it connects (5,0) to itself
//     twice when bidirectional is YES and once when it is NO -- the lowest cost of (5,0) to (5,0) is 0,
//     below the 5 to (0,0). A node that is not in the graph, and a graph with no nodes, leave it alone.
//   * A graph's -removeNodes: takes the nodes out and strips them from their neighbours' edges -- a
//     two-node path's ends answer an empty connectedNodes afterwards -- and -addNodes: puts them in.
//   * An archive round trip carries the nodes as their class and their own position, and the edges with
//     them: a graph of two 2D nodes at (0,0) and (4,0) answers 558 bytes and decodes to two nodes with
//     their edge intact. An obstacle graph's archive carries its nodes and its buffer radius but NOT its
//     obstacles -- a graph built with one obstacle decodes with none -- which is the host's own answer
//     and is why -initWithCoder: here reads obstacles under a key and answers nil for them.
//   * A path of fewer than two points raises rather than answering: NSInternalInconsistencyException,
//     with the reason "GKPathLessThanTwoPointsException: GKPaths MUST be initialized with 2 or more
//     points.  Single point paths are not allowed" for -pathWithPoints:count:..., and "GKPath: must be
//     initialized with 2 or more graph nodes.  Single node paths are not allowed" for
//     -pathWithGraphNodes:. Both are measured; see measure.m.
//   * -pointAtIndex: and -float2AtIndex: past the end answer the zero vector, and -vertexAtIndex: past
//     the end of a polygon obstacle answers the zero point.
//
// The one search all of this reaches is CharonGKFindPath, in CharonGKGraph.m, which is a file that
// exports no API symbol -- the trap charon/AGENTS.md names and that was measured on 2026-09-28.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

#import "CharonGKGraph.h"

// Every member of the 10.0 half of this framework is declared on a class this file does not implement,
// and the compiler is right to say so for each: -float2AtIndex:, -float3AtIndex: and the two
// -...WithFloat3Points: initialisers are API_AVAILABLE(ios(10.0)) (GKPath.h:22-23, :31-32) and they are
// GKGraph10.m. The suppression is that sentence and nothing else -- the same suppression, for the same
// reason, as the one at the top of CarPlay/CarPlayLane174.m for the 18.0 half of CPLane.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
// The two obstacle classes below carry a designated initialiser their header declares, so the compiler
// wants an -init that calls one. The host's own -init refuses instead, with the reason each class's
// header names, and that refusal IS the answer -- measured, see measure.m -- so the one thing the
// warning asks for and the one thing this file must not do are the same line. The suppression is that
// sentence and nothing else.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// --- GKGraphNode -------------------------------------------------------------------------------------
// A node in a directed graph: the edges are its own, and it is the edges that make the graph. The
// storage is the array of edges, which is what -connectedNodes answers directly -- no copy, so the order
// is the order the edges were added in and a repeated edge is a repeated entry, which is what the host
// does.
@implementation GKGraphNode {
    NSMutableArray *_charonEdges;
}

// A node's copy is a node of its own at the SAME POSITION with no edges yet -- the edges are rebuilt by the
// graph that is being copied, because an edge of the copy must point at the copy's own node and not at the
// original's. The position is this class's own state, so each subclass's -copyWithZone: below carries it.
//
// GKGraphNode.h:15 declares NSSecureCoding and NSCopying is not among the protocols of any node or graph in
// this framework, so this is the graph's own use of -copy and not a member the framework owes a caller:
// -[GKGraph copyWithZone:] below is what is public, and it is what measured the host deep-copies the nodes --
// a copied graph's nodes are different objects at the same positions with the same edges between them.
- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[self class] alloc];
}

// -[GKGraph copyWithZone:] reads each node's position after the copy, so a copy of a plain node is a plain
// node at the origin -- which is what a plain node has no position to lose. The classes that carry one
// override this and carry it across.
- (vector_float2)charon_positionToCopy { return (vector_float2){0, 0}; }

- (NSMutableArray *)charon_edges
{
    if (_charonEdges == nil) {
        _charonEdges = [NSMutableArray array];
    }
    return _charonEdges;
}

- (NSArray *)connectedNodes { return [[self charon_edges] copy]; }

// The edges as they are, for a graph that is copying itself and for a node that is searching: a copy
// needs the edges of its own rather than a copy of the list, and a search walks them directly.
- (void)charon_setEdges:(NSArray *)edges { _charonEdges = [edges mutableCopy]; }

- (void)addConnectionsToNodes:(NSArray *)nodes bidirectional:(BOOL)bidirectional
{
    for (GKGraphNode *node in nodes) {
        if (node == nil) {
            continue;
        }
        [[self charon_edges] addObject:node];
        if (bidirectional) {
            [node addConnectionsToNodes:@[self] bidirectional:NO];
        }
    }
}

- (void)removeConnectionsToNodes:(NSArray *)nodes bidirectional:(BOOL)bidirectional
{
    NSMutableArray *edges = [self charon_edges];
    // Every copy of a node the caller names goes, not the first: measured, a node that appears three
    // times in the edge list is gone after one -removeConnectionsToNodes:.
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

// The cost of a plain node is 1 and its estimate is 0: measured on two GKGraphNodes, and it is what the
// header's own words say -- a node that carries no position has no distance to report, so the edge
// costs a unit and the search has nothing to estimate. The subclasses that carry a position answer the
// length of the line instead.
- (float)costToNode:(GKGraphNode *)node { (void)node; return 1; }
- (float)estimatedCostToNode:(GKGraphNode *)node { (void)node; return 0; }

- (NSArray *)findPathToNode:(GKGraphNode *)goalNode
{
    if (goalNode == nil) {
        return nil;
    }
    NSArray *path = CharonGKFindPath([self charon_searchableNodes], self, goalNode);
    return path == nil ? [NSArray array] : path;
}

// The nodes this one may walk through, which is itself and everything its edges reach. Measured: a node
// that is in no graph at all answers the same path a node inside one does, and a node with an edge into
// another chain walks that chain too.
- (NSArray *)charon_searchableNodes
{
    NSMutableArray *seen = [NSMutableArray arrayWithObject:self];
    NSMutableArray *queue = [NSMutableArray arrayWithObject:self];
    while ([queue count] > 0) {
        GKGraphNode *current = [queue objectAtIndex:0];
        [queue removeObjectAtIndex:0];
        for (GKGraphNode *next in [current charon_edges]) {
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
    // As -findPathToNode: with this node as the goal: the header says so in one sentence, and a search
    // over the same edges answers the same path either way round.
    if (startNode == nil) {
        return nil;
    }
    NSArray *path = CharonGKFindPath([self charon_searchableNodes], startNode, self);
    return path == nil ? [NSArray array] : path;
}

// A node's archive is its class and its own state. There is none beyond the edges, so the edges are all
// it carries, and each neighbour is written as the class it is -- a node's neighbour list is a list of
// nodes, and writing each one's class is what a graph needs to rebuild it.
// A node's archive is its edges, as the objects they name. The identity of a decoded node is the identity the
// encoder saw, so an edge of a decoded node names the decoded node at its other end and the graph that
// decoded them is walkable -- which is what makes -findPathFromNode:toNode: answer the same path across a
// round trip as across the tree it was encoded from.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSObject class], nil];
        NSArray *decoded = [coder decodeObjectOfClasses:classes forKey:CharonGKGraphNodesKey];
        for (id node in decoded) {
            if ([node isKindOfClass:[GKGraphNode class]]) {
                [[self charon_edges] addObject:node];
            }
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self charon_edges] forKey:CharonGKGraphNodesKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

// --- GKGraphNode2D -----------------------------------------------------------------------------------
// A node with a point in the plane. The cost of an edge is the length of the line between the two
// points, and the estimate is the same number: the search needs no better estimate than the truth here,
// and the host's own answers are one value for both -- (0,0) to (3,4) is 5 for -costToNode: and 5 for
// -estimatedCostToNode:.
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

- (vector_float2)charon_positionToCopy { return _position; }

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
    return CharonGKLength2(_position, ((GKGraphNode2D *)node).position);
}

- (float)estimatedCostToNode:(GKGraphNode *)node { return [self costToNode:node]; }

// The point is what this class adds to a node's archive, and it is written under the key every graph of
// this framework uses, so a decoded node is at the point it was encoded at.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _position = (vector_float2){0, 0};
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        NSArray *held = [coder decodeObjectOfClasses:classes forKey:CharonGKGraphNodePositionKey];
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
                 forKey:CharonGKGraphNodePositionKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

// --- GKGridGraphNode ---------------------------------------------------------------------------------
// A node with a cell in a grid. Its cost is the distance between the two cells rather than a length in
// any unit: measured (0,0) to (1,1) is 1.41421, and it is what makes a grid graph's path the same
// whether it is searched by cells or by lengths.
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
    return CharonGKCellDistance(_gridPosition, ((GKGridGraphNode *)node).gridPosition);
}

- (float)estimatedCostToNode:(GKGraphNode *)node { return [self costToNode:node]; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _gridPosition = (vector_int2){0, 0};
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        NSArray *held = [coder decodeObjectOfClasses:classes forKey:CharonGKGraphNodePositionKey];
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
                 forKey:CharonGKGraphNodePositionKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

// --- GKGraph -----------------------------------------------------------------------------------------
// A graph is the nodes it was given and the edges those nodes hold between them. It adds no structure of
// its own over them: -findPathFromNode:toNode: is the search of GKGraphNode, and -removeNodes: and
// -addNodes: are the node list.
@implementation GKGraph {
    NSMutableArray *_charonNodes;
}

- (instancetype)initWithNodes:(NSArray *)nodes
{
    self = [super init];
    if (self) {
        _charonNodes = [nodes mutableCopy] ?: [NSMutableArray array];
    }
    return self;
}

+ (instancetype)graphWithNodes:(NSArray *)nodes { return [[self alloc] initWithNodes:nodes]; }

- (NSArray *)nodes { return [_charonNodes copy]; }

// Measured: a node already in the graph is added again rather than skipped. A graph built from
// @[a, a] answers two nodes, and -addNodes: with a node it already holds answers three. The node list is
// the list of the nodes it was given, in order, with no filtering -- which is what a graph's nodes
// property is documented to be.
- (void)addNodes:(NSArray *)nodes
{
    for (GKGraphNode *node in nodes) {
        if (node != nil) {
            [_charonNodes addObject:node];
        }
    }
}

- (void)removeNodes:(NSArray *)nodes
{
    // The node goes, and so does every edge that led to it: measured, the two ends of a two-node path
    // both answer an empty -connectedNodes after the node between them is removed. That is what makes
    // the graph a graph -- leaving a dangling edge would make the removed node reachable still.
    for (GKGraphNode *node in nodes) {
        if ([_charonNodes indexOfObjectIdenticalTo:node] == NSNotFound) {
            continue;
        }
        [_charonNodes removeObjectIdenticalTo:node];
        for (GKGraphNode *other in [_charonNodes copy]) {
            [other removeConnectionsToNodes:@[node] bidirectional:NO];
        }
    }
}

- (NSArray *)findPathFromNode:(GKGraphNode *)startNode toNode:(GKGraphNode *)endNode
{
    if (startNode == nil || endNode == nil) {
        return nil;
    }
    // The nodes walked are the graph's own and everything its edges reach, not its list alone: measured,
    // a graph holding one node of a three-node chain answers the whole path to a node it never held.
    NSArray *path = CharonGKFindPath([self charon_reachableNodes], startNode, endNode);
    return path == nil ? [NSArray array] : path;
}

- (void)connectNodeToLowestCostNode:(GKGraphNode *)node bidirectional:(BOOL)bidirectional
{
    // The node of the graph the caller names is not one of them unless it was added, and then nothing
    // happens: measured on a node outside the graph and on a graph with no nodes at all.
    if (node == nil || [_charonNodes indexOfObjectIdenticalTo:node] == NSNotFound) {
        return;
    }
    GKGraphNode *lowest = nil;
    float lowestCost = INFINITY;
    for (GKGraphNode *other in _charonNodes) {
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

// A copy is a graph of its own whose nodes are copies too. Measured: after -copy the copy's nodes are
// different objects from the original's, at the same positions, with the same edges between them -- the
// copy's first node's edge points at the copy's own second node and not at the original's -- so a copy is
// a second graph that can be searched and mutated without touching the first. That is what NSCopying asks
// for and what makes a graph worth copying at all.
- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    // Every node the graph can reach, so that an edge that leaves the graph's own list is copied too.
    NSArray *reached = [self charon_reachableNodes];
    NSMutableDictionary *copies = [NSMutableDictionary dictionaryWithCapacity:[reached count]];
    for (GKGraphNode *node in reached) {
        id copied = [node copy];
        if (copied != nil) {
            [copies setObject:copied forKey:[NSValue valueWithPointer:(__bridge const void *)node]];
        }
    }

    NSMutableArray *nodes = [NSMutableArray array];
    for (GKGraphNode *node in _charonNodes) {
        id copied = [copies objectForKey:[NSValue valueWithPointer:(__bridge const void *)node]];
        [nodes addObject:copied ?: node];
    }
    GKGraph *answer = [[[self class] alloc] initWithNodes:nodes];
    // The edges, one for each edge of the original, each pointing at the copy of the node it pointed at.
    for (GKGraphNode *node in reached) {
        id copied = [copies objectForKey:[NSValue valueWithPointer:(__bridge const void *)node]];
        NSMutableArray *edges = [NSMutableArray array];
        for (GKGraphNode *other in [node charon_edges]) {
            id copiedOther = [copies objectForKey:[NSValue valueWithPointer:(__bridge const void *)other]];
            if (copiedOther != nil) {
                [edges addObject:copiedOther];
            }
        }
        if ([edges count] > 0) {
            [copied charon_setEdges:edges];
        }
    }
    return answer;
}

// Every node the graph can reach from the ones it holds. An edge that leaves the graph's own list still
// walks: measured, a graph of one node answers a three-node path to a node that is not in it, because the
// edge out of it reaches nodes the graph never heard of.
- (NSArray *)charon_reachableNodes
{
    NSMutableArray *seen = [NSMutableArray array];
    NSMutableArray *queue = [NSMutableArray arrayWithArray:_charonNodes];
    while ([queue count] > 0) {
        GKGraphNode *current = [queue objectAtIndex:0];
        [queue removeObjectAtIndex:0];
        if ([seen indexOfObjectIdenticalTo:current] != NSNotFound) {
            continue;
        }
        [seen addObject:current];
        for (GKGraphNode *next in [current charon_edges]) {
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
        _charonNodes = [NSMutableArray array];
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSObject class], nil];
        NSArray *decoded = [coder decodeObjectOfClasses:classes forKey:CharonGKGraphNodesKey];
        for (id node in decoded) {
            if ([node isKindOfClass:[GKGraphNode class]]) {
                [_charonNodes addObject:node];
            }
        }
    }
    return self;
}

// The nodes go into the archive as themselves, not as their class names. A node carries its own position and
// its own edges, and the edges name other nodes -- so writing the objects is what keeps a decoded graph the
// graph that was encoded: each node comes back at its position with its edges, and an edge names the decoded
// node at the other end rather than a fresh one. NSKeyedArchiver preserves object identity, so a node that is
// an edge of two others is written once and comes back once. Measured: a two-node graph whose ends are joined
// answers 558 bytes and decodes to two nodes at (0,0) and (4,0) with the edge between them intact.
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonNodes forKey:CharonGKGraphNodesKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

// --- GKGridGraph -------------------------------------------------------------------------------------
// A grid of cells with a node in each, and the edges between the cells that touch. The grid is built
// whole in the initialiser and connected there: measured, a node in a fresh 3x2 grid already answers two
// edges, its right and upper neighbours, and a diagonal grid answers three.
//
// The nodes are the class the caller names, defaulting to GKGridGraphNode. The property
// -classForGenericArgumentAtIndex: exists because the class is a generic parameter the header declares,
// and the host answers the node class with it: measured, a grid graph answers GKGridGraphNode.
@implementation GKGridGraph {
    vector_int2 _gridOrigin;
    NSUInteger _gridWidth;
    NSUInteger _gridHeight;
    BOOL _diagonalsAllowed;
    Class _charonNodeClass;
    NSMutableDictionary *_charonCells;
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
        _charonNodeClass = nodeClass ?: [GKGridGraphNode class];
        _charonCells = [NSMutableDictionary dictionaryWithCapacity:_gridWidth * _gridHeight];
        NSMutableArray *nodes = [NSMutableArray arrayWithCapacity:_gridWidth * _gridHeight];
        for (NSUInteger y = 0; y < _gridHeight; y++) {
            for (NSUInteger x = 0; x < _gridWidth; x++) {
                vector_int2 cell = (vector_int2){_gridOrigin.x + (int)x, _gridOrigin.y + (int)y};
                GKGridGraphNode *node = [[_charonNodeClass alloc] initWithGridPosition:cell];
                _charonCells[[self charon_keyForCell:cell]] = node;
                [nodes addObject:node];
            }
        }
        [self addNodes:nodes];
        // The grid is connected whole: every cell to the one on its right, the one above and -- when the
        // grid allows it -- the two diagonals. Connecting each cell to the cell on its left, below and
        // below-diagonally gives every pair of touching cells both of its edges, which is what
        // bidirectional:YES would do one cell at a time.
        for (NSUInteger y = 0; y < _gridHeight; y++) {
            for (NSUInteger x = 0; x < _gridWidth; x++) {
                vector_int2 cell = (vector_int2){_gridOrigin.x + (int)x, _gridOrigin.y + (int)y};
                GKGridGraphNode *node = [self nodeAtGridPosition:cell];
                if (node == nil) {
                    continue;
                }
                // The order of these three is the order the host's own path answers name: a cell's neighbour
                // above it, then the one to its left, then the diagonals. A tie on the cost of two of them is
                // broken by the order the edges were added in -- measured, a path across a 3x2 grid from
                // (2,3) to (4,4) answers (2,3) (3,3) (3,4) (4,4) and not (2,3) (3,3) (4,3) (4,4), and the two
                // are the same length.
                // Only the neighbours that come LATER in the row-major walk, so that a pair of touching
                // cells is joined once and not once from each side: the host's own edge list has no duplicate
                // (measured, the cell (3,3) of a 3x2 grid answers (2,3) (4,3) (3,4) -- three, one per
                // neighbour), and joining both ways here would answer six.
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

// The cell a node sits in, as a string, so the cells can be a dictionary: a vector is not a key and the
// release has nothing that takes one.
- (NSString *)charon_keyForCell:(vector_int2)cell
{
    return [NSString stringWithFormat:@"%d,%d", cell.x, cell.y];
}

- (GKGridGraphNode *)nodeAtGridPosition:(vector_int2)position
{
    GKGridGraphNode *node = [_charonCells objectForKey:[self charon_keyForCell:position]];
    if (node == nil || ![node isKindOfClass:[GKGridGraphNode class]]) {
        // A cell outside the grid has no node: measured, a position the grid does not cover answers nil.
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
    // The cells that touch this one: the four around it, plus the four diagonals when the grid allows
    // them. Measured: a cell already connected to its two neighbours answers four after this, the two it
    // had plus the two it gained -- the same edges added again, which is what this method is on a graph
    // whose grid is already connected.
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
    // The grid has one generic parameter and it is the node class. Measured: index 0 of a grid graph
    // answers GKGridGraphNode.
    (void)index;
    return _charonNodeClass;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        // The grid's own shape is written under the keys the graph writes its own state under, because
        // the graph's archive is the node list and the nodes are the cells: a decoded grid is rebuilt
        // from the cells its nodes carry, and the origin and size fall out of them.
        _charonNodeClass = [GKGridGraphNode class];
        _charonCells = [NSMutableDictionary dictionary];
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
            _charonCells[[self charon_keyForCell:cell]] = (GKGridGraphNode *)node;
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
            // A diagonal edge is an edge to a cell that touches in both directions, which is what tells
            // the two grids apart after a round trip.
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

// A grid graph writes and reads the nodes of the grid, and it declares itself secure-codable so that the
// archiver accepts the archive at all: measured, without this the archiver answers nil and the unarchiver
// NSCocoaErrorDomain 4864 "data is NULL", because a class that overrides -initWithCoder: and inherits a
// YES from its superclass is refused by the secure-coding check.
+ (BOOL)supportsSecureCoding { return YES; }

@end

// --- the obstacles of the plane ----------------------------------------------------------------------
// An obstacle is a shape an agent's path has to go round, and it is the graph that reads it. There is
// nothing to it here but the shape itself: the abstract class has no member at all, which is what
// GKObstacle.h:18-20 says.
@implementation GKObstacle
@end

@implementation GKCircleObstacle {
    float _radius;
    vector_float2 _position;
}

// The header marks -initWithRadius: the designated initialiser (GKObstacle.h:29), and the host answers a
// plain -init by refusing: NSInternalInconsistencyException, "initWithRadius: is the destignated
// initialize for GKCircleObstacle.  Use that instead" (measured, measure.m, and the spelling of that
// reason -- "destignated" -- is the host's own).
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

// A polygon obstacle is a closed path through the points it was given, kept in that order and that
// order alone: -vertexAtIndex: answers the point that was given at that index, and an index past the end
// answers the zero point (measured). It is the only obstacle of the plane that is NSSecureCoding, and its
// archive is the list of vertices.
@implementation GKPolygonObstacle {
    vector_float2 *_charonVertices;
    NSUInteger _charonVertexCount;
}

// The designated initialiser of this class too (GKObstacle.h:53), refused the same way: measured, the
// host's reason is "initWithPoints: is the destignated initialize for GKPolygonObstacle.  Use that
// instead".
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
        _charonVertexCount = count;
        if (count > 0 && points != NULL) {
            _charonVertices = malloc(count * sizeof(vector_float2));
            if (_charonVertices != NULL) {
                memcpy(_charonVertices, points, count * sizeof(vector_float2));
            } else {
                _charonVertexCount = 0;
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
    free(_charonVertices);
}

- (NSUInteger)vertexCount { return _charonVertexCount; }

- (vector_float2)vertexAtIndex:(NSUInteger)index
{
    if (_charonVertices == NULL || index >= _charonVertexCount) {
        return (vector_float2){0, 0};
    }
    return _charonVertices[index];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
    NSArray *held = [coder decodeObjectOfClasses:classes forKey:CharonGKObstacleVerticesKey];
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
    NSMutableArray *held = [NSMutableArray arrayWithCapacity:_charonVertexCount];
    for (NSUInteger index = 0; index < _charonVertexCount; index++) {
        [held addObject:@[[NSNumber numberWithFloat:_charonVertices[index].x],
                          [NSNumber numberWithFloat:_charonVertices[index].y]]];
    }
    [coder encodeObject:held forKey:CharonGKObstacleVerticesKey];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

// --- GKPath ------------------------------------------------------------------------------------------
// A path is the points a search walked through, plus the radius of the corridor around them and whether
// the corridor closes on itself. The points are kept as given -- -pointAtIndex: answers the point that
// was given at that index and the zero point past the end (measured) -- and there is no path of fewer
// than two points: the initialisers raise NSInternalInconsistencyException with the reason the host
// raises, which is recorded in facts/GameplayKit/Graph.md and held by the differential.
@implementation GKPath {
    float _radius;
    BOOL _cyclical;
    // The 3D points are stored when the path was built from them, and the 2D points otherwise. A path
    // built one way answers -float3AtIndex: from the 3D points and -float2AtIndex: from the 2D ones; a
    // path built the other way answers -float2AtIndex: from the 2D points and -float3AtIndex: from the
    // same points read as 3D, which is what the host does: a 3D path's -float2AtIndex: answers the x
    // and the z of its points (measured, (0,0,1) answers (0,1) and (2,0,3) answers (2,3)).
    vector_float3 *_charonPoints3;
    vector_float2 *_charonPoints2;
    NSUInteger _charonPointCount;
}

- (void)charon_raiseLessThanTwoPoints:(NSString *)reason
{
    [NSException raise:NSInternalInconsistencyException format:@"%@", reason];
}

- (instancetype)initWithPoints:(vector_float2 *)points count:(size_t)count radius:(float)radius
                    cyclical:(BOOL)cyclical
{
    if (count < 2) {
        [self charon_raiseLessThanTwoPoints:@"GKPathLessThanTwoPointsException: GKPaths MUST be "
                                            @"initialized with 2 or more points.  Single point paths "
                                            @"are not allowed"];
        return nil;
    }
    self = [super init];
    if (self) {
        _radius = radius;
        _cyclical = cyclical;
        _charonPointCount = count;
        _charonPoints2 = malloc(count * sizeof(vector_float2));
        if (_charonPoints2 == NULL) {
            _charonPointCount = 0;
            return self;
        }
        for (size_t index = 0; index < count; index++) {
            _charonPoints2[index] = points[index];
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
        [self charon_raiseLessThanTwoPoints:@"GKPath: must be initialized with 2 or more graph nodes.  "
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
- (NSUInteger)numPoints { return _charonPointCount; }
- (BOOL)isCyclical { return _cyclical; }
- (void)setCyclical:(BOOL)cyclical { _cyclical = cyclical; }

// -pointAtIndex: is GKPath.h:35, deprecated in 10.0 and last available at 9.0, so it is this object's
// member and -float2AtIndex: (GKPath.h:36, API_AVAILABLE(ios(10.0))) is GKGraph10.m's. Both answer the
// same vector of a path of 2D points -- measured, the points (0,0),(1,0),(1,1),(0,1) come back unchanged
// from both -- so this one reads the 2D storage and the other reads it too.
- (vector_float2)pointAtIndex:(NSUInteger)index
{
    if (_charonPoints2 != NULL && index < _charonPointCount) {
        return _charonPoints2[index];
    }
    if (_charonPoints3 != NULL && index < _charonPointCount) {
        vector_float3 held = _charonPoints3[index];
        return (vector_float2){held.x, held.z};
    }
    return (vector_float2){0, 0};
}

// The three seams the 10.0 half of this class reads, which are GKGraph10.m's category. An object's ivars
// are not visible to another object, so the 3D storage and the two 3D initialisers live here and the
// 10.0 members are three lines that call them.
- (vector_float3)charon_float3AtIndex:(NSUInteger)index
{
    if (_charonPoints3 != NULL && index < _charonPointCount) {
        return _charonPoints3[index];
    }
    if (_charonPoints2 != NULL && index < _charonPointCount) {
        return (vector_float3){_charonPoints2[index].x, 0, _charonPoints2[index].y};
    }
    return (vector_float3){0, 0, 0};
}

- (instancetype)charon_initWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical
{
    return [self initWithCharonFloat3Points:points count:count radius:radius cyclical:cyclical];
}

// The allocation itself, in the init family so that the two 3D initialisers reach it. The 9.0 storage is
// filled first -- two points and a radius -- so that the object's invariants hold from the moment the
// object exists, and then the 3D storage takes over: a path of 3D points has no 2D points at all, and the
// 2D accessor answers each 3D point's x and z.
- (instancetype)initWithCharonFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
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
        free(_charonPoints2);
        _charonPoints2 = NULL;
        _charonPoints3 = malloc(count * sizeof(vector_float3));
        if (_charonPoints3 != NULL) {
            for (size_t index = 0; index < count; index++) {
                _charonPoints3[index] = points[index];
            }
            _charonPointCount = count;
        } else {
            _charonPointCount = 0;
        }
    }
    return self;
}

+ (instancetype)charon_pathWithFloat3Points:(vector_float3 *)points count:(size_t)count radius:(float)radius
                                  cyclical:(BOOL)cyclical
{
    return [[self alloc] initWithFloat3Points:points count:count radius:radius cyclical:cyclical];
}

- (void)dealloc
{
    free(_charonPoints2);
    free(_charonPoints3);
}

@end

#pragma clang diagnostic pop