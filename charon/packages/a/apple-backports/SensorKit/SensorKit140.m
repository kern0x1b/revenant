#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 14, the release the framework arrived in: 16 classes, 118 properties.
//
// One file per release, because an object carries API that arrived in one release alone. A class is
// implemented in the class itself, with one exception: SRKeyboardMetrics is declared over four
// CATEGORIES of the SDK's own, and a property one of those declares can be neither @dynamic-able in a
// category of ours - the name would be declared twice on the class - nor implemented in a class
// implementation, so those accessors are written out and only the five the class declares itself are
// @dynamic.
//
// Each class is followed by the store it keeps its values in, and the store is the one CharonValueStore
// describes: one dictionary keyed by the property's own name, so a value is found by the same string
// the header declares it under.
@implementation SRAmbientLightSample
@dynamic placement, chromaticity, lux;
CHARON_SCALAR_PROPERTY(SRAmbientLightSensorPlacement, placement)
CHARON_STRUCT_PROPERTY(SRAmbientLightChromaticity, chromaticity)
CHARON_VALUE_PROPERTY(NSMeasurement *, lux)
@end

@implementation SRAmbientLightSample (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRApplicationUsage
@dynamic bundleIdentifier, usageTime;
CHARON_VALUE_PROPERTY(NSString *, bundleIdentifier)
CHARON_SCALAR_PROPERTY(NSTimeInterval, usageTime)
@end

@implementation SRApplicationUsage (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRDeletionRecord
@dynamic startTime, endTime, reason;
CHARON_SCALAR_PROPERTY(SRAbsoluteTime, startTime)
CHARON_SCALAR_PROPERTY(SRAbsoluteTime, endTime)
CHARON_SCALAR_PROPERTY(SRDeletionReason, reason)
// The SDK's own header declares this class conforming, so the port owes the three archiving methods,
// and -copyWithZone: where the header says NSCopying. The archiver walks the same property list the
// representation does, through CharonValueStore's own pair, so a value archived and read back lands in
// the store under the property's own name and nothing has to be written out by hand for it.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        CharonValueDecode(self, coder, CharonValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A value object: the copy is a new object with the same values under the same names. A copy that
    // shared the store would be two names for one value, which is the opposite of what a copy is.
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = CharonValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        CharonValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end

@implementation SRDeletionRecord (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRDevice
@dynamic currentDevice, name, model, systemName, systemVersion;
CHARON_VALUE_PROPERTY(SRDevice *, currentDevice)
CHARON_VALUE_PROPERTY(NSString *, name)
CHARON_VALUE_PROPERTY(NSString *, model)
CHARON_VALUE_PROPERTY(NSString *, systemName)
CHARON_VALUE_PROPERTY(NSString *, systemVersion)
// The SDK's own header declares this class conforming, so the port owes the three archiving methods,
// and -copyWithZone: where the header says NSCopying. The archiver walks the same property list the
// representation does, through CharonValueStore's own pair, so a value archived and read back lands in
// the store under the property's own name and nothing has to be written out by hand for it.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        CharonValueDecode(self, coder, CharonValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A value object: the copy is a new object with the same values under the same names. A copy that
    // shared the store would be two names for one value, which is the opposite of what a copy is.
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = CharonValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        CharonValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end

@implementation SRDevice (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRDeviceUsageReport
@dynamic duration, applicationUsageByCategory, notificationUsageByCategory, webUsageByCategory, totalScreenWakes, totalUnlocks, totalUnlockDuration;
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
CHARON_VALUE_PROPERTY(NSDictionary *, applicationUsageByCategory)
CHARON_VALUE_PROPERTY(NSDictionary *, notificationUsageByCategory)
CHARON_VALUE_PROPERTY(NSDictionary *, webUsageByCategory)
CHARON_SCALAR_PROPERTY(NSInteger, totalScreenWakes)
CHARON_SCALAR_PROPERTY(NSInteger, totalUnlocks)
CHARON_SCALAR_PROPERTY(NSTimeInterval, totalUnlockDuration)
@end

@implementation SRDeviceUsageReport (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRFetchRequest
@dynamic from, to, device;
CHARON_SCALAR_PROPERTY(SRAbsoluteTime, from)
CHARON_SCALAR_PROPERTY(SRAbsoluteTime, to)
CHARON_VALUE_PROPERTY(SRDevice *, device)
// The SDK's own header declares this class conforming, so the port owes the three archiving methods,
// and -copyWithZone: where the header says NSCopying - see the same block on SRDeletionRecord.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        CharonValueDecode(self, coder, CharonValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A value object: the copy is a new object with the same values under the same names.
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = CharonValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        CharonValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end

@implementation SRFetchRequest (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

// The class's own door, declared here because no SDK header declares it and the copy below is its
// only caller. Both this and the registry row naming it are the shape registry/MPS graph.json uses for
// the thirteen charon_ names its own files share.
@interface SRFetchResult ()
- (instancetype)initWithCharonValues:(NSDictionary *)values;
@end

@implementation SRFetchResult
@dynamic timestamp, sample;
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
// The class's own framework refuses -init here, with the exception and the reason string the macro
// carries, so the copy below cannot go through it either and takes the class's own door instead.
CHARON_VALUE_COPY_INITIALISER
CHARON_SCALAR_PROPERTY(SRAbsoluteTime, timestamp)
// The header's SampleType is the class's lightweight generic parameter, an object; the value is held
// in the store like every other member, so an archived result carries its sample through.
CHARON_VALUE_PROPERTY(id, sample)
// The SDK's own header declares this class conforming, so the port owes the three archiving methods,
// and -copyWithZone: where the header says NSCopying - see the same block on SRDeletionRecord.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        CharonValueDecode(self, coder, CharonValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A value object: the copy is a new object with the same values under the same names. SRFetchResult
    // is one of the fourteen classes whose own framework refuses -init, so the new object is made
    // through the door the class keeps for itself.
    return [[[self class] allocWithZone:zone] initWithCharonValues:CharonValueStore(self)];
}

@end

@implementation SRFetchResult (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRKeyboardMetrics
@dynamic duration, keyboardIdentifier, version, width, height;
CHARON_VALUE_PROPERTY(NSString *, keyboardIdentifier)
CHARON_VALUE_PROPERTY(NSString *, version)
CHARON_VALUE_PROPERTY(NSMeasurement *, width)
CHARON_VALUE_PROPERTY(NSMeasurement *, height)
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
-(NSInteger)totalWords { NSNumber *boxed = [self charon_valueForKey:@"totalWords"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalWords:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalWords"]; }
-(NSInteger)totalAlteredWords { NSNumber *boxed = [self charon_valueForKey:@"totalAlteredWords"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalAlteredWords:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalAlteredWords"]; }
-(NSInteger)totalTaps { NSNumber *boxed = [self charon_valueForKey:@"totalTaps"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalTaps:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalTaps"]; }
-(NSInteger)totalDrags { NSNumber *boxed = [self charon_valueForKey:@"totalDrags"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalDrags:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalDrags"]; }
-(NSInteger)totalDeletes { NSNumber *boxed = [self charon_valueForKey:@"totalDeletes"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalDeletes:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalDeletes"]; }
-(NSInteger)totalEmojis { NSNumber *boxed = [self charon_valueForKey:@"totalEmojis"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalEmojis:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalEmojis"]; }
-(NSInteger)totalPaths { NSNumber *boxed = [self charon_valueForKey:@"totalPaths"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalPaths:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalPaths"]; }
-(NSTimeInterval)totalPathTime { NSNumber *boxed = [self charon_valueForKey:@"totalPathTime"];
    return boxed ? (NSTimeInterval)[boxed longLongValue] : (NSTimeInterval)0; }
-(void)charon_setTotalPathTime:(NSTimeInterval)value { [self charon_setValue:@(value) forKey:@"totalPathTime"]; }
-(NSMeasurement *)totalPathLength { return (NSMeasurement *)[self charon_valueForKey:@"totalPathLength"]; }
-(void)charon_setTotalPathLength:(NSMeasurement *)value { [self charon_setValue:value forKey:@"totalPathLength"]; }
-(NSInteger)totalAutoCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalAutoCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalAutoCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalAutoCorrections"]; }
-(NSInteger)totalSpaceCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalSpaceCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalSpaceCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalSpaceCorrections"]; }
-(NSInteger)totalRetroCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalRetroCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalRetroCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalRetroCorrections"]; }
-(NSInteger)totalTranspositionCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalTranspositionCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalTranspositionCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalTranspositionCorrections"]; }
-(NSInteger)totalInsertKeyCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalInsertKeyCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalInsertKeyCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalInsertKeyCorrections"]; }
-(NSInteger)totalSkipTouchCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalSkipTouchCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalSkipTouchCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalSkipTouchCorrections"]; }
-(NSInteger)totalNearKeyCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalNearKeyCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalNearKeyCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalNearKeyCorrections"]; }
-(NSInteger)totalSubstitutionCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalSubstitutionCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalSubstitutionCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalSubstitutionCorrections"]; }
-(NSInteger)totalHitTestCorrections { NSNumber *boxed = [self charon_valueForKey:@"totalHitTestCorrections"];
    return boxed ? (NSInteger)[boxed longLongValue] : (NSInteger)0; }
-(void)charon_setTotalHitTestCorrections:(NSInteger)value { [self charon_setValue:@(value) forKey:@"totalHitTestCorrections"]; }
-(NSTimeInterval)totalTypingDuration { NSNumber *boxed = [self charon_valueForKey:@"totalTypingDuration"];
    return boxed ? (NSTimeInterval)[boxed longLongValue] : (NSTimeInterval)0; }
-(void)charon_setTotalTypingDuration:(NSTimeInterval)value { [self charon_setValue:@(value) forKey:@"totalTypingDuration"]; }
-(SRKeyboardProbabilityMetric *)upErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"upErrorDistance"]; }
-(void)charon_setUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"upErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)downErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"downErrorDistance"]; }
-(void)charon_setDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"downErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)spaceUpErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceUpErrorDistance"]; }
-(void)charon_setSpaceUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceUpErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)spaceDownErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceDownErrorDistance"]; }
-(void)charon_setSpaceDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceDownErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)deleteUpErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteUpErrorDistance"]; }
-(void)charon_setDeleteUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteUpErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)deleteDownErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteDownErrorDistance"]; }
-(void)charon_setDeleteDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteDownErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyUpErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"shortWordCharKeyUpErrorDistance"]; }
-(void)charon_setShortWordCharKeyUpErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"shortWordCharKeyUpErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyDownErrorDistance { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"shortWordCharKeyDownErrorDistance"]; }
-(void)charon_setShortWordCharKeyDownErrorDistance:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"shortWordCharKeyDownErrorDistance"]; }
-(SRKeyboardProbabilityMetric *)touchDownUp { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"touchDownUp"]; }
-(void)charon_setTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"touchDownUp"]; }
-(SRKeyboardProbabilityMetric *)spaceTouchDownUp { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceTouchDownUp"]; }
-(void)charon_setSpaceTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceTouchDownUp"]; }
-(SRKeyboardProbabilityMetric *)deleteTouchDownUp { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteTouchDownUp"]; }
-(void)charon_setDeleteTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteTouchDownUp"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyTouchDownUp { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"shortWordCharKeyTouchDownUp"]; }
-(void)charon_setShortWordCharKeyTouchDownUp:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"shortWordCharKeyTouchDownUp"]; }
-(SRKeyboardProbabilityMetric *)touchDownDown { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"touchDownDown"]; }
-(void)charon_setTouchDownDown:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"touchDownDown"]; }
-(SRKeyboardProbabilityMetric *)charKeyToPrediction { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"charKeyToPrediction"]; }
-(void)charon_setCharKeyToPrediction:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"charKeyToPrediction"]; }
-(SRKeyboardProbabilityMetric *)shortWordCharKeyToCharKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"shortWordCharKeyToCharKey"]; }
-(void)charon_setShortWordCharKeyToCharKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"shortWordCharKeyToCharKey"]; }
-(SRKeyboardProbabilityMetric *)charKeyToAnyTapKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"charKeyToAnyTapKey"]; }
-(void)charon_setCharKeyToAnyTapKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"charKeyToAnyTapKey"]; }
-(SRKeyboardProbabilityMetric *)anyTapToCharKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"anyTapToCharKey"]; }
-(void)charon_setAnyTapToCharKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"anyTapToCharKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToCharKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToCharKey"]; }
-(void)charon_setSpaceToCharKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToCharKey"]; }
-(SRKeyboardProbabilityMetric *)charKeyToSpaceKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"charKeyToSpaceKey"]; }
-(void)charon_setCharKeyToSpaceKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"charKeyToSpaceKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToDeleteKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToDeleteKey"]; }
-(void)charon_setSpaceToDeleteKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToDeleteKey"]; }
-(SRKeyboardProbabilityMetric *)deleteToSpaceKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteToSpaceKey"]; }
-(void)charon_setDeleteToSpaceKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteToSpaceKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToSpaceKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToSpaceKey"]; }
-(void)charon_setSpaceToSpaceKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToSpaceKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToShiftKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToShiftKey"]; }
-(void)charon_setSpaceToShiftKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToShiftKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToPlaneChangeKey"]; }
-(void)charon_setSpaceToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)spaceToPredictionKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToPredictionKey"]; }
-(void)charon_setSpaceToPredictionKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToPredictionKey"]; }
-(SRKeyboardProbabilityMetric *)deleteToCharKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteToCharKey"]; }
-(void)charon_setDeleteToCharKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteToCharKey"]; }
-(SRKeyboardProbabilityMetric *)charKeyToDelete { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"charKeyToDelete"]; }
-(void)charon_setCharKeyToDelete:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"charKeyToDelete"]; }
-(SRKeyboardProbabilityMetric *)deleteToDelete { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteToDelete"]; }
-(void)charon_setDeleteToDelete:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteToDelete"]; }
-(SRKeyboardProbabilityMetric *)deleteToShiftKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteToShiftKey"]; }
-(void)charon_setDeleteToShiftKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteToShiftKey"]; }
-(SRKeyboardProbabilityMetric *)deleteToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteToPlaneChangeKey"]; }
-(void)charon_setDeleteToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)anyTapToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"anyTapToPlaneChangeKey"]; }
-(void)charon_setAnyTapToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"anyTapToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)planeChangeToAnyTap { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"planeChangeToAnyTap"]; }
-(void)charon_setPlaneChangeToAnyTap:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"planeChangeToAnyTap"]; }
-(SRKeyboardProbabilityMetric *)charKeyToPlaneChangeKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"charKeyToPlaneChangeKey"]; }
-(void)charon_setCharKeyToPlaneChangeKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"charKeyToPlaneChangeKey"]; }
-(SRKeyboardProbabilityMetric *)planeChangeKeyToCharKey { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"planeChangeKeyToCharKey"]; }
-(void)charon_setPlaneChangeKeyToCharKey:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"planeChangeKeyToCharKey"]; }
-(NSArray *)pathErrorDistanceRatio { return (NSArray *)[self charon_valueForKey:@"pathErrorDistanceRatio"]; }
-(void)charon_setPathErrorDistanceRatio:(NSArray *)value { [self charon_setValue:value forKey:@"pathErrorDistanceRatio"]; }
-(SRKeyboardProbabilityMetric *)deleteToPath { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"deleteToPath"]; }
-(void)charon_setDeleteToPath:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"deleteToPath"]; }
-(SRKeyboardProbabilityMetric *)pathToDelete { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"pathToDelete"]; }
-(void)charon_setPathToDelete:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"pathToDelete"]; }
-(SRKeyboardProbabilityMetric *)spaceToPath { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"spaceToPath"]; }
-(void)charon_setSpaceToPath:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"spaceToPath"]; }
-(SRKeyboardProbabilityMetric *)pathToSpace { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"pathToSpace"]; }
-(void)charon_setPathToSpace:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"pathToSpace"]; }
-(SRKeyboardProbabilityMetric *)pathToPath { return (SRKeyboardProbabilityMetric *)[self charon_valueForKey:@"pathToPath"]; }
-(void)charon_setPathToPath:(SRKeyboardProbabilityMetric *)value { [self charon_setValue:value forKey:@"pathToPath"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordUpErrorDistance { return (NSArray<SRKeyboardProbabilityMetric *> *)[self charon_valueForKey:@"longWordUpErrorDistance"]; }
-(void)charon_setLongWordUpErrorDistance:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self charon_setValue:value forKey:@"longWordUpErrorDistance"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordDownErrorDistance { return (NSArray<SRKeyboardProbabilityMetric *> *)[self charon_valueForKey:@"longWordDownErrorDistance"]; }
-(void)charon_setLongWordDownErrorDistance:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self charon_setValue:value forKey:@"longWordDownErrorDistance"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordTouchDownUp { return (NSArray<SRKeyboardProbabilityMetric *> *)[self charon_valueForKey:@"longWordTouchDownUp"]; }
-(void)charon_setLongWordTouchDownUp:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self charon_setValue:value forKey:@"longWordTouchDownUp"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)longWordTouchDownDown { return (NSArray<SRKeyboardProbabilityMetric *> *)[self charon_valueForKey:@"longWordTouchDownDown"]; }
-(void)charon_setLongWordTouchDownDown:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self charon_setValue:value forKey:@"longWordTouchDownDown"]; }
-(NSArray<SRKeyboardProbabilityMetric *> *)deleteToDeletes { return (NSArray<SRKeyboardProbabilityMetric *> *)[self charon_valueForKey:@"deleteToDeletes"]; }
-(void)charon_setDeleteToDeletes:(NSArray<SRKeyboardProbabilityMetric *> *)value { [self charon_setValue:value forKey:@"deleteToDeletes"]; }
@end

