#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

// ExposureNotification's value types, iOS 12.5.
//
// Seven of the framework's nine classes are values the framework itself produces and hands an
// application: a temporary exposure key, a scan instance, a summary item, an exposure window, a day's
// summary, the summary of a detection pass, and the information about one exposure. The ninth,
// ENExposureConfiguration, is the one an application writes and ENManager reads; it is ENExposure-
// Configuration.m.
//
// None of the seven declares a public initialiser in any SDK header -- SDK 26.2's ENCommon.h gives each
// class's properties and nothing else -- because on a system that runs Exposure Notification they only
// ever come out of the framework's own service. On this release that service does not exist (see
// ENManager.m), so these classes are reached the other way round: as NSSecureCoding, the protocol every
// one of them adopts in Apple's own header, over the release's own NSKeyedArchiver and NSKeyedUnarchiver.
// That is the whole surface then -- the properties, and the coding that carries them.
//
// The archive keys are the property names. That is the shape a keyed archive of an object with these
// properties has, and it round-trips: what one of these writes, another reads back with every property
// answering what it was given. Nothing on this release produces Apple's own archive of these objects, so
// there is no second archive to agree with; what would make it one is ENManager answering with real
// values, which needs the exposure-notification service this release does not run.
//
// One release per object file: every property below arrived in iOS 12.5 and none of them is a member of
// anything this release carries. ENExposureWindow's variantOfConcernType arrived in 15.2 and is carried
// by ENExposureWindowVariant15.m, whose associated object holds the value. This class is @dynamic for
// the property so that the 12.5 object exports no symbol for a member of a later release.


@implementation ENExposureSummaryItem {
    double _scoreSum;
    double _maximumScore;
    double _weightedDurationSum;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _scoreSum = (double)[[coder decodeObjectForKey:@"scoreSum"] doubleValue];
    _maximumScore = (double)[[coder decodeObjectForKey:@"maximumScore"] doubleValue];
    _weightedDurationSum = (double)[[coder decodeObjectForKey:@"weightedDurationSum"] doubleValue];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithDouble: _scoreSum] forKey:@"scoreSum"];
    [coder encodeObject:[NSNumber numberWithDouble: _maximumScore] forKey:@"maximumScore"];
    [coder encodeObject:[NSNumber numberWithDouble: _weightedDurationSum] forKey:@"weightedDurationSum"];
}

@end

@implementation ENScanInstance {
    NSInteger _secondsSinceLastScan;
    ENAttenuation _minimumAttenuation;
    ENAttenuation _typicalAttenuation;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _secondsSinceLastScan = (NSInteger)[[coder decodeObjectForKey:@"secondsSinceLastScan"] integerValue];
    _minimumAttenuation = (ENAttenuation)[[coder decodeObjectForKey:@"minimumAttenuation"] unsignedCharValue];
    _typicalAttenuation = (ENAttenuation)[[coder decodeObjectForKey:@"typicalAttenuation"] unsignedCharValue];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithInteger: _secondsSinceLastScan] forKey:@"secondsSinceLastScan"];
    [coder encodeObject:[NSNumber numberWithUnsignedChar: _minimumAttenuation] forKey:@"minimumAttenuation"];
    [coder encodeObject:[NSNumber numberWithUnsignedChar: _typicalAttenuation] forKey:@"typicalAttenuation"];
}

@end

@implementation ENExposureWindow {
    id _date;
    id _scanInstances;
    ENDiagnosisReportType _diagnosisReportType;
    ENInfectiousness _infectiousness;
    ENCalibrationConfidence _calibrationConfidence;
}

