#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 16.0, by the held ladder's answer and not the header's.
//
// THIS FILE EXISTS BECAUSE AN OBJECT MAY NOT CARRY TWO RELEASES, and the gate said so. SensorKit170.m
// held SRAudioLevel, SRFaceMetrics, SRFaceMetricsExpression, SRSpeechExpression, SRSpeechMetrics,
// SRWristTemperature and SRWristTemperatureSession alongside two constants that
// modules/apple/backports.lua's check_releases places at a different release:
//
//   error: 2 objects hold API no single release introduced:
//     SensorKitBackports: SensorKit170.m defines SRSensorHeartRate SRSensorOdometer from iOS 16.0 and
//       SRAudioLevel … from iOS 17.0 and SRSensorFaceMetrics SRSensorWristTemperature from iOS 18.0
//
// The two that do not agree with 17.0 move here, and the values come from CharonSensorKitNames.h under
// this file's own guard, so there is still exactly one definition of each string in the tree. Nothing
// else moves: no row changes, no measurement changes, and the header's API_AVAILABLE(ios(17.0)) on both
// names is not what this file is asserting.
//
// WHY 16.0 AND NOT 17.0, measured rather than argued. SRSensors.h:276 and :307 declare both
// API_AVAILABLE(ios(17.0)), and the registry says introduced 17.0, and sdk-26.2-surface.tsv agrees. But
// check_releases asks dyld.first_releases which HELD release first exports the symbol, and re-running
// that measurement over the built object prints:
//
//   == SensorKit160.o  (1 release)
//      iOS 16.0   _SRSensorHeartRate _SRSensorOdometer
//
// One release for one object is the rule the gate enforces, and the ladder's answer is the one it
// enforces it with.

// The two string constants of iOS 16.0 by that measurement,
// SRSensors.h:276 and :307, named from CharonSensorKitNames.h rather than written here.

#define CHARON_SENSORKIT_NAMES_16_0
#import "CharonSensorKitNames.h"