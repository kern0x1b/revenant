#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <math.h>

static inline float RevenantGKLength2(vector_float2 from, vector_float2 to)
{
    float dx = to.x - from.x;
    float dy = to.y - from.y;
    return (float)sqrt((double)(dx * dx + dy * dy));
}

static inline float RevenantGKLength3(vector_float3 from, vector_float3 to)
{
    float dx = to.x - from.x;
    float dy = to.y - from.y;
    float dz = to.z - from.z;
    return (float)sqrt((double)(dx * dx + dy * dy + dz * dz));
}

static inline float RevenantGKCellDistance(vector_int2 from, vector_int2 to)
{
    float dx = (float)(to.x - from.x);
    float dy = (float)(to.y - from.y);
    return (float)sqrt((double)(dx * dx + dy * dy));
}

float RevenantGKCellSize(float minimum, float extent);

float RevenantGKCellFloor(float value, float size);
float RevenantGKCellCeiling(float value, float size, float limit);

float RevenantGKNodeSize(float cellSize);

float RevenantGKNodeCeiling(float edge, float limit);

BOOL RevenantGKPointInPolygon(vector_float2 point, const vector_float2 *vertices, NSUInteger count,
                            float buffer);

BOOL RevenantGKPointOnBoundary(vector_float2 point, const vector_float2 *vertices, NSUInteger count);

BOOL RevenantGKSegmentCrossesPolygon(vector_float2 from, vector_float2 to, const vector_float2 *vertices,
                                   NSUInteger count, float buffer);

NSArray *RevenantGKFindPath(NSArray *nodes, id start, id goal);

@interface RevenantGKEntry : NSObject {
@public
    id revenant_element;
    vector_float3 revenant_min;
    vector_float3 revenant_max;
    BOOL revenant_isPoint;
}

+ (instancetype)revenant_entryWithElement:(id)element low:(vector_float3)low high:(vector_float3)high
                               isPoint:(BOOL)isPoint;

- (BOOL)revenant_holdsPoint:(vector_float3)point;

- (BOOL)revenant_meetsRange:(vector_float2)low high:(vector_float2)high;

@end


NSArray *RevenantGKConnected(id node);
float RevenantGKSearchScore(id node);
float RevenantGKCostTo(id from, id to);

@interface RevenantGKPoint2 : NSObject {
@public
    vector_float2 point;
}
+ (instancetype)pointWithX:(float)x y:(float)y;
- (vector_float2)vector;
@end

@interface RevenantGKTriangle3 : NSObject {
@public
    vector_float3 points[3];
}
+ (instancetype)triangleAt:(vector_float2)a first:(vector_float2)b second:(vector_float2)c;
@end

@interface RevenantGKEdgePair : NSObject {
@public
    NSUInteger first;
    NSUInteger second;
}
+ (instancetype)pairWithFirst:(NSUInteger)first second:(NSUInteger)second;
@end

id RevenantGKPointNodeWithClass(Class nodeClass, vector_float2 point);

NSArray *RevenantGKTriangulateRegion(NSArray *outline, NSArray *holes);

NSArray *RevenantGKBufferedCorners(NSArray *obstacles, float buffer, NSMutableArray *perObstacle);

NSArray *RevenantGKVisibilityEdges(NSArray *corners, NSArray *obstacles, float buffer);

NSArray *RevenantGKVerticesOfObstacle(id obstacle);

extern NSString *const RevenantGKSearchClosedKey;
extern NSString *const RevenantGKSearchScoreKey;
extern NSString *const RevenantGKSearchParentKey;
extern NSString *const RevenantGKGraphNodesKey;
extern NSString *const RevenantGKGraphNodeClassKey;
extern NSString *const RevenantGKGraphNodePositionKey;
extern NSString *const RevenantGKObstacleVerticesKey;
extern NSString *const RevenantGKObstacleGraphObstaclesKey;
extern NSString *const RevenantGKObstacleGraphBufferKey;
extern NSString *const RevenantGKObstacleGraphLocksKey;
