// differential.m -- the port's pathfinding graphs held against what the host's own GameplayKit answers.
//
// Every check below names the block of measure.m whose number it came from, and run.sh prints measure.m's own
// output beside the checks, so each one can be re-measured rather than trusted. The port's sources are compiled
// with no GameplayKit framework in the picture, so its classes are the only ones of these names in the process
// and this file calls the port exactly as an application would.
//
// FOUR MEMBERS ARE NOT HELD AGAINST A HOST NUMBER, and each says so in its own check text:
//   * -[GKGraphNode findPathFromNode:] -- the host traps (SIGBUS inside GameplayKit) on every input tried.
//   * -[GKQuadtreeNode quad] -- the host answers the zero quad for every node of every tree tried.
//   * -elementsAtPoint: for an element added with a box or a quad, and -elementsInBox: for a box element
//     -- the host's answers contradict its own header and, at one cell size, its own tree.
//   * the node positions of an obstacle graph -- the host answers NaN for every one of them.
//
// The two float tolerances are the ones the port's own header already records: CharonGK.h:37-38 says the
// host's own float arithmetic is up to two units in the last place away from the correctly rounded division,
// so a distance is compared with a relative slack rather than for equality. Measured on the host: 7.21110249
// for the distance from (9,8) to (3,4), 1.41421354 and 2.23606801 for two grid cells.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>
#import <math.h>

static int checksRun = 0;
static int checksFailed = 0;

static BOOL near(float value, float expected)
{
    float slack = expected * 1e-6f;
    if (slack < 1e-6f) {
        slack = 1e-6f;
    }
    return fabsf(value - expected) <= slack;
}

static void host(BOOL ok, NSString *what)
{
    checksRun++;
    if (!ok) {
        checksFailed++;
        printf("FAIL host: %s\n", [what UTF8String]);
    }
}

static void contract(BOOL ok, NSString *what)
{
    checksRun++;
    if (!ok) {
        checksFailed++;
        printf("FAIL contract: %s\n", [what UTF8String]);
    }
}

// A point cannot go through NSValue: @encode cannot describe a vector type and -getValue:size: is iOS 11.
// So the format helpers below read a vector into a two-float box and print it, and a node list is printed from
// the node's own -position or -gridPosition.
@interface CharonHostPoint : NSObject {
@public
    float px;
    float py;
}
+ (instancetype)atX:(float)x y:(float)y;
@end

@implementation CharonHostPoint
+ (instancetype)atX:(float)x y:(float)y
{
    CharonHostPoint *answer = [[CharonHostPoint alloc] init];
    answer->px = x;
    answer->py = y;
    return answer;
}
@end

static NSArray *one(vector_float2 a)
{
    return [NSArray arrayWithObject:[CharonHostPoint atX:a.x y:a.y]];
}

static NSArray *two(vector_float2 a, vector_float2 b)
{
    return [NSArray arrayWithObjects:[CharonHostPoint atX:a.x y:a.y], [CharonHostPoint atX:b.x y:b.y], nil];
}

static NSArray *four(vector_float2 a, vector_float2 b, vector_float2 c, vector_float2 d)
{
    return [NSArray arrayWithObjects:[CharonHostPoint atX:a.x y:a.y], [CharonHostPoint atX:b.x y:b.y],
                                    [CharonHostPoint atX:c.x y:c.y], [CharonHostPoint atX:d.x y:d.y], nil];
}

static NSString *printed(NSArray *boxes)
{
    NSMutableString *answer = [NSMutableString string];
    for (CharonHostPoint *box in boxes) {
        [answer appendFormat:@" (%g,%g)", box->px, box->py];
    }
    return answer;
}

static NSString *printedNodes(NSArray *nodes)
{
    NSMutableString *answer = [NSMutableString string];
    for (GKGraphNode *node in nodes) {
        if ([node isKindOfClass:[GKGraphNode2D class]]) {
            vector_float2 point = ((GKGraphNode2D *)node).position;
            [answer appendFormat:@" (%g,%g)", point.x, point.y];
        } else if ([node isKindOfClass:[GKGridGraphNode class]]) {
            vector_int2 cell = ((GKGridGraphNode *)node).gridPosition;
            [answer appendFormat:@" (%d,%d)", cell.x, cell.y];
        } else {
            [answer appendString:@" ?"];
        }
    }
    return answer;
}

static NSString *printedCells(NSArray *nodes)
{
    NSMutableString *answer = [NSMutableString string];
    for (GKGraphNode *node in nodes) {
        if ([node isKindOfClass:[GKGridGraphNode class]]) {
            vector_int2 cell = ((GKGridGraphNode *)node).gridPosition;
            [answer appendFormat:@" (%d,%d)", cell.x, cell.y];
        } else {
            [answer appendString:@" ?"];
        }
    }
    return answer;
}

static NSString *printedNames(NSArray *elements)
{
    NSMutableString *answer = [NSMutableString string];
    for (id element in elements) {
        [answer appendFormat:@" %@", element];
    }
    return answer;
}