// variantOfConcernType arrived in 15.2 and is carried by ENExposureWindowVariant15.m, so the
// auto-synthesis of this class's own properties has to be told that one is not among them.
@dynamic variantOfConcernType;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _date = [coder decodeObjectForKey:@"date"];
    _scanInstances = [coder decodeObjectForKey:@"scanInstances"];
    _diagnosisReportType = (ENDiagnosisReportType)[[coder decodeObjectForKey:@"diagnosisReportType"] unsignedIntValue];
    _infectiousness = (ENInfectiousness)[[coder decodeObjectForKey:@"infectiousness"] unsignedIntValue];
    _calibrationConfidence = (ENCalibrationConfidence)[[coder decodeObjectForKey:@"calibrationConfidence"] unsignedCharValue];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeObject:_scanInstances forKey:@"scanInstances"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _diagnosisReportType] forKey:@"diagnosisReportType"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _infectiousness] forKey:@"infectiousness"];
    [coder encodeObject:[NSNumber numberWithUnsignedChar: _calibrationConfidence] forKey:@"calibrationConfidence"];
}

@end

@implementation ENExposureDaySummary {
    id _date;
    id _confirmedTestSummary;
    id _confirmedClinicalDiagnosisSummary;
    id _recursiveSummary;
    id _selfReportedSummary;
    id _daySummary;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _date = [coder decodeObjectForKey:@"date"];
    _confirmedTestSummary = [coder decodeObjectForKey:@"confirmedTestSummary"];
    _confirmedClinicalDiagnosisSummary = [coder decodeObjectForKey:@"confirmedClinicalDiagnosisSummary"];
    _recursiveSummary = [coder decodeObjectForKey:@"recursiveSummary"];
    _selfReportedSummary = [coder decodeObjectForKey:@"selfReportedSummary"];
    _daySummary = [coder decodeObjectForKey:@"daySummary"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeObject:_confirmedTestSummary forKey:@"confirmedTestSummary"];
    [coder encodeObject:_confirmedClinicalDiagnosisSummary forKey:@"confirmedClinicalDiagnosisSummary"];
    [coder encodeObject:_recursiveSummary forKey:@"recursiveSummary"];
    [coder encodeObject:_selfReportedSummary forKey:@"selfReportedSummary"];
    [coder encodeObject:_daySummary forKey:@"daySummary"];
}

@end

@implementation ENExposureDetectionSummary {
    NSInteger _daysSinceLastExposure;
    uint64_t _matchedKeyCount;
    ENRiskScore _maximumRiskScore;
    double _maximumRiskScoreFullRange;
    double _riskScoreSumFullRange;
    id _attenuationDurations;
    id _metadata;
    id _daySummaries;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _daysSinceLastExposure = (NSInteger)[[coder decodeObjectForKey:@"daysSinceLastExposure"] integerValue];
    _matchedKeyCount = (uint64_t)[[coder decodeObjectForKey:@"matchedKeyCount"] unsignedLongLongValue];
    _maximumRiskScore = (ENRiskScore)[[coder decodeObjectForKey:@"maximumRiskScore"] unsignedCharValue];
    _maximumRiskScoreFullRange = (double)[[coder decodeObjectForKey:@"maximumRiskScoreFullRange"] doubleValue];
    _riskScoreSumFullRange = (double)[[coder decodeObjectForKey:@"riskScoreSumFullRange"] doubleValue];
    _attenuationDurations = [coder decodeObjectForKey:@"attenuationDurations"];
    _metadata = [coder decodeObjectForKey:@"metadata"];
    _daySummaries = [coder decodeObjectForKey:@"daySummaries"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithInteger: _daysSinceLastExposure] forKey:@"daysSinceLastExposure"];
    [coder encodeObject:[NSNumber numberWithUnsignedLongLong: _matchedKeyCount] forKey:@"matchedKeyCount"];
    [coder encodeObject:[NSNumber numberWithUnsignedChar: _maximumRiskScore] forKey:@"maximumRiskScore"];
    [coder encodeObject:[NSNumber numberWithDouble: _maximumRiskScoreFullRange] forKey:@"maximumRiskScoreFullRange"];
    [coder encodeObject:[NSNumber numberWithDouble: _riskScoreSumFullRange] forKey:@"riskScoreSumFullRange"];
    [coder encodeObject:_attenuationDurations forKey:@"attenuationDurations"];
    [coder encodeObject:_metadata forKey:@"metadata"];
    [coder encodeObject:_daySummaries forKey:@"daySummaries"];
}

