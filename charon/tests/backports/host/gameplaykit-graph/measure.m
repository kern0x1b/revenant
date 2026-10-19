// measure.m -- what the host's own GameplayKit answers for the pathfinding graphs.
//
// The host is the oracle and it is measured, not called: the port's classes and the host's have the same
// names, so loading both into one process would answer one of the two for the other. Every number in
// differential.m is one of the lines printed here, and each line says the call it came from. Run by
// run.sh, which also prints this file's output beside the checks.
//
// One of the calls on the host TRAPS rather than answering -- -[GKGraphNode findPathFromNode:] raises
// SIGBUS inside GameplayKit on every input tried, including a node asked for a path to itself and a node
// in no graph at all (m4 below). That is the host's own behaviour, recorded rather than worked around,
// and it is why -findPathFromNode: is held here against what the header says it does rather than against
// a host number: it is the one member of this family with no host answer to compare against.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>

static void path(const char *tag, NSArray *answer)
{
    printf("%s: count=%lu [", tag, (unsigned long)answer.count);
    for (GKGraphNode *node in answer) {
        if ([node isKindOfClass:[GKGridGraphNode class]]) {
            vector_int2 cell = ((GKGridGraphNode *)node).gridPosition;
            printf(" (%d,%d)", cell.x, cell.y);
        } else if ([node isKindOfClass:[GKGraphNode2D class]]) {
            vector_float2 point = ((GKGraphNode2D *)node).position;
            printf(" (%g,%g)", point.x, point.y);
        } else {
            printf(" ?");
        }
    }
    printf(" ]\n");
}

