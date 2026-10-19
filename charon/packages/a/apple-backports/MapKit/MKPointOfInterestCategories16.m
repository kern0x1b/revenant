// The two map constants iOS 16.0 added: MKLaunchOptionsDirectionsModeCycling and
// MKPointsOfInterestRequestMaxRadius. The values are Apple's, read out of the MapKit.framework of
// macOS 27.0 (build 26A428): a generated probe declares each of these as the extern its own SDK header
// declares, links against that framework, and prints what the symbol holds. The measurement is in
// tests/backports/host/mapkit-constants, which fails the moment a name is missing there, so a value
// this file gets wrong is a value the host disagrees with. The point of interest categories iOS 13.4
// added are in MKPointOfInterestCategories134.m.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern NSString *const MKLaunchOptionsDirectionsModeCycling;
extern const double MKPointsOfInterestRequestMaxRadius;

NSString *const MKLaunchOptionsDirectionsModeCycling = @"MKLaunchOptionsDirectionsModeCycling";
const double MKPointsOfInterestRequestMaxRadius = 2000;
