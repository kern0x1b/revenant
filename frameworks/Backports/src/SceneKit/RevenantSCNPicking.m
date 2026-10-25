#import "RevenantSCN.h"
#import "RevenantSCNGeometry.h"
#import "RevenantSCNMath.h"
#import "RevenantSCNPicking.h"
#import <UIKit/UIKit.h>
#include <string.h>

typedef struct {
    BOOL clipToZRange;
    BOOL backFaceCulling;
    BOOL boundingBoxOnly;
    BOOL ignoreChildNodes;
    BOOL ignoreHiddenNodes;
    NSUInteger categoryMask;
} RevenantSCNPickOptions;

@interface RevenantSCNHit : NSObject
@property (nonatomic, assign) float distance;
@property (nonatomic, strong) SCNHitTestResult *result;
@end

@implementation RevenantSCNHit
@synthesize distance = _distance;
@synthesize result = _result;
@end

static void RevenantSCNFaceNormal(const float a[3], const float b[3], const float c[3], float out[3])
{
    float edge1[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]};
    float edge2[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
    float normal[3] = {edge1[1] * edge2[2] - edge1[2] * edge2[1], edge1[2] * edge2[0] - edge1[0] * edge2[2], edge1[0] * edge2[1] - edge1[1] * edge2[0]};
    float length = sqrtf(normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2]);
    for (int axis = 0; axis < 3; axis++) {
        out[axis] = length > 0 ? normal[axis] / length : 0;
    }
}

static void RevenantSCNTransformPoint(SCNMatrix4 matrix, const float point[3], float out[3])
{
    float in[4] = {point[0], point[1], point[2], 1}, result[4];
    RevenantSCNRowTransform(matrix, in, result);
    for (int axis = 0; axis < 3; axis++) {
        out[axis] = result[axis] / result[3];
    }
}

@interface RevenantSCNPicker : NSObject
- (instancetype)initWithOrigin:(const float *)origin direction:(const float *)direction options:(RevenantSCNPickOptions)options;
- (NSArray<RevenantSCNHit *> *)hitsUnderNode:(SCNNode *)root;
@end

@implementation RevenantSCNPicker
{
    float _origin[3];
    float _direction[3];
    RevenantSCNPickOptions _options;
    NSMutableArray<RevenantSCNHit *> *_hits;
}

- (instancetype)initWithOrigin:(const float *)origin direction:(const float *)direction options:(RevenantSCNPickOptions)options
{
    if ((self = [super init])) {
        memcpy(_origin, origin, sizeof _origin);
        memcpy(_direction, direction, sizeof _direction);
        _options = options;
        _hits = [NSMutableArray array];
    }
    return self;
}

- (NSArray<RevenantSCNHit *> *)hitsUnderNode:(SCNNode *)root
{
    [self visit:root];
    return _hits;
}

- (BOOL)acceptsDistance:(float)distance
{
    return distance >= 0 && (!_options.clipToZRange || distance <= 1);
}

- (void)visit:(SCNNode *)node
{
    if (node == nil || (_options.ignoreHiddenNodes && node.hidden)) {
        return;
    }
    if (node.geometry && (node.categoryBitMask & _options.categoryMask) != 0) {
        [self testGeometry:node.geometry node:node world:[node revenantPresentedWorldTransform]];
    }
    if (!_options.ignoreChildNodes) {
        for (SCNNode *child in node.childNodes) {
            [self visit:child];
        }
    }
}

