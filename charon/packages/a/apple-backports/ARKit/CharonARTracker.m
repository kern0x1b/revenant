#import "CharonARTracker.h"

#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

#if CHARON_TRACKER_OFFLINE
#define CHARON_NO_MOTION 1
#define CHARON_NO_CAMERA 1
#else
#import <CoreMotion/CoreMotion.h>
#endif

#import <math.h>
#import <stdlib.h>
#import <string.h>

#pragma mark - The error an application is told when the hardware is not there

NSString * const CharonARTrackerErrorDomain = @"com.apple.arkit.execution";

typedef NS_ENUM(NSInteger, CharonARTrackerError) {
    CharonARTrackerErrorCameraUnavailable = 1,
    CharonARTrackerErrorCameraDenied     = 2,
    CharonARTrackerErrorMotionUnavailable = 3,
};

static NSError *CharonTrackerError(CharonARTrackerError code, NSString *reason)
{
    return [NSError errorWithDomain:CharonARTrackerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

typedef struct {
    simd_float3 deltaVelocity;
    simd_float3 deltaPosition;
    float       duration;
} CharonPreintegration;

static CharonPreintegration CharonPreintegrateInterval(simd_float3 specificForceWorld, float dt)
{
    CharonPreintegration out;
    out.deltaVelocity = simd_make_float3(specificForceWorld.x * dt, specificForceWorld.y * dt,
                                        specificForceWorld.z * dt);
    out.deltaPosition = simd_make_float3(0.5f * specificForceWorld.x * dt * dt,
                                        0.5f * specificForceWorld.y * dt * dt,
                                        0.5f * specificForceWorld.z * dt * dt);
    out.duration = dt;
    return out;
}

typedef struct {
    simd_float3 bias;
    float       covariance[3][3];
    float       uncertainty;
} CharonAccelerationBias;

typedef struct {
    float skew[3][3];
    float bracket[3][3];
    float duration;
} CharonBiasTerms;

static void CharonUpdateAccelerationBias(CharonAccelerationBias *state, const CharonBiasTerms *terms,
                                         simd_float3 residual)
{
    float H[3][3];
    for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
            float sum = 0;
            for (int k = 0; k < 3; k++)
                sum += terms->skew[row][k] * terms->bracket[k][col];
            H[row][col] = 0.5f * sum;
        }
    }

    float S[3][3];
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) {
            float hp = 0;
            for (int k = 0; k < 3; k++)
                hp += H[i][k] * state->covariance[k][j];
            S[i][j] = hp;
        }
    for (int i = 0; i < 3; i++)
        S[i][i] += state->uncertainty;

    float a[3][4] = {{ S[0][0], S[0][1], S[0][2], residual.x },
                     { S[1][0], S[1][1], S[1][2], residual.y },
                     { S[2][0], S[2][1], S[2][2], residual.z }};
    for (int column = 0; column < 3; column++) {
        int pivot = column;
        for (int row = column + 1; row < 3; row++)
            if (fabsf(a[row][column]) > fabsf(a[pivot][column]))
                pivot = row;
        if (fabsf(a[pivot][column]) < 1e-9f)
            return;
        if (pivot != column) {
            for (int k = 0; k < 4; k++) {
                float swap = a[column][k];
                a[column][k] = a[pivot][k];
                a[pivot][k] = swap;
            }
        }
        for (int row = column + 1; row < 3; row++) {
            float factor = a[row][column] / a[column][column];
            for (int k = column; k < 4; k++)
                a[row][k] -= factor * a[column][k];
        }
    }
    float gain[3][3];
    for (int column = 0; column < 3; column++) {
        for (int k = 0; k < 3; k++) {
            float sum = 0;
            for (int row = 0; row < 3; row++)
                if (row == column)
                    sum += state->covariance[column][row] * H[row][k];
            gain[column][k] = sum;
        }
    }
    float step[3] = { 0, 0, 0 };
    for (int row = 0; row < 3; row++) {
        float sum = 0;
        for (int k = 0; k < 3; k++)
            sum += gain[row][k] * (k == 0 ? residual.x : (k == 1 ? residual.y : residual.z));
        step[row] = fmaxf(-0.5f, fminf(0.5f, sum));
    }
    state->bias = simd_make_float3(state->bias.x + step[0], state->bias.y + step[1],
                                   state->bias.z + step[2]);

    float updated[3][3];
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) {
            float kh = 0;
            for (int k = 0; k < 3; k++)
                kh += gain[i][k] * H[k][j];
            float sum = 0;
            for (int k = 0; k < 3; k++)
                sum += (i == k ? 1.0f : 0.0f) * state->covariance[k][j] - kh * state->covariance[k][j] * 0.0f;
            updated[i][j] = sum;
        }
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            state->covariance[i][j] = fmaxf(0.0f, updated[i][j]);
}

#pragma mark - The small linear algebra the tracking needs

static inline simd_float3 CharonAlongRay(simd_float3 origin, simd_float3 direction, float distance)
{
    return origin + direction * distance;
}

static inline simd_float3 CharonNormalized(simd_float3 v)
{
    float length = simd_length(v);
    return length > 1e-8f ? v / length : (simd_float3){0, 0, 0};
}

static simd_float4 CharonQuaternionProduct(simd_float4 lhs, simd_float4 rhs)
{
    float x1 = lhs.x, y1 = lhs.y, z1 = lhs.z, w1 = lhs.w;
    float x2 = rhs.x, y2 = rhs.y, z2 = rhs.z, w2 = rhs.w;
    return (simd_float4){
        w1 * x2 + x1 * w2 + (y1 * z2 - z1 * y2),
        w1 * y2 + y1 * w2 + (z1 * x2 - x1 * z2),
        w1 * z2 + z1 * w2 + (x1 * y2 - y1 * x2),
        w1 * w2 - (x1 * x2 + y1 * y2 + z1 * z2)
    };
}

static const simd_float3 CharonGravity = { 0, 0, -9.80665f };

static simd_quatf CharonRotationBetween(simd_quatf from, simd_quatf to)
{
    simd_quatf inverse = simd_normalize(simd_conjugate(from));
    simd_float4 product = CharonQuaternionProduct(inverse.vector, to.vector);
    return simd_normalize(simd_quaternion(product.x, product.y, product.z, product.w));
}

static simd_float4x4 CharonPoseIncrement(simd_float3 w, simd_float3 t)
{
    float angle = simd_length(w);
    float half = angle / 2.0f;
    simd_quatf rotation;
    if (angle < 1e-8f)
        rotation.vector = simd_make_float4(0, 0, 0, 1);
    else
        rotation.vector = simd_make_float4(w.x / angle * sinf(half), w.y / angle * sinf(half),
                                           w.z / angle * sinf(half), cosf(half));
    simd_float4x4 increment = CharonQuaternionMatrix(rotation);
    increment.columns[3] = simd_make_float4(t.x, t.y, t.z, 1);
    return increment;
}

static simd_float4x4 simd_matrix_inverse_local(simd_float4x4 m)
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
            return CharonARKitIdentityFloat4x4;
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
    simd_float4x4 inverse = CharonARKitIdentityFloat4x4;
    for (int row = 0; row < 4; row++) {
        float scale = 1.0f / a[row][row];
        for (int column = 0; column < 4; column++)
            inverse.columns[column][row] = a[row][4 + column] * scale;
    }
    return inverse;
}

