// ARDirectionalLightEstimate.m - the light a frame measures as a direction, at 11.0 beside the ambient one.
//
// The directional estimate is the ambient pair plus a direction, an intensity and spherical harmonics of
// the light, and this port computes none of the three: ARFrame.m builds the ambient pair from fixed
// values, which is the only light estimate a frame here carries. So the frame never hands out this
// subclass. The class is carried so the name resolves and its three members answer what a frame would
// have put in them, which is nothing. See facts/ARKit/SensorShells.md and facts/ARKit/ARKit.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARDirectionalLightEstimate

@synthesize sphericalHarmonicsCoefficients = _sphericalHarmonicsCoefficients;
@synthesize primaryLightDirection = _primaryLightDirection;
@synthesize primaryLightIntensity = _primaryLightIntensity;

@end

NS_ASSUME_NONNULL_END
