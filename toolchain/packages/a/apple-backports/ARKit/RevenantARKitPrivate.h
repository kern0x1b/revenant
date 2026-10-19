#import <ARKit/ARKit.h>
#import <simd/simd.h>
#import <math.h>

#import <SceneKit/SceneKit.h>

#import "RevenantARTracker.h"

NS_ASSUME_NONNULL_BEGIN

enum { kPlaneQuadCorners = 4, kPlaneQuadTriangles = 6 };

static void RevenantEncodeStruct(NSCoder *coder, NSString *key, const void *bytes, size_t size)
{
    [coder encodeBytes:(const uint8_t *)bytes length:size forKey:key];
}

static BOOL RevenantDecodeStruct(NSCoder *coder, NSString *key, void *bytes, size_t size)
{
    NSUInteger length = 0;
    const uint8_t *decoded = [coder decodeBytesForKey:key returnedLength:&length];
    if (!decoded || length < size)
        return NO;
    memcpy(bytes, decoded, size);
    return YES;
}

static inline BOOL RevenantInvert4x4(simd_float4x4 m, simd_float4x4 *out)
{
    float a[4][8];
    for (int row = 0; row < 4; row++) {
        for (int column = 0; column < 4; column++)
            a[row][column] = m.columns[column][row];
        for (int column = 0; column < 4; column++)
            a[row][4 + column] = (row == column) ? 1.0f : 0.0f;
    }
    for (int column = 0; column < 4; column++) {
        int pivot = column;
        for (int row = column + 1; row < 4; row++)
            if (fabsf(a[row][column]) > fabsf(a[pivot][column]))
                pivot = row;
        if (fabsf(a[pivot][column]) < 1e-12f)
            return NO;
        if (pivot != column)
            for (int k = 0; k < 8; k++) {
                float swap = a[column][k];
                a[column][k] = a[pivot][k];
                a[pivot][k] = swap;
            }
        for (int row = 0; row < 4; row++) {
            if (row == column)
                continue;
            float factor = a[row][column] / a[column][column];
            for (int k = 0; k < 8; k++)
                a[row][k] -= factor * a[column][k];
        }
    }
    for (int column = 0; column < 4; column++) {
        float inverse = 1.0f / a[column][column];
        for (int row = 0; row < 4; row++)
            out->columns[column][row] = a[row][4 + column] * inverse;
    }
    return YES;
}

static inline simd_float4x4 RevenantInverse(simd_float4x4 m)
{
    simd_float4x4 inverse = RevenantARKitIdentityFloat4x4;
    if (!RevenantInvert4x4(m, &inverse))
        return RevenantARKitIdentityFloat4x4;
    return inverse;
}

@interface ARConfiguration (RevenantPrivate)
- (instancetype)initRevenantCommon;
@end

@interface ARVideoFormat (RevenantPrivate)
- (instancetype)initWithCaptureFormat:(AVCaptureDeviceFormat *)format;
@end

@interface ARPlaneAnchor (RevenantPrivate)
- (instancetype)initWithPlaneValue:(RevenantARValue *)value;
@end

@interface ARPlaneGeometry (RevenantPrivate)
- (instancetype)initWithPlaneValue:(RevenantARValue *)value;
@end

@interface ARHitTestResult (RevenantPrivate)
- (instancetype)initWithHitValue:(RevenantARValue *)value;
@end

@interface ARPointCloud (RevenantPrivate)
- (instancetype)initWithPoints:(NSData *)points count:(NSUInteger)count;
@end

@interface ARRaycastQuery (RevenantPrivate)
- (instancetype)initWithOrigin:(simd_float3)origin
                    direction:(simd_float3)direction
             allowingTarget:(ARRaycastTarget)target
                    alignment:(ARRaycastTargetAlignment)alignment;
@end

@interface ARWorldMap (RevenantPrivate)
- (instancetype)initWithAnchors:(NSArray<ARAnchor *> *)anchors
                   featurePoints:(nullable ARPointCloud *)featurePoints;
- (nullable NSData *)trackerState;
- (void)setTrackerState:(nullable NSData *)trackerState;
@end

@interface ARTrackedRaycast (RevenantPrivate)
@property (nonatomic, strong) ARRaycastQuery *query;
- (instancetype)initWithQuery:(ARRaycastQuery *)query;
@end

@interface ARRaycastResult (RevenantPrivate)
- (instancetype)initWithHitValue:(RevenantARValue *)value;
@end

@interface ARFrame (RevenantPrivate)
- (instancetype)initWithCameraTransform:(simd_float4x4)cameraTransform
                        deviceTransform:(simd_float4x4)deviceTransform
                  cameraTransformTime:(NSTimeInterval)timestamp
                         imageResolution:(CGSize)resolution
                           lightEstimate:(CGFloat)lightEstimate
                ambientColorTemperature:(CGFloat)ambientColorTemperature
                               tracking:(BOOL)tracking
                         hitTestTracker:(RevenantARTracker *)hitTestTracker;

- (void)addAnchor:(ARAnchor *)anchor;
@end

@interface ARAnchor (RevenantPrivate)
@property (nonatomic, copy) NSUUID *identifier;

- (ARAnchor *)anchorByApplyingOrigin:(simd_float4x4)origin;
@end

NS_ASSUME_NONNULL_END