static BOOL CharonProject(simd_float4x4 pose, simd_float3x3 intrinsics, simd_float3 world,
                          simd_float2 *pixel)
{
    simd_float4 camera = simd_mul(simd_matrix_inverse_local(pose), simd_make_float4(world.x, world.y, world.z, 1));
    if (camera.z <= 1e-4f)
        return NO;
    float depth = camera.z;
    float u = camera.x * intrinsics.columns[0][0] / depth + intrinsics.columns[2][0];
    float v = camera.y * intrinsics.columns[1][1] / depth + intrinsics.columns[2][1];
    if (!isfinite(u) || !isfinite(v))
        return NO;
    pixel->x = u;
    pixel->y = v;
    return YES;
}

static BOOL CharonSolveSix(float A[6][6], float b[6], float out[6])
{
    for (int column = 0; column < 6; column++) {
        int pivot = column;
        for (int row = column + 1; row < 6; row++)
            if (fabsf(A[row][column]) > fabsf(A[pivot][column]))
                pivot = row;
        if (fabsf(A[pivot][column]) < 1e-9f)
            return NO;
        if (pivot != column) {
            for (int k = 0; k < 6; k++) {
                float swap = A[column][k];
                A[column][k] = A[pivot][k];
                A[pivot][k] = swap;
            }
            float swap = b[column];
            b[column] = b[pivot];
            b[pivot] = swap;
        }
        for (int row = column + 1; row < 6; row++) {
            float factor = A[row][column] / A[column][column];
            if (factor == 0)
                continue;
            for (int k = column; k < 6; k++)
                A[row][k] -= factor * A[column][k];
            b[row] -= factor * b[column];
        }
    }
    for (int row = 5; row >= 0; row--) {
        float sum = b[row];
        for (int k = row + 1; k < 6; k++)
            sum -= A[row][k] * out[k];
        out[row] = sum / A[row][row];
    }
    for (int row = 0; row < 6; row++)
        if (!isfinite(out[row]))
            return NO;
    return YES;
}

#pragma mark - The tracker

@implementation CharonARValue
{
    NSMutableData *_bytes;
    size_t _size;
}

@synthesize size = _size;

- (instancetype)initWithBytes:(const void *)bytes size:(size_t)size
{
    self = [super init];
    if (!self)
        return nil;
    _bytes = [NSMutableData dataWithBytes:bytes length:size];
    _size = size;
    return self;
}

- (BOOL)getValue:(void *)value
{
    if (_bytes.length < self.size)
        return NO;
    memcpy(value, _bytes.bytes, self.size);
    return YES;
}

@end

static const char CharonWorldStateMagic[8] = "CHWORLD1";
static const NSUInteger CharonWorldStateHeaderBytes = 8 + 4 + 4;
static const NSUInteger CharonWorldStatePointBytes = 46;
static const NSUInteger CharonWorldStatePlaneBytes = 44;

static void CharonAppendUInt32(NSMutableData *out, uint32_t value)
{
    uint8_t bytes[4] = { value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff };
    [out appendBytes:bytes length:4];
}

static void CharonAppendFloat(NSMutableData *out, float value)
{
    uint32_t bits;
    memcpy(&bits, &value, sizeof bits);
    CharonAppendUInt32(out, bits);
}

static void CharonAppendVector3(NSMutableData *out, simd_float3 value)
{
    CharonAppendFloat(out, value.x);
    CharonAppendFloat(out, value.y);
    CharonAppendFloat(out, value.z);
}

static uint32_t CharonReadUInt32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static float CharonReadFloat(const uint8_t *p)
{
    uint32_t bits = CharonReadUInt32(p);
    float value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

static simd_float3 CharonReadVector3(const uint8_t *p)
{
    return simd_make_float3(CharonReadFloat(p), CharonReadFloat(p + 4), CharonReadFloat(p + 8));
}

@interface CharonARTracker () <AVCaptureVideoDataOutputSampleBufferDelegate>
@end

@implementation CharonARTracker
{
    AVCaptureSession *_capture;
    AVCaptureConnection *_connection;
    AVCaptureVideoOrientation _videoOrientation;
    AVCaptureVideoDataOutput *_output;
    dispatch_queue_t _frameQueue;
    AVCaptureDeviceInput *_input;
#if !CHARON_NO_MOTION
    CMMotionManager *_motion;
    NSOperationQueue *_motionQueue;
#endif
    BOOL _running;
    simd_quatf _lastDeviceRotation;

    NSMutableData *_worldPoints;
    NSMutableArray<CharonARValue *> *_planes;
    uint32_t _nextIdentifier;

    simd_float4x4 _cameraTransform;
    simd_float4x4 _deviceTransform;
    simd_quatf _lastRotation;
    NSTimeInterval _timestamp;
    CGSize _resolution;
    CGFloat _lightEstimate;
    CGFloat _ambientColorTemperature;
    BOOL _tracking;
    BOOL _havePose;
    simd_float4x4 _previousPose;
    simd_float3 _measuredAcceleration;
    simd_float3 _velocity;
    double _lastCaptureTime;
    CharonAccelerationBias _bias;
    BOOL _haveTimestamp;

    CharonARPoint *_points;
    NSUInteger _pointCount;
    CharonARPoint *_candidates;
    NSUInteger _candidateCount;
    CharonARPoint *_previous;
    NSUInteger _previousCount;

    uint8_t *_luma;
    NSUInteger _lumaWidth;
    NSUInteger _lumaHeight;
}

    @synthesize measuredAcceleration = _measuredAcceleration;

static simd_float3x3 CharonRecordedIntrinsics = { 0 };

+ (void)useCameraIntrinsics:(simd_float3x3)intrinsics
{
    CharonRecordedIntrinsics = intrinsics;
}

+ (simd_float3x3)cameraIntrinsicsForResolution:(CGSize)resolution
{
#if CHARON_NO_CAMERA
    return CharonRecordedIntrinsics;
#else
    AVCaptureDevice *camera = [self captureDeviceForPosition:AVCaptureDevicePositionBack];
    AVCaptureDeviceFormat *format = camera.activeFormat ?: camera.formats.firstObject;
    CGFloat fieldOfView = format ? format.videoFieldOfView : 0;
    if (resolution.width <= 0 || resolution.height <= 0 || fieldOfView <= 0)
        return CharonARKitIdentityFloat3x3;

    CGFloat focalLength = (resolution.width / 2) / tanf((float)(fieldOfView * M_PI / 360.0));
    simd_float3x3 intrinsics;
    intrinsics.columns[0] = simd_make_float3(focalLength, 0, 0);
    intrinsics.columns[1] = simd_make_float3(0, focalLength, 0);
    intrinsics.columns[2] = simd_make_float3(resolution.width / 2, resolution.height / 2, 1);
    return intrinsics;
#endif
}

    @synthesize delegate = _delegate;
    @synthesize pointCloud = _pointCloud;
    @synthesize planes = _planes;
    @synthesize cameraTransform = _cameraTransform;
    @synthesize deviceTransform = _deviceTransform;
    @synthesize lightEstimate = _lightEstimate;
    @synthesize ambientColorTemperature = _ambientColorTemperature;
    @synthesize isTracking = _isTracking;
    @synthesize imageResolution = _imageResolution;
    @synthesize timestamp = _timestamp;


+ (BOOL)isSupported
{
#if !CHARON_NO_CAMERA
    if (![AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo])
        return NO;
#endif
#if CHARON_NO_MOTION
    return YES;
#else
    return [CMMotionManager new].deviceMotionAvailable;
#endif
}

+ (BOOL)hasFrontCamera
{
#if CHARON_NO_CAMERA
    return NO;
#else
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([device hasMediaType:AVMediaTypeVideo] && device.position == AVCaptureDevicePositionFront)
            return YES;
    }
    return NO;
#endif
}

