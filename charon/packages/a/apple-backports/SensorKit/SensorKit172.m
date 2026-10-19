#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 17.2, the properties that arrived then.
// SRSpeechMetrics is a class of 17.0 (SensorKit170.m); the one member 17.2 added is a category, so
// the class is implemented once.
@implementation SRSpeechMetrics (CharonSensorKit172)
@dynamic timeSinceAudioStart;
CHARON_SCALAR_PROPERTY(NSTimeInterval, timeSinceAudioStart)
@end
