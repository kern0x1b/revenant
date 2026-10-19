#import "CharonMetricKit.h"
#import "CharonMetricValue.h"

@implementation MXCrashDiagnosticObjectiveCExceptionReason
@dynamic composedMessage, formatString, arguments, exceptionType, className, exceptionName;

CHARON_VALUE_PROPERTY(NSString *, composedMessage)
CHARON_VALUE_PROPERTY(NSString *, formatString)
CHARON_VALUE_PROPERTY(NSArray *, arguments)
CHARON_VALUE_PROPERTY(NSString *, exceptionType)
CHARON_VALUE_PROPERTY(NSString *, className)
CHARON_VALUE_PROPERTY(NSString *, exceptionName)


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


- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
