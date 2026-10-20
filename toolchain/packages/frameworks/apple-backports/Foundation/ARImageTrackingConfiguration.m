#import <ARKit/ARConfiguration.h>
#import <ARKit/ARReferenceObject.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString *const ARReferenceObjectArchiveExtension = @"arobject";

@implementation ARImageTrackingConfiguration

@dynamic autoFocusEnabled, trackingImages, maximumNumberOfTrackedImages;

@end

@implementation ARObjectScanningConfiguration

@dynamic autoFocusEnabled, planeDetection;

@end
