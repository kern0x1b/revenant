#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern NSString *const MKLaunchOptionsCameraKey;

NSString *const BACKPORT_IMPL(MKLaunchOptionsCameraKey) = @"MKLaunchOptionsCameraKey";
