#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern NSString *const MKMapItemTypeIdentifier;
extern NSString *const MKMapViewDefaultAnnotationViewReuseIdentifier;
extern NSString *const MKMapViewDefaultClusterAnnotationViewReuseIdentifier;

NSString *const BACKPORT_IMPL(MKMapItemTypeIdentifier) = @"com.apple.mapkit.map-item";
NSString *const BACKPORT_IMPL(MKMapViewDefaultAnnotationViewReuseIdentifier) = @"MKMapViewDefaultAnnotationViewReuseIdentifier";
NSString *const BACKPORT_IMPL(MKMapViewDefaultClusterAnnotationViewReuseIdentifier) = @"MKMapViewDefaultClusterAnnotationViewReuseIdentifier";