+ (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position
{
#if CHARON_NO_CAMERA
    return nil;
#else
    AVCaptureDevice *fallback = nil;
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (![device hasMediaType:AVMediaTypeVideo])
            continue;
        if (device.position == position)
            return device;
        if (device.position == AVCaptureDevicePositionUnspecified && !fallback)
            fallback = device;
    }
    if (position == AVCaptureDevicePositionBack)
        return fallback;
    return nil;
#endif
}

+ (NSArray<AVCaptureDeviceFormat *> *)supportedCaptureFormatsForPosition:(AVCaptureDevicePosition)position
{
#if CHARON_NO_CAMERA
    return @[];
#else
    AVCaptureDevice *device = [self captureDeviceForPosition:position];
    return device ? device.formats : @[];
#endif
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _worldPoints = [NSMutableData data];
    _lastDeviceRotation = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
    _planes = [NSMutableArray array];
    _nextIdentifier = 1;
    _cameraTransform = CharonARKitIdentityFloat4x4;
    _deviceTransform = CharonARKitIdentityFloat4x4;
    _lastRotation = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
    _resolution = CGSizeZero;
    _lightEstimate = 1000;
    _ambientColorTemperature = 6500;
    _tracking = NO;
    _timestamp = 0;
    _pointCount = 0;
    _haveTimestamp = NO;
    _bias.uncertainty = 0.05f;
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            _bias.covariance[i][j] = (i == j) ? 1.0f : 0.0f;
    _previousCount = 0;
    return self;
}

- (void)dealloc
{
    [self stop];
    free(_points);
    free(_previous);
    free(_candidates);
    free(_luma);
}

#pragma mark - Starting and stopping

- (void)setLastDeviceRotation:(simd_quatf)rotation
{
    @synchronized (self) {
        _lastDeviceRotation = rotation;
    }
}

- (simd_quatf)lastDeviceRotation
{
    @synchronized (self) {
        return _lastDeviceRotation;
    }
}

- (BOOL)startWithError:(NSError **)error
{
    if (_running)
        return YES;

#if CHARON_NO_MOTION
    _running = YES;
    return YES;
#else
    _motion = [[CMMotionManager alloc] init];
    if (!_motion || !_motion.deviceMotionAvailable) {
        _motion = nil;
        if (error)
            *error = CharonTrackerError(CharonARTrackerErrorMotionUnavailable,
                                        @"This device has no gyroscope or accelerometer, so an "
                                        @"augmented-reality session cannot be tracked.");
        return NO;
    }
    if (![AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]) {
        if (error)
            *error = CharonTrackerError(CharonARTrackerErrorCameraUnavailable,
                                        @"This device has no camera.");
        return NO;
    }

#if CHARON_NO_CAMERA
    _running = YES;
    return YES;
#else
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *inputError = nil;
    _input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&inputError];
    if (!_input) {
        _input = nil;
        if (error)
            *error = inputError ?: CharonTrackerError(CharonARTrackerErrorCameraDenied,
                                                      @"The camera cannot be opened.");
        return NO;
    }

    _capture = [[AVCaptureSession alloc] init];
    if (![_capture canAddInput:_input]) {
        _capture = nil;
        _input = nil;
        if (error)
            *error = CharonTrackerError(CharonARTrackerErrorCameraDenied,
                                        @"The camera cannot be added to a capture session.");
        return NO;
    }
    [_capture addInput:_input];

    _output = [[AVCaptureVideoDataOutput alloc] init];
    if ([_output isKindOfClass:NSClassFromString(@"AVCaptureVideoDataOutput")])
        [_output setAlwaysDiscardsLateVideoFrames:YES];
    if ([_capture canAddOutput:_output]) {
        [_capture addOutput:_output];
    } else {
        _output = nil;
        if (error)
            *error = CharonTrackerError(CharonARTrackerErrorCameraDenied,
                                        @"The camera cannot give frames to track.");
        return NO;
    }
    _frameQueue = dispatch_queue_create("space.kern0x1b.arkit.frames", DISPATCH_QUEUE_SERIAL);
    [_output setSampleBufferDelegate:self queue:_frameQueue];
    [_capture startRunning];

    [_motion setDeviceMotionUpdateInterval:1.0 / 30.0];
    _motionQueue = [[NSOperationQueue alloc] init];
    _motionQueue.maxConcurrentOperationCount = 1;
    _motionQueue.name = @"space.kern0x1b.arkit.motion";
    [_motion startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                 toQueue:_motionQueue
                                             withHandler:^(CMDeviceMotion *motion, NSError *motionError) {
        (void)motionError;
        if (motion) {
            CMQuaternion q = motion.attitude.quaternion;
            [self setLastDeviceRotation:simd_quaternion((float)q.x, (float)q.y, (float)q.z, (float)q.w)];
        }
    }];

    _running = YES;
    return YES;
#endif
#endif
}

+ (BOOL)isOrientationSupported
{
    return [[CMMotionManager alloc] init].deviceMotionAvailable;
}

- (BOOL)startOrientationWithError:(NSError **)error
{
    if (_running)
        return YES;
#if CHARON_NO_MOTION
    if (error)
        *error = CharonTrackerError(CharonARTrackerErrorMotionUnavailable,
                                    @"This build has no motion, so orientation cannot be tracked.");
    return NO;
#else
    _motion = [[CMMotionManager alloc] init];
    if (!_motion || !_motion.deviceMotionAvailable) {
        _motion = nil;
        if (error)
            *error = CharonTrackerError(CharonARTrackerErrorMotionUnavailable,
                                        @"This device has no gyroscope, so its orientation cannot be tracked.");
        return NO;
    }
    [_motion setDeviceMotionUpdateInterval:1.0 / 30.0];
    _motionQueue = [[NSOperationQueue alloc] init];
    _motionQueue.maxConcurrentOperationCount = 1;
    _motionQueue.name = @"space.kern0x1b.arkit.motion";
    [_motion startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                 toQueue:_motionQueue
                                             withHandler:^(CMDeviceMotion *motion, NSError *motionError) {
        (void)motionError;
        if (motion)
            [self updateOrientationFromMotion:motion];
    }];
    _running = YES;
    return YES;
#endif
}

- (void)updateOrientationFromMotion:(CMDeviceMotion *)motion
{
    CMQuaternion q = motion.attitude.quaternion;
    simd_quatf rotation = simd_normalize(simd_quaternion((float)q.x, (float)q.y, (float)q.z, (float)q.w));
    [self setLastDeviceRotation:rotation];
    simd_float4x4 pose = CharonQuaternionMatrix(rotation);
    _cameraTransform = pose;
    _deviceTransform = pose;
    _timestamp = motion.timestamp;
    _tracking = YES;
    if ([_delegate respondsToSelector:@selector(tracker:didUpdateWithTimestamp:)])
        [_delegate tracker:self didUpdateWithTimestamp:motion.timestamp];
}

#pragma mark - Frames from the camera

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    (void)output;
    (void)connection;
    CVPixelBufferRef pixels = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixels)
        return;
    NSTimeInterval captureTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
    [self processPixelBuffer:pixels captureTime:captureTime deviceRotation:[self lastDeviceRotation]];
}

#pragma mark - The world as an archive holds it

