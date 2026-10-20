#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import "../RevenantValueStore.h"

@implementation SRAmbientLightSample
@dynamic placement, chromaticity, lux;
REVENANT_SCALAR_PROPERTY(SRAmbientLightSensorPlacement, placement)
REVENANT_STRUCT_PROPERTY(SRAmbientLightChromaticity, chromaticity)
REVENANT_VALUE_PROPERTY(NSMeasurement *, lux)
@end

@implementation SRAmbientLightSample (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRApplicationUsage
@dynamic bundleIdentifier, usageTime;
REVENANT_VALUE_PROPERTY(NSString *, bundleIdentifier)
REVENANT_SCALAR_PROPERTY(NSTimeInterval, usageTime)
@end

@implementation SRApplicationUsage (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRDeletionRecord
@dynamic startTime, endTime, reason;
REVENANT_SCALAR_PROPERTY(SRAbsoluteTime, startTime)
REVENANT_SCALAR_PROPERTY(SRAbsoluteTime, endTime)
REVENANT_SCALAR_PROPERTY(SRDeletionReason, reason)
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    RevenantValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        RevenantValueDecode(self, coder, RevenantValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = RevenantValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        RevenantValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end

@implementation SRDeletionRecord (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRDevice
@dynamic currentDevice, name, model, systemName, systemVersion;
REVENANT_VALUE_PROPERTY(SRDevice *, currentDevice)
REVENANT_VALUE_PROPERTY(NSString *, name)
REVENANT_VALUE_PROPERTY(NSString *, model)
REVENANT_VALUE_PROPERTY(NSString *, systemName)
REVENANT_VALUE_PROPERTY(NSString *, systemVersion)
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    RevenantValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        RevenantValueDecode(self, coder, RevenantValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = RevenantValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        RevenantValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end

@implementation SRDevice (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRDeviceUsageReport
@dynamic duration, applicationUsageByCategory, notificationUsageByCategory, webUsageByCategory, totalScreenWakes, totalUnlocks, totalUnlockDuration;
REVENANT_SCALAR_PROPERTY(NSTimeInterval, duration)
REVENANT_VALUE_PROPERTY(NSDictionary *, applicationUsageByCategory)
REVENANT_VALUE_PROPERTY(NSDictionary *, notificationUsageByCategory)
REVENANT_VALUE_PROPERTY(NSDictionary *, webUsageByCategory)
REVENANT_SCALAR_PROPERTY(NSInteger, totalScreenWakes)
REVENANT_SCALAR_PROPERTY(NSInteger, totalUnlocks)
REVENANT_SCALAR_PROPERTY(NSTimeInterval, totalUnlockDuration)
@end

@implementation SRDeviceUsageReport (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRFetchRequest
@dynamic from, to, device;
REVENANT_SCALAR_PROPERTY(SRAbsoluteTime, from)
REVENANT_SCALAR_PROPERTY(SRAbsoluteTime, to)
REVENANT_VALUE_PROPERTY(SRDevice *, device)
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    RevenantValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        RevenantValueDecode(self, coder, RevenantValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = RevenantValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        RevenantValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end

@implementation SRFetchRequest (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@interface SRFetchResult ()
- (instancetype)initWithRevenantValues:(NSDictionary *)values;
@end

@implementation SRFetchResult
@dynamic timestamp, sample;
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
REVENANT_VALUE_COPY_INITIALISER
REVENANT_SCALAR_PROPERTY(SRAbsoluteTime, timestamp)
REVENANT_VALUE_PROPERTY(id, sample)
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    RevenantValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        RevenantValueDecode(self, coder, RevenantValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithRevenantValues:RevenantValueStore(self)];
}

@end

@implementation SRFetchResult (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRKeyboardMetrics
@dynamic duration, keyboardIdentifier, version, width, height;
REVENANT_VALUE_PROPERTY(NSString *, keyboardIdentifier)
REVENANT_VALUE_PROPERTY(NSString *, version)
REVENANT_VALUE_PROPERTY(NSMeasurement *, width)
REVENANT_VALUE_PROPERTY(NSMeasurement *, height)
REVENANT_SCALAR_PROPERTY(NSTimeInterval, duration)
-(NSInteger)totalWords { NSNumber *boxed = [self revenant_valueForKey:@"totalWords"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalWords:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalWords"]; }
-(NSInteger)totalAlteredWords { NSNumber *boxed = [self revenant_valueForKey:@"totalAlteredWords"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalAlteredWords:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalAlteredWords"]; }
-(NSInteger)totalTaps { NSNumber *boxed = [self revenant_valueForKey:@"totalTaps"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalTaps:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalTaps"]; }
-(NSInteger)totalDrags { NSNumber *boxed = [self revenant_valueForKey:@"totalDrags"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalDrags:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalDrags"]; }
-(NSInteger)totalDeletes { NSNumber *boxed = [self revenant_valueForKey:@"totalDeletes"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalDeletes:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalDeletes"]; }
-(NSInteger)totalEmojis { NSNumber *boxed = [self revenant_valueForKey:@"totalEmojis"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalEmojis:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalEmojis"]; }
-(NSInteger)totalPaths { NSNumber *boxed = [self revenant_valueForKey:@"totalPaths"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalPaths:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalPaths"]; }
-(NSTimeInterval)totalPathTime { NSNumber *boxed = [self revenant_valueForKey:@"totalPathTime"];
    return boxed ? (NSTimeInterval)[boxed longLongValue] : (NSTimeInterval)0; }
-(void)revenant_setTotalPathTime:(NSTimeInterval)value { [self revenant_setValue:@(value) forKey:@"totalPathTime"]; }
-(NSMeasurement *)totalPathLength { return (NSMeasurement *)[self revenant_valueForKey:@"totalPathLength"]; }
-(void)revenant_setTotalPathLength:(NSMeasurement *)value { [self revenant_setValue:value forKey:@"totalPathLength"]; }
-(NSInteger)totalAutoCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalAutoCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalAutoCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalAutoCorrections"]; }
-(NSInteger)totalSpaceCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalSpaceCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalSpaceCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalSpaceCorrections"]; }
-(NSInteger)totalRetroCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalRetroCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalRetroCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalRetroCorrections"]; }
-(NSInteger)totalTranspositionCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalTranspositionCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalTranspositionCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalTranspositionCorrections"]; }
-(NSInteger)totalInsertKeyCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalInsertKeyCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalInsertKeyCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalInsertKeyCorrections"]; }
-(NSInteger)totalSkipTouchCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalSkipTouchCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalSkipTouchCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalSkipTouchCorrections"]; }
-(NSInteger)totalNearKeyCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalNearKeyCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalNearKeyCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalNearKeyCorrections"]; }
-(NSInteger)totalSubstitutionCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalSubstitutionCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalSubstitutionCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalSubstitutionCorrections"]; }
-(NSInteger)totalHitTestCorrections { NSNumber *boxed = [self revenant_valueForKey:@"totalHitTestCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)revenant_setTotalHitTestCorrections:(NSInteger)value { [self revenant_setValue:@(value) forKey:@"totalHitTestCorrections"]; }
-(NSTimeInterval)totalTypingDuration { NSNumber *boxed = [self revenant_valueForKey:@"totalTypingDuration"];
    return boxed ? (NSTimeInterval)[boxed longLongValue] : (NSTimeInterval)0; }
-(void)revenant_setTotalTypingDuration:(NSTimeInterval)value { [self revenant_setValue:@(value) forKey:@"totalTypingDuration"]; }
-(SRKeyboardProbabilityMetric *)upErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"upErrorDistance"]; }
-(void)revenant_setUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"upErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)downErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"downErrorDistance"]; }
-(void)revenant_setDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"downErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)spaceUpErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceUpErrorDistance"]; }
-(void)revenant_setSpaceUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceUpErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)spaceDownErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceDownErrorDistance"]; }
-(void)revenant_setSpaceDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceDownErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)deleteUpErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteUpErrorDistance"]; }
-(void)revenant_setDeleteUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteUpErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)deleteDownErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteDownErrorDistance"]; }
-(void)revenant_setDeleteDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteDownErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyUpErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"shortWordCharKeyUpErrorDistance"]; }
-(void)revenant_setShortWordCharKeyUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"shortWordCharKeyUpErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyDownErrorDistance { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"shortWordCharKeyDownErrorDistance"]; }
-(void)revenant_setShortWordCharKeyDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"shortWordCharKeyDownErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)touchDownUp { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"touchDownUp"]; }
-(void)revenant_setTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"touchDownUp"]; }
-(SRKeyboardProbabilityMetric *)spaceTouchDownUp { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceTouchDownUp"]; }
-(void)revenant_setSpaceTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceTouchDownUp"]; }
-(SRKeyboardProbabilityMetric *)deleteTouchDownUp { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteTouchDownUp"]; }
-(void)revenant_setDeleteTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteTouchDownUp"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyTouchDownUp { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"shortWordCharKeyTouchDownUp"]; }
-(void)revenant_setShortWordCharKeyTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"shortWordCharKeyTouchDownUp"]; }
-(SRKeyboardProbabilityMetric *)touchDownDown { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"touchDownDown"]; }
-(void)revenant_setTouchDownDown:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"touchDownDown"]; }
-(SRKeyboardProbabilityMetric *)charKeyToPrediction { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"charKeyToPrediction"]; }
-(void)revenant_setCharKeyToPrediction:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"charKeyToPrediction"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyToCharKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"shortWordCharKeyToCharKey"]; }
-(void)revenant_setShortWordCharKeyToCharKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"shortWordCharKeyToCharKey"]; }
-(SRKeyboardProbabilityMetric *)charKeyToAnyTapKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"charKeyToAnyTapKey"]; }
-(void)revenant_setCharKeyToAnyTapKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"charKeyToAnyTapKey"]; }
-(SRKeyboardProbabilityMetric *)anyTapToCharKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"anyTapToCharKey"]; }
-(void)revenant_setAnyTapToCharKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"anyTapToCharKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToCharKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToCharKey"]; }
-(void)revenant_setSpaceToCharKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToCharKey"]; }
-(SRKeyboardProbabilityMetric *)charKeyToSpaceKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"charKeyToSpaceKey"]; }
-(void)revenant_setCharKeyToSpaceKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"charKeyToSpaceKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToDeleteKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToDeleteKey"]; }
-(void)revenant_setSpaceToDeleteKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToDeleteKey"]; }
-(SRKeyboardProbabilityMetric *)deleteToSpaceKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteToSpaceKey"]; }
-(void)revenant_setDeleteToSpaceKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteToSpaceKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToSpaceKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToSpaceKey"]; }
-(void)revenant_setSpaceToSpaceKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToSpaceKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToShiftKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToShiftKey"]; }
-(void)revenant_setSpaceToShiftKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToShiftKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToPlaneChangeKey"]; }
-(void)revenant_setSpaceToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToPredictionKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToPredictionKey"]; }
-(void)revenant_setSpaceToPredictionKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToPredictionKey"]; }
-(SRKeyboardProbabilityMetric *)deleteToCharKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteToCharKey"]; }
-(void)revenant_setDeleteToCharKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteToCharKey"]; }
-(SRKeyboardProbabilityMetric *)charKeyToDelete { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"charKeyToDelete"]; }
-(void)revenant_setCharKeyToDelete:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"charKeyToDelete"]; }
-(SRKeyboardProbabilityMetric *)deleteToDelete { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteToDelete"]; }
-(void)revenant_setDeleteToDelete:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteToDelete"]; }
-(SRKeyboardProbabilityMetric *)deleteToShiftKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteToShiftKey"]; }
-(void)revenant_setDeleteToShiftKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteToShiftKey"]; }
-(SRKeyboardProbabilityMetric *)deleteToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteToPlaneChangeKey"]; }
-(void)revenant_setDeleteToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)anyTapToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"anyTapToPlaneChangeKey"]; }
-(void)revenant_setAnyTapToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"anyTapToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)planeChangeToAnyTap { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"planeChangeToAnyTap"]; }
-(void)revenant_setPlaneChangeToAnyTap:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"planeChangeToAnyTap"]; }
-(SRKeyboardProbabilityMetric *)charKeyToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"charKeyToPlaneChangeKey"]; }
-(void)revenant_setCharKeyToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"charKeyToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)planeChangeKeyToCharKey { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"planeChangeKeyToCharKey"]; }
-(void)revenant_setPlaneChangeKeyToCharKey:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"planeChangeKeyToCharKey"]; }
-(NSArray *)pathErrorDistanceRatio { return (NSArray *)[self revenant_valueForKey:@"pathErrorDistanceRatio"]; }
-(void)revenant_setPathErrorDistanceRatio:(NSArray *)value { [self revenant_setValue:value forKey:@"pathErrorDistanceRatio"]; }
-(SRKeyboardProbabilityMetric *)deleteToPath { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"deleteToPath"]; }
-(void)revenant_setDeleteToPath:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"deleteToPath"]; }
-(SRKeyboardProbabilityMetric *)pathToDelete { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"pathToDelete"]; }
-(void)revenant_setPathToDelete:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"pathToDelete"]; }
-(SRKeyboardProbabilityMetric *)spaceToPath { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"spaceToPath"]; }
-(void)revenant_setSpaceToPath:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"spaceToPath"]; }
-(SRKeyboardProbabilityMetric *)pathToSpace { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"pathToSpace"]; }
-(void)revenant_setPathToSpace:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"pathToSpace"]; }
-(SRKeyboardProbabilityMetric *)pathToPath { return (SRKeyboardProbabilityMetric *)[self revenant_valueForKey:@"pathToPath"]; }
-(void)revenant_setPathToPath:(SRKeyboardProbabilityMetric *)value { [self revenant_setValue:value forKey:@"pathToPath"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordUpErrorDistance { return (NSArray<SRKeyboardProbabilityMetric *> *)[self revenant_valueForKey:@"longWordUpErrorDistance"]; }
-(void)revenant_setLongWordUpErrorDistance:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self revenant_setValue:value forKey:@"longWordUpErrorDistance"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordDownErrorDistance { return (NSArray<SRKeyboardProbabilityMetric *> *)[self revenant_valueForKey:@"longWordDownErrorDistance"]; }
-(void)revenant_setLongWordDownErrorDistance:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self revenant_setValue:value forKey:@"longWordDownErrorDistance"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordTouchDownUp { return (NSArray<SRKeyboardProbabilityMetric *> *)[self revenant_valueForKey:@"longWordTouchDownUp"]; }
-(void)revenant_setLongWordTouchDownUp:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self revenant_setValue:value forKey:@"longWordTouchDownUp"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordTouchDownDown { return (NSArray<SRKeyboardProbabilityMetric *> *)[self revenant_valueForKey:@"longWordTouchDownDown"]; }
-(void)revenant_setLongWordTouchDownDown:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self revenant_setValue:value forKey:@"longWordTouchDownDown"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)deleteToDeletes { return (NSArray<SRKeyboardProbabilityMetric *> *)[self revenant_valueForKey:@"deleteToDeletes"]; }
-(void)revenant_setDeleteToDeletes:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self revenant_setValue:value forKey:@"deleteToDeletes"]; }
@end

