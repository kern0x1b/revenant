#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>


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
