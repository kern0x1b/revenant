// CharonARTracker.h - the visual-inertial tracker behind ARSession on a device whose camera and
// gyroscope are the whole of its sensing.
//
// An ARKit session on a device with a camera, a gyroscope and an accelerometer but no LiDAR and no
// structured-depth sensor is a visual-inertial odometry problem, and that is what this is: features
// found in the camera frames, matched between consecutive frames by a patch around a corner, and
// integrated into a camera pose with the gyroscope's rotation. Planes are what a plane *detector*
// reports without measuring: a run of points that stays level and does not turn, which is a surface
// the camera has seen enough of to guess that it is there - a real answer to Apple's "detected"
// rather than its "alignment", which needs the sensor this device does not have.
//
// Nothing here is a stand-in. The camera frames come from the release's own
// AVCaptureVideoDataOutput and the rotation from the release's own CMMotionManager, both measured
// present in the armv7 shared cache of iOS 6.1.3; the tracking, the matching, the integration and the
// plane detection are this file's own.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

/// The identity matrices the library uses, its own.
///
/// simd declares matrix_identity_float3x3 and matrix_identity_float4x4 as `extern const` (the 16.4
/// SDK's usr/include/simd/matrix.h:97-98), so the *definitions* live in libsimd - and the armv7
/// release does not export them. A use of them in this library is therefore a weak import that is
/// NULL on 6.1.3, and reading one is a crash, which is what the 6.1.3 gate named: "weakly imports 2
/// symbols the armv7 release does not export".
///
/// The values are the identity - ones on the diagonal, zeros off it - and they were read out of the
/// host's own libsimd rather than written from memory (the record is
/// .agent-work/runs/identity/values.txt: "float4x4: 1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1").
static const simd_float3x3 CharonARKitIdentityFloat3x3 = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
static const simd_float4x4 CharonARKitIdentityFloat4x4 = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}};
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

/// One point the tracker follows, in normalised image coordinates and in the camera's own frame.
typedef struct {
    simd_float2 image;          ///< where it is in the frame, 0..1 with the origin top left
    simd_float3 camera;         ///< where it is in the camera's frame, metres
    simd_float3 world;          ///< where it is in the world, metres, once the pose is known
    float      scale;           ///< how big it looks, for the size of its patch
    float      depth;           ///< how far off it is, from the turn and its drift across the frame
    uint32_t   identifier;      ///< stable across frames, so an anchor can name it
    uint8_t    age;             ///< frames seen, so a stale point can be dropped
    uint8_t    hits;            ///< frames matched in a row
} CharonARPoint;

/// A surface the plane detector found: a centre, a normal, an extent and how much of it was seen.
typedef struct {
    simd_float3 center;
    simd_float3 normal;         ///< unit, in the world
    simd_float3 extent;         ///< half the width, height and length of what was seen
    float       alignment;      ///< the confidence the detector has in the plane
    uint32_t    identifier;
} CharonARPlane;

/// One hit of a ray against a plane, in world coordinates.
typedef struct {
    simd_float3 position;
    simd_float3 localNormal;
    uint32_t     planeIdentifier;
} CharonARHit;

/// A point cloud sample, which ARKit hands out as indices into a buffer it names itself.
typedef struct {
    simd_float3 position;
} CharonARCloudPoint;

/// A pixel and a camera's intrinsics are the direction a ray leaves the camera in.
static inline simd_float3 CharonRayDirection(simd_float3x3 intrinsics, simd_float4x4 transform, simd_float2 point)
{
    float fx = intrinsics.columns[0][0], cx = intrinsics.columns[2][0];
    float fy = intrinsics.columns[1][1], cy = intrinsics.columns[2][1];
    if (fx == 0 || fy == 0)
        return simd_make_float3(0, 0, -1);
    simd_float3 inCamera = simd_make_float3((point.x - cx) / fx, (point.y - cy) / fy, -1);
    simd_float4 product = simd_mul(transform, (simd_float4){ inCamera.x, inCamera.y, inCamera.z, 0 });
    return simd_normalize(simd_make_float3(product.x, product.y, product.z));
}

