#import "RevenantMetricKit.h"
#import "RevenantMetricValue.h"

@implementation MXCrashDiagnosticObjectiveCExceptionReason
@dynamic composedMessage, formatString, arguments, exceptionType, className, exceptionName;

REVENANT_VALUE_PROPERTY(NSString *, composedMessage)
REVENANT_VALUE_PROPERTY(NSString *, formatString)
REVENANT_VALUE_PROPERTY(NSArray *, arguments)
REVENANT_VALUE_PROPERTY(NSString *, exceptionType)
REVENANT_VALUE_PROPERTY(NSString *, className)
REVENANT_VALUE_PROPERTY(NSString *, exceptionName)


- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end
@implementation MXSignpostRecord
@dynamic subsystem, category, name, beginTimeStamp, endTimeStamp, duration, isInterval;

REVENANT_VALUE_PROPERTY(NSString *, subsystem)
REVENANT_VALUE_PROPERTY(NSString *, category)
REVENANT_VALUE_PROPERTY(NSString *, name)
REVENANT_VALUE_PROPERTY(NSDate *, beginTimeStamp)
REVENANT_VALUE_PROPERTY(NSDate *, endTimeStamp)
REVENANT_VALUE_PROPERTY(NSMeasurement *, duration)
REVENANT_SCALAR_PROPERTY(BOOL, isInterval)


- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end