- (NSData *)worldState
{
    NSMutableData *out = [NSMutableData dataWithBytes:CharonWorldStateMagic length:sizeof CharonWorldStateMagic];
    const NSUInteger count = _worldPoints.length / sizeof(CharonARPoint);
    CharonAppendUInt32(out, (uint32_t)count);
    CharonAppendUInt32(out, (uint32_t)_planes.count);
    const CharonARPoint *points = (const CharonARPoint *)_worldPoints.bytes;
    for (NSUInteger i = 0; i < count; i++) {
        const CharonARPoint *p = &points[i];
        CharonAppendFloat(out, p->image.x);
        CharonAppendFloat(out, p->image.y);
        CharonAppendVector3(out, p->camera);
        CharonAppendVector3(out, p->world);
        CharonAppendFloat(out, p->scale);
        CharonAppendFloat(out, p->depth);
        CharonAppendUInt32(out, p->identifier);
        uint8_t counts[2] = { p->age, p->hits };
        [out appendBytes:counts length:2];
    }
    for (CharonARValue *value in _planes) {
        CharonARPlane plane;
        memset(&plane, 0, sizeof plane);
        if (![value getValue:&plane])
            continue;
        CharonAppendVector3(out, plane.center);
        CharonAppendVector3(out, plane.normal);
        CharonAppendVector3(out, plane.extent);
        CharonAppendFloat(out, plane.alignment);
        CharonAppendUInt32(out, plane.identifier);
    }
    return out;
}

- (BOOL)restoreWorldState:(NSData *)state
{
    const NSUInteger length = state.length;
    if (length < CharonWorldStateHeaderBytes)
        return NO;
    const uint8_t *bytes = state.bytes;
    if (memcmp(bytes, CharonWorldStateMagic, sizeof CharonWorldStateMagic) != 0)
        return NO;
    const NSUInteger pointCount = CharonReadUInt32(bytes + 8);
    const NSUInteger planeCount = CharonReadUInt32(bytes + 12);
    if (length != CharonWorldStateHeaderBytes + pointCount * CharonWorldStatePointBytes + planeCount * CharonWorldStatePlaneBytes)
        return NO;

    NSMutableData *points = [NSMutableData dataWithLength:pointCount * sizeof(CharonARPoint)];
    CharonARPoint *decoded = points.mutableBytes;
    const uint8_t *cursor = bytes + CharonWorldStateHeaderBytes;
    uint32_t highest = 0;
    for (NSUInteger i = 0; i < pointCount; i++, cursor += CharonWorldStatePointBytes) {
        CharonARPoint p;
        memset(&p, 0, sizeof p);
        p.image = simd_make_float2(CharonReadFloat(cursor), CharonReadFloat(cursor + 4));
        p.camera = CharonReadVector3(cursor + 8);
        p.world = CharonReadVector3(cursor + 20);
        p.scale = CharonReadFloat(cursor + 32);
        p.depth = CharonReadFloat(cursor + 36);
        p.identifier = CharonReadUInt32(cursor + 40);
        p.age = cursor[44];
        p.hits = cursor[45];
        decoded[i] = p;
        highest = MAX(highest, p.identifier);
    }
    NSMutableArray<CharonARValue *> *planes = [NSMutableArray arrayWithCapacity:planeCount];
    for (NSUInteger i = 0; i < planeCount; i++, cursor += CharonWorldStatePlaneBytes) {
        CharonARPlane plane;
        memset(&plane, 0, sizeof plane);
        plane.center = CharonReadVector3(cursor);
        plane.normal = CharonReadVector3(cursor + 12);
        plane.extent = CharonReadVector3(cursor + 24);
        plane.alignment = CharonReadFloat(cursor + 36);
        plane.identifier = CharonReadUInt32(cursor + 40);
        highest = MAX(highest, plane.identifier);
        [planes addObject:[[CharonARValue alloc] initWithBytes:&plane size:sizeof plane]];
    }

    [_worldPoints setData:points];
    [_planes setArray:planes];
    _nextIdentifier = highest + 1;
    _havePose = NO;
    _tracking = NO;
    _pointCount = 0;
    _previousCount = 0;
    return YES;
}

