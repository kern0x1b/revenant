#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

@implementation SRAudioLevel
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic timeRange, loudness;
CHARON_STRUCT_PROPERTY(CMTimeRange, timeRange)
CHARON_SCALAR_PROPERTY(double, loudness)
@end
@implementation SRAudioLevel (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRDevice (CharonSensorKit170)
@dynamic productType;
CHARON_VALUE_PROPERTY(NSString *, productType)
@end
@implementation SRDevice (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRFaceMetrics
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
@dynamic version, sessionIdentifier, context, wholeFaceExpressions, partialFaceExpressions, faceAnchor;
CHARON_VALUE_PROPERTY(NSString *, version)
CHARON_VALUE_PROPERTY(NSString *, sessionIdentifier)
CHARON_SCALAR_PROPERTY(SRFaceMetricsContext, context)
CHARON_VALUE_PROPERTY(NSArray *, wholeFaceExpressions)
CHARON_VALUE_PROPERTY(NSArray *, partialFaceExpressions)
CHARON_VALUE_PROPERTY(id, faceAnchor)
@end
@implementation SRFaceMetrics (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRFaceMetricsExpression
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
@dynamic identifier, value;
CHARON_VALUE_PROPERTY(NSString *, identifier)
CHARON_SCALAR_PROPERTY(double, value)
@end
@implementation SRFaceMetricsExpression (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRSpeechExpression
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic version, timeRange, confidence, mood, valence, activation, dominance;
CHARON_VALUE_PROPERTY(NSString *, version)
CHARON_STRUCT_PROPERTY(CMTimeRange, timeRange)
CHARON_SCALAR_PROPERTY(double, confidence)
CHARON_SCALAR_PROPERTY(double, mood)
CHARON_SCALAR_PROPERTY(double, valence)
CHARON_SCALAR_PROPERTY(double, activation)
CHARON_SCALAR_PROPERTY(double, dominance)
@end
@implementation SRSpeechExpression (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRSpeechMetrics
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic sessionIdentifier, sessionFlags, timestamp, audioLevel, speechExpression,
         speechRecognition, soundClassification;
CHARON_VALUE_PROPERTY(NSString *, sessionIdentifier)
CHARON_SCALAR_PROPERTY(SRSpeechMetricsSessionFlags, sessionFlags)
CHARON_VALUE_PROPERTY(NSDate *, timestamp)
CHARON_VALUE_PROPERTY(SRAudioLevel *, audioLevel)
CHARON_VALUE_PROPERTY(SRSpeechExpression *, speechExpression)
CHARON_VALUE_PROPERTY(id, speechRecognition)
CHARON_VALUE_PROPERTY(id, soundClassification)
@end
@implementation SRSpeechMetrics (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRWristTemperature
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic timestamp, value, condition, errorEstimate;
CHARON_VALUE_PROPERTY(NSDate *, timestamp)
CHARON_VALUE_PROPERTY(NSMeasurement *, value)
CHARON_SCALAR_PROPERTY(SRWristTemperatureCondition, condition)
CHARON_VALUE_PROPERTY(NSMeasurement *, errorEstimate)
@end
@implementation SRWristTemperature (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRWristTemperatureSession
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic startDate, duration, version, temperatures;
CHARON_VALUE_PROPERTY(NSDate *, startDate)
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
CHARON_VALUE_PROPERTY(NSString *, version)
CHARON_VALUE_PROPERTY(NSEnumerator *, temperatures)
@end
@implementation SRWristTemperatureSession (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
