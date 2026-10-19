#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 15.4.
//
// One file per release, because an object carries API that arrived in one release alone, and 15.4 is
// a release of its own with no other file: the properties that arrived in it were declared by the
// build's own 16.4 SDK and need nothing here, so the constant below is the whole of what iOS 15.4
// adds to this port.

// The single string constant of iOS 15.4,
// declared at SRSensors.h:230,
// named from CharonSensorKitNames.h rather than written here: an object carries the API of
// one release alone, while the values are one list that the host comparison in
// tests/backports/host/sensorkit-names walks whole.

#define CHARON_SENSORKIT_NAMES_15_4
#import "CharonSensorKitNames.h"
