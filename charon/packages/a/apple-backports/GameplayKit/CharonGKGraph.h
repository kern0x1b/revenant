#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <math.h>

static inline float CharonGKLength2(vector_float2 from, vector_float2 to)
{
    float dx = to.x - from.x;
    float dy = to.y - from.y;
    return (float)sqrt((double)(dx * dx + dy * dy));
}

static inline float CharonGKLength3(vector_float3 from, vector_float3 to)
{
    float dx = to.x - from.x;
    float dy = to.y - from.y;
    float dz = to.z - from.z;
    return (float)sqrt((double)(dx * dx + dy * dy + dz * dz));
}

static inline float CharonGKCellDistance(vector_int2 from, vector_int2 to)
{
    float dx = (float)(to.x - from.x);
    float dy = (float)(to.y - from.y);
    return (float)sqrt((double)(dx * dx + dy * dy));
}

float CharonGKCellSize(float minimum, float extent);

float CharonGKCellFloor(float value, float size);
float CharonGKCellCeiling(float value, float size, float limit);

float CharonGKNodeSize(float cellSize);

float CharonGKNodeCeiling(float edge, float limit);

BOOL CharonGKPointInPolygon(vector_float2 point, const vector_float2 *vertices, NSUInteger count,
                            float buffer);

BOOL CharonGKPointOnBoundary(vector_float2 point, const vector_float2 *vertices, NSUInteger count);

BOOL CharonGKSegmentCrossesPolygon(vector_float2 from, vector_float2 to, const vector_float2 *vertices,
                                   NSUInteger count, float buffer);

NSArray *CharonGKFindPath(NSArray *nodes, id start, id goal);

@interface CharonGKEntry : NSObject {
@public
    id charon_element;
    vector_float3 charon_min;
    vector_float3 charon_max;
    BOOL charon_isPoint;
}

+ (instancetype)charon_entryWithElement:(id)element low:(vector_float3)low high:(vector_float3)high
                               isPoint:(BOOL)isPoint;

- (BOOL)charon_holdsPoint:(vector_float3)point;

- (BOOL)charon_meetsRange:(vector_float2)low high:(vector_float2)high;

@end


NSArray *CharonGKConnected(id node);
float CharonGKSearchScore(id node);
float CharonGKCostTo(id from, id to);

@interface CharonGKPoint2 : NSObject {
@public
    vector_float2 point;
}
+ (instancetype)pointWithX:(float)x y:(float)y;
- (vector_float2)vector;
@end

@interface CharonGKTriangle3 : NSObject {
@public
    vector_float3 points[3];
}
+ (instancetype)triangleAt:(vector_float2)a first:(vector_float2)b second:(vector_float2)c;
@end

@interface CharonGKEdgePair : NSObject {
@public
    NSUInteger first;
    NSUInteger second;
}
+ (instancetype)pairWithFirst:(NSUInteger)first second:(NSUInteger)second;
@end

id CharonGKPointNodeWithClass(Class nodeClass, vector_float2 point);

NSArray *CharonGKTriangulateRegion(NSArray *outline, NSArray *holes);

NSArray *CharonGKBufferedCorners(NSArray *obstacles, float buffer, NSMutableArray *perObstacle);

NSArray *CharonGKVisibilityEdges(NSArray *corners, NSArray *obstacles, float buffer);

NSArray *CharonGKVerticesOfObstacle(id obstacle);

extern NSString *const CharonGKSearchClosedKey;
extern NSString *const CharonGKSearchScoreKey;
extern NSString *const CharonGKSearchParentKey;
extern NSString *const CharonGKGraphNodesKey;
extern NSString *const CharonGKGraphNodeClassKey;
extern NSString *const CharonGKGraphNodePositionKey;
extern NSString *const CharonGKObstacleVerticesKey;
extern NSString *const CharonGKObstacleGraphObstaclesKey;
extern NSString *const CharonGKObstacleGraphBufferKey;
extern NSString *const CharonGKObstacleGraphLocksKey;