- (void)testGeometry:(SCNGeometry *)geometry node:(SCNNode *)node world:(SCNMatrix4)world
{
    SCNGeometrySource *position = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticVertex].firstObject;
    if (position == nil) {
        return;
    }
    SCNMatrix4 inverse = RevenantSCNMatrixInvert(world);
    if (_options.boundingBoxOnly) {
        float min[3], max[3], worldMin[3], worldMax[3];
        if (!RevenantSCNGeometryBounds(geometry, min, max)) {
            return;
        }
        RevenantSCNWorldBox(world, min, max, worldMin, worldMax);
        float distance = 0;
        if (!RevenantSCNRayHitsBox(_origin, _direction, worldMin, worldMax, &distance) || ![self acceptsDistance:distance]) {
            return;
        }
        float point[3], localPoint[3], zero[3] = {0, 0, 0};
        [self pointAt:distance point:point];
        RevenantSCNTransformPoint(inverse, point, localPoint);
        [self recordNode:node geometryIndex:0 faceIndex:-1 distance:distance world:point local:localPoint localNormal:zero worldNormal:zero matrix:world texcoords:@[]];
        return;
    }
    NSArray<SCNGeometryElement *> *elements = geometry.geometryElements;
    NSArray<SCNGeometrySource *> *texcoordSources = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticTexcoord];
    for (NSUInteger element = 0; element < elements.count; element++) {
        SCNGeometryElement *triangles = elements[element];
        if (triangles.primitiveType != SCNGeometryPrimitiveTypeTriangles) {
            continue;
        }
        for (NSUInteger face = 0; face < triangles.primitiveCount; face++) {
            NSUInteger corners[3];
            BOOL indexed = YES;
            for (int corner = 0; corner < 3 && indexed; corner++) {
                indexed = RevenantSCNReadIndex(triangles, face * 3 + corner, &corners[corner]);
            }
            float local[3][3], worldCorners[3][3];
            BOOL readable = indexed;
            for (int corner = 0; corner < 3 && readable; corner++) {
                readable = RevenantSCNReadVector(position, corners[corner], 3, local[corner]);
            }
            if (!readable) {
                continue;
            }
            for (int corner = 0; corner < 3; corner++) {
                RevenantSCNTransformPoint(world, local[corner], worldCorners[corner]);
            }
            float distance = 0, u = 0, v = 0;
            if (!RevenantSCNRayHitsTriangle(_origin, _direction, worldCorners[0], worldCorners[1], worldCorners[2], _options.backFaceCulling, &distance, &u, &v) || ![self acceptsDistance:distance]) {
                continue;
            }
            float point[3], localPoint[3], localNormal[3], worldNormal[3];
            [self pointAt:distance point:point];
            RevenantSCNTransformPoint(inverse, point, localPoint);
            RevenantSCNFaceNormal(local[0], local[1], local[2], localNormal);
            RevenantSCNFaceNormal(worldCorners[0], worldCorners[1], worldCorners[2], worldNormal);
            NSMutableArray<NSValue *> *coordinates = [NSMutableArray arrayWithCapacity:texcoordSources.count];
            for (SCNGeometrySource *source in texcoordSources) {
                float uv[3][2] = {{0, 0}, {0, 0}, {0, 0}};
                BOOL mapped = YES;
                for (int corner = 0; corner < 3 && mapped; corner++) {
                    mapped = RevenantSCNReadVector(source, corners[corner], 2, uv[corner]);
                }
                CGPoint coordinate = CGPointZero;
                if (mapped) {
                    coordinate = CGPointMake((1 - u - v) * uv[0][0] + u * uv[1][0] + v * uv[2][0],
                                             (1 - u - v) * uv[0][1] + u * uv[1][1] + v * uv[2][1]);
                }
                [coordinates addObject:[NSValue valueWithCGPoint:coordinate]];
            }
            [self recordNode:node geometryIndex:element faceIndex:(NSInteger)face distance:distance world:point local:localPoint localNormal:localNormal worldNormal:worldNormal matrix:world texcoords:coordinates];
        }
    }
}

- (void)pointAt:(float)distance point:(float[3])point
{
    for (int axis = 0; axis < 3; axis++) {
        point[axis] = _origin[axis] + distance * _direction[axis];
    }
}

- (void)recordNode:(SCNNode *)node geometryIndex:(NSUInteger)geometryIndex faceIndex:(NSInteger)faceIndex distance:(float)distance world:(const float *)world local:(const float *)local localNormal:(const float *)localNormal worldNormal:(const float *)worldNormal matrix:(SCNMatrix4)matrix texcoords:(NSArray<NSValue *> *)texcoords
{
    RevenantSCNHit *hit = [[RevenantSCNHit alloc] init];
    hit.distance = distance;
    hit.result = [SCNHitTestResult revenantResultWithNode:node geometryIndex:(NSInteger)geometryIndex faceIndex:faceIndex localCoordinates:local worldCoordinates:world localNormal:localNormal worldNormal:worldNormal modelTransform:matrix textureCoordinates:texcoords];
    [_hits addObject:hit];
}

@end

static BOOL RevenantSCNOption(NSDictionary *options, id key, BOOL fallback)
{
    NSNumber *value = options[key];
    return value ? value.boolValue : fallback;
}