@implementation SRKeyboardMetrics (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRKeyboardProbabilityMetric
@dynamic distributionSampleValues;
REVENANT_VALUE_PROPERTY(NSArray<NSMeasurement *> *, distributionSampleValues)
@end

@implementation SRKeyboardProbabilityMetric (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRMessagesUsageReport
@dynamic duration, totalOutgoingMessages, totalIncomingMessages, totalUniqueContacts;
REVENANT_SCALAR_PROPERTY(NSTimeInterval, duration)
REVENANT_SCALAR_PROPERTY(NSInteger, totalOutgoingMessages)
REVENANT_SCALAR_PROPERTY(NSInteger, totalIncomingMessages)
REVENANT_SCALAR_PROPERTY(NSInteger, totalUniqueContacts)
@end

@implementation SRMessagesUsageReport (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRNotificationUsage
@dynamic bundleIdentifier, event;
REVENANT_VALUE_PROPERTY(NSString *, bundleIdentifier)
REVENANT_SCALAR_PROPERTY(SRNotificationEvent, event)
@end

@implementation SRNotificationUsage (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRPhoneUsageReport
@dynamic duration, totalOutgoingCalls, totalIncomingCalls, totalUniqueContacts, totalPhoneCallDuration;
REVENANT_SCALAR_PROPERTY(NSTimeInterval, duration)
REVENANT_SCALAR_PROPERTY(NSInteger, totalOutgoingCalls)
REVENANT_SCALAR_PROPERTY(NSInteger, totalIncomingCalls)
REVENANT_SCALAR_PROPERTY(NSInteger, totalUniqueContacts)
REVENANT_SCALAR_PROPERTY(NSTimeInterval, totalPhoneCallDuration)
@end

@implementation SRPhoneUsageReport (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRVisit
@dynamic distanceFromHome, arrivalDateInterval, departureDateInterval, locationCategory, identifier;
REVENANT_SCALAR_PROPERTY(CLLocationDistance, distanceFromHome)
REVENANT_VALUE_PROPERTY(NSDateInterval *, arrivalDateInterval)
REVENANT_VALUE_PROPERTY(NSDateInterval *, departureDateInterval)
REVENANT_SCALAR_PROPERTY(SRLocationCategory, locationCategory)
REVENANT_VALUE_PROPERTY(NSUUID *, identifier)
@end

@implementation SRVisit (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRWebUsage
@dynamic totalUsageTime;
REVENANT_SCALAR_PROPERTY(NSTimeInterval, totalUsageTime)
@end

@implementation SRWebUsage (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRWristDetection
@dynamic onWrist, wristLocation, crownOrientation;
REVENANT_SCALAR_PROPERTY(BOOL, onWrist)
REVENANT_SCALAR_PROPERTY(SRWristLocation, wristLocation)
REVENANT_SCALAR_PROPERTY(SRCrownOrientation, crownOrientation)
@end

@implementation SRWristDetection (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
