// MKMapItemTypeIdentifier, the uniform type identifier of a map item since iOS 11. The two reuse
// identifiers of iOS 11 are in MKAnnotationViews11.m, the same release and therefore the same object.
//
// The values are Apple's own, read out of the MapKit.framework of macOS 27.0 (build 26A428): a
// generated probe declares each of these as the extern its own SDK header declares, links against
// that framework, and prints what the symbol holds. The measurement is in
// tests/backports/host/mapkit-constants, which fails the moment a name is missing there, so a
// value this file gets wrong is a value the host disagrees with.
//
// Two of them are cross-checked against a different release of Apple's own, and they agree:
// MKMapCameraZoomDefault is -1 in the macOS image and -1.0 read out of the MapKit image
// dyld.extract took of the arm64e dyld shared cache of 18.0, and MKMapItemTypeIdentifier is
// "com.apple.mapkit.map-item" in both the macOS image and the arm64 cache of 12.0.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern NSString *const MKMapItemTypeIdentifier;
extern NSString *const MKMapViewDefaultAnnotationViewReuseIdentifier;
extern NSString *const MKMapViewDefaultClusterAnnotationViewReuseIdentifier;

NSString *const MKMapItemTypeIdentifier = @"com.apple.mapkit.map-item";
NSString *const MKMapViewDefaultAnnotationViewReuseIdentifier = @"MKMapViewDefaultAnnotationViewReuseIdentifier";
NSString *const MKMapViewDefaultClusterAnnotationViewReuseIdentifier = @"MKMapViewDefaultClusterAnnotationViewReuseIdentifier";