static RevenantSCNPickOptions RevenantSCNPickOptionsFrom(NSDictionary *options, NSInteger *mode)
{
    RevenantSCNPickOptions pick;
    pick.clipToZRange = RevenantSCNOption(options, SCNHitTestClipToZRangeKey, YES);
    pick.backFaceCulling = RevenantSCNOption(options, SCNHitTestBackFaceCullingKey, NO);
    pick.boundingBoxOnly = RevenantSCNOption(options, SCNHitTestBoundingBoxOnlyKey, NO);
    pick.ignoreChildNodes = RevenantSCNOption(options, SCNHitTestIgnoreChildNodesKey, NO);
    pick.ignoreHiddenNodes = RevenantSCNOption(options, SCNHitTestIgnoreHiddenNodesKey, YES);
    NSNumber *mask = options[SCNHitTestOptionCategoryBitMask];
    pick.categoryMask = mask ? mask.unsignedIntegerValue : NSUIntegerMax;
    *mode = SCNHitTestSearchModeClosest;
    NSNumber *searchMode = options[SCNHitTestOptionSearchMode];
    if (searchMode) {
        *mode = searchMode.integerValue;
    }
    if (RevenantSCNOption(options, SCNHitTestFirstFoundOnlyKey, NO)) {
        *mode = SCNHitTestSearchModeAny;
    }
    if (RevenantSCNOption(options, SCNHitTestSortResultsKey, NO)) {
        *mode = SCNHitTestSearchModeAll;
    }
    return pick;
}

