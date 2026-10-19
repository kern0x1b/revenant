#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 17.0, the properties that arrived then.
@implementation SRAudioLevel
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic timeRange, loudness;
CHARON_STRUCT_PROPERTY(CMTimeRange, timeRange)
CHARON_SCALAR_PROPERTY(double, loudness)
@end
@implementation SRAudioLevel (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
// -productType is declared in the (CharonSensorKit170) category of CharonSensorKit.h, because the 16.4
// SDK does not have it, and a property a category declares is implemented in a category.
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
// faceAnchor is ARFaceAnchor * in the header and ARKit is not a framework this package carries, so it is
// declared as id and read out of the store under its own name like every other property here. Nil is
// what comes back when nothing was archived under it, which is what the host's own framework answers
// for a face reading - except that the host does not implement it at all, so that nil is the port's and
// the row says so.
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
// The two whose types Speech and SoundAnalysis own, so they are id here and nil from the store when
// nothing was archived under them. Both are nullable in the header, and BOTH read nil on the host's own
// SensorKit for a metrics object with no session - measured over ten categories' worth of the same
// shape in the harness facts/SensorKit/SensorKit.md names. Declaring them matters beyond the accessor:
// the archiver walks the declared property list, so an undeclared one is dropped on the way out.
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

// The string constants of iOS 17.0 are NOT here, and where they went is the point. SRSensors.h declares
// all four API_AVAILABLE(ios(17.0)), and check_releases does not agree for two of them: it places
// SRSensorHeartRate and SRSensorOdometer at 16.0 and SRSensorFaceMetrics and SRSensorWristTemperature at
// 18.0, so an object carrying this file's classes alongside them held three releases at once. They are in
// SensorKit160.m and SensorKit180.m now, and the measurements behind them are unchanged.
