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

static NSUInteger countReadable(NSArray *positions, NSString *what)
{
    NSMutableArray *readable = [NSMutableArray array];
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
        expectReadable(countReadable(bothPositions, @"two obstacles at buffer 1"), 2,
                       @"two obstacles at buffer 1");

        printf("positions probed: %d, failures: %d\n", 3 * 4 + 8, failures);
    }
    return failures == 0 ? 0 : 1;
}
