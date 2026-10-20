#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

static const simd_float3x3 RevenantARKitIdentityFloat3x3 = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
static const simd_float4x4 RevenantARKitIdentityFloat4x4 = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}};
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    simd_float2 image;
    simd_float3 camera;
    simd_float3 world;
    float      scale;
    float      depth;
    uint32_t   identifier;
    uint8_t    age;
    uint8_t    hits;
} RevenantARPoint;

typedef struct {
    simd_float3 center;
    simd_float3 normal;
    simd_float3 extent;
    float       alignment;
    uint32_t    identifier;
} RevenantARPlane;

typedef struct {
    simd_float3 position;
    simd_float3 localNormal;
    uint32_t     planeIdentifier;
} RevenantARHit;

typedef struct {
    simd_float3 position;
} RevenantARCloudPoint;

static inline simd_float3 RevenantRayDirection(simd_float3x3 intrinsics, simd_float4x4 transform, simd_float2 point)
{
    float fx = intrinsics.columns[0][0], cx = intrinsics.columns[2][0];
    float fy = intrinsics.columns[1][1], cy = intrinsics.columns[2][1];
    if (fx == 0 || fy == 0)
        return simd_make_float3(0, 0, -1);
    simd_float3 inCamera = simd_make_float3((point.x - cx) / fx, (point.y - cy) / fy, -1);
    simd_float4 product = simd_mul(transform, (simd_float4){ inCamera.x, inCamera.y, inCamera.z, 0 });
    return simd_normalize(simd_make_float3(product.x, product.y, product.z));
}

static inline simd_float4x4 RevenantQuaternionMatrix(simd_quatf q)
{
    float x = q.vector.x, y = q.vector.y, z = q.vector.z, w = q.vector.w;
    simd_float4x4 m;
    m.columns[0] = simd_make_float4(1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0);
    m.columns[1] = simd_make_float4(2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0);
    m.columns[2] = simd_make_float4(2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0);
    m.columns[3] = simd_make_float4(0, 0, 0, 1);
    return m;
}

@protocol RevenantARTrackerDelegate;

@interface RevenantARValue : NSObject

- (instancetype)initWithBytes:(const void *)bytes size:(size_t)size NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)getValue:(void *)value;

@property (nonatomic, readonly) size_t size;

@end

@interface RevenantARTracker : NSObject

+ (BOOL)isSupported;

+ (BOOL)hasFrontCamera;

+ (nullable AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;

+ (NSArray<AVCaptureDeviceFormat *> *)supportedCaptureFormatsForPosition:(AVCaptureDevicePosition)position;

+ (simd_float3x3)cameraIntrinsicsForResolution:(CGSize)resolution;

+ (void)useCameraIntrinsics:(simd_float3x3)intrinsics;

@property (nonatomic, weak, nullable) id<RevenantARTrackerDelegate> delegate;

- (BOOL)startWithError:(NSError **)error;

+ (BOOL)isOrientationSupported;

- (BOOL)startOrientationWithError:(NSError **)error;

- (NSData *)worldState;
- (BOOL)restoreWorldState:(NSData *)state;

- (nullable CVPixelBufferRef)copyHighResolutionImageWithError:(NSError **)error
    CF_RETURNS_RETAINED;

- (void)stop;

@property (nonatomic, assign) simd_float3 measuredAcceleration;

- (simd_float4x4)processPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        captureTime:(NSTimeInterval)captureTime
                      deviceRotation:(simd_quatf)deviceRotation;

@property (nonatomic, readonly) NSData *pointCloud;

@property (nonatomic, readonly) NSArray<RevenantARValue *> *planes;

@property (nonatomic, readonly) simd_float4x4 cameraTransform;

@property (nonatomic, readonly) simd_float4x4 deviceTransform;

@property (nonatomic, readonly) CGFloat lightEstimate;

@property (nonatomic, readonly) CGFloat ambientColorTemperature;

@property (nonatomic, readonly) BOOL isTracking;

@property (nonatomic, readonly) CGSize imageResolution;

@property (nonatomic, readonly) NSTimeInterval timestamp;

- (BOOL)raycastFromPoint:(CGPoint)point
                allowing:(NSUInteger)targets
                results:(NSMutableArray<RevenantARValue *> *)results;

- (BOOL)raycastFromOrigin:(simd_float3)origin
                 direction:(simd_float3)direction
                allowing:(NSUInteger)targets
                  results:(NSMutableArray<RevenantARValue *> *)results;

- (BOOL)hitTestPoint:(CGPoint)point
          results:(NSMutableArray<RevenantARValue *> *)results;

- (BOOL)hitTestPoint:(CGPoint)point
    existingPlane:(BOOL)existingPlane
          results:(NSMutableArray<RevenantARValue *> *)results;

@end

@protocol RevenantARTrackerDelegate <NSObject>
- (void)tracker:(RevenantARTracker *)tracker didUpdateWithTimestamp:(NSTimeInterval)timestamp;
@end

NS_ASSUME_NONNULL_END
