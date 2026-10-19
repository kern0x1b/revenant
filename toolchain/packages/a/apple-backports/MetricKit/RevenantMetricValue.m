#import "CharonMetricValue.h"
#import "CharonMetricKit.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CharonMetricValue

+ (NSArray<NSString *> *)propertyNamesOf:(Class)cls
{
    return CharonValuePropertyNames(cls);
}

+ (NSDictionary *)dictionaryOf:(id)value
{
    return CharonValueConvertProperties(value, [MXMetric class], [MXDiagnostic class]);
}

+ (NSData *)jsonOf:(id)value
{
    return CharonValueJSON(value, [MXMetric class], [MXDiagnostic class]);
}

+ (NSSet<Class> *)decodableClasses
{
    return CharonValueDecodableClasses(@"MX");
}

@end

static NSSet<Class> *charon_decodable(void)
{
    return CharonValueDecodableClasses(@"MX");
}

@implementation MXMetric (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)DictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
CHARON_VALUE_CODING_METHODS
@end

@implementation MXDiagnostic (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSArray<MXSignpostRecord *> *)signpostData
{
    return (NSArray<MXSignpostRecord *> *)[self charon_valueForKey:@"signpostData"];
}

- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
CHARON_VALUE_CODING_METHODS
@end

@implementation MXAverage (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXHistogram (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXHistogramBucket (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXMetaData (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)DictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end

@implementation MXMetricPayload (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)DictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end

@implementation MXDiagnosticPayload (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXCrashDiagnosticObjectiveCExceptionReason (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
@end

@implementation MXSignpostRecord (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
CHARON_VALUE_CODING_METHODS
@end

@implementation MXSignpostIntervalData (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXBackgroundExitData (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXForegroundExitData (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXCallStackTree (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
CHARON_VALUE_CODING_METHODS
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@end

@implementation MXUnitAveragePixelLuminance (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
@end

@implementation MXUnitSignalBars (CharonMetricValue)
CHARON_VALUE_STORE_IMPLEMENTATION
@end