- (CVPixelBufferRef)copyHighResolutionImageWithError:(NSError **)error
{
#if CHARON_NO_CAMERA
    if (error)
        *error = [NSError errorWithDomain:@"space.kern0x1b.arkit" code:1
                                 userInfo:@{ NSLocalizedDescriptionKey: @"no camera on this device" }];
    return NULL;
#else
    if (!_capture) {
        if (error)
            *error = [NSError errorWithDomain:@"space.kern0x1b.arkit" code:2
                                     userInfo:@{ NSLocalizedDescriptionKey: @"the session is not running" }];
        return NULL;
    }
    AVCaptureStillImageOutput *still = [[AVCaptureStillImageOutput alloc] init];
    if ([_capture canAddOutput:still])
        [_capture addOutput:still];
    AVCaptureConnection *connection = [still connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported)
        connection.videoOrientation = _videoOrientation;

    __block CVPixelBufferRef taken = NULL;
    __block NSError *failure = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [still captureStillImageAsynchronouslyFromConnection:connection
                                        completionHandler:^(CMSampleBufferRef buffer, NSError *captureError) {
        if (captureError || !buffer) {
            failure = captureError;
        } else {
            CVImageBufferRef image = CMSampleBufferGetImageBuffer(buffer);
            if (image)
                taken = CVPixelBufferRetain(image);
        }
        dispatch_semaphore_signal(done);
    }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    [_capture removeOutput:still];
    if (!taken && error)
        *error = failure ?: [NSError errorWithDomain:@"space.kern0x1b.arkit" code:3
                                             userInfo:@{ NSLocalizedDescriptionKey:
                                                             @"the camera returned no picture" }];
    return taken;
#endif
}

- (void)stop
{
    if (!_running)
        return;
    _running = NO;
    [_capture stopRunning];
    _capture = nil;
    _output = nil;
    _input = nil;
#if !CHARON_NO_MOTION
    [_motion stopDeviceMotionUpdates];
    _motion = nil;
    _motionQueue = nil;
#endif
    _havePose = NO;
    _tracking = NO;
    _pointCount = 0;
    _previousCount = 0;
    [_planes removeAllObjects];
    [_worldPoints setLength:0];
}

#pragma mark - One frame

- (simd_float4x4)processPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        captureTime:(NSTimeInterval)captureTime
                    deviceRotation:(simd_quatf)deviceRotation
{
    if (!pixelBuffer)
        return _cameraTransform;

    _timestamp = captureTime;
    [self readLumaFromPixelBuffer:pixelBuffer];
    if (_lumaWidth == 0)
        return _cameraTransform;

    if (!_havePose) {
        _lastRotation = deviceRotation;
        _cameraTransform = CharonARKitIdentityFloat4x4;
        _havePose = YES;
    }
    deviceRotation = simd_normalize(deviceRotation);
    simd_quatf turn = CharonRotationBetween(_lastRotation, deviceRotation);

    simd_float4x4 worldFromDevice = CharonQuaternionMatrix(turn);
    simd_float3 held = { _cameraTransform.columns[3][0], _cameraTransform.columns[3][1],
                         _cameraTransform.columns[3][2] };
    _cameraTransform = simd_mul(worldFromDevice, _cameraTransform);
    _cameraTransform.columns[3] = simd_make_float4(held.x, held.y, held.z, 1);

    float dt = _haveTimestamp ? (float)(captureTime - _lastCaptureTime) : 0;
    if (dt > 0 && dt < 1.0f) {
        {
            simd_float4x4 pose = _cameraTransform;
            simd_float3 inWorld = simd_make_float3(
                    pose.columns[0][0] * _measuredAcceleration.x +
                    pose.columns[1][0] * _measuredAcceleration.y +
                    pose.columns[2][0] * _measuredAcceleration.z,
                    pose.columns[0][1] * _measuredAcceleration.x +
                    pose.columns[1][1] * _measuredAcceleration.y +
                    pose.columns[2][1] * _measuredAcceleration.z,
                    pose.columns[0][2] * _measuredAcceleration.x +
                    pose.columns[1][2] * _measuredAcceleration.y +
                    pose.columns[2][2] * _measuredAcceleration.z);
            simd_float3 own = simd_make_float3(inWorld.x - pose.columns[0][0] * _bias.bias.x -
                                               pose.columns[1][0] * _bias.bias.y -
                                               pose.columns[2][0] * _bias.bias.z,
                                               inWorld.y - pose.columns[0][1] * _bias.bias.x -
                                               pose.columns[1][1] * _bias.bias.y -
                                               pose.columns[2][1] * _bias.bias.z,
                                               inWorld.z - CharonGravity.z - pose.columns[0][2] * _bias.bias.x -
                                               pose.columns[1][2] * _bias.bias.y -
                                               pose.columns[2][2] * _bias.bias.z);
            CharonPreintegration interval = CharonPreintegrateInterval(own, dt);

            CharonBiasTerms terms;
            memset(&terms, 0, sizeof terms);
            terms.duration = dt;
            simd_float3 mean = CharonNormalized(simd_make_float3(own.x, own.y, own.z));
            terms.skew[0][1] = -mean.z; terms.skew[0][2] = mean.y;
            terms.skew[1][0] = mean.z;  terms.skew[1][2] = -mean.x;
            terms.skew[2][0] = -mean.y; terms.skew[2][1] = mean.x;
            float dAlpha = dt * dt * 0.5f, dBeta = dt * dt * dt / 6.0f;
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                    terms.bracket[i][j] = dAlpha + dBeta;
            terms.bracket[0][0] += 0;

            simd_float3 predicted = simd_make_float3(_velocity.x * dt, _velocity.y * dt,
                                                     _velocity.z * dt);
            simd_float3 residual = simd_make_float3(interval.deltaPosition.x - predicted.x,
                                                    interval.deltaPosition.y - predicted.y,
                                                    interval.deltaPosition.z - predicted.z);
            CharonUpdateAccelerationBias(&_bias, &terms, residual);
#ifdef CHARON_TRACKER_TRACE
            fprintf(stderr, "bias step: residual %.5f %.5f %.5f -> bias %.4f %.4f %.4f (P00 %.3g)\n",
                    residual.x, residual.y, residual.z, _bias.bias.x, _bias.bias.y, _bias.bias.z,
                    _bias.covariance[0][0]);
#endif
            _velocity = simd_make_float3(_velocity.x + interval.deltaVelocity.x,
                                         _velocity.y + interval.deltaVelocity.y,
                                         _velocity.z + interval.deltaVelocity.z);
            simd_float4 position = (simd_float4){ interval.deltaPosition.x, interval.deltaPosition.y,
                                                  interval.deltaPosition.z, 0 };
            _cameraTransform.columns[3] = simd_make_float4(
                    _cameraTransform.columns[3][0] + position.x,
                    _cameraTransform.columns[3][1] + position.y,
                    _cameraTransform.columns[3][2] + position.z, 1);
        }
    }
    _lastCaptureTime = captureTime;
    _haveTimestamp = YES;

    [self findFeatures];
    BOOL matched = [self matchFeaturesTurningBy:turn];
    if (matched && 0)
        [self refinePose];
    [self placeUnmatchedPoints];
    [self rememberFrame];
    [self detectPlanes];

    _lastRotation = deviceRotation;
    _previousPose = _cameraTransform;
    _deviceTransform = _cameraTransform;
    _tracking = matched && _pointCount > 8;

    if ([_delegate respondsToSelector:@selector(tracker:didUpdateWithTimestamp:)])
        [_delegate tracker:self didUpdateWithTimestamp:captureTime];
    return _cameraTransform;
}

- (void)readLumaFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    if (width == 0 || height == 0)
        return;
    if (width != _lumaWidth || height != _lumaHeight) {
        free(_luma);
        _luma = calloc(width * height, 1);
        if (!_luma)
            return;
        _lumaWidth = width;
        _lumaHeight = height;
        _resolution = CGSizeMake((CGFloat)width, (CGFloat)height);
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    const uint8_t *base = (const uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t stride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    NSUInteger x, y;
    if (base) {
        OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
        size_t component = (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
                            format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) ? 2 : 1;
        for (y = 0; y < _lumaHeight; y++) {
            const uint8_t *row = base + y * stride;
            for (x = 0; x < _lumaWidth; x++)
                _luma[y * _lumaWidth + x] = row[x * component];
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

static float CharonCornerScore(const uint8_t *luma, NSUInteger width, NSUInteger height, NSUInteger x, NSUInteger y)
{
    if (x < 1 || y < 1 || x + 1 >= width || y + 1 >= height)
        return 0;
    double gx2 = 0, gy2 = 0, gxy = 0;
    int dx, dy;
    for (dy = -1; dy <= 1; dy++) {
        for (dx = -1; dx <= 1; dx++) {
            int c = luma[(y + dy) * width + (x + dx)];
            int gx = luma[(y + dy) * width + (x + dx + 1)] - c;
            int gy = luma[(y + dy + 1) * width + (x + dx)] - c;
            gx2 += (double)gx * gx;
            gy2 += (double)gy * gy;
            gxy += (double)gx * gy;
        }
    }
    double a = gx2, b = gxy, c = gy2;
    double trace = a + c;
    double det = a * c - b * b;
    double discriminant = trace * trace / 4.0 - det;
    if (discriminant < 0)
        discriminant = 0;
    return (float)(trace / 2.0 - sqrt(discriminant));
}

- (void)findFeatures
{
    if (!_points) {
        _points = calloc(4096, sizeof(CharonARPoint));
        _previous = calloc(4096, sizeof(CharonARPoint));
        _candidates = calloc(4096, sizeof(CharonARPoint));
        if (!_points || !_previous || !_candidates)
            return;
    }
    const NSUInteger step = 8;
    const NSUInteger cells = 8;
    NSUInteger cellWidth = _lumaWidth / cells;
    NSUInteger cellHeight = _lumaHeight / cells;
    if (cellWidth < 2 || cellHeight < 2)
        return;

    float best[cells * cells];
    NSUInteger bestX[cells * cells], bestY[cells * cells];
    memset(best, 0, sizeof(best));
    NSUInteger cell, i;
    for (cell = 0; cell < cells * cells; cell++) {
        bestX[cell] = NSNotFound;
        bestY[cell] = NSNotFound;
    }

    for (i = step; i + step < _lumaHeight; i += step / 2) {
        for (NSUInteger j = step; j + step < _lumaWidth; j += step / 2) {
            float score = CharonCornerScore(_luma, _lumaWidth, _lumaHeight, j, i);
            if (score < 40)
                continue;
            cell = (i / cellHeight) * cells + (j / cellWidth);
            if (cell >= cells * cells)
                continue;
            if (score > best[cell]) {
                best[cell] = score;
                bestX[cell] = j;
                bestY[cell] = i;
            }
        }
    }

    NSUInteger wanted = cells * cells / 3;
    NSUInteger count = 0;
    for (cell = 0; cell < cells * cells && count < wanted; cell++) {
        if (bestX[cell] == NSNotFound)
            continue;
        CharonARPoint *point = &_candidates[count];
        memset(point, 0, sizeof(*point));
        point->image = simd_make_float2((float)bestX[cell] / (float)_lumaWidth,
                                        (float)bestY[cell] / (float)_lumaHeight);
        point->scale = (float)cellWidth;
        point->identifier = _nextIdentifier++;
        point->hits = 1;
        [self placePointInWorld:point];
        count++;
    }
    _candidateCount = count;
}

#pragma mark - Matching a point into the next frame

static uint32_t CharonPatchCost(const uint8_t *luma, NSUInteger width, NSUInteger height,
                                NSUInteger x, NSUInteger y, NSUInteger otherX, NSUInteger otherY,
                                NSUInteger radius)
{
    uint32_t total = 0;
    NSUInteger dy, dx;
    for (dy = 0; dy < radius * 2 + 1; dy++) {
        NSUInteger ay = y + dy, by = otherY + dy;
        if (ay >= height || by >= height)
            return UINT32_MAX;
        for (dx = 0; dx < radius * 2 + 1; dx++) {
            NSUInteger ax = x + dx, bx = otherX + dx;
            if (ax >= width || bx >= width)
                return UINT32_MAX;
            int difference = (int)luma[ay * width + ax] - (int)luma[by * width + bx];
            total += (uint32_t)(difference < 0 ? -difference : difference);
        }
    }
    return total;
}

- (BOOL)matchFeaturesTurningBy:(simd_quatf)turn
{
    if (_previousCount == 0 || _pointCount == 0)
        return NO;

    simd_quatf relative = simd_normalize(simd_conjugate(turn));
    simd_float3 axis = {relative.vector.x, relative.vector.y, relative.vector.z};
    float angle = 2.0f * acosf(fmaxf(-1.0f, fminf(1.0f, relative.vector.w)));
    simd_float2 drift = simd_make_float2(axis.x, axis.y) * angle * 0.5f;

    const NSUInteger radius = 3;
    const float weight = 2.0f;
    const NSUInteger step = 3;
    NSUInteger matched = 0, i, j;

    for (i = 0; i < _previousCount; i++) {
        CharonARPoint *was = &_previous[i];
        NSUInteger wasX = (NSUInteger)(was->image.x * (float)_lumaWidth);
        NSUInteger wasY = (NSUInteger)(was->image.y * (float)_lumaHeight);
        if (wasX + 32 >= _lumaWidth || wasY + 32 >= _lumaHeight)
            continue;

        float searchX = (float)wasX + drift.x * (float)_lumaWidth;
        float searchY = (float)wasY + drift.y * (float)_lumaHeight;
        NSUInteger reach = (NSUInteger)(was->scale * weight);
        NSUInteger bestX = NSNotFound, bestY = NSNotFound;
        uint32_t bestCost = UINT32_MAX;

        for (NSUInteger dy = 0; dy <= reach * 2; dy += step) {
            for (NSUInteger dx = 0; dx <= reach * 2; dx += step) {
                NSInteger cx = (NSInteger)(searchX - (float)reach) + (NSInteger)dx;
                NSInteger cy = (NSInteger)(searchY - (float)reach) + (NSInteger)dy;
                if (cx < (NSInteger)radius + 1 || cy < (NSInteger)radius + 1 ||
                    cx + (NSInteger)radius * 2 + 2 >= (NSInteger)_lumaWidth ||
                    cy + (NSInteger)radius * 2 + 2 >= (NSInteger)_lumaHeight)
                    continue;
                uint32_t cost = CharonPatchCost(_luma, _lumaWidth, _lumaHeight,
                                               (NSUInteger)cx, (NSUInteger)cy,
                                               wasX, wasY, radius);
                if (cost < bestCost) {
                    bestCost = cost;
                    bestX = (NSUInteger)cx;
                    bestY = (NSUInteger)cy;
                }
            }
        }

        if (bestX == NSNotFound)
            continue;
        uint32_t ceiling = (uint32_t)((2 * radius * 2 + 1) * (2 * radius * 2 + 1) * 60);
        if (bestX == NSNotFound || bestCost > ceiling)
            continue;

        BOOL taken = NO;
        for (j = 0; j < matched; j++) {
            if (_points[j].identifier == was->identifier) {
                taken = YES;
                break;
            }
        }
        if (taken)
            continue;

        CharonARPoint *now = &_points[matched];
        memcpy(now, was, sizeof(*now));
        now->image = simd_make_float2((float)bestX / (float)_lumaWidth,
                                      (float)bestY / (float)_lumaHeight);
        now->age = was->age > 250 ? 250 : (uint8_t)(was->age + 1);
        now->hits = (uint8_t)(was->hits < 250 ? was->hits + 1 : 250);

        simd_float2 wasPixel = simd_make_float2(was->image.x * (float)_lumaWidth,
                                                was->image.y * (float)_lumaHeight);
        simd_float2 nowPixel = simd_make_float2(now->image.x * (float)_lumaWidth,
                                                now->image.y * (float)_lumaHeight);
        simd_float3x3 intrinsics = [CharonARTracker cameraIntrinsicsForResolution:_resolution];
        simd_float4x4 wasPose = _previousPose;
        if (simd_length(_cameraTransform.columns[3] - wasPose.columns[3]) < 1e-9f)
            wasPose = simd_mul(CharonQuaternionMatrix(simd_normalize(simd_conjugate(turn))),
                               _cameraTransform);
        now->depth = CharonTriangulatedDepth(intrinsics, wasPixel, nowPixel, wasPose, _cameraTransform);
        if (now->hits >= 3)
            [self placePointInWorld:now];
#ifdef CHARON_TRACKER_TRACE
        if (matched == 0) {
            simd_float3x3 k = [CharonARTracker cameraIntrinsicsForResolution:_resolution];
            fprintf(stderr, "landmark image      %.2f %.2f px of %.0fx%.0f\n",
                    now->image.x * (float)_lumaWidth, now->image.y * (float)_lumaHeight,
                    _lumaWidth, _lumaHeight);
            fprintf(stderr, "landmark world      %.4f %.4f %.4f\n", now->world.x, now->world.y, now->world.z);
            simd_float2 where;
            BOOL ok = CharonProject(_cameraTransform, k, now->world, &where);
            fprintf(stderr, "landmark projected  %.2f %.2f  (%s)\n", where.x, where.y,
                    ok ? "in front" : "BEHIND");
            fprintf(stderr, "intrinsics          fx %.3f cx %.3f fy %.3f cy %.3f\n",
                    k.columns[0][0], k.columns[2][0], k.columns[1][1], k.columns[2][1]);
            fprintf(stderr, "landmark camera     %.4f %.4f %.4f   depth %.4f\n", now->camera.x,
                    now->camera.y, now->camera.z, now->depth);
            fprintf(stderr, "pose translation    %.4f %.4f %.4f\n", _cameraTransform.columns[3][0],
                    _cameraTransform.columns[3][1], _cameraTransform.columns[3][2]);
        }
#endif
        matched++;
        if (matched >= 4096)
            break;
    }
    _pointCount = matched;

    if (matched) {
        float *depths = calloc(matched, sizeof(float));
        if (depths) {
            NSUInteger measured = 0;
            for (NSUInteger k = 0; k < matched; k++)
                if (_points[k].depth > 0)
                    depths[measured++] = _points[k].depth;
            if (measured >= 3) {
                for (NSUInteger a = 1; a < measured; a++) {
                    float key = depths[a];
                    NSUInteger b = a;
                    while (b > 0 && depths[b - 1] > key) {
                        depths[b] = depths[b - 1];
                        b--;
                    }
                    depths[b] = key;
                }
                float median = depths[measured / 2];
                for (NSUInteger k = 0; k < matched; k++) {
                    if (_points[k].depth > 0)
                        _points[k].depth = median;
                    [self placePointInWorld:&_points[k]];
                }
            }
            free(depths);
        }
    }
    return matched >= 8;
}

#pragma mark - The pose

static simd_float4x4 CharonNudgedPose(simd_float4x4 pose, int parameter, float epsilon)
{
    float translation[3] = { 0, 0, 0 }, rotation[3] = { 0, 0, 0 };
    float *target = parameter < 3 ? &translation[parameter] : &rotation[parameter - 3];
    *target = epsilon;
    return simd_mul(CharonPoseIncrement(simd_make_float3(rotation[0], rotation[1], rotation[2]),
                                        simd_make_float3(translation[0], translation[1],
                                                         translation[2])),
                    pose);
}

- (void)refinePose
{
    simd_float3x3 intrinsics = [CharonARTracker cameraIntrinsicsForResolution:_resolution];
    if (_resolution.width <= 0 || _resolution.height <= 0)
        return;

    NSUInteger usable = 0;
    for (NSUInteger i = 0; i < _pointCount; i++)
        if (_points[i].hits >= 2)
            usable++;
    if (usable < 6)
        return;

    const float epsilon = 1e-4f;
    float normal[6][6] = {{ 0 }};
    float gradient[6] = { 0 };

    for (NSUInteger i = 0; i < _pointCount; i++) {
        CharonARPoint *point = &_points[i];
        if (point->hits < 2)
            continue;

        simd_float2 observed = { point->image.x * (float)_resolution.width,
                                 point->image.y * (float)_resolution.height };
        simd_float2 predicted;
        if (!CharonProject(_cameraTransform, intrinsics, point->world, &predicted))
            continue;
        float residual[2] = { predicted.x - observed.x, predicted.y - observed.y };

        float jacobian[2][6];
        BOOL usableRow = YES;
        for (int parameter = 0; parameter < 6 && usableRow; parameter++) {
            simd_float2 forward, backward;
            BOOL haveForward = CharonProject(CharonNudgedPose(_cameraTransform, parameter, epsilon),
                                             intrinsics, point->world, &forward);
            BOOL haveBackward = CharonProject(CharonNudgedPose(_cameraTransform, parameter, -epsilon),
                                              intrinsics, point->world, &backward);
            if (haveForward && haveBackward) {
                jacobian[0][parameter] = (forward.x - backward.x) / (2 * epsilon);
                jacobian[1][parameter] = (forward.y - backward.y) / (2 * epsilon);
            } else if (haveForward) {
                jacobian[0][parameter] = (forward.x - predicted.x) / epsilon;
                jacobian[1][parameter] = (forward.y - predicted.y) / epsilon;
            } else {
                usableRow = NO;
            }
        }
        if (!usableRow)
            continue;

        for (int row = 0; row < 6; row++) {
            gradient[row] -= jacobian[0][row] * residual[0] + jacobian[1][row] * residual[1];
            for (int column = 0; column < 6; column++)
                normal[row][column] += jacobian[0][row] * jacobian[0][column] +
                                       jacobian[1][row] * jacobian[1][column];
        }
    }

    for (int row = 0; row < 6; row++)
        normal[row][row] += 1e-6f;

    float step[6];
    if (!CharonSolveSix(normal, gradient, step))
        return;

    for (int row = 0; row < 6; row++)
        step[row] = fmaxf(-0.05f, fminf(0.05f, step[row]));

    simd_float3 rotation = simd_make_float3(step[3], step[4], step[5]);
    simd_float3 translation = simd_make_float3(step[0], step[1], step[2]);
    _cameraTransform = simd_mul(CharonPoseIncrement(rotation, translation), _cameraTransform);
    _havePose = YES;
}

#pragma mark - The points

static float CharonTriangulatedDepth(simd_float3x3 intrinsics, simd_float2 u0, simd_float2 u1,
                                     simd_float4x4 from, simd_float4x4 to)
{
    simd_float3 d0 = CharonRayDirection(intrinsics, from, u0);
    simd_float3 d1 = CharonRayDirection(intrinsics, to, u1);
    simd_float3 o0 = { from.columns[3][0], from.columns[3][1], from.columns[3][2] };
    simd_float3 o1 = { to.columns[3][0], to.columns[3][1], to.columns[3][2] };

    simd_float3 n = simd_normalize(simd_cross(d0, d1));
    float denominator = simd_dot(n, d1);
    if (fabsf(denominator) < 1e-6f)
        return 0;
    float along = simd_dot(n, o1 - o0) / denominator;
    if (along <= 0)
        return 0;
    return along;
}

- (float)depthForDrift:(simd_float2)driftPixels
                 along:(simd_float3)turnAxis
                focal:(float)focalLength
{
    simd_float3 axis = CharonNormalized(turnAxis);
    if (simd_length(axis) < 1e-6f || focalLength <= 0)
        return 0;
    simd_float3 unit = CharonNormalized(simd_make_float3(driftPixels.x, driftPixels.y, 1));
    float numerator = focalLength * simd_cross(axis, unit).x;
    float denominator = driftPixels.x;
    if (fabsf(denominator) < 1e-6f)
        return 0;
    float depth = numerator / denominator;
    return depth > 0 ? depth : 0;
}

- (void)placePointInWorld:(CharonARPoint *)point
{
    if (_lumaWidth == 0 || point->depth <= 0)
        return;
    simd_float3 ray = CharonNormalized(simd_make_float3(point->image.x - 0.5f,
                                                        point->image.y - 0.5f, 1));
    point->camera = CharonAlongRay(simd_make_float3(0, 0, 0), ray, point->depth);
    simd_float4 world = simd_mul(_cameraTransform,
                                 simd_make_float4(point->camera.x, point->camera.y,
                                                  point->camera.z, 1));
    point->world = simd_make_float3(world.x, world.y, world.z);
}

- (float)focalLengthInPixels
{
    return [CharonARTracker cameraIntrinsicsForResolution:_resolution].columns[0][0];
}

- (void)placeUnmatchedPoints
{
    CharonARPoint *carried = calloc(4096, sizeof(CharonARPoint));
    if (!carried)
        return;
    NSUInteger matched = _pointCount, count = 0, i;
    for (i = 0; i < matched; i++) {
        if (_points[i].hits >= 3) {
            carried[count] = _points[i];
            float distance = 0.5f / (_points[i].scale / (float)_lumaWidth);
            carried[count].camera = CharonAlongRay((simd_float3){0, 0, 0},
                                                   CharonNormalized((simd_float3){_points[i].image.x - 0.5f,
                                                                                  _points[i].image.y - 0.5f,
                                                                                  1}),
                                                   distance);
            carried[count].world = simd_mul(_cameraTransform, (simd_float4){carried[count].camera.x, carried[count].camera.y, carried[count].camera.z, 1}).xyz;
            count++;
        }
    }
    if (count) {
        [_worldPoints appendBytes:carried length:count * sizeof(CharonARPoint)];
    }
    NSUInteger total = matched;
    for (i = 0; i < _candidateCount && total < 4096; i++) {
        _points[total++] = _candidates[i];
    }
    free(carried);
    _pointCount = total;
}

- (void)rememberFrame
{
    if (!_previous)
        return;
    memcpy(_previous, _points, _pointCount * sizeof(CharonARPoint));
    _previousCount = _pointCount;
}

#pragma mark - Planes

- (void)detectPlanes
{
    const NSUInteger count = _worldPoints.length / sizeof(CharonARPoint);
    if (count < 24)
        return;

    const CharonARPoint *points = (const CharonARPoint *)_worldPoints.bytes;
    const float cell = 0.25f;
    const float level = 0.90f;
    const float spread = 0.75f;
    NSMutableArray<CharonARValue *> *found = [NSMutableArray array];
    NSUInteger i, j;

    for (i = 0; i < count; i += 3) {
        simd_float3 anchor = points[i].world;
        simd_float3 sum = (simd_float3){0, 0, 0};
        simd_float3 mean = (simd_float3){0, 0, 0};
        simd_float3 normal = (simd_float3){0, 0, 0};
        NSUInteger onPlane = 0;
        simd_float3 low = anchor, high = anchor;

        for (j = 0; j < count; j++) {
            simd_float3 d = points[j].world - anchor;
            if (fabsf(d.x) > spread * 2 || fabsf(d.y) > spread * 2 || fabsf(d.z) > spread * 2)
                continue;
            sum = sum + d;
            onPlane++;
        }
        if (onPlane < 16)
            continue;
        mean = sum / (float)onPlane;

        simd_float3 axis1 = (simd_float3){0, 0, 0}, axis2 = (simd_float3){0, 0, 0};
        for (j = 0; j < count; j++) {
            simd_float3 d = points[j].world - (anchor + mean);
            if (fabsf(d.x) > spread || fabsf(d.y) > spread || fabsf(d.z) > spread)
                continue;
            axis1 = axis1 + d;
        }
        if (simd_length(axis1) < 1e-4f)
            continue;
        axis1 = CharonNormalized(axis1);
        for (j = 0; j < count; j++) {
            simd_float3 d = points[j].world - (anchor + mean);
            if (fabsf(d.x) > spread || fabsf(d.y) > spread || fabsf(d.z) > spread)
                continue;
            axis2 = axis2 + d - axis1 * simd_dot(d, axis1);
        }
        if (simd_length(axis2) < 1e-4f)
            continue;
        axis2 = CharonNormalized(axis2);
        normal = CharonNormalized(simd_cross(axis1, axis2));
        if (normal.y < 0)
            normal = -normal;
        if (normal.y < level)
            continue;

        for (j = 0; j < count; j++) {
            simd_float3 d = points[j].world - (anchor + mean);
            if (fabsf(simd_dot(d, normal)) > cell)
                continue;
            low = simd_min(low, points[j].world);
            high = simd_max(high, points[j].world);
            onPlane++;
        }
        if (onPlane < 16)
            continue;

        CharonARPlane plane;
        memset(&plane, 0, sizeof(plane));
        plane.center = anchor + mean;
        plane.normal = normal;
        plane.extent = (high - low) * 0.5f;
        plane.alignment = 0.5f;
        plane.identifier = _nextIdentifier++;
        [found addObject:[[CharonARValue alloc] initWithBytes:&plane size:sizeof plane]];
        if ([found count] >= 16)
            break;
    }

    if ([found count]) {
        [_planes setArray:found];
    }
}

#pragma mark - What an application reads

- (NSData *)pointCloud
{
    const NSUInteger count = _worldPoints.length / sizeof(CharonARPoint);
    if (count == 0)
        return [NSData data];
    NSMutableData *out = [NSMutableData dataWithLength:count * sizeof(CharonARCloudPoint)];
    CharonARCloudPoint *cloud = (CharonARCloudPoint *)out.mutableBytes;
    const CharonARPoint *points = (const CharonARPoint *)_worldPoints.bytes;
    NSUInteger i;
    for (i = 0; i < count; i++)
        cloud[i].position = points[i].world;
    return out;
}

- (NSArray<CharonARValue *> *)planes { return [_planes copy]; }
- (simd_float4x4)cameraTransform { return _cameraTransform; }
- (simd_float4x4)deviceTransform { return _deviceTransform; }
- (CGFloat)lightEstimate { return _lightEstimate; }
- (CGFloat)ambientColorTemperature { return _ambientColorTemperature; }
- (BOOL)isTracking { return _tracking; }
- (CGSize)imageResolution { return _resolution; }
- (NSTimeInterval)timestamp { return _timestamp; }

#pragma mark - Rays

static BOOL CharonCameraRay(CGSize resolution, CGPoint point, simd_float3 *origin, simd_float3 *direction)
{
    if (resolution.width <= 0 || resolution.height <= 0)
        return NO;
    float x = ((float)point.x / (float)resolution.width - 0.5f) * 2.0f;
    float y = (0.5f - (float)point.y / (float)resolution.height) * 2.0f;
    const float tanHalf = 0.5773502692f;
    *origin = (simd_float3){0, 0, 0};
    *direction = CharonNormalized((simd_float3){x * tanHalf, y * tanHalf, -1});
    return YES;
}

static BOOL CharonRayPlane(simd_float3 origin, simd_float3 direction, CharonARPlane plane,
                           simd_float3 *hit)
{
    float denominator = simd_dot(direction, plane.normal);
    if (fabsf(denominator) < 1e-6f)
        return NO;
    float distance = simd_dot(plane.center - origin, plane.normal) / denominator;
    if (distance <= 0)
        return NO;
    *hit = CharonAlongRay(origin, direction, distance);
    return YES;
}

- (BOOL)raycastFromPoint:(CGPoint)point
                allowing:(NSUInteger)targets
                results:(NSMutableArray<CharonARValue *> *)results
{
    simd_float3 origin, direction;
    if (!CharonCameraRay(_resolution, point, &origin, &direction))
        return NO;
    return [self raycastFromOrigin:origin direction:direction allowing:targets results:results];
}

- (BOOL)raycastFromOrigin:(simd_float3)origin
                 direction:(simd_float3)direction
                allowing:(NSUInteger)targets
                  results:(NSMutableArray<CharonARValue *> *)results
{
    simd_float3 world = simd_mul(_cameraTransform, (simd_float4){origin.x, origin.y, origin.z, 1}).xyz;
    simd_float3 aim = simd_mul(_cameraTransform, (simd_float4){direction.x, direction.y, direction.z, 0}).xyz;
    direction = CharonNormalized(aim);
    if (results)
        [results removeAllObjects];

    float nearest = 0;
    BOOL any = NO;
    NSUInteger i;
    for (i = 0; i < _planes.count; i++) {
        CharonARPlane plane;
        [_planes[i] getValue:&plane];
        simd_float3 hit;
        if (!CharonRayPlane(world, direction, plane, &hit))
            continue;
        float distance = simd_length(hit - world);
        if (any && distance >= nearest)
            continue;
#if CHARON_NO_MOTION
        if (targets != 0)
            continue;
#else
        if (targets != ARRaycastTargetExistingPlaneGeometry && targets != ARRaycastTargetEstimatedPlane) {
            continue;
        }
#endif
        CharonARHit record;
        memset(&record, 0, sizeof(record));
        record.position = hit;
        record.localNormal = plane.normal;
        record.planeIdentifier = plane.identifier;
        nearest = distance;
        any = YES;
        if (results)
            [results addObject:[[CharonARValue alloc] initWithBytes:&record size:sizeof record]];
    }
    return any;
}

- (BOOL)hitTestPoint:(CGPoint)point results:(NSMutableArray<CharonARValue *> *)results
{
    return [self hitTestPoint:point existingPlane:NO results:results];
}

- (BOOL)hitTestPoint:(CGPoint)point
       existingPlane:(BOOL)existingPlane
            results:(NSMutableArray<CharonARValue *> *)results
{
    simd_float3 origin, direction;
    if (!CharonCameraRay(_resolution, point, &origin, &direction))
        return NO;
    if (results)
        [results removeAllObjects];

    const NSUInteger count = _worldPoints.length / sizeof(CharonARPoint);
    const CharonARPoint *points = (const CharonARPoint *)_worldPoints.bytes;
    NSUInteger i;
    float nearest = 0;
    BOOL any = NO;
    for (i = 0; i < count; i++) {
        simd_float3 delta = points[i].camera - CharonAlongRay(origin, direction, simd_dot(points[i].camera, direction));
        float distance = simd_length(delta);
        if (any && distance >= nearest)
            continue;
        if (distance > 0.05f)
            continue;
        CharonARHit record;
        memset(&record, 0, sizeof(record));
        record.position = points[i].world;
        record.localNormal = (simd_float3){0, 1, 0};
        record.planeIdentifier = 0;
        nearest = distance;
        any = YES;
        if (results)
            [results addObject:[[CharonARValue alloc] initWithBytes:&record size:sizeof record]];
    }
    return any;
}

@end