// Did a call raise with exactly this reason? Every refusal in this family is a refusal the host makes, and
// the reason text is part of the answer -- two of them carry Apple's own spelling mistake, "destignated".
static BOOL raisedWith(void (^body)(void), NSString *name, NSString *reason)
{
    @try {
        body();
    } @catch (NSException *exception) {
        return [exception.name isEqualToString:name] && [exception.reason isEqualToString:reason];
    }
    return NO;
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        // === m1: the nodes and their costs ==========================================================
        {
            GKGraphNode2D *a = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 4}];
            host([a isMemberOfClass:[GKGraphNode2D class]] && a.position.x == 0 && a.position.y == 0,
                 @"m1 the 2D factory answers a 2D node at the point it was given");
            host(near([a costToNode:b], 5) && near([a estimatedCostToNode:b], 5),
                 @"m1 the cost of an edge is the length of the line between its ends, and the estimate is the "
                 @"same number");
            a.position = (vector_float2){9, 8};
            host(near(a.position.x, 9) && near(a.position.y, 8) && near([a costToNode:b], 7.21110249f),
                 @"m1 a position set afterwards is read back and the cost follows it");
            GKGraphNode2D *fresh = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            host([fresh connectedNodes].count == 0, @"m1 a fresh node has no edges");

            GKGraphNode3D *t = [GKGraphNode3D nodeWithPoint:(vector_float3){0, 0, 0}];
            GKGraphNode3D *u = [GKGraphNode3D nodeWithPoint:(vector_float3){1, 2, 2}];
            host([t isMemberOfClass:[GKGraphNode3D class]] && near([t costToNode:u], 3) &&
                     near([t estimatedCostToNode:u], 3),
                 @"m1 the 3D factory answers a 3D node, and its cost is the length of the line in space");

            GKGraphNode *plain = [[GKGraphNode alloc] init];
            GKGraphNode *other = [[GKGraphNode alloc] init];
            host([plain costToNode:other] == 1 && [plain estimatedCostToNode:other] == 0,
                 @"m1 a node with no position charges one to reach another and estimates nothing");

            GKGridGraphNode *c = [GKGridGraphNode nodeWithGridPosition:(vector_int2){0, 0}];
            GKGridGraphNode *d = [GKGridGraphNode nodeWithGridPosition:(vector_int2){1, 1}];
            float cellCost = [c costToNode:d];
            float cellEstimate = [c estimatedCostToNode:d];
            float cellExact = 1.41421354f;
            host([c isMemberOfClass:[GKGridGraphNode class]] && near(cellCost, cellExact) &&
                     near(cellEstimate, cellExact),
                 @"m1 the grid factory answers a grid node, and its cost is the distance between two cells -- "
                 @"sqrt(2) to the last bit a float carries, which is 1.41421354 on the host");
            GKGridGraphNode *e = [GKGridGraphNode nodeWithGridPosition:(vector_int2){2, 3}];
            GKGridGraphNode *f = [GKGridGraphNode nodeWithGridPosition:(vector_int2){1, 1}];
            host(near([e costToNode:f], 2.23606801f),
                 @"m1 a grid node's cost is the distance between the two cells whatever the two cells are");
            GKGridGraphNode *plainInit = [[GKGridGraphNode alloc] init];
            host(plainInit.gridPosition.x == 0 && plainInit.gridPosition.y == 0,
                 @"m1 a grid node made with -init answers the origin cell");
            GKGraphNode2D *plain2d = [[GKGraphNode2D alloc] init];
            host(plain2d.position.x == 0 && plain2d.position.y == 0,
                 @"m1 a 2D node made with -init answers the origin point");
        }

        // === m2: the edges ========================================================================
        {
            GKGraphNode2D *n0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *n1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *n2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            GKGraphNode2D *n3 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 0}];
            host([n0 connectedNodes].count == 0, @"m2 a fresh node has no edges");
            [n0 addConnectionsToNodes:@[n1, n2] bidirectional:NO];
            host([n0 connectedNodes].count == 2, @"m2 two edges are two entries");
            [n0 addConnectionsToNodes:@[n1, n2] bidirectional:NO];
            host([n0 connectedNodes].count == 4,
                 @"m2 an edge added twice is listed twice -- the host does not filter, and neither does the port");
            [n0 addConnectionsToNodes:@[n1] bidirectional:YES];
            host([n0 connectedNodes].count == 5 && [n1 connectedNodes].count == 1,
                 @"m2 a bidirectional edge adds the edge out of the other node as well");
            host(near([n0 costToNode:n3], 3), @"m2 the cost of a node that is not connected is the distance anyway");
            [n0 removeConnectionsToNodes:@[n1, n3] bidirectional:YES];
            host([n0 connectedNodes].count == 2 && [n1 connectedNodes].count == 0,
                 @"m2 removal takes out every copy of a node named and leaves the rest, and it works both ways");
            [n0 removeConnectionsToNodes:@[n1] bidirectional:YES];
            host([n0 connectedNodes].count == 2, @"m2 removing a node that is not there leaves the edges alone");
            [n0 removeConnectionsToNodes:@[n1] bidirectional:NO];
            host([n0 connectedNodes].count == 2, @"m2 removing one way removes nothing when there is nothing");
            [n0 addConnectionsToNodes:nil bidirectional:NO];
            host([n0 connectedNodes].count == 2, @"m2 adding nothing adds nothing");
            GKGraphNode2D *self = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            [self addConnectionsToNodes:@[self] bidirectional:YES];
            host([self connectedNodes].count == 2, @"m2 an edge from a node to itself is two entries both ways");
        }

        // === m3: the finds ========================================================================
        {
            GKGraphNode2D *q0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *q1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *q2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            GKGraphNode2D *q3 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 0}];
            [q0 addConnectionsToNodes:@[q1] bidirectional:YES];
            [q1 addConnectionsToNodes:@[q2] bidirectional:YES];
            [q2 addConnectionsToNodes:@[q3] bidirectional:YES];
            NSString *forward = printedNodes([q0 findPathToNode:q3]);
            NSString *backward = printedNodes([q3 findPathToNode:q0]);
            host([forward isEqualToString:@" (0,0) (1,0) (2,0) (3,0)"],
                 @"m3 a path answers start to end with both ends in it, as points");
            host([backward isEqualToString:@" (3,0) (2,0) (1,0) (0,0)"],
                 @"m3 the same path asked for the other way round answers the other way round");
            host([[q0 findPathToNode:q0] count] == 1, @"m3 a node asked for a path to itself answers itself alone");
            GKGraphNode2D *u0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *u1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *u2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            [u0 addConnectionsToNodes:@[u1] bidirectional:YES];
            host([[u2 findPathToNode:u0] count] == 0,
                 @"m3 a target that cannot be reached answers an empty array rather than nil");
            GKGraph *g = [GKGraph graphWithNodes:@[q0, q1, q2, q3]];
            host([printedNodes([g findPathFromNode:q0 toNode:q3]) isEqualToString:@" (0,0) (1,0) (2,0) (3,0)"],
                 @"m3 a graph's find answers the same path a node's does");
            host([printedNodes([g findPathFromNode:q3 toNode:q0]) isEqualToString:@" (3,0) (2,0) (1,0) (0,0)"],
                 @"m3 and the same the other way round");
            GKGraphNode2D *alone = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            host([[alone findPathToNode:q3] count] == 0, @"m3 a node with no edges finds nothing");
            GKGraph *empty = [GKGraph graphWithNodes:@[]];
            GKGraphNode2D *only = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            host([[empty findPathFromNode:only toNode:only] count] == 1,
                 @"m3 an empty graph asked for a path from a node to itself answers that node");
            // A path that leaves the graph's own node list still walks: measured, a graph holding one node of a
            // three-node chain answers the whole path to a node it never held.
            GKGraphNode2D *c0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *c1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            [c0 addConnectionsToNodes:@[c1] bidirectional:YES];
            GKGraph *partial = [GKGraph graphWithNodes:@[c0]];
            host([[partial findPathFromNode:c0 toNode:c1] count] == 2,
                 @"m3 a graph answers a path to a node it does not hold, because the edge out of the one it does "
                 @"hold reaches it");
            contract([printedNodes([q3 findPathFromNode:q0]) isEqualToString:@" (0,0) (1,0) (2,0) (3,0)"],
                     @"contract: -findPathFromNode: answers -findPathToNode: with this node as the goal, as "
                     @"GKGraphNode.h:55-56 says -- the host traps with SIGBUS inside GameplayKit on every input "
                     @"tried, so there is no host answer to hold it to");
        }

        // === m5: the graph's own members ===========================================================
        {
            GKGraphNode2D *g0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *g1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *g2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            GKGraph *g = [GKGraph graphWithNodes:@[g0, g1, g2]];
            host([g isMemberOfClass:[GKGraph class]] && g.nodes.count == 3 && g.nodes[0] == g0,
                 @"m5 the factory answers a graph holding the nodes it was given, in order");
            [g0 addConnectionsToNodes:@[g1] bidirectional:YES];
            [g1 addConnectionsToNodes:@[g2] bidirectional:YES];
            [g removeNodes:@[g1]];
            host(g.nodes.count == 2 && [g0 connectedNodes].count == 0 && [g2 connectedNodes].count == 0,
                 @"m5 removing a node takes it out and strips it from its neighbours' edges");
            GKGraphNode2D *g3 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 0}];
            [g addNodes:@[g3]];
            host(g.nodes.count == 3, @"m5 adding a node puts it in");
            [g addNodes:@[g3]];
            host(g.nodes.count == 4,
                 @"m5 a node already in the graph is added again rather than skipped -- the host does not filter");
            GKGraph *dup = [GKGraph graphWithNodes:@[g0, g0]];
            host(dup.nodes.count == 2, @"m5 a graph built from the same node twice holds it twice");
            GKGraphNode2D *absent = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            [g removeNodes:@[absent]];
            host(g.nodes.count == 4, @"m5 removing a node the graph does not hold changes nothing");
            GKGraph *copy = [g copy];
            host([copy isMemberOfClass:[GKGraph class]] && copy.nodes.count == 4 && copy.nodes[0] != g.nodes[0],
                 @"m5 a copy is a graph of the same size whose nodes are its own objects, not the original's");
            // The copy of a graph whose nodes hold edges: the copy's nodes must be at the same positions and
            // their edges must name the COPY's nodes. The graph above has no edges left -- m5 removed the node
            // in the middle of its chain -- so this builds one with edges to copy.
            GKGraphNode2D *e0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *e1 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 4}];
            [e0 addConnectionsToNodes:@[e1] bidirectional:YES];
            GKGraph *wired = [GKGraph graphWithNodes:@[e0, e1]];
            GKGraph *wiredCopy = [wired copy];
            GKGraphNode2D *copied0 = (GKGraphNode2D *)wiredCopy.nodes[0];
            GKGraphNode2D *copied1 = (GKGraphNode2D *)wiredCopy.nodes[1];
            BOOL edgesInside = [copied0 connectedNodes].count == 1 &&
                               [copied0 connectedNodes].firstObject == copied1 && copied1 != e1;
            host(edgesInside && near(copied0.position.x, 0) && near(copied0.position.y, 0) &&
                     near(copied1.position.x, 3) && near(copied1.position.y, 4),
                 @"m5 and a copy's nodes are at the positions the originals were at and their edges point at the "
                 @"COPY's own nodes, never at the original's -- measured on the host too, where the copy's first "
                 @"node's edge answers the copy's second node");
            GKGraph *nilNodes = [GKGraph graphWithNodes:nil];
            host(nilNodes.nodes.count == 0, @"m5 a graph built from nil holds no nodes");
            GKGraph *made = [[GKGraph alloc] init];
            host(made.nodes.count == 0, @"m5 -init gives a graph with no nodes");
        }

        // === m6: connectNodeToLowestCostNode: ======================================================
        {
            GKGraphNode2D *me = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            GKGraphNode2D *a = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraph *g = [GKGraph graphWithNodes:@[me, a, b]];
            [g connectNodeToLowestCostNode:me bidirectional:NO];
            host([me connectedNodes].count == 1 && [a connectedNodes].count == 0,
                 @"m6 it joins the node to the node of the graph whose cost from it is lowest -- the node at "
                 @"(5,0) is nearest to itself, so that is what it joins to");
            GKGraphNode2D *m2 = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            GKGraphNode2D *a2 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b2 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraph *g2 = [GKGraph graphWithNodes:@[m2, a2, b2]];
            [g2 connectNodeToLowestCostNode:m2 bidirectional:YES];
            host([m2 connectedNodes].count == 2 && [a2 connectedNodes].count == 0,
                 @"m6 the same, bidirectional: two edges out of the node it joined to and none back");
            GKGraphNode2D *outsider = [GKGraphNode2D nodeWithPoint:(vector_float2){7, 0}];
            [g2 connectNodeToLowestCostNode:outsider bidirectional:NO];
            host([outsider connectedNodes].count == 0, @"m6 a node the graph does not hold is left alone");
            GKGraph *empty = [GKGraph graphWithNodes:@[]];
            GKGraphNode2D *c = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            [empty connectNodeToLowestCostNode:c bidirectional:NO];
            host([c connectedNodes].count == 0, @"m6 a graph with no nodes leaves the node alone");
        }

        // === m7: the grid graph ===================================================================
        {
            GKGridGraph *g = [GKGridGraph graphFromGridStartingAt:(vector_int2){2, 3}
                                                             width:3 height:2 diagonalsAllowed:NO];
            host([g isMemberOfClass:[GKGridGraph class]] && g.gridWidth == 3 && g.gridHeight == 2 &&
                     g.gridOrigin.x == 2 && g.gridOrigin.y == 3 && !g.diagonalsAllowed && g.nodes.count == 6,
                 @"m7 the factory builds a grid of the width, height and origin it was given, one node per cell");
            GKGridGraphNode *corner = [g nodeAtGridPosition:(vector_int2){2, 3}];
            host([corner connectedNodes].count == 2,
                 @"m7 a corner of a 3x2 grid is joined to its two neighbours, so the grid is connected whole");
            host([g nodeAtGridPosition:(vector_int2){99, 99}] == nil, @"m7 a cell outside the grid answers nil");
            NSArray *walk = [g findPathFromNode:corner toNode:[g nodeAtGridPosition:(vector_int2){4, 4}]];
            host([printedCells(walk) isEqualToString:@" (2,3) (3,3) (3,4) (4,4)"],
                 @"m7 a path across the grid answers cells, start to end, both ends in it -- and it goes UP "
                 @"before it goes right, which is the tie the host's own ordering decides");

            GKGridGraph *diag = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0}
                                                               width:3 height:3 diagonalsAllowed:YES];
            GKGridGraphNode *origin = [diag nodeAtGridPosition:(vector_int2){0, 0}];
            host([origin connectedNodes].count == 3,
                 @"m7 with diagonals allowed a corner of a 3x3 grid has three neighbours, the diagonal included");
            NSArray *diagonal = [diag findPathFromNode:origin
                                                toNode:[diag nodeAtGridPosition:(vector_int2){1, 1}]];
            host([printedCells(diagonal) isEqualToString:@" (0,0) (1,1)"],
                 @"m7 and a diagonal grid walks the diagonal: two cells for the two that touch");
            NSString *generic = NSStringFromClass([diag classForGenericArgumentAtIndex:0]);
            host([generic isEqualToString:@"GKGridGraphNode"],
                 @"m7 the generic argument of a grid graph is its node class");

            GKGridGraph *solo = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0}
                                                               width:1 height:1 diagonalsAllowed:NO];
            GKGridGraphNode *onlyCell = [solo nodeAtGridPosition:(vector_int2){0, 0}];
            host(solo.nodes.count == 1 && [onlyCell connectedNodes].count == 0,
                 @"m7 a one-cell grid has one node and no edges");
            GKGridGraph *zero = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0}
                                                               width:0 height:0 diagonalsAllowed:NO];
            host(zero.nodes.count == 0 && zero.gridWidth == 0 && zero.gridHeight == 0,
                 @"m7 a grid of no cells has no nodes and a width and a height of nothing");
            [solo connectNodeToAdjacentNodes:onlyCell];
            host([onlyCell connectedNodes].count == 0,
                 @"m7 connecting a cell to its neighbours on a one-cell grid adds nothing");
            GKGridGraphNode *stranger = [GKGridGraphNode nodeWithGridPosition:(vector_int2){9, 9}];
            [solo connectNodeToAdjacentNodes:stranger];
            host([stranger connectedNodes].count == 0,
                 @"m7 and the same for a cell the grid does not hold");
            GKGridGraph *made = [[GKGridGraph alloc] init];
            host(made.nodes.count == 0, @"m7 -init gives a grid with no cells");

            GKGridGraph *typed = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0} width:2 height:2
                                                  diagonalsAllowed:NO
                                                            nodeClass:[GKGridGraphNode class]];
            GKGridGraphNode *typedCell = [typed nodeAtGridPosition:(vector_int2){0, 0}];
            NSString *typedNamed = NSStringFromClass([typed classForGenericArgumentAtIndex:0]);
            host([typedCell isMemberOfClass:[GKGridGraphNode class]] &&
                     [typedNamed isEqualToString:@"GKGridGraphNode"],
                 @"m7 the nodes are the class the caller named, and the generic argument answers it too");
        }

        // === m8: the obstacles and their archives ==================================================
        {
            GKCircleObstacle *circle = [GKCircleObstacle obstacleWithRadius:2.5f];
            host([circle isMemberOfClass:[GKCircleObstacle class]] && circle.radius == 2.5f &&
                     circle.position.x == 0 && circle.position.y == 0,
                 @"m8 the circle factory answers a circle with the radius it was given at the origin");
            circle.position = (vector_float2){4, 5};
            circle.radius = 7;
            host(circle.radius == 7 && circle.position.x == 4 && circle.position.y == 5,
                 @"m8 a radius and a position set afterwards are read back unchanged");
            GKCircleObstacle *made = [[GKCircleObstacle alloc] initWithRadius:3];
            host(made.radius == 3 && made.position.x == 0 && made.position.y == 0,
                 @"m8 the circle initialiser answers the radius it was given at the origin");
            host([(GKObstacle *)circle isKindOfClass:[GKObstacle class]], @"m8 a circle is a GKObstacle");
            host(raisedWith(^{
                     [[GKCircleObstacle alloc] init];
                 }, @"NSInternalInconsistencyException",
                     @"initWithRadius: is the destignated initialize for GKCircleObstacle.  Use that instead"),
                 @"m8 -init on a circle is refused with the host's own reason, spelling and all");

            vector_float2 square[4] = {{0, 0}, {4, 0}, {4, 4}, {0, 4}};
            GKPolygonObstacle *polygon = [GKPolygonObstacle obstacleWithPoints:square count:4];
            host([polygon isMemberOfClass:[GKPolygonObstacle class]] && polygon.vertexCount == 4 &&
                     [polygon conformsToProtocol:@protocol(NSSecureCoding)],
                 @"m8 the polygon factory answers a polygon with the four points it was given, and a polygon is "
                 @"securely codable");
            NSArray *vertices = four([polygon vertexAtIndex:0], [polygon vertexAtIndex:1],
                                     [polygon vertexAtIndex:2], [polygon vertexAtIndex:3]);
            host([printed(vertices) isEqualToString:@" (0,0) (4,0) (4,4) (0,4)"],
                 @"m8 each vertex answers the point that was given at that index, in order");
            vector_float2 past = [polygon vertexAtIndex:99];
            host(past.x == 0 && past.y == 0, @"m8 a vertex past the end answers the zero point");
            host([GKPolygonObstacle obstacleWithPoints:NULL count:0].vertexCount == 0,
                 @"m8 a polygon of no points has no vertices");
            host(raisedWith(^{
                     [[GKPolygonObstacle alloc] init];
                 }, @"NSInternalInconsistencyException",
                     @"initWithPoints: is the destignated initialize for GKPolygonObstacle.  Use that instead"),
                 @"m8 -init on a polygon is refused with the host's own reason");

            NSError *error = nil;
            NSData *polygonData = [NSKeyedArchiver archivedDataWithRootObject:polygon
                                                        requiringSecureCoding:YES error:&error];
            GKPolygonObstacle *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKPolygonObstacle class]
                                                                       fromData:polygonData error:&error];
            host(polygonData.length > 0 && error == nil && [back isMemberOfClass:[GKPolygonObstacle class]] &&
                     back.vertexCount == 4,
                 @"m8 a polygon survives an archive round trip with its four vertices");
            NSArray *decodedVertices = four([back vertexAtIndex:0], [back vertexAtIndex:1],
                                            [back vertexAtIndex:2], [back vertexAtIndex:3]);
            host([printed(decodedVertices) isEqualToString:@" (0,0) (4,0) (4,4) (0,4)"],
                 @"m8 and the vertices come back in the order they went in");

            GKGraphNode2D *e0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *e1 = [GKGraphNode2D nodeWithPoint:(vector_float2){4, 0}];
            [e0 addConnectionsToNodes:@[e1] bidirectional:YES];
            NSData *graphData = [NSKeyedArchiver archivedDataWithRootObject:[GKGraph graphWithNodes:@[e0, e1]]
                                                        requiringSecureCoding:YES error:&error];
            GKGraph *backGraph = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKGraph class]
                                                                    fromData:graphData error:&error];
            GKGraphNode2D *decoded0 = (GKGraphNode2D *)backGraph.nodes[0];
            GKGraphNode2D *decoded1 = (GKGraphNode2D *)backGraph.nodes[1];
            host(graphData.length > 0 && error == nil && [backGraph isMemberOfClass:[GKGraph class]] &&
                     backGraph.nodes.count == 2,
                 @"m8 a two-node graph survives an archive round trip with both of its nodes");
            host(decoded0.position.x == 0 && decoded0.position.y == 0 && decoded1.position.x == 4 &&
                     decoded1.position.y == 0,
                 @"m8 and each node comes back at the position it was encoded at");
            NSArray *decodedPath = [backGraph findPathFromNode:backGraph.nodes[0] toNode:backGraph.nodes[1]];
            host([decoded0 connectedNodes].count == 1 &&
                     [printedNodes(decodedPath) isEqualToString:@" (0,0) (4,0)"],
                 @"m8 and the edge between them survives, so the decoded graph is walkable");

            GKGridGraph *diag = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0} width:3 height:3
                                                   diagonalsAllowed:YES];
            NSData *gridData = [NSKeyedArchiver archivedDataWithRootObject:diag requiringSecureCoding:YES
                                                                       error:&error];
            GKGridGraph *backGrid = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKGridGraph class]
                                                                      fromData:gridData error:&error];
            GKGridGraphNode *backCell = [backGrid nodeAtGridPosition:(vector_int2){0, 0}];
            host([backGrid isMemberOfClass:[GKGridGraph class]] && backGrid.gridWidth == 3 &&
                     backGrid.gridHeight == 3 && backGrid.nodes.count == 9 &&
                     [backCell connectedNodes].count == 3,
                 @"m8 a diagonal 3x3 grid round trips with its shape and its corner's three edges");
            contract(backGrid.diagonalsAllowed,
                     @"contract: a decoded grid reports diagonalsAllowed as it was encoded. The host answers NO "
                     @"even for a grid built WITH diagonals while that grid's own (0,0) cell answers three edges "
                     @"(measure.m m8) -- a property that contradicts the graph it describes -- so this is held "
                     @"against the encoded value, not against the host's");
            GKGridGraph *plainGrid = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0} width:3 height:3
                                                       diagonalsAllowed:NO];
            NSData *plainData = [NSKeyedArchiver archivedDataWithRootObject:plainGrid
                                                        requiringSecureCoding:YES error:&error];
            GKGridGraph *backPlain = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKGridGraph class]
                                                                       fromData:plainData error:&error];
            GKGridGraphNode *plainCell = [backPlain nodeAtGridPosition:(vector_int2){0, 0}];
            host(!backPlain.diagonalsAllowed && [plainCell connectedNodes].count == 2,
                 @"m8 and a grid built without diagonals round trips without them");
        }

        // === m9: the path =========================================================================
        {
            vector_float2 pathPoints[4] = {{0, 0}, {1, 0}, {1, 1}, {0, 1}};
            GKPath *path = [GKPath pathWithPoints:pathPoints count:4 radius:2.5f cyclical:YES];
            host([path isMemberOfClass:[GKPath class]] && path.numPoints == 4 && path.radius == 2.5f &&
                     path.isCyclical,
                 @"m9 the factory answers a path with the four points, the radius and the winding it was given");
            NSArray *points = four([path pointAtIndex:0], [path pointAtIndex:1], [path pointAtIndex:2],
                                   [path pointAtIndex:3]);
            host([printed(points) isEqualToString:@" (0,0) (1,0) (1,1) (0,1)"],
                 @"m9 each point answers the point that was given at that index");
            NSArray *twos = two([path float2AtIndex:0], [path float2AtIndex:1]);
            host([printed(twos) isEqualToString:@" (0,0) (1,0)"],
                 @"m9 and the 2D accessor answers the same vector of a path of 2D points");
            vector_float2 past = [path pointAtIndex:99];
            host(past.x == 0 && past.y == 0, @"m9 a point past the end answers the zero vector");
            path.radius = 9;
            path.cyclical = NO;
            host(path.radius == 9 && !path.isCyclical, @"m9 a radius and a winding set afterwards are read back");

            GKGraphNode2D *a = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            GKPath *fromNodes = [GKPath pathWithGraphNodes:@[a, b] radius:1];
            host(fromNodes.numPoints == 2 && fromNodes.radius == 1 && !fromNodes.isCyclical,
                 @"m9 a path built from two nodes holds their two positions and the radius, and is not cyclical");
            NSArray *nodePoints = two([fromNodes pointAtIndex:0], [fromNodes pointAtIndex:1]);
            host([printed(nodePoints) isEqualToString:@" (0,0) (5,0)"],
                 @"m9 and answers them in the order the nodes were given");

            for (size_t count = 0; count <= 1; count++) {
                vector_float2 *given = pathPoints;
                size_t howMany = count;
                host(raisedWith(^{
                         [GKPath pathWithPoints:given count:howMany radius:1 cyclical:NO];
                     }, @"NSInternalInconsistencyException",
                         @"GKPathLessThanTwoPointsException: GKPaths MUST be initialized with 2 or more "
                         @"points.  Single point paths are not allowed"),
                     @"m9 a path of fewer than two points raises with the host's own reason");
            }
            for (NSUInteger count = 0; count <= 1; count++) {
                NSArray *given = count == 0 ? @[] : @[a];
                host(raisedWith(^{
                         [GKPath pathWithGraphNodes:given radius:1];
                     }, @"NSInternalInconsistencyException",
                         @"GKPath: must be initialized with 2 or more graph nodes.  Single node paths are not "
                         @"allowed"),
                     @"m9 a path of fewer than two nodes raises with the host's own other reason");
            }
            GKPath *made = [[GKPath alloc] init];
            host(made.numPoints == 0 && made.radius == 0 && !made.isCyclical,
                 @"m9 -init gives a path with no points, no radius and no winding");
        }

        // === m10: the 3D node and the sphere, the 10.0 half of the path =============================
        {
            GKSphereObstacle *sphere = [GKSphereObstacle obstacleWithRadius:1.5f];
            host([sphere isMemberOfClass:[GKSphereObstacle class]] && sphere.radius == 1.5f &&
                     sphere.position.x == 0 && sphere.position.y == 0 && sphere.position.z == 0,
                 @"m10 the sphere factory answers a sphere with the radius it was given at the origin");
            sphere.position = (vector_float3){1, 2, 3};
            host(sphere.position.x == 1 && sphere.position.y == 2 && sphere.position.z == 3,
                 @"m10 and a 3D position set afterwards is read back unchanged");
            host(raisedWith(^{
                     [[GKSphereObstacle alloc] init];
                 }, @"NSInternalInconsistencyException",
                     @"initWithRadius: is the destignated initialize for GKSphereObstacle.  Use that instead"),
                 @"m10 -init on a sphere is refused the way the circle's is");

            vector_float3 raised3[3] = {{0, 0, 1}, {2, 0, 3}, {2, 4, 5}};
            GKPath *three = [GKPath pathWithFloat3Points:raised3 count:3 radius:0.5f cyclical:NO];
            host([three isMemberOfClass:[GKPath class]] && three.numPoints == 3 && three.radius == 0.5f &&
                     !three.isCyclical,
                 @"m10 the 3D factory answers a path with the three 3D points and the radius it was given");
            vector_float3 first = [three float3AtIndex:0];
            vector_float3 second = [three float3AtIndex:1];
            host(first.x == 0 && first.y == 0 && first.z == 1 && second.x == 2 && second.y == 0 && second.z == 3,
                 @"m10 and the 3D accessor answers the 3D points as they were given");
            vector_float2 asTwo = [three float2AtIndex:0];
            vector_float2 deprecated = [three pointAtIndex:0];
            host(asTwo.x == 0 && asTwo.y == 1 && deprecated.x == 0 && deprecated.y == 1,
                 @"m10 and both 2D accessors of a 3D path answer the x and the z of its points, as the host does");
            vector_float3 *raised = raised3;
            host(raisedWith(^{
                     [GKPath pathWithFloat3Points:raised count:1 radius:1 cyclical:NO];
                 }, @"NSInternalInconsistencyException",
                     @"GKPathLessThanTwoPointsException: GKPaths MUST be initialized with 2 or more points.  "
                     @"Single point paths are not allowed"),
                 @"m10 a 3D path of one point raises the same reason a 2D one does");

            vector_float2 pathPoints[4] = {{0, 0}, {1, 0}, {1, 1}, {0, 1}};
            GKPath *flat = [GKPath pathWithPoints:pathPoints count:4 radius:1 cyclical:NO];
            vector_float3 lifted = [flat float3AtIndex:1];
            host(lifted.x == 1 && lifted.y == 0 && lifted.z == 0,
                 @"m10 a path of 2D points answers the 3D accessor with its own x and y and a zero z");
        }

        // === m11: the octree ======================================================================
        {
            GKBox outer = {{0, 0, 0}, {8, 8, 8}};
            GKOctree *tree = [GKOctree octreeWithBoundingBox:outer minimumCellSize:2];
            GKOctreeNode *first = [tree addElement:@"a" withPoint:(vector_float3){1.9f, 1.9f, 1.9f}];
            host(first.box.boxMin.x == 0 && first.box.boxMin.y == 0 && first.box.boxMin.z == 0 &&
                     first.box.boxMax.x == 2 && first.box.boxMax.y == 2 && first.box.boxMax.z == 2,
                 @"m11 a minimum cell size of 2 files (1.9,1.9,1.9) in the cell 0..2 on all three axes");
            GKOctree *fine = [GKOctree octreeWithBoundingBox:outer minimumCellSize:1];
            GKOctreeNode *finer = [fine addElement:@"b" withPoint:(vector_float3){5.5f, 5.5f, 5.5f}];
            host(finer.box.boxMin.x == 5 && finer.box.boxMax.x == 6,
                 @"m11 a minimum cell size of 1 files (5.5,5.5,5.5) in the cell 5..6");
            GKOctree *wide = [GKOctree octreeWithBoundingBox:outer minimumCellSize:3];
            GKOctreeNode *wider = [wide addElement:@"c" withPoint:(vector_float3){7.9f, 7.9f, 7.9f}];
            host(wider.box.boxMin.x == 4 && wider.box.boxMax.x == 8,
                 @"m11 a minimum cell size of 3 files (7.9,7.9,7.9) in the cell 4..8, clipped to the box -- the "
                 @"tree halves, so 3 settles on 4");
            GKOctree *tiny = [GKOctree octreeWithBoundingBox:outer minimumCellSize:0.5f];
            GKOctreeNode *tinier = [tiny addElement:@"d" withPoint:(vector_float3){3.3f, 0, 0}];
            host(tinier.box.boxMin.x == 3 && tinier.box.boxMax.x == 3.5f,
                 @"m11 a minimum cell size of 0.5 files (3.3,0,0) in the cell 3..3.5");
            NSArray *inside = [tree elementsAtPoint:(vector_float3){1.1f, 1.1f, 1.1f}];
            NSArray *outside = [tree elementsAtPoint:(vector_float3){4, 4, 4}];
            host([printedNames(inside) isEqualToString:@" a"] &&
                     [printedNames(outside) isEqualToString:@""],
                 @"m11 a point element is answered for the whole of its cell, so (1.1,1.1,1.1) finds the element "
                 @"added at (1.9,1.9,1.9) and (4,4,4) finds nothing");

            GKOctree *boxed = [GKOctree octreeWithBoundingBox:outer minimumCellSize:2];
            GKOctreeNode *boxNode = [boxed addElement:@"box" withBox:(GKBox){{3, 0, 0}, {5, 2, 2}}];
            host(near(boxNode.box.boxMin.x, 0) && near(boxNode.box.boxMax.x, 4),
                 @"m11 a box element is filed in the NODE one level above the cell of its low corner, and that "
                 @"node is what the method hands back: a low corner at 3 in a tree of minimum cell size 2 is "
                 @"in the cell 2..4, so the node is 0..4");
            // -elementsAtPoint: NEVER answers a box element. Measured on the host over a dense sweep of 256
            // points from (0,0,0) to (7.5,7.5,7.5) -- every one of them inside the box -- at cell sizes 1,
            // 2 and 4: all of them empty. A point element at (1,1,1) in the same tree IS answered.
            NSArray *insideBox = [boxed elementsAtPoint:(vector_float3){1.5f, 1.5f, 1.5f}];
            NSArray *onBox = [boxed elementsAtPoint:(vector_float3){3.5f, 1, 1}];
            NSArray *farFromBox = [boxed elementsAtPoint:(vector_float3){7, 7, 7}];
            host([printedNames(insideBox) isEqualToString:@""] &&
                     [printedNames(onBox) isEqualToString:@""] &&
                     [printedNames(farFromBox) isEqualToString:@""],
                 @"m11 -elementsAtPoint: never answers a box element: one added at (3,0,0)-(5,2,2) in a tree "
                 @"of minimum cell size 2 is answered at nothing, inside the box, on its far edge or away from "
                 @"it -- measured over a 256-point sweep of the whole box at cell sizes 1, 2 and 4");
            GKOctree *pointBeside = [GKOctree octreeWithBoundingBox:outer minimumCellSize:2];
            [pointBeside addElement:@"p" withPoint:(vector_float3){1, 1, 1}];
            NSArray *pointAnswered = [pointBeside elementsAtPoint:(vector_float3){1.5f, 1.5f, 1.5f}];
            host([printedNames(pointAnswered) isEqualToString:@" p"],
                 @"m11 while a POINT element in the same tree is answered from its cell -- so the two kinds "
                 @"are kept apart and this is the branch that keeps them apart");
            // -elementsInBox: answers a box element where its OWN box meets the query. The node it is filed
            // in is one level above the cell, and its own -box answers that NODE: measured, a box element at
            // (1,1,1)-(2,2,2) in a tree of minimum cell size 2 hands back a node of 0..4.
            GKOctree *lifted = [GKOctree octreeWithBoundingBox:outer minimumCellSize:2];
            GKOctreeNode *liftedNode = [lifted addElement:@"box" withBox:(GKBox){{1, 1, 1}, {2, 2, 2}}];
            host(near(liftedNode.box.boxMin.x, 0) && near(liftedNode.box.boxMax.x, 4),
                 @"m11 and the node a box element is filed in is one level above the cell: (1,1,1) in a tree "
                 @"of minimum cell size 2 hands back the node 0..4, which is why the host's answer for a box "
                 @"is a NODE's and not the box's");
            NSArray *meets = [lifted elementsInBox:(GKBox){{0, 0, 0}, {4, 4, 4}}];
            NSArray *doesNotMeet = [lifted elementsInBox:(GKBox){{4, 4, 4}, {8, 8, 8}}];
            host([printedNames(meets) isEqualToString:@" box"] &&
                     [printedNames(doesNotMeet) isEqualToString:@""],
                 @"m11 and -elementsInBox: answers it where the box meets the query and not where the node is, "
                 @"which is its own extent rather than the node it is filed in");

            GKOctree *pair = [GKOctree octreeWithBoundingBox:outer minimumCellSize:2];
            [pair addElement:@"p" withPoint:(vector_float3){0.1f, 0.1f, 0.1f}];
            [pair addElement:@"q" withPoint:(vector_float3){1.9f, 1.9f, 1.9f}];
            NSArray *both = [pair elementsAtPoint:(vector_float3){0.5f, 0.5f, 0.5f}];
            host([printedNames(both) isEqualToString:@" p q"],
                 @"m11 two elements in one cell are answered in the order they were added");
            NSArray *farEdge = [pair elementsAtPoint:(vector_float3){2, 0, 0}];
            host([printedNames(farEdge) isEqualToString:@""],
                 @"m11 and a point on the far edge of a cell is in the next cell, which is empty");
            BOOL once = [pair removeElement:@"p"];
            BOOL twice = [pair removeElement:@"p"];
            BOOL absent = [pair removeElement:@"absent"];
            host(once && !twice && !absent,
                 @"m11 removal answers YES once and NO after that, and NO for an element never there");
            NSArray *afterRemoval = [pair elementsAtPoint:(vector_float3){0.5f, 0.5f, 0.5f}];
            host([printedNames(afterRemoval) isEqualToString:@" q"], @"m11 and the removed element is gone");
            GKOctreeNode *held = [pair addElement:@"r" withPoint:(vector_float3){0.5f, 0.5f, 0.5f}];
            BOOL byNode = [pair removeElement:@"r" withNode:held];
            NSArray *afterByNode = [pair elementsAtPoint:(vector_float3){0.5f, 0.5f, 0.5f}];
            host(byNode && [printedNames(afterByNode) isEqualToString:@" q"],
                 @"m11 removal with the node the element was filed in takes it out");
        }

        // === m12: the quadtree ====================================================================
        {
            GKQuad outer = {{0, 0}, {8, 8}};
            GKQuadtree *tree = [GKQuadtree quadtreeWithBoundingQuad:outer minimumCellSize:2];
            GKQuadtreeNode *node = [tree addElement:@"p" withPoint:(vector_float2){1.1f, 1.1f}];
            contract(node.quad.quadMin.x == 0 && node.quad.quadMin.y == 0 && node.quad.quadMax.x == 2 &&
                         node.quad.quadMax.y == 2,
                     @"contract: a quadtree node answers the cell its element was filed in, as "
                     @"GKQuadtree.h:11-12 says. The host answers the ZERO quad for every node of every tree tried "
                     @"(measure.m m12), which describes no region at all, so this is held against the header "
                     @"rather than against a host number");
            NSArray *inQuad = [tree elementsInQuad:(GKQuad){{0, 0}, {4, 4}}];
            host([printedNames(inQuad) isEqualToString:@" p"],
                 @"m12 a point element is answered by a quad of cells that meets the one asked for");

            GKQuadtree *quads = [GKQuadtree quadtreeWithBoundingQuad:outer minimumCellSize:2];
            [quads addElement:@"y" withQuad:(GKQuad){{3, 3}, {5, 5}}];
            // The coordinator's table, measured: bounding quad (0,0)-(8,8), minimumCellSize 1, one quad
            // element at (1,1)-(2,2). The answer follows the NODE, not the element's extent -- (0.5,0.5) and
            // (0,0) are outside the quad and are answered, (2.5,2.5) is inside its bounding node and is not.
            GKQuadtree *one = [GKQuadtree quadtreeWithBoundingQuad:outer minimumCellSize:1];
            [one addElement:@"box" withQuad:(GKQuad){{1, 1}, {2, 2}}];
            struct { float x, y; BOOL found; } probes[] = {
                {1.5f, 1.5f, YES}, {0.5f, 0.5f, YES}, {0, 0, YES}, {1, 1, YES},
                {2.5f, 2.5f, NO},  {3, 3, NO},     {1.5f, 3.5f, NO}, {3.5f, 1.5f, NO},
                {6, 6, NO},        {4, 4, NO},     {7.9f, 0.1f, NO}, {2, 2, NO},
            };
            BOOL pointsAgree = YES;
            for (unsigned index = 0; index < sizeof(probes) / sizeof(probes[0]); index++) {
                BOOL found = [one elementsAtPoint:(vector_float2){probes[index].x, probes[index].y}].count > 0;
                if (found != probes[index].found) {
                    pointsAgree = NO;
                }
            }
            host(pointsAgree,
                 @"m12 -elementsAtPoint: answers the quad elements of the NODE the point falls in, as "
                 @"GKQuadtree.h:61 says -- a quad at (1,1)-(2,2) in a tree of minimum cell size 1 is answered "
                 @"at (1.5,1.5), (0.5,0.5), (0,0) and (1,1), which includes points OUTSIDE its own extent, and "
                 @"at (2.5,2.5), (3,3), (1.5,3.5), (3.5,1.5), (6,6), (4,4), (7.9,0.1) and (2,2), which are "
                 @"not: the answer is the node's, not the quad's");
            struct { float lo, hi; BOOL found; } asked[] = {
                {0, 0.5f, YES}, {3, 4, NO}, {0, 4, YES}, {2.5f, 0, NO}, {1.2f, 1.8f, YES},
            };
            BOOL quadsAgree = YES;
            for (unsigned index = 0; index < 5; index++) {
                float lo = asked[index].lo, hi = asked[index].hi;
                GKQuadtree *fresh = [GKQuadtree quadtreeWithBoundingQuad:outer minimumCellSize:1];
                [fresh addElement:@"box" withQuad:(GKQuad){{1, 1}, {2, 2}}];
                BOOL found = [fresh elementsInQuad:(GKQuad){{lo, lo}, {hi, hi}}].count > 0;
                if (found != asked[index].found) {
                    quadsAgree = NO;
                }
            }
            host(quadsAgree,
                 @"m12 and -elementsInQuad: answers the elements whose NODE meets the quad, as GKQuadtree.h:69 "
                 @"says -- the same quad element is answered for (0,0)-(0.5,0.5), which is nowhere near it, "
                 @"and for (1.2,1.2)-(1.8,1.8), and not for (3,3)-(4,4) or (2.5,0)-(4,1)");
            GKQuadtree *justPoint = [GKQuadtree quadtreeWithBoundingQuad:outer minimumCellSize:1];
            [justPoint addElement:@"p" withPoint:(vector_float2){1, 1}];
            NSArray *pointNever = [justPoint elementsAtPoint:(vector_float2){1.5f, 1.5f}];
            NSArray *pointInQuad = [justPoint elementsInQuad:(GKQuad){{0, 0}, {2, 2}}];
            host([printedNames(pointNever) isEqualToString:@""] &&
                     [printedNames(pointInQuad) isEqualToString:@" p"],
                 @"m12 and the two queries are not symmetric on the host: a POINT element is in "
                 @"-elementsInQuad:'s answer and in NOBODY's -elementsAtPoint: answer, at any point and any "
                 @"cell size -- measured, a point element at (1,1) answers nothing of a 256-point sweep");
            BOOL once = [quads removeElement:@"y"];
            BOOL twice = [quads removeElement:@"y"];
            host(once && !twice, @"m12 removal answers YES once and NO after that");
        }

        // === m13: the R-tree ======================================================================
        {
            GKRTree *tree = [GKRTree treeWithMaxNumberOfChildren:2];
            host([tree isMemberOfClass:[GKRTree class]] && tree.queryReserve == 1,
                 @"m13 the factory answers an R-tree whose query reserve is one");
            [tree addElement:@"a" boundingRectMin:(vector_float2){0, 0} boundingRectMax:(vector_float2){1, 1}
                               splitStrategy:GKRTreeSplitStrategyHalve];
            [tree addElement:@"b" boundingRectMin:(vector_float2){2, 2} boundingRectMax:(vector_float2){3, 3}
                               splitStrategy:GKRTreeSplitStrategyHalve];
            NSArray *firstRect = [tree elementsInBoundingRectMin:(vector_float2){0, 0}
                                                        rectMax:(vector_float2){1, 1}];
            NSArray *secondRect = [tree elementsInBoundingRectMin:(vector_float2){2, 2}
                                                         rectMax:(vector_float2){3, 3}];
            NSArray *bothRects = [tree elementsInBoundingRectMin:(vector_float2){0, 0}
                                                         rectMax:(vector_float2){3, 3}];
            NSArray *neither = [tree elementsInBoundingRectMin:(vector_float2){9, 9}
                                                       rectMax:(vector_float2){10, 10}];
            NSArray *halfOverFirst = [tree elementsInBoundingRectMin:(vector_float2){0.5f, 0.5f}
                                                           rectMax:(vector_float2){3, 3}];
            NSArray *overBoth = [tree elementsInBoundingRectMin:(vector_float2){0, 0}
                                                       rectMax:(vector_float2){1.5f, 1.5f}];
            host([printedNames(firstRect) isEqualToString:@" a"] &&
                     [printedNames(secondRect) isEqualToString:@" b"] &&
                     [printedNames(bothRects) isEqualToString:@" a b"] &&
                     [printedNames(neither) isEqualToString:@""] &&
                     [printedNames(halfOverFirst) isEqualToString:@" b"] &&
                     [printedNames(overBoth) isEqualToString:@" a"],
                 @"m13 a query answers the elements wholly INSIDE the rectangle asked for and not the ones that "
                 @"overlap it -- a query over (0.5,0.5)-(3,3) answers the element at (2,2)-(3,3) alone although "
                 @"the element at (0,0)-(1,1) overlaps it, and a query over (0,0)-(1.5,1.5) answers the other "
                 @"alone. That is what GKRTree.h:20 asks for");
            host(tree.queryReserve == 1, @"m13 adding elements does not change the query reserve");
            [tree removeElement:@"a" boundingRectMin:(vector_float2){0, 0}
                                   boundingRectMax:(vector_float2){1, 1}];
            NSArray *afterRemoval = [tree elementsInBoundingRectMin:(vector_float2){0, 0}
                                                           rectMax:(vector_float2){3, 3}];
            host([printedNames(afterRemoval) isEqualToString:@" b"], @"m13 and a removed element is gone");
            tree.queryReserve = 99;
            host(tree.queryReserve == 1,
                 @"m13 -setQueryReserve: changes nothing and -queryReserve keeps answering one, which is what "
                 @"the host does -- the port does not keep a value the host would not read back");

            GKRTree *six = [GKRTree treeWithMaxNumberOfChildren:2];
            for (int index = 0; index < 6; index++) {
                [six addElement:[NSString stringWithFormat:@"e%d", index]
               boundingRectMin:(vector_float2){index, index}
               boundingRectMax:(vector_float2){index + 0.5f, index + 0.5f}
                splitStrategy:GKRTreeSplitStrategyHalve];
            }
            NSArray *allSix = [six elementsInBoundingRectMin:(vector_float2){0, 0}
                                                     rectMax:(vector_float2){9, 9}];
            NSArray *firstTwo = [six elementsInBoundingRectMin:(vector_float2){0, 0}
                                                       rectMax:(vector_float2){1.4f, 1.4f}];
            NSArray *firstSix = [six elementsInBoundingRectMin:(vector_float2){0, 0}
                                                       rectMax:(vector_float2){6, 6}];
            host([printedNames(allSix) isEqualToString:@" e0 e1 e2 e3 e4 e5"] &&
                     [printedNames(firstTwo) isEqualToString:@" e0"] &&
                     [printedNames(firstSix) isEqualToString:@" e0 e1 e2 e3 e4 e5"],
                 @"m13 six elements answer in the order they were added, and a rectangle answers exactly the "
                 @"elements it wholly holds");
        }

        // === m14: the mesh graph ==================================================================
        {
            vector_float2 square[4] = {{3, 3}, {7, 3}, {7, 7}, {3, 7}};
            GKPolygonObstacle *obstacle = [GKPolygonObstacle obstacleWithPoints:square count:4];
            GKMeshGraph *mesh = [GKMeshGraph graphWithBufferRadius:0
                                                    minCoordinate:(vector_float2){0, 0}
                                                    maxCoordinate:(vector_float2){10, 10}];
            host([mesh isMemberOfClass:[GKMeshGraph class]] && mesh.bufferRadius == 0 &&
                     mesh.obstacles.count == 0 &&
                     mesh.triangulationMode == GKMeshGraphTriangulationModeVertices,
                 @"m14 a fresh mesh graph answers no obstacles, the buffer radius it was given, and the vertex "
                 @"triangulation mode");
            host([mesh classForGenericArgumentAtIndex:0] == [GKGraphNode2D class],
                 @"m14 and the generic argument of a mesh graph is GKGraphNode2D");
            [mesh addObstacles:@[obstacle]];
            host(mesh.obstacles.count == 1, @"m14 an obstacle added is in the answer");
            [mesh triangulate];
            host(mesh.triangleCount > 0 && mesh.nodes.count > 0,
                 @"m14 triangulating cuts the free space of the rectangle into triangles with a node at each "
                 @"corner");
            GKTriangle firstTriangle = [mesh triangleAtIndex:0];
            host(firstTriangle.points[0].z == 0 && firstTriangle.points[1].z == 0 &&
                     firstTriangle.points[2].z == 0,
                 @"m14 every triangle's points are in the plane the mesh was built in");
            host([mesh triangleAtIndex:999].points[0].x == 0,
                 @"m14 a triangle past the end answers the zero triangle");

            NSUInteger withVertices = mesh.nodes.count;
            mesh.triangulationMode = GKMeshGraphTriangulationModeCenters;
            [mesh triangulate];
            NSUInteger withCentres = mesh.nodes.count;
            mesh.triangulationMode = GKMeshGraphTriangulationModeEdgeMidpoints;
            [mesh triangulate];
            NSUInteger withMidpoints = mesh.nodes.count;
            mesh.triangulationMode = GKMeshGraphTriangulationModeVertices |
                                     GKMeshGraphTriangulationModeCenters |
                                     GKMeshGraphTriangulationModeEdgeMidpoints;
            [mesh triangulate];
            NSUInteger withAll = mesh.nodes.count;
            host(withCentres < withVertices && withMidpoints > withCentres &&
                     withAll == withVertices + withCentres + withMidpoints,
                 @"m14 the vertex mode puts a node at every corner, the centre mode one at the middle of every "
                 @"triangle, the edge-midpoint mode one at the middle of every side, and all three together the "
                 @"sum of the three -- the host's own ratios for the same rectangle are 4, 2, 5 and 11");

            [mesh removeObstacles:@[obstacle]];
            host(mesh.obstacles.count == 0, @"m14 and a removed obstacle is gone");
            [mesh addObstacles:@[]];
            host(mesh.obstacles.count == 0, @"m14 adding no obstacles adds none");

            GKMeshGraph *open = [GKMeshGraph graphWithBufferRadius:0
                                                   minCoordinate:(vector_float2){0, 0}
                                                   maxCoordinate:(vector_float2){10, 10}];
            [open triangulate];
            host(open.triangleCount == 2 && open.nodes.count == 4,
                 @"m14 a rectangle with nothing in it is two triangles and four corners, which is what the host "
                 @"answers for the same rectangle");
            NSMutableSet *corners = [NSMutableSet set];
            for (GKGraphNode2D *node in open.nodes) {
                [corners addObject:[NSString stringWithFormat:@"%g,%g", node.position.x, node.position.y]];
            }
            host([corners containsObject:@"0,10"] && [corners containsObject:@"10,0"] &&
                     [corners containsObject:@"10,10"] && [corners containsObject:@"0,0"] &&
                     [corners count] == 4,
                 @"m14 and the four of them are the rectangle's corners, in the host's own order");
        }

        // === m15: the obstacle graph ===============================================================
        {
            vector_float2 wall[4] = {{4, -2}, {4, 2}, {4, 2}, {4, -2}};
            GKPolygonObstacle *obstacle = [GKPolygonObstacle obstacleWithPoints:wall count:4];
            GKObstacleGraph *graph = [GKObstacleGraph graphWithObstacles:@[obstacle] bufferRadius:1];
            host([graph isMemberOfClass:[GKObstacleGraph class]] && graph.obstacles.count == 1 &&
                     graph.bufferRadius == 1,
                 @"m15 the factory answers a graph with the one obstacle and the buffer radius it was given");
            host([graph classForGenericArgumentAtIndex:0] == [GKGraphNode2D class],
                 @"m15 and the generic argument is GKGraphNode2D");
            host(graph.nodes.count == obstacle.vertexCount,
                 @"m15 an obstacle graph files one node per obstacle vertex, so a wall given as four points "
                 @"answers four nodes -- the host's count, which is well defined at every buffer radius tried");
            BOOL placed = YES;
            for (GKGraphNode2D *node in graph.nodes) {
                if (isnan(node.position.x) || isnan(node.position.y)) {
                    placed = NO;
                }
            }
            contract(placed,
                     @"contract: every node of an obstacle graph answers a real position. The host answers NaN "
                     @"for all four of a wall's nodes and for seven of eight for two walls, at buffer radii 0, "
                     @"1 and 2 alike (measure.m m15), and the same for a node joined by "
                     @"-connectNodeUsingObstacles: -- a node that cannot say where it is describes nothing, and "
                     @"a path walked through the graph would be walked through points that are not numbers");
            host([[graph nodesForObstacle:obstacle] count] == obstacle.vertexCount,
                 @"m15 -nodesForObstacle: answers the corners of the obstacle named");

            vector_float2 farPoints[4] = {{20, 0}, {22, 0}, {22, 2}, {20, 0}};
            GKPolygonObstacle *far = [GKPolygonObstacle obstacleWithPoints:farPoints count:4];
            [graph addObstacles:@[far]];
            host(graph.obstacles.count == 2 && graph.nodes.count == 8,
                 @"m15 adding an obstacle re-scans: two obstacles of four vertices are eight nodes, four and "
                 @"four and not six, so the first obstacle's four are the same four");
            [graph removeObstacles:@[far]];
            host(graph.obstacles.count == 1, @"m15 and removing it takes it back out");
            [graph removeAllObstacles];
            host(graph.obstacles.count == 0 && graph.nodes.count == 0,
                 @"m15 -removeAllObstacles takes every obstacle and every node out");

            host(raisedWith(^{
                     [GKObstacleGraph graphWithObstacles:@[obstacle] bufferRadius:1
                                              nodeClass:[GKGraphNode3D class]];
                 }, @"NSInternalInconsistencyException",
                     @"initWithObstacles: nodeClass does not descend from GKGraphNode2D"),
                 @"m15 a node class that is not a GKGraphNode2D is refused with the host's own reason, because "
                 @"GKObstacleGraph.h:15 declares the class as GKGraphNode2D");

            GKObstacleGraph *walls = [GKObstacleGraph graphWithObstacles:@[obstacle] bufferRadius:1];
            NSArray *corners = walls.nodes;
            host(corners.count == 4, @"m15 one wall gives the four corners it was filed over");
            GKGraphNode2D *firstCorner = (GKGraphNode2D *)[corners objectAtIndex:0];
            GKGraphNode2D *lastCorner = (GKGraphNode2D *)[corners objectAtIndex:3];
            host([firstCorner connectedNodes].count > 0,
                 @"m15 and the corners are joined to the ones they can see");
            [walls lockConnectionFromNode:firstCorner toNode:lastCorner];
            host([walls isConnectionLockedFromNode:firstCorner toNode:lastCorner],
                 @"m15 a locked pair answers YES from -isConnectionLockedFromNode:toNode:");
            [walls unlockConnectionFromNode:firstCorner toNode:lastCorner];
            host(![walls isConnectionLockedFromNode:firstCorner toNode:lastCorner],
                 @"m15 and unlocking it answers NO");
            GKGraphNode2D *caller = [GKGraphNode2D nodeWithPoint:(vector_float2){-5, -5}];
            [walls connectNodeUsingObstacles:caller];
            host([caller connectedNodes].count > 0,
                 @"m15 -connectNodeUsingObstacles: joins a node of the caller's own to the corners it can see");
            GKGraphNode2D *withIgnored = [GKGraphNode2D nodeWithPoint:(vector_float2){-5, -5}];
            [walls connectNodeUsingObstacles:withIgnored ignoringObstacles:@[obstacle]];
            host([withIgnored connectedNodes].count > 0,
                 @"m15 the variant that names obstacles to ignore still joins what is left");
            GKGraphNode2D *noBuffer = [GKGraphNode2D nodeWithPoint:(vector_float2){-5, -5}];
            [walls connectNodeUsingObstacles:noBuffer ignoringBufferRadiusOfObstacles:@[obstacle]];
            host([noBuffer connectedNodes].count > 0,
                 @"m15 and so does the variant that drops the buffer of the obstacles named");

            // The other half of the visibility test, and the half a mutation of it would break: a CLOSED
            // obstacle really does cut the graph. A square at (4,-4)-(8,4) with a node on either side of it,
            // measured on the host: the two sides answer no edges at all between them and cannot see each
            // other, while a node near the square on one side is joined to the three corners it can see. A
            // visibility graph whose test always passed would answer "they can see each other" here.
            vector_float2 blockPoints[4] = {{4, -4}, {8, -4}, {8, 4}, {4, 4}};
            GKPolygonObstacle *block = [GKPolygonObstacle obstacleWithPoints:blockPoints count:4];
            GKObstacleGraph *cut = [GKObstacleGraph graphWithObstacles:@[block] bufferRadius:0];
            host(cut.nodes.count == 4, @"m15 a closed square of four points answers four nodes");
            GKGraphNode2D *left = [GKGraphNode2D nodeWithPoint:(vector_float2){-5, 0}];
            GKGraphNode2D *right = [GKGraphNode2D nodeWithPoint:(vector_float2){13, 0}];
            [cut addNodes:@[left, right]];
            [cut connectNodeUsingObstacles:left];
            [cut connectNodeUsingObstacles:right];
            BOOL theySeeEachOther = NO;
            for (GKGraphNode *edge in [left connectedNodes]) {
                if ([[right connectedNodes] indexOfObjectIdenticalTo:edge] != NSNotFound) {
                    theySeeEachOther = YES;
                }
            }
            host(!theySeeEachOther,
                 @"m15 and an obstacle CUTS the graph: two nodes on either side of a closed square cannot see "
                 @"each other and answer no common edge at all -- measured, both answer zero edges on the "
                 @"obstacle and the host's own scan puts a corner a thousandth of a unit out from each vertex");
            GKGraphNode2D *near = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            [cut connectNodeUsingObstacles:near];
            host([near connectedNodes].count == 3,
                 @"m15 while a node on one side of the same square is joined to the three corners it can see -- "
                 @"so the cut is the obstacle's doing and not the graph refusing to connect anything");
        }

        printf("checks=%d failures=%d\n", checksRun, checksFailed);
    }
    return checksFailed == 0 ? 0 : 1;
}