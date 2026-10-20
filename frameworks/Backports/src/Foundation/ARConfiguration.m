#import <ARKit/ARConfiguration.h>
#import <ARKit/ARError.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString *const ARErrorDomain = @"com.apple.arkit.error";

@implementation ARConfiguration

@dynamic supportedVideoFormats, videoFormat, worldAlignment, lightEstimationEnabled, providesAudioData, frameSemantics;
@dynamic configurableCaptureDeviceForPrimaryCamera, recommendedVideoFormatFor4KResolution, recommendedVideoFormatForHighResolutionFrameCapturing, videoHDRAllowed;

+ (BOOL)isSupported
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] init];
}

@end

@implementation ARWorldTrackingConfiguration

@dynamic autoFocusEnabled, environmentTexturing, wantsHDREnvironmentTextures, planeDetection, initialWorldMap, detectionImages;
@dynamic automaticImageScaleEstimationEnabled, maximumNumberOfTrackedImages, detectionObjects, collaborationEnabled, supportsUserFaceTracking;
@dynamic userFaceTrackingEnabled, appClipCodeTrackingEnabled, supportsAppClipCodeTracking, sceneReconstruction;

@end

@implementation AROrientationTrackingConfiguration

@dynamic autoFocusEnabled;

@end

@implementation ARFaceTrackingConfiguration

@dynamic supportedNumberOfTrackedFaces, maximumNumberOfTrackedFaces, supportsWorldTracking, worldTrackingEnabled;

@end
