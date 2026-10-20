#import "RevenantMetricValue.h"
#import "RevenantMetricKit.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation RevenantMetricValue

+ (NSArray<NSString *> *)propertyNamesOf:(Class)cls
{
    return RevenantValuePropertyNames(cls);
}

+ (NSDictionary *)dictionaryOf:(id)value
{
    return RevenantValueConvertProperties(value, [MXMetric class], [MXDiagnostic class]);
}

+ (NSData *)jsonOf:(id)value
{
    return RevenantValueJSON(value, [MXMetric class], [MXDiagnostic class]);
}

+ (NSSet<Class> *)decodableClasses
{
    return RevenantValueDecodableClasses(@"MX");
}

@end

static NSSet<Class> *revenant_decodable(void)
{
    return RevenantValueDecodableClasses(@"MX");
}

@implementation MXMetric (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)DictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
REVENANT_VALUE_CODING_METHODS
@end

@implementation MXDiagnostic (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSArray<MXSignpostRecord *> *)signpostData
{
    return (NSArray<MXSignpostRecord *> *)[self revenant_valueForKey:@"signpostData"];
}

- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
REVENANT_VALUE_CODING_METHODS
@end

@implementation MXAverage (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXHistogram (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXHistogramBucket (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXMetaData (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)DictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end

@implementation MXMetricPayload (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)DictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end

@implementation MXDiagnosticPayload (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXCrashDiagnosticObjectiveCExceptionReason (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
@end

@implementation MXSignpostRecord (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
REVENANT_VALUE_CODING_METHODS
@end

@implementation MXSignpostIntervalData (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXBackgroundExitData (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXForegroundExitData (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXCallStackTree (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
REVENANT_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXUnitAveragePixelLuminance (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
@end

@implementation MXUnitSignalBars (RevenantMetricValue)
REVENANT_VALUE_STORE_IMPLEMENTATION
@end
