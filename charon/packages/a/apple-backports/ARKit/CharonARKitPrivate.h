// CharonARKitPrivate.h - the declarations two of the ARKit files share, which the SDK's headers
// do not carry because the framework keeps them to itself. Nothing here is API: an application
// never sees these names, and the registry weighs none of them.

#import <ARKit/ARKit.h>
#import <simd/simd.h>
#import <math.h>

#import <SceneKit/SceneKit.h>

#import "CharonARTracker.h"

NS_ASSUME_NONNULL_BEGIN

/// A plane is a quad, so its geometry is four corners and the six indices that join them.
enum { kPlaneQuadCorners = 4, kPlaneQuadTriangles = 6 };

/// A struct across a keyed coder.
///
/// The anchored values here are structs of SIMD vectors, and `@encode` cannot describe one, so the
/// bytes go across as bytes. The keyed pair is `encodeBytes:length:forKey:` and
/// `decodeBytesForKey:returnedLength:`, and the length is checked on the way back because a coder
/// that holds fewer bytes than the struct needs is a different class's archive, not this one's.
static void CharonEncodeStruct(NSCoder *coder, NSString *key, const void *bytes, size_t size)
{
    [coder encodeBytes:(const uint8_t *)bytes length:size forKey:key];
}

static BOOL CharonDecodeStruct(NSCoder *coder, NSString *key, void *bytes, size_t size)
{
    NSUInteger length = 0;
    const uint8_t *decoded = [coder decodeBytesForKey:key returnedLength:&length];
    if (!decoded || length < size)
        return NO;
    memcpy(bytes, decoded, size);
    return YES;
}

/// A matrix turned around, by Gauss-Jordan elimination on the augmented matrix.
///
/// `simd_inverse` is not usable here: on this clang it compiles to a call to `_invert_f4`, which the
/// libSystem of iOS 6.1.3 does not export, so a dylib that calls it is refused at the gate with the
/// import unresolvable against the device. The same elimination the six-parameter solve does, over
/// sixteen unknowns, is written out here instead.
///
/// A matrix with no turn-around is one whose rows are dependent, and there is no inverse to return;
/// NO is answered and the caller keeps what it had, which for a pose that can only mean a degenerate
/// frame, and for a projection that can only mean a viewport of no size.
static inline BOOL CharonInvert4x4(simd_float4x4 m, simd_float4x4 *out)
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

/// `simd_inverse` with the degenerate case answered rather than left to whatever the libSystem of the
/// release happens to do: a matrix that cannot be turned around comes back as the identity, which
/// projects a frame to the middle of its picture and leaves a pose where it was.
static inline simd_float4x4 CharonInverse(simd_float4x4 m)
{
    simd_float4x4 inverse = CharonARKitIdentityFloat4x4;
    if (!CharonInvert4x4(m, &inverse))
        return CharonARKitIdentityFloat4x4;
    return inverse;
}

@interface ARConfiguration (CharonPrivate)
/// The base class's own initialiser under a name a subclass can call. The SDK marks `-init`
/// unavailable on `ARConfiguration` because the class is abstract, and an unavailable method is
/// unreachable from the subclass that would initialise it, so the same initialiser is reached here
/// instead. It is not API: nothing outside this library calls it, and a caller cannot create an
/// abstract configuration in the first place.
- (instancetype)initCharonCommon;
@end

@interface ARVideoFormat (CharonPrivate)
/// Built from a format the primary camera really has, which the tracker enumerates.
- (instancetype)initWithCaptureFormat:(AVCaptureDeviceFormat *)format;
@end

@interface ARPlaneAnchor (CharonPrivate)
/// Built from a plane the detector found, which the tracker carries as its own struct.
- (instancetype)initWithPlaneValue:(CharonARValue *)value;
@end

@interface ARPlaneGeometry (CharonPrivate)
/// Built from one plane the detector found, which the tracker carries as its own struct.
- (instancetype)initWithPlaneValue:(CharonARValue *)value;
@end

@interface ARHitTestResult (CharonPrivate)
- (instancetype)initWithHitValue:(CharonARValue *)value;
@end

@interface ARPointCloud (CharonPrivate)
/// Built from the tracker's own samples, which are the same three floats a point cloud is.
- (instancetype)initWithPoints:(NSData *)points count:(NSUInteger)count;
@end

@interface ARRaycastQuery (CharonPrivate)
/// Built from a ray in the world, which is what a caller asking for a raycast gives the framework.
- (instancetype)initWithOrigin:(simd_float3)origin
                    direction:(simd_float3)direction
             allowingTarget:(ARRaycastTarget)target
                    alignment:(ARRaycastTargetAlignment)alignment;
@end

@interface ARWorldMap (CharonPrivate)
/// Built from the anchors a session is carrying and the points behind them.
- (instancetype)initWithAnchors:(NSArray<ARAnchor *> *)anchors
                   featurePoints:(nullable ARPointCloud *)featurePoints;
/// The tracker's own world, as CharonARTracker's worldState gives it: the points and planes the tracker placed. A map
/// archives it with itself, and a session that starts from the map restores it into the tracker.
- (nullable NSData *)trackerState;
- (void)setTrackerState:(nullable NSData *)trackerState;
@end

@interface ARTrackedRaycast (CharonPrivate)
/// The query a tracked raycast keeps casting, which the session needs in order to cast it again.
@property (nonatomic, strong) ARRaycastQuery *query;
- (instancetype)initWithQuery:(ARRaycastQuery *)query;
@end

@interface ARRaycastResult (CharonPrivate)
- (instancetype)initWithHitValue:(CharonARValue *)value;
@end

@interface ARFrame (CharonPrivate)
- (instancetype)initWithCameraTransform:(simd_float4x4)cameraTransform
                        deviceTransform:(simd_float4x4)deviceTransform
                  cameraTransformTime:(NSTimeInterval)timestamp
                         imageResolution:(CGSize)resolution
                           lightEstimate:(CGFloat)lightEstimate
                ambientColorTemperature:(CGFloat)ambientColorTemperature
                               tracking:(BOOL)tracking
                         hitTestTracker:(CharonARTracker *)hitTestTracker;

/// Adds an anchor to this frame, which the session does once it has seen the world.
- (void)addAnchor:(ARAnchor *)anchor;
@end

@interface ARAnchor (CharonPrivate)
/// The session names an anchor the application adds, because a name is what the application then
/// finds it by.
@property (nonatomic, copy) NSUUID *identifier;

/// The same anchor in a different world frame, which is what moving the world's origin does to
/// everything in it. A copy is made because an anchor's own transform is readonly and the
/// application placed it where it placed it.
- (ARAnchor *)anchorByApplyingOrigin:(simd_float4x4)origin;
@end

NS_ASSUME_NONNULL_END

/// The view's renderer delegate is the SDK's own, declared at ARSCNView.h:104. It is not redeclared
/// here - a duplicate protocol definition is ignored by the compiler and warns - and what the port
/// owes it is smaller and more useful: the metadata has to exist and the view has to actually call
/// those five methods, because a row that says `implemented` and describes a view that never asks its
/// delegate for a node is a false row.
///
/// The metadata is emitted by `ARSCNView11.m`, in the object that carries the class and with it the
/// protocol's own release, and the calls are made where a pairing is made, changed and broken.
