#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern NSString *const MKLaunchOptionsDirectionsModeCycling;
extern const double MKPointsOfInterestRequestMaxRadius;

NSString *const BACKPORT_IMPL(MKLaunchOptionsDirectionsModeCycling) = @"MKLaunchOptionsDirectionsModeCycling";
const double BACKPORT_IMPL(MKPointsOfInterestRequestMaxRadius) = 2000;