static NSArray<SCNHitTestResult *> *RevenantSCNSelectHits(NSArray<RevenantSCNHit *> *hits, NSInteger mode)
{
    if (hits.count == 0) {
        return @[];
    }
    if (mode == SCNHitTestSearchModeAny) {
        return @[hits.firstObject.result];
    }
    NSArray<RevenantSCNHit *> *sorted = [hits sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(RevenantSCNHit *a, RevenantSCNHit *b) {
        if (a.distance == b.distance) {
            return NSOrderedSame;
        }
        return a.distance < b.distance ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray<SCNHitTestResult *> *results = [NSMutableArray array];
    for (RevenantSCNHit *hit in sorted) {
        [results addObject:hit.result];
        if (mode == SCNHitTestSearchModeClosest) {
            break;
        }
    }
    return results;
}

static void RevenantSCNViewPixels(SCNView *scnView, int *width, int *height)
{
    CGFloat scale = scnView.contentScaleFactor;
    *width = (int)lround(scnView.bounds.size.width * scale);
    *height = (int)lround(scnView.bounds.size.height * scale);
}

static BOOL RevenantSCNViewFrustum(SCNView *scnView, SCNNode *pointOfView, float planes[6][4])
{
    int width = 0, height = 0;
    RevenantSCNViewPixels(scnView, &width, &height);
    if (pointOfView == nil || width <= 0 || height <= 0) {
        return NO;
    }
    SCNMatrix4 viewMatrix = RevenantSCNMatrixInvert([pointOfView revenantPresentedWorldTransform]);
    SCNMatrix4 viewProjection = RevenantSCNMatrixMultiply(viewMatrix, RevenantSCNProjectionMatrix(pointOfView, width, height));
    RevenantSCNFrustumPlanes(viewProjection, planes);
    return YES;
}

static void RevenantSCNIncludeSubtree(SCNNode *node, float min[3], float max[3], BOOL *found)
{
    float local[3], localMax[3];
    if (node.geometry && RevenantSCNGeometryBounds(node.geometry, local, localMax)) {
        float worldMin[3], worldMax[3];
        RevenantSCNWorldBox([node revenantPresentedWorldTransform], local, localMax, worldMin, worldMax);
        if (*found) {
            RevenantSCNExpandBox(min, max, worldMin);
            RevenantSCNExpandBox(min, max, worldMax);
        } else {
            memcpy(min, worldMin, sizeof worldMin);
            memcpy(max, worldMax, sizeof worldMax);
            *found = YES;
        }
    }
    for (SCNNode *child in node.childNodes) {
        RevenantSCNIncludeSubtree(child, min, max, found);
    }
}

static BOOL RevenantSCNSubtreeInFrustum(SCNNode *node, const float planes[6][4])
{
    float min[3], max[3];
    BOOL found = NO;
    RevenantSCNIncludeSubtree(node, min, max, &found);
    if (!found) {
        SCNMatrix4 world = [node revenantPresentedWorldTransform];
        float position[3] = {(float)world.m41, (float)world.m42, (float)world.m43};
        memcpy(min, position, sizeof position);
        memcpy(max, position, sizeof position);
    }
    return RevenantSCNBoxInFrustum(planes, min, max);
}

static void RevenantSCNCollectInside(SCNNode *node, const float planes[6][4], NSMutableArray<SCNNode *> *nodes)
{
    if (RevenantSCNSubtreeInFrustum(node, planes)) {
        [nodes addObject:node];
    }
    for (SCNNode *child in node.childNodes) {
        RevenantSCNCollectInside(child, planes, nodes);
    }
}

@implementation SCNView (RevenantSCNPicking)

- (NSArray<SCNHitTestResult *> *)hitTest:(CGPoint)point options:(nullable NSDictionary<SCNHitTestOption, id> *)options
{
    SCNNode *root = options[SCNHitTestRootNodeKey] ?: self.scene.rootNode;
    SCNNode *pointOfView = self.pointOfView;
    int width = 0, height = 0;
    RevenantSCNViewPixels(self, &width, &height);
    if (root == nil || pointOfView == nil || width <= 0 || height <= 0) {
        return @[];
    }
    SCNMatrix4 viewMatrix = RevenantSCNMatrixInvert([pointOfView revenantPresentedWorldTransform]);
    SCNMatrix4 inverseViewProjection = RevenantSCNMatrixInvert(RevenantSCNMatrixMultiply(viewMatrix, RevenantSCNProjectionMatrix(pointOfView, width, height)));
    float screenX = (float)(point.x * self.contentScaleFactor);
    float screenY = (float)((self.bounds.size.height - point.y) * self.contentScaleFactor);
    float nearPoint[3], farPoint[3];
    float ndcNear[4] = {2 * screenX / width - 1, 2 * screenY / height - 1, -1, 1};
    float ndcFar[4] = {2 * screenX / width - 1, 2 * screenY / height - 1, 1, 1};
    float nearWorld[4], farWorld[4];
    RevenantSCNRowTransform(inverseViewProjection, ndcNear, nearWorld);
    RevenantSCNRowTransform(inverseViewProjection, ndcFar, farWorld);
    for (int axis = 0; axis < 3; axis++) {
        nearPoint[axis] = nearWorld[axis] / nearWorld[3];
        farPoint[axis] = farWorld[axis] / farWorld[3];
    }
    NSInteger mode = SCNHitTestSearchModeClosest;
    RevenantSCNPickOptions pick = RevenantSCNPickOptionsFrom(options, &mode);
    float origin[3], direction[3];
    if (pick.clipToZRange) {
        memcpy(origin, nearPoint, sizeof origin);
    } else {
        SCNMatrix4 cameraWorld = [pointOfView revenantPresentedWorldTransform];
        origin[0] = (float)cameraWorld.m41;
        origin[1] = (float)cameraWorld.m42;
        origin[2] = (float)cameraWorld.m43;
    }
    for (int axis = 0; axis < 3; axis++) {
        direction[axis] = farPoint[axis] - origin[axis];
    }
    RevenantSCNPicker *picker = [[RevenantSCNPicker alloc] initWithOrigin:origin direction:direction options:pick];
    return RevenantSCNSelectHits([picker hitsUnderNode:root], mode);
}

- (BOOL)isNodeInsideFrustum:(SCNNode *)node withPointOfView:(SCNNode *)pointOfView
{
    float planes[6][4];
    return node != nil && RevenantSCNViewFrustum(self, pointOfView, planes) && RevenantSCNSubtreeInFrustum(node, planes);
}

- (NSArray<SCNNode *> *)nodesInsideFrustumWithPointOfView:(SCNNode *)pointOfView
{
    NSMutableArray<SCNNode *> *nodes = [NSMutableArray array];
    float planes[6][4];
    if (!RevenantSCNViewFrustum(self, pointOfView, planes)) {
        return nodes;
    }
    for (SCNNode *child in self.scene.rootNode.childNodes) {
        RevenantSCNCollectInside(child, planes, nodes);
    }
    return nodes;
}

@end
