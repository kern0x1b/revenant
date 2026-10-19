#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 18.0, by the held ladder's answer and not the header's.
//
// THIS FILE EXISTS BECAUSE AN OBJECT MAY NOT CARRY TWO RELEASES, and the gate said so. Two constants
// were asked for here and two more were handed to it:
//
//   SensorKit170.m held SRSensorFaceMetrics SRSensorWristTemperature, which check_releases places at
//   18.0 while the file is the 17.0 object;
//   SensorKit174.m held SRSensorElectrocardiogram SRSensorPhotoplethysmogram, which the same
//   measurement places at 18.0 while that file is the 17.4 one.
//
// All four land here, and they can share a file precisely because all four are 18.0 by that
// measurement — which is also why SRSensorHeartRate and SRSensorOdometer could NOT come here: they are
// 16.0, and they are in SensorKit160.m. One object, one release.
//
// WHY 18.0 AND NOT 17.0 OR 17.4, measured rather than argued. SRSensors.h declares these four
// API_AVAILABLE(ios(17.0)) or ios(17.4), the registry carries their introduced as 17.0 and 17.4, and
// sdk-26.2-surface.tsv agrees with the registry on all of them. check_releases asks
// dyld.first_releases which HELD release first exports each symbol, and re-running that over the built
// object prints:
//
//   == SensorKit180.o  (1 release)
//      iOS 18.0   _SRSensorFaceMetrics _SRSensorWristTemperature
//                 _SRSensorElectrocardiogram _SRSensorPhotoplethysmogram
//
// Nothing here claims these names arrived in 18.0. The header's own date is what the registry says, and
// no row changes.

// The four string constants of iOS 18.0 by that measurement, SRSensors.h:295, :265, :320 and :332,
// named from CharonSensorKitNames.h rather than written here.

#define CHARON_SENSORKIT_NAMES_18_0
#import "CharonSensorKitNames.h"