#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import "../RevenantValueStore.h"

@implementation SRAudioLevel
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic timeRange, loudness;
REVENANT_STRUCT_PROPERTY(CMTimeRange, timeRange)
REVENANT_SCALAR_PROPERTY(double, loudness)
@end
@implementation SRAudioLevel (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRDevice (RevenantSensorKit170)
@dynamic productType;
REVENANT_VALUE_PROPERTY(NSString *, productType)
@end
@implementation SRDevice (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRFaceMetrics
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
@dynamic version, sessionIdentifier, context, wholeFaceExpressions, partialFaceExpressions, faceAnchor;
REVENANT_VALUE_PROPERTY(NSString *, version)
REVENANT_VALUE_PROPERTY(NSString *, sessionIdentifier)
REVENANT_SCALAR_PROPERTY(SRFaceMetricsContext, context)
REVENANT_VALUE_PROPERTY(NSArray *, wholeFaceExpressions)
REVENANT_VALUE_PROPERTY(NSArray *, partialFaceExpressions)
REVENANT_VALUE_PROPERTY(id, faceAnchor)
@end
@implementation SRFaceMetrics (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRFaceMetricsExpression
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
@dynamic identifier, value;
REVENANT_VALUE_PROPERTY(NSString *, identifier)
REVENANT_SCALAR_PROPERTY(double, value)
@end
@implementation SRFaceMetricsExpression (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRSpeechExpression
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic version, timeRange, confidence, mood, valence, activation, dominance;
REVENANT_VALUE_PROPERTY(NSString *, version)
REVENANT_STRUCT_PROPERTY(CMTimeRange, timeRange)
REVENANT_SCALAR_PROPERTY(double, confidence)
REVENANT_SCALAR_PROPERTY(double, mood)
REVENANT_SCALAR_PROPERTY(double, valence)
REVENANT_SCALAR_PROPERTY(double, activation)
REVENANT_SCALAR_PROPERTY(double, dominance)
@end
@implementation SRSpeechExpression (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRSpeechMetrics
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic sessionIdentifier, sessionFlags, timestamp, audioLevel, speechExpression,
         speechRecognition, soundClassification;
REVENANT_VALUE_PROPERTY(NSString *, sessionIdentifier)
REVENANT_SCALAR_PROPERTY(SRSpeechMetricsSessionFlags, sessionFlags)
REVENANT_VALUE_PROPERTY(NSDate *, timestamp)
REVENANT_VALUE_PROPERTY(SRAudioLevel *, audioLevel)
REVENANT_VALUE_PROPERTY(SRSpeechExpression *, speechExpression)
REVENANT_VALUE_PROPERTY(id, speechRecognition)
REVENANT_VALUE_PROPERTY(id, soundClassification)
@end
@implementation SRSpeechMetrics (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRWristTemperature
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic timestamp, value, condition, errorEstimate;
REVENANT_VALUE_PROPERTY(NSDate *, timestamp)
REVENANT_VALUE_PROPERTY(NSMeasurement *, value)
REVENANT_SCALAR_PROPERTY(SRWristTemperatureCondition, condition)
REVENANT_VALUE_PROPERTY(NSMeasurement *, errorEstimate)
@end
@implementation SRWristTemperature (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRWristTemperatureSession
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic startDate, duration, version, temperatures;
REVENANT_VALUE_PROPERTY(NSDate *, startDate)
REVENANT_SCALAR_PROPERTY(NSTimeInterval, duration)
REVENANT_VALUE_PROPERTY(NSString *, version)
REVENANT_VALUE_PROPERTY(NSEnumerator *, temperatures)
@end
@implementation SRWristTemperatureSession (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
