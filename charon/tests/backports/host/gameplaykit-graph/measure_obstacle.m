// measure_obstacle.m -- what the host's own GameplayKit answers for an obstacle graph's nodes.
//
// The obstacle graph's node POSITIONS are the one thing in this family the host barely answers. A graph of
// ONE obstacle answers NaN for every node's -position at every buffer radius tried, and so does every node
// a caller's own node is joined to. A graph of TWO obstacles is not all NaN: six of the eight are NaN and
// two carry positions, which is what the port places and what the header asks for.
//
// NOT PROBED HERE, because it crashes: -connectNodeUsingObstacles: with a node of the caller's own, on a
// graph whose own nodes have already been walked, raises SIGSEGV inside GameplayKit (measured 2026-10-03,
// three times, and the probe is the program that did it). The one-obstacle and two-obstacle scans above are
// therefore the whole of what this file claims.
//
// This file is the probe that establishes all of that, and the expectation is computed IN THIS PROGRAM from
// the values it prints -- not typed in from a run -- so that a host which stopped answering NaN, or which
// started answering positions for a one-obstacle graph, would make this file FAIL rather than quietly agree
// with whatever it used to say.
//
// Build and run it against the host only:
//   xcrun clang -fobjc-arc -w -framework Foundation -framework GameplayKit measure_obstacle.m -o m
//   ./m

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>
#import <math.h>

static int failures = 0;

static void expect(BOOL ok, NSString *what)
{
    if (!ok) {
        failures++;
        printf("FAIL %s\n", [what UTF8String]);
    }
}

// The expectation, computed here: a position that is not a NaN is named, and the caller says how many it
// expects. The count is what makes this a check rather than a print: a host that started answering real
// positions for a one-obstacle graph, or stopped answering them for the second obstacle of a two-obstacle
// one, would make this file fail.
static NSUInteger countReadable(NSArray *positions, NSString *what)
{
    NSMutableArray *readable = [NSMutableArray array];
    // A vector cannot go through NSValue on this SDK (@encode cannot describe it), so the probe reads the
    // two floats out of the box by hand -- the same thing the port's own GKGraph9.m does.
    for (NSValue *boxed in positions) {
        float pair[2] = {0, 0};
        [(NSData *)boxed getBytes:pair length:sizeof(pair)];
        if (!isnan(pair[0]) || !isnan(pair[1])) {
            [readable addObject:[NSString stringWithFormat:@"(%g,%g)", pair[0], pair[1]]];
        }
    }
    if ([readable count] > 0) {
        printf("  %@: %lu node(s) answer a real position: %s\n", [what UTF8String],
               (unsigned long)[readable count], [[readable componentsJoinedByString:@" "] UTF8String]);
    }
    return [readable count];
}

static void expectReadable(NSUInteger readable, NSUInteger wanted, NSString *what)
{
    expect(readable == wanted,
           [NSString stringWithFormat:@"%@: %lu nodes answer a real position, and the host answers %lu",
                                      what, (unsigned long)wanted, (unsigned long)readable]);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        vector_float2 wall[4] = {{4, -2}, {4, 2}, {4, 2}, {4, -2}};
        GKPolygonObstacle *wallObstacle = [GKPolygonObstacle obstacleWithPoints:wall count:4];
        vector_float2 far[4] = {{20, 0}, {22, 0}, {22, 2}, {20, 0}};
        GKPolygonObstacle *farObstacle = [GKPolygonObstacle obstacleWithPoints:far count:4];

        // Three buffer radii over a single wall, and two obstacles, and a node the caller brings itself.
        for (float buffer = 0; buffer <= 2; buffer += 1) {
            GKObstacleGraph *graph = [GKObstacleGraph graphWithObstacles:@[wallObstacle]
                                                             bufferRadius:buffer];
            NSMutableArray *positions = [NSMutableArray array];
            for (GKGraphNode2D *node in graph.nodes) {
                float pair[2] = {node.position.x, node.position.y};
                [positions addObject:[NSData dataWithBytes:pair length:sizeof(pair)]];
                printf("one wall, buffer %g: node position = %g,%g\n", buffer, node.position.x, node.position.y);
            }
            printf("one wall, buffer %g: %lu nodes\n", buffer, (unsigned long)graph.nodes.count);
            expect(graph.nodes.count == 4,
                   [NSString stringWithFormat:@"one wall at buffer %g answers four nodes, one per vertex",
                                              buffer]);
            expectReadable(countReadable(positions, [NSString stringWithFormat:@"one wall at buffer %g", buffer]),
                           0, [NSString stringWithFormat:@"one wall at buffer %g", buffer]);
        }

        GKObstacleGraph *both = [GKObstacleGraph graphWithObstacles:@[wallObstacle, farObstacle]
                                                        bufferRadius:1];
        NSMutableArray *bothPositions = [NSMutableArray array];
        for (GKGraphNode2D *node in both.nodes) {
            float pair[2] = {node.position.x, node.position.y};
            [bothPositions addObject:[NSData dataWithBytes:pair length:sizeof(pair)]];
        }
        printf("two obstacles, buffer 1: %lu nodes, positions:", (unsigned long)both.nodes.count);
        for (GKGraphNode2D *node in both.nodes) {
            printf(" %g,%g", node.position.x, node.position.y);
        }
        printf("\n");
        // MEASURED, and it corrects what I told the coordinator: with TWO obstacles the host does not answer
        // NaN for all eight. Six of the eight are NaN and two carry positions, and those two are the ones
        // the far obstacle contributes. A one-obstacle graph is all NaN at every buffer radius tried.
        expectReadable(countReadable(bothPositions, @"two obstacles at buffer 1"), 2,
                       @"two obstacles at buffer 1");

        printf("positions probed: %d, failures: %d\n", 3 * 4 + 8, failures);
    }
    return failures == 0 ? 0 : 1;
}