@end

@implementation ENExposureInfo {
    id _date;
    ENDiagnosisReportType _diagnosisReportType;
    NSInteger _daysSinceOnsetOfSymptoms;
    double _duration;
    ENRiskScore _totalRiskScore;
    double _totalRiskScoreFullRange;
    ENAttenuation _attenuationValue;
    ENRiskLevel _transmissionRiskLevel;
    id _attenuationDurations;
    id _metadata;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _date = [coder decodeObjectForKey:@"date"];
    _diagnosisReportType = (ENDiagnosisReportType)[[coder decodeObjectForKey:@"diagnosisReportType"] unsignedIntValue];
    _daysSinceOnsetOfSymptoms = (NSInteger)[[coder decodeObjectForKey:@"daysSinceOnsetOfSymptoms"] integerValue];
    _duration = (double)[[coder decodeObjectForKey:@"duration"] doubleValue];
    _totalRiskScore = (ENRiskScore)[[coder decodeObjectForKey:@"totalRiskScore"] unsignedCharValue];
    _totalRiskScoreFullRange = (double)[[coder decodeObjectForKey:@"totalRiskScoreFullRange"] doubleValue];
    _attenuationValue = (ENAttenuation)[[coder decodeObjectForKey:@"attenuationValue"] unsignedCharValue];
    _transmissionRiskLevel = (ENRiskLevel)[[coder decodeObjectForKey:@"transmissionRiskLevel"] unsignedIntValue];
    _attenuationDurations = [coder decodeObjectForKey:@"attenuationDurations"];
    _metadata = [coder decodeObjectForKey:@"metadata"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _diagnosisReportType] forKey:@"diagnosisReportType"];
    [coder encodeObject:[NSNumber numberWithInteger: _daysSinceOnsetOfSymptoms] forKey:@"daysSinceOnsetOfSymptoms"];
    [coder encodeObject:[NSNumber numberWithDouble: _duration] forKey:@"duration"];
    [coder encodeObject:[NSNumber numberWithUnsignedChar: _totalRiskScore] forKey:@"totalRiskScore"];
    [coder encodeObject:[NSNumber numberWithDouble: _totalRiskScoreFullRange] forKey:@"totalRiskScoreFullRange"];
    [coder encodeObject:[NSNumber numberWithUnsignedChar: _attenuationValue] forKey:@"attenuationValue"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _transmissionRiskLevel] forKey:@"transmissionRiskLevel"];
    [coder encodeObject:_attenuationDurations forKey:@"attenuationDurations"];
    [coder encodeObject:_metadata forKey:@"metadata"];
}

@end

@implementation ENTemporaryExposureKey {
    id _keyData;
    ENIntervalNumber _rollingStartNumber;
    ENIntervalNumber _rollingPeriod;
    ENRiskLevel _transmissionRiskLevel;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _keyData = [coder decodeObjectForKey:@"keyData"];
    _rollingStartNumber = (ENIntervalNumber)[[coder decodeObjectForKey:@"rollingStartNumber"] unsignedIntValue];
    _rollingPeriod = (ENIntervalNumber)[[coder decodeObjectForKey:@"rollingPeriod"] unsignedIntValue];
    _transmissionRiskLevel = (ENRiskLevel)[[coder decodeObjectForKey:@"transmissionRiskLevel"] unsignedIntValue];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_keyData forKey:@"keyData"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _rollingStartNumber] forKey:@"rollingStartNumber"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _rollingPeriod] forKey:@"rollingPeriod"];
    [coder encodeObject:[NSNumber numberWithUnsignedInt: _transmissionRiskLevel] forKey:@"transmissionRiskLevel"];
}

@end