static void edges(const char *tag, GKGraphNode *node)
{
    printf("%s: %lu [", tag, (unsigned long)node.connectedNodes.count);
    for (GKGraphNode *other in node.connectedNodes) {
        GKGraphNode2D *point = (GKGraphNode2D *)other;
        printf(" (%g,%g)", point.position.x, point.position.y);
    }
    printf(" ]\n");
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        printf("== m1: the nodes and their costs\n");
        {
            GKGraphNode2D *a = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 4}];
            printf("m1 node2d factory: class=%s pos=%g,%g\n", class_getName([a class]), a.position.x, a.position.y);
            printf("m1 cost a->b=%g estimated a->b=%g\n", [a costToNode:b], [a estimatedCostToNode:b]);
            a.position = (vector_float2){9, 8};
            printf("m1 node2d set: pos=%g,%g cost a->b=%g\n", a.position.x, a.position.y, [a costToNode:b]);
            printf("m1 fresh connected=%lu\n", (unsigned long)a.connectedNodes.count);
            GKGraphNode3D *t = [GKGraphNode3D nodeWithPoint:(vector_float3){0, 0, 0}];
            GKGraphNode3D *u = [GKGraphNode3D nodeWithPoint:(vector_float3){1, 2, 2}];
            printf("m1 node3d factory: class=%s cost=%g estimated=%g\n", class_getName([t class]),
                   [t costToNode:u], [t estimatedCostToNode:u]);
            GKGraphNode *plain = [GKGraphNode new];
            printf("m1 plain node: class=%s cost=%g estimated=%g\n", class_getName([plain class]),
                   [plain costToNode:[GKGraphNode new]], [plain estimatedCostToNode:[GKGraphNode new]]);
            GKGridGraphNode *c = [GKGridGraphNode nodeWithGridPosition:(vector_int2){0, 0}];
            GKGridGraphNode *d = [GKGridGraphNode nodeWithGridPosition:(vector_int2){1, 1}];
            printf("m1 gridnode factory: class=%s cost=%g estimated=%g\n", class_getName([c class]),
                   [c costToNode:d], [c estimatedCostToNode:d]);
            GKGridGraphNode *e = [GKGridGraphNode nodeWithGridPosition:(vector_int2){2, 3}];
            printf("m1 gridnode (2,3)->(1,1)=%g\n", [e costToNode:[GKGridGraphNode nodeWithGridPosition:(vector_int2){1, 1}]]);
            GKGridGraphNode *plainInit = [[GKGridGraphNode alloc] init];
            printf("m1 gridnode -init: gp=%d,%d\n", plainInit.gridPosition.x, plainInit.gridPosition.y);
            GKGraphNode2D *plain2d = [[GKGraphNode2D alloc] init];
            printf("m1 node2d -init: pos=%g,%g\n", plain2d.position.x, plain2d.position.y);
        }

        printf("== m2: the edges\n");
        {
            GKGraphNode2D *n0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *n1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *n2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            GKGraphNode2D *n3 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 0}];
            edges("m2 n0 fresh", n0);
            [n0 addConnectionsToNodes:@[n1, n2] bidirectional:NO];
            edges("m2 n0 -> n1,n2 one way", n0);
            [n0 addConnectionsToNodes:@[n1, n2] bidirectional:NO];
            edges("m2 n0 -> n1,n2 again", n0);
            [n0 addConnectionsToNodes:@[n1] bidirectional:YES];
            edges("m2 n0 -> n1 bidirectional", n0);
            edges("m2 n1", n1);
            printf("m2 cost n0->n3 not connected=%g\n", [n0 costToNode:n3]);
            [n0 removeConnectionsToNodes:@[n1, n3] bidirectional:YES];
            edges("m2 n0 after remove n1,n3 both ways", n0);
            edges("m2 n1 after", n1);
            [n0 removeConnectionsToNodes:@[n1] bidirectional:YES];
            edges("m2 n0 after remove n1 again", n0);
            [n0 addConnectionsToNodes:nil bidirectional:NO];
            edges("m2 n0 after adding nil", n0);
            GKGraphNode2D *self = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            [self addConnectionsToNodes:@[self] bidirectional:YES];
            edges("m2 self edge both ways", self);
        }

        printf("== m3: the finds\n");
        {
            GKGraphNode2D *q0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *q1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *q2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            GKGraphNode2D *q3 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 0}];
            [q0 addConnectionsToNodes:@[q1] bidirectional:YES];
            [q1 addConnectionsToNodes:@[q2] bidirectional:YES];
            [q2 addConnectionsToNodes:@[q3] bidirectional:YES];
            path("m3 q0 findPathToNode:q3", [q0 findPathToNode:q3]);
            path("m3 q3 findPathToNode:q0", [q3 findPathToNode:q0]);
            path("m3 q0 findPathToNode:q0", [q0 findPathToNode:q0]);
            GKGraphNode2D *u0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *u1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *u2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            [u0 addConnectionsToNodes:@[u1] bidirectional:YES];
            path("m3 u2 findPathToNode:u0 unreachable", [u2 findPathToNode:u0]);
            GKGraph *g = [GKGraph graphWithNodes:@[q0, q1, q2, q3]];
            path("m3 graph findPath q0->q3", [g findPathFromNode:q0 toNode:q3]);
            path("m3 graph findPath q3->q0", [g findPathFromNode:q3 toNode:q0]);
            GKGraphNode2D *alone = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            path("m3 a node in no graph finds its own chain", [alone findPathToNode:q3]);
            GKGraph *empty = [GKGraph graphWithNodes:@[]];
            GKGraphNode2D *one = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            path("m3 an empty graph, start to itself", [empty findPathFromNode:one toNode:one]);
        }

        printf("== m4: findPathFromNode: on a node TRAPS on the host, so it is not called here\n");
        printf("m4 (see the header of this file: every input tried raised SIGBUS inside GameplayKit)\n");

        printf("== m5: the graph's own members\n");
        {
            GKGraphNode2D *g0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *g1 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraphNode2D *g2 = [GKGraphNode2D nodeWithPoint:(vector_float2){2, 0}];
            GKGraph *g = [GKGraph graphWithNodes:@[g0, g1, g2]];
            printf("m5 graph factory: class=%s nodes=%lu firstIsGiven=%d\n", class_getName([g class]),
                   (unsigned long)g.nodes.count, g.nodes[0] == g0);
            [g0 addConnectionsToNodes:@[g1] bidirectional:YES];
            [g1 addConnectionsToNodes:@[g2] bidirectional:YES];
            [g removeNodes:@[g1]];
            printf("m5 after removeNodes: nodes=%lu g0 edges=%lu g2 edges=%lu\n", (unsigned long)g.nodes.count,
                   (unsigned long)g0.connectedNodes.count, (unsigned long)g2.connectedNodes.count);
            GKGraphNode2D *g3 = [GKGraphNode2D nodeWithPoint:(vector_float2){3, 0}];
            [g addNodes:@[g3]];
            printf("m5 after addNodes: nodes=%lu\n", (unsigned long)g.nodes.count);
            [g addNodes:@[g3]];
            printf("m5 after addNodes the same node again: nodes=%lu\n", (unsigned long)g.nodes.count);
            GKGraph *dup = [GKGraph graphWithNodes:@[g0, g0]];
            printf("m5 a graph built from the same node twice: nodes=%lu\n", (unsigned long)dup.nodes.count);
            GKGraphNode2D *absent = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            [g removeNodes:@[absent]];
            printf("m5 removing a node the graph does not hold: nodes=%lu\n", (unsigned long)g.nodes.count);
            GKGraph *copy = [g copy];
            printf("m5 copy: class=%s nodes=%lu sharesNodes=%d\n", class_getName([copy class]),
                   (unsigned long)copy.nodes.count, copy.nodes[0] == g.nodes[0]);
            GKGraph *nilNodes = [GKGraph graphWithNodes:nil];
            printf("m5 a graph built from nil: nodes=%lu\n", (unsigned long)nilNodes.nodes.count);
            GKGraph *fresh = [[GKGraph alloc] init];
            printf("m5 -init: nodes=%lu\n", (unsigned long)fresh.nodes.count);
        }

        printf("== m6: connectNodeToLowestCostNode:\n");
        {
            GKGraphNode2D *me = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            GKGraphNode2D *a = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraph *g = [GKGraph graphWithNodes:@[me, a, b]];
            [g connectNodeToLowestCostNode:me bidirectional:NO];
            edges("m6 (5,0) in a graph of (5,0),(0,0),(1,0), one way", me);
            GKGraphNode2D *m2 = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            GKGraphNode2D *a2 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b2 = [GKGraphNode2D nodeWithPoint:(vector_float2){1, 0}];
            GKGraph *g2 = [GKGraph graphWithNodes:@[m2, a2, b2]];
            [g2 connectNodeToLowestCostNode:m2 bidirectional:YES];
            edges("m6 the same, bidirectional", m2);
            edges("m6 the node it connected to, bidirectional", a2);
            GKGraphNode2D *outsider = [GKGraphNode2D nodeWithPoint:(vector_float2){7, 0}];
            [g2 connectNodeToLowestCostNode:outsider bidirectional:NO];
            edges("m6 a node the graph does not hold", outsider);
            GKGraph *empty = [GKGraph graphWithNodes:@[]];
            GKGraphNode2D *c = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            [empty connectNodeToLowestCostNode:c bidirectional:NO];
            edges("m6 a graph with no nodes", c);
        }

        printf("== m7: the grid graph\n");
        {
            GKGridGraph *g = [GKGridGraph graphFromGridStartingAt:(vector_int2){2, 3}
                                                             width:3 height:2 diagonalsAllowed:NO];
            printf("m7 factory: class=%s w=%lu h=%lu origin=%d,%d diag=%d nodes=%lu\n", class_getName([g class]),
                   (unsigned long)g.gridWidth, (unsigned long)g.gridHeight, g.gridOrigin.x, g.gridOrigin.y,
                   (int)g.diagonalsAllowed, (unsigned long)g.nodes.count);
            GKGridGraphNode *corner = [g nodeAtGridPosition:(vector_int2){2, 3}];
            printf("m7 a corner's edges=%lu\n", (unsigned long)corner.connectedNodes.count);
            printf("m7 a cell outside the grid answers=%s\n",
                   [g nodeAtGridPosition:(vector_int2){99, 99}] == nil ? "nil" : "a node");
            path("m7 path (2,3)->(4,4)", [g findPathFromNode:corner
                                                   toNode:[g nodeAtGridPosition:(vector_int2){4, 4}]]);
            GKGridGraph *diag = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0}
                                                               width:3 height:3 diagonalsAllowed:YES];
            GKGridGraphNode *origin = [diag nodeAtGridPosition:(vector_int2){0, 0}];
            printf("m7 a corner's edges with diagonals=%lu\n", (unsigned long)origin.connectedNodes.count);
            path("m7 diagonal path (0,0)->(1,1)",
                 [diag findPathFromNode:origin toNode:[diag nodeAtGridPosition:(vector_int2){1, 1}]]);
            printf("m7 classForGenericArgumentAtIndex:0=%s\n",
                   class_getName([diag classForGenericArgumentAtIndex:0]));
            GKGridGraph *solo = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0}
                                                               width:1 height:1 diagonalsAllowed:NO];
            printf("m7 a 1x1 grid: nodes=%lu corner edges=%lu\n", (unsigned long)solo.nodes.count,
                   (unsigned long)[solo nodeAtGridPosition:(vector_int2){0, 0}].connectedNodes.count);
            GKGridGraph *zero = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0}
                                                               width:0 height:0 diagonalsAllowed:NO];
            printf("m7 a 0x0 grid: nodes=%lu w=%lu h=%lu\n", (unsigned long)zero.nodes.count,
                   (unsigned long)zero.gridWidth, (unsigned long)zero.gridHeight);
            GKGridGraphNode *i00 = [solo nodeAtGridPosition:(vector_int2){0, 0}];
            [solo connectNodeToAdjacentNodes:i00];
            printf("m7 connectNodeToAdjacentNodes: on a 1x1 grid, edges=%lu\n",
                   (unsigned long)i00.connectedNodes.count);
            GKGridGraphNode *stranger = [GKGridGraphNode nodeWithGridPosition:(vector_int2){9, 9}];
            [solo connectNodeToAdjacentNodes:stranger];
            printf("m7 the same for a node the grid does not hold, edges=%lu\n",
                   (unsigned long)stranger.connectedNodes.count);
            GKGridGraph *fresh = [[GKGridGraph alloc] init];
            printf("m7 -init: nodes=%lu w=%lu\n", (unsigned long)fresh.nodes.count,
                   (unsigned long)fresh.gridWidth);
            printf("m7 a grid of one cell's nodeClass: ");
            GKGridGraph *typed = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0} width:2 height:2
                                                  diagonalsAllowed:NO
                                                            nodeClass:[GKGridGraphNode class]];
            printf("class=%s classForGenericArgumentAtIndex:0=%s\n",
                   class_getName([[typed nodeAtGridPosition:(vector_int2){0, 0}] class]),
                   class_getName([typed classForGenericArgumentAtIndex:0]));
        }

        printf("== m8: the obstacles and their archives\n");
        {
            GKCircleObstacle *c = [GKCircleObstacle obstacleWithRadius:2.5f];
            printf("m8 circle factory: class=%s radius=%g pos=%g,%g\n", class_getName([c class]), c.radius,
                   c.position.x, c.position.y);
            c.position = (vector_float2){4, 5};
            c.radius = 7;
            printf("m8 circle set: radius=%g pos=%g,%g\n", c.radius, c.position.x, c.position.y);
            printf("m8 circle initialiser: radius=%g pos=%g,%g\n",
                   [[[GKCircleObstacle alloc] initWithRadius:3] radius],
                   [[[GKCircleObstacle alloc] initWithRadius:3] position].x,
                   [[[GKCircleObstacle alloc] initWithRadius:3] position].y);
            printf("m8 a circle is a GKObstacle=%d\n", [(GKObstacle *)c isKindOfClass:[GKObstacle class]]);
            vector_float2 square[4] = {{0, 0}, {4, 0}, {4, 4}, {0, 4}};
            GKPolygonObstacle *p = [GKPolygonObstacle obstacleWithPoints:square count:4];
            printf("m8 polygon factory: class=%s vertexCount=%lu isaSecureCoding=%d\n",
                   class_getName([p class]), (unsigned long)p.vertexCount,
                   [p conformsToProtocol:@protocol(NSSecureCoding)]);
            for (NSUInteger index = 0; index < 4; index++) {
                vector_float2 vertex = [p vertexAtIndex:index];
                printf("m8 polygon vertex %lu = %g,%g\n", (unsigned long)index, vertex.x, vertex.y);
            }
            vector_float2 past = [p vertexAtIndex:99];
            printf("m8 polygon vertex 99 = %g,%g\n", past.x, past.y);
            printf("m8 polygon from nil points: vertexCount=%lu\n",
                   (unsigned long)[GKPolygonObstacle obstacleWithPoints:NULL count:0].vertexCount);
            NSError *error = nil;
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:p requiringSecureCoding:YES
                                                                 error:&error];
            printf("m8 a polygon archives to %lu bytes, error=%s\n", (unsigned long)data.length,
                   error == nil ? "nil" : [[error description] UTF8String]);
            GKPolygonObstacle *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKPolygonObstacle class]
                                                                         fromData:data error:&error];
            printf("m8 and decodes to %s with %lu vertices, error=%s\n", class_getName([back class]),
                   (unsigned long)back.vertexCount, error == nil ? "nil" : [[error description] UTF8String]);
            for (NSUInteger index = 0; index < back.vertexCount; index++) {
                vector_float2 vertex = [back vertexAtIndex:index];
                printf("m8 decoded vertex %lu = %g,%g\n", (unsigned long)index, vertex.x, vertex.y);
            }
            GKGraphNode2D *e0 = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *e1 = [GKGraphNode2D nodeWithPoint:(vector_float2){4, 0}];
            [e0 addConnectionsToNodes:@[e1] bidirectional:YES];
            NSData *graphData = [NSKeyedArchiver archivedDataWithRootObject:[GKGraph graphWithNodes:@[e0, e1]]
                                                       requiringSecureCoding:YES error:&error];
            printf("m8 a two-node graph archives to %lu bytes, error=%s\n", (unsigned long)graphData.length,
                   error == nil ? "nil" : [[error description] UTF8String]);
            GKGraph *backGraph = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKGraph class]
                                                                    fromData:graphData error:&error];
            printf("m8 and decodes to %s with %lu nodes, error=%s\n", class_getName([backGraph class]),
                   (unsigned long)backGraph.nodes.count,
                   error == nil ? "nil" : [[error description] UTF8String]);
            GKGraphNode2D *decoded0 = (GKGraphNode2D *)backGraph.nodes[0];
            GKGraphNode2D *decoded1 = (GKGraphNode2D *)backGraph.nodes[1];
            printf("m8 decoded node0 pos=%g,%g edges=%lu; node1 pos=%g,%g\n", decoded0.position.x,
                   decoded0.position.y, (unsigned long)decoded0.connectedNodes.count, decoded1.position.x,
                   decoded1.position.y);
            path("m8 and a path across them", [backGraph findPathFromNode:backGraph.nodes[0]
                                                                   toNode:backGraph.nodes[1]]);
            GKGridGraph *diag = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0} width:3 height:3
                                                   diagonalsAllowed:YES];
            NSData *gridData = [NSKeyedArchiver archivedDataWithRootObject:diag requiringSecureCoding:YES
                                                                       error:&error];
            printf("m8 a 3x3 diagonal grid archives to %lu bytes, error=%s\n", (unsigned long)gridData.length,
                   error == nil ? "nil" : [[error description] UTF8String]);
            GKGridGraph *backGrid = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKGridGraph class]
                                                                      fromData:gridData error:&error];
            printf("m8 and decodes to %s w=%lu h=%lu nodes=%lu diag=%d, error=%s\n",
                   class_getName([backGrid class]), (unsigned long)backGrid.gridWidth,
                   (unsigned long)backGrid.gridHeight, (unsigned long)backGrid.nodes.count,
                   (int)backGrid.diagonalsAllowed, error == nil ? "nil" : [[error description] UTF8String]);
            GKGridGraphNode *backCell = [backGrid nodeAtGridPosition:(vector_int2){0, 0}];
            printf("m8 its (0,0) cell has %lu edges\n", (unsigned long)backCell.connectedNodes.count);
            GKGridGraph *plainGrid = [GKGridGraph graphFromGridStartingAt:(vector_int2){0, 0} width:3 height:3
                                                       diagonalsAllowed:NO];
            NSData *plainData = [NSKeyedArchiver archivedDataWithRootObject:plainGrid
                                                        requiringSecureCoding:YES error:&error];
            GKGridGraph *backPlain = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKGridGraph class]
                                                                       fromData:plainData error:&error];
            printf("m8 a 3x3 grid without diagonals decodes to diag=%d, its (0,0) cell has %lu edges\n",
                   (int)backPlain.diagonalsAllowed,
                   (unsigned long)[backPlain nodeAtGridPosition:(vector_int2){0, 0}].connectedNodes.count);
        }

        printf("== m9: the path\n");
        {
            vector_float2 points[4] = {{0, 0}, {1, 0}, {1, 1}, {0, 1}};
            GKPath *p = [GKPath pathWithPoints:points count:4 radius:2.5f cyclical:YES];
            printf("m9 factory: class=%s numPoints=%lu radius=%g cyclical=%d\n", class_getName([p class]),
                   (unsigned long)p.numPoints, p.radius, (int)p.isCyclical);
            for (NSUInteger index = 0; index < 4; index++) {
                vector_float2 point = [p pointAtIndex:index];
                vector_float2 two = [p float2AtIndex:index];
                printf("m9 point %lu = %g,%g float2 %g,%g\n", (unsigned long)index, point.x, point.y, two.x,
                       two.y);
            }
            vector_float2 past = [p pointAtIndex:99];
            printf("m9 point 99 = %g,%g\n", past.x, past.y);
            p.radius = 9;
            p.cyclical = NO;
            printf("m9 set: radius=%g cyclical=%d\n", p.radius, (int)p.isCyclical);
            GKGraphNode2D *a = [GKGraphNode2D nodeWithPoint:(vector_float2){0, 0}];
            GKGraphNode2D *b = [GKGraphNode2D nodeWithPoint:(vector_float2){5, 0}];
            GKPath *fromNodes = [GKPath pathWithGraphNodes:@[a, b] radius:1];
            printf("m9 from two nodes: numPoints=%lu radius=%g cyclical=%d\n", (unsigned long)fromNodes.numPoints,
                   fromNodes.radius, (int)fromNodes.isCyclical);
            for (NSUInteger index = 0; index < fromNodes.numPoints; index++) {
                vector_float2 point = [fromNodes pointAtIndex:index];
                printf("m9 from two nodes point %lu = %g,%g\n", (unsigned long)index, point.x, point.y);
            }
            for (NSUInteger count = 0; count <= 1; count++) {
                @try {
                    [GKPath pathWithPoints:points count:count radius:1 cyclical:NO];
                    printf("m9 %lu points did NOT raise\n", (unsigned long)count);
                } @catch (NSException *exception) {
                    printf("m9 %lu points raised %s: %s\n", (unsigned long)count, [exception.name UTF8String],
                           [exception.reason UTF8String]);
                }
            }
            for (NSUInteger count = 0; count <= 1; count++) {
                @try {
                    [GKPath pathWithGraphNodes:count == 0 ? @[] : @[a] radius:1];
                    printf("m9 %lu nodes did NOT raise\n", (unsigned long)count);
                } @catch (NSException *exception) {
                    printf("m9 %lu nodes raised %s: %s\n", (unsigned long)count, [exception.name UTF8String],
                           [exception.reason UTF8String]);
                }
            }
            @try {
                [[GKCircleObstacle alloc] init];
                printf("m9 -init on a circle did NOT raise\n");
            } @catch (NSException *exception) {
                printf("m9 -init on a circle raised %s: %s\n", [exception.name UTF8String],
                       [exception.reason UTF8String]);
            }
            @try {
                [[GKPolygonObstacle alloc] init];
                printf("m9 -init on a polygon did NOT raise\n");
            } @catch (NSException *exception) {
                printf("m9 -init on a polygon raised %s: %s\n", [exception.name UTF8String],
                       [exception.reason UTF8String]);
            }
            GKPath *fresh = [[GKPath alloc] init];
            printf("m9 -init: numPoints=%lu radius=%g cyclical=%d\n", (unsigned long)fresh.numPoints,
                   fresh.radius, (int)fresh.isCyclical);
        }
    }
    return 0;
}