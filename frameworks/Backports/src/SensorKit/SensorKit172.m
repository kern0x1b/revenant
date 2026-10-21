#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import "../RevenantValueStore.h"

@implementation SRSpeechMetrics (RevenantSensorKit172)
@dynamic timeSinceAudioStart;
REVENANT_SCALAR_PROPERTY(NSTimeInterval, timeSinceAudioStart)
@end
