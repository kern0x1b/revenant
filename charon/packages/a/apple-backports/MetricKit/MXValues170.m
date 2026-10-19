#import "CharonMetricKit.h"
#import "CharonMetricValue.h"
// The value classes of this framework that arrived in iOS 17.0, one file for that release alone: an
// object carries API that arrived in one release, so this is the iOS 17.0 half and no two of them are one
// object.

@implementation MXCrashDiagnosticObjectiveCExceptionReason
@dynamic composedMessage, formatString, arguments, exceptionType, className, exceptionName;

CHARON_VALUE_PROPERTY(NSString *, composedMessage)
CHARON_VALUE_PROPERTY(NSString *, formatString)
CHARON_VALUE_PROPERTY(NSArray *, arguments)
CHARON_VALUE_PROPERTY(NSString *, exceptionType)
CHARON_VALUE_PROPERTY(NSString *, className)
CHARON_VALUE_PROPERTY(NSString *, exceptionName)


// Its own header gives it the two representations.
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
@implementation MXSignpostRecord
@dynamic subsystem, category, name, beginTimeStamp, endTimeStamp, duration, isInterval;

CHARON_VALUE_PROPERTY(NSString *, subsystem)
CHARON_VALUE_PROPERTY(NSString *, category)
CHARON_VALUE_PROPERTY(NSString *, name)
CHARON_VALUE_PROPERTY(NSDate *, beginTimeStamp)
CHARON_VALUE_PROPERTY(NSDate *, endTimeStamp)
CHARON_VALUE_PROPERTY(NSMeasurement *, duration)
CHARON_SCALAR_PROPERTY(BOOL, isInterval)


// Its own header gives it the two representations.
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
