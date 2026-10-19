// The port's own eighteen later SensorKit names, linked into the differential from the port's header.
//
// It exists because of a shape, not a convenience: an object carries the API of exactly one release,
// so those eighteen values are defined in six objects (SensorKit150.m, SensorKit154.m,
// SensorKit164.m, SensorKit170.m, SensorKit174.m, SensorKit260.m), one release each - and six
// host-compilable sources would be six copies of one list. They are not: the values live in
// CharonSensorKitNames.h behind one guard per release, and this file is the seventh release - the one
// that is only a harness - which defines all seven guards and imports it. So the eighteen strings the
// comparison below walks are the eighteen the objects carry, and run.sh's mutations reach them
// through this import rather than through a copy that could drift.
#define CHARON_SENSORKIT_NAMES_15_0
#define CHARON_SENSORKIT_NAMES_15_4
#define CHARON_SENSORKIT_NAMES_16_4
#define CHARON_SENSORKIT_NAMES_16_0
#define CHARON_SENSORKIT_NAMES_18_0
#define CHARON_SENSORKIT_NAMES_17_4
#define CHARON_SENSORKIT_NAMES_26_0
#import "CharonSensorKitNames.h"