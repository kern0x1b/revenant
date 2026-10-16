// ARReferenceObject.m - a scanned object, at 12.0: the reference a session matches an object against.
//
// A reference object is made by scanning an object with a depth sensor (the release's own scanning
// configuration answers NO on this device, ARConfiguration3.m), and its archive is written by that scan. So no
// object is made here, and the six members are the synthesised accessors of the SDK's own properties, which
// answer what an unscanned object would have: nothing. The archive readers and the merge and transform methods
// are not carried; facts/ARKit/AbsentClasses.md lists them and the reason. `detectionObjects` is owed by its own
// row (ios11.json) for the same reason.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARReferenceObject

@synthesize name = _name;
@synthesize center = _center;
@synthesize extent = _extent;
@synthesize scale = _scale;
@synthesize resourceGroupName = _resourceGroupName;
@synthesize rawFeaturePoints = _rawFeaturePoints;

@end

NS_ASSUME_NONNULL_END