/// The matrix of the rotation a quaternion names, in the tracker's own header because the recorded
/// sequence that measures the tracker needs the same one the tracker uses - a differential that
/// measured a different rotation would be measuring its own.
///
/// A C simd has no helper for this: `simd_quatf` is a structure wrapping a vector and carries no
/// operator, so it is the usual construction from the quaternion's components.
static inline simd_float4x4 CharonQuaternionMatrix(simd_quatf q)
{
    float x = q.vector.x, y = q.vector.y, z = q.vector.z, w = q.vector.w;
    simd_float4x4 m;
    m.columns[0] = simd_make_float4(1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0);
    m.columns[1] = simd_make_float4(2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0);
    m.columns[2] = simd_make_float4(2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0);
    m.columns[3] = simd_make_float4(0, 0, 0, 1);
    return m;
}

@protocol CharonARTrackerDelegate;

/// The tracker. One per session; a session owns it and asks it for a pose.
@interface CharonARValue : NSObject

/// A plane or a hit, carried out of the tracker as an object.
///
/// These are structs that hold SIMD vectors, and `@encode` cannot describe an extended vector type
/// on this target - it answers that the type's encoding is incomplete - so the bytes travel in a
/// box object with a declared ivar rather than in an NSValue, whose `objCType` would have to name
/// the struct. Reading the struct back is `getValue:`, and the size is the struct's own.
- (instancetype)initWithBytes:(const void *)bytes size:(size_t)size NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Copies the struct out. NO is answered when the box holds fewer bytes than the struct needs,
/// which is what a box of a different struct is.
- (BOOL)getValue:(void *)value;

@property (nonatomic, readonly) size_t size;

@end

@interface CharonARTracker : NSObject

/// Whether the camera and the gyroscope this needs are both really there. ARKit's own
/// `+[ARWorldTrackingConfiguration isSupported]` asks the same question.
+ (BOOL)isSupported;

/// Whether the front camera can be asked for, which the body and face work would need.
+ (BOOL)hasFrontCamera;