@implementation SRKeyboardMetrics (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRKeyboardProbabilityMetric
@dynamic distributionSampleValues;
CHARON_VALUE_PROPERTY(NSArray<NSMeasurement *> *, distributionSampleValues)
@end

@implementation SRKeyboardProbabilityMetric (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRMessagesUsageReport
@dynamic duration, totalOutgoingMessages, totalIncomingMessages, totalUniqueContacts;
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
CHARON_SCALAR_PROPERTY(NSInteger, totalOutgoingMessages)
CHARON_SCALAR_PROPERTY(NSInteger, totalIncomingMessages)
CHARON_SCALAR_PROPERTY(NSInteger, totalUniqueContacts)
@end

@implementation SRMessagesUsageReport (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRNotificationUsage
@dynamic bundleIdentifier, event;
CHARON_VALUE_PROPERTY(NSString *, bundleIdentifier)
CHARON_SCALAR_PROPERTY(SRNotificationEvent, event)
@end

@implementation SRNotificationUsage (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRPhoneUsageReport
@dynamic duration, totalOutgoingCalls, totalIncomingCalls, totalUniqueContacts, totalPhoneCallDuration;
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
CHARON_SCALAR_PROPERTY(NSInteger, totalOutgoingCalls)
CHARON_SCALAR_PROPERTY(NSInteger, totalIncomingCalls)
CHARON_SCALAR_PROPERTY(NSInteger, totalUniqueContacts)
CHARON_SCALAR_PROPERTY(NSTimeInterval, totalPhoneCallDuration)
@end

@implementation SRPhoneUsageReport (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRVisit
@dynamic distanceFromHome, arrivalDateInterval, departureDateInterval, locationCategory, identifier;
CHARON_SCALAR_PROPERTY(CLLocationDistance, distanceFromHome)
CHARON_VALUE_PROPERTY(NSDateInterval *, arrivalDateInterval)
CHARON_VALUE_PROPERTY(NSDateInterval *, departureDateInterval)
CHARON_SCALAR_PROPERTY(SRLocationCategory, locationCategory)
CHARON_VALUE_PROPERTY(NSUUID *, identifier)
@end

@implementation SRVisit (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRWebUsage
@dynamic totalUsageTime;
CHARON_SCALAR_PROPERTY(NSTimeInterval, totalUsageTime)
@end

@implementation SRWebUsage (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

@implementation SRWristDetection
@dynamic onWrist, wristLocation, crownOrientation;
CHARON_SCALAR_PROPERTY(BOOL, onWrist)
CHARON_SCALAR_PROPERTY(SRWristLocation, wristLocation)
CHARON_SCALAR_PROPERTY(SRCrownOrientation, crownOrientation)
@end

@implementation SRWristDetection (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
