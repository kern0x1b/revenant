#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const MPVolumeViewWirelessRouteActiveDidChangeNotification;
extern NSString *const MPVolumeViewWirelessRoutesAvailableDidChangeNotification;

NSString *const BACKPORT_IMPL(MPVolumeViewWirelessRouteActiveDidChangeNotification) = @"MPVolumeViewWirelessRouteActiveDidChangeNotification";
NSString *const BACKPORT_IMPL(MPVolumeViewWirelessRoutesAvailableDidChangeNotification) = @"MPVolumeViewWirelessRoutesAvailableDidChangeNotification";