/// The camera ARKit would capture from, or nil when there is none. This is the only place in the
/// library that enumerates cameras, so `+[ARConfiguration configurableCaptureDeviceForPrimaryCamera]`
/// and the video formats answer from the same enumeration the session captures with.
+ (nullable AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;

/// Every format the given camera can be configured to, as AVCaptureVideoDataOutput would list them.
+ (NSArray<AVCaptureDeviceFormat *> *)supportedCaptureFormatsForPosition:(AVCaptureDevicePosition)position;

/// The camera's own intrinsics for a frame of the given size: the focal length in pixels and the
/// principal point, in the order the framework's `simd_float3x3` puts them.
///
/// The camera states how wide it sees - `AVCaptureDeviceFormat`'s field of view - and the size of
/// the frame says how many pixels that width is, which between them fix the focal length in pixels
/// and the principal point. A camera that states no field of view has nothing to build them from,
/// and the answer is the matrix of ones, which projects nothing to anywhere.
+ (simd_float3x3)cameraIntrinsicsForResolution:(CGSize)resolution;

/// The calibration to use where there is no camera to ask.
///
/// A camera and a gyroscope cannot recover a metric reconstruction on their own: the depth of a
/// point and its size in the picture trade off exactly, and what breaks the trade-off is the camera's
/// own focal length. A device gets that from `AVCaptureDeviceFormat`'s field of view, read above; a
/// recorded sequence has no camera to read, and the calibration is recorded beside the frames. This
/// is where such a recording hands it over, and it is the same matrix `cameraIntrinsicsForResolution:`
/// would have built - the same three numbers, from the same field of view.
+ (void)useCameraIntrinsics:(simd_float3x3)intrinsics;

@property (nonatomic, weak, nullable) id<CharonARTrackerDelegate> delegate;

/// Starts the camera and the gyroscope. `error` is filled in and NO answered when either is
/// refused - the camera by the application's own authorisation, the gyroscope by hardware.
- (BOOL)startWithError:(NSError **)error;

/// Whether the gyroscope is there for orientation tracking, which needs nothing else.
+ (BOOL)isOrientationSupported;

/// Starts the gyroscope alone, and reports the device's attitude as the camera's pose: the orientation tracking that
/// AROrientationTrackingConfiguration asks for. There is no picture and no camera, so the world is not built.
- (BOOL)startOrientationWithError:(NSError **)error;

/// The world the tracker has placed, as bytes an archive keeps (the points, the planes and the identifiers' counter),
/// and the state an archive gives back to a session that starts from it. See CharonARTracker.m for the format.
- (NSData *)worldState;
- (BOOL)restoreWorldState:(NSData *)state;

/// A still photograph of the scene, at the largest size the primary camera's still output will give.
///
/// This is the same camera the session captures from, asked for a single frame rather than a
/// stream, which is what a high-resolution frame is: the same optics, the same pose, the same
/// moment. The still output of this release's AVFoundation takes the picture at the camera's own
/// active format, so the size is whatever the video output was configured for and nothing larger is
/// claimed. `error` is filled in and NULL answered when the output could not take the picture.
- (nullable CVPixelBufferRef)copyHighResolutionImageWithError:(NSError **)error
    CF_RETURNS_RETAINED;

/// Stops both, and forgets the world.
- (void)stop;

/// The camera's own pose for the frame just handed in: a 4x4 from the camera's space to the
/// world's, which is the transform every anchor and every ray is expressed in.
/// The specific force the accelerometer measured for this frame, in the device's own axes.
///
/// This is what an accelerometer reads: the acceleration the device is undergoing, with gravity
/// still in it, because gravity is an acceleration too. It is the same reading from
/// CMMotionManager's accelerometer data on a device, and the same reading the tracker removes
/// gravity from using the attitude above, which is why the attitude is the thing that has to be
/// right first: with the attitude exact, gravity comes out exactly.
@property (nonatomic, assign) simd_float3 measuredAcceleration;

- (simd_float4x4)processPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        captureTime:(NSTimeInterval)captureTime
                      deviceRotation:(simd_quatf)deviceRotation;

/// The points of the current frame, which is the point cloud an anchor is made of.
@property (nonatomic, readonly) NSData *pointCloud;

/// The planes the detector has, which is the geometry a plane anchor is made of.
@property (nonatomic, readonly) NSArray<CharonARValue *> *planes;

/// The pose of the camera at the capture time of the current frame, as a `simd_float4x4`.
@property (nonatomic, readonly) simd_float4x4 cameraTransform;

/// The device motion at the capture time of the current frame, in the world's frame.
@property (nonatomic, readonly) simd_float4x4 deviceTransform;

/// The intensity of the ambient light in the current frame, 1000 being the neutral Apple uses.
@property (nonatomic, readonly) CGFloat lightEstimate;

/// The ambient colour temperature in kelvin, 6500 being the neutral Apple uses.
@property (nonatomic, readonly) CGFloat ambientColorTemperature;

/// Whether the camera sees a tracked feature in the current frame, which
/// `ARCamera.trackingState` reports as `ARCameraTrackingStateLimited` when it does not.
@property (nonatomic, readonly) BOOL isTracking;

/// The size of the frame the camera is giving, in pixels.
@property (nonatomic, readonly) CGSize imageResolution;

/// The capture time of the current frame, in seconds since the session started.
@property (nonatomic, readonly) NSTimeInterval timestamp;

/// A ray from the camera through a point of the frame, in world coordinates.
- (BOOL)raycastFromPoint:(CGPoint)point
                allowing:(NSUInteger)targets
                results:(NSMutableArray<CharonARValue *> *)results;

/// A ray from a world point along a world direction.
- (BOOL)raycastFromOrigin:(simd_float3)origin
                 direction:(simd_float3)direction
                allowing:(NSUInteger)targets
                  results:(NSMutableArray<CharonARValue *> *)results;

/// A ray in the camera's own space, which is what a hit test against a feature is.
- (BOOL)hitTestPoint:(CGPoint)point
          results:(NSMutableArray<CharonARValue *> *)results;

/// A ray against the planes only, which is what Apple's "existingPlaneGeometry" asks for.
- (BOOL)hitTestPoint:(CGPoint)point
    existingPlane:(BOOL)existingPlane
          results:(NSMutableArray<CharonARValue *> *)results;

@end

/// What the tracker tells its owner, once per frame.
@protocol CharonARTrackerDelegate <NSObject>
- (void)tracker:(CharonARTracker *)tracker didUpdateWithTimestamp:(NSTimeInterval)timestamp;
@end

NS_ASSUME_NONNULL_END
