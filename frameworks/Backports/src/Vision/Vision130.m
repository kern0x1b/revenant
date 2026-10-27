#import "RevenantVision.h"
#import "VNTextRecognizer.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

VNAnimalIdentifier const VNAnimalIdentifierCat = @"Cat";
VNAnimalIdentifier const VNAnimalIdentifierDog = @"Dog";

NSUInteger VNElementTypeSize(VNElementType elementType)
{
    switch (elementType) {
        case VNElementTypeFloat:
            return sizeof(float);
        case VNElementTypeDouble:
            return sizeof(double);
        case VNElementTypeUnknown:
            break;
    }
    return 0;
}

@implementation VNDetectFaceLandmarksRequest (RevenantVision130Constellation)

+ (BOOL)revision:(NSUInteger)requestRevision supportsConstellation:(VNRequestFaceLandmarksConstellation)constellation
{
    if (constellation == VNRequestFaceLandmarksConstellation65Points)
        return requestRevision >= 1 && requestRevision <= 3;
    if (constellation == VNRequestFaceLandmarksConstellation76Points)
        return requestRevision == 3;
    return NO;
}

@end

@implementation VNClassificationObservation (RevenantVision130PrecisionRecall)

- (BOOL)hasPrecisionRecallCurve
{
    return NO;
}

- (BOOL)hasMinimumPrecision:(float)minimumPrecision forRecall:(float)recall
{
    return NO;
}

- (BOOL)hasMinimumRecall:(float)minimumRecall forPrecision:(float)precision
{
    return NO;
}

@end

@implementation VNRecognizeAnimalsRequest

+ (NSArray<VNAnimalIdentifier> *)knownAnimalIdentifiersForRevision:(NSUInteger)requestRevision error:(NSError **)error
{
    if (![[self supportedRevisions] containsIndex:requestRevision]) {
        if (error)
            *error = revenant_vision_error(VNErrorUnsupportedRevision, [NSString stringWithFormat:@"%@ does not support Revision%lu",
                                                                           NSStringFromClass(self), (unsigned long)requestRevision]);
        return nil;
    }
    return @[VNAnimalIdentifierCat, VNAnimalIdentifierDog];
}

@end

@implementation VNClassifyImageRequest
@end

@implementation VNDetectFaceCaptureQualityRequest {
    NSArray *_inputFaceObservations;
}
@synthesize inputFaceObservations = _inputFaceObservations;
@end

@implementation VNGenerateAttentionBasedSaliencyImageRequest
@end

@implementation VNGenerateObjectnessBasedSaliencyImageRequest
@end

@implementation VNGenerateImageFeaturePrintRequest {
    VNImageCropAndScaleOption _imageCropAndScaleOption;
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler]))
        _imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;
    return self;
}

@end

@implementation VNRecognizeTextRequest {
    VNRequestProgressHandler _progressHandler;
    VNRequestTextRecognitionLevel _recognitionLevel;
    NSArray<NSString *> *_recognitionLanguages;
    BOOL _usesLanguageCorrection;
    NSArray<NSString *> *_customWords;
    float _minimumTextHeight;
    CGRect _regionOfInterest;
}
@synthesize progressHandler = _progressHandler;
@synthesize recognitionLevel = _recognitionLevel;
@synthesize recognitionLanguages = _recognitionLanguages;
@synthesize usesLanguageCorrection = _usesLanguageCorrection;
@synthesize customWords = _customWords;
@synthesize minimumTextHeight = _minimumTextHeight;
@synthesize regionOfInterest = _regionOfInterest;

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _recognitionLevel = VNRequestTextRecognitionLevelAccurate;
        _recognitionLanguages = @[@"en-US"];
        _usesLanguageCorrection = YES;
        _customWords = @[];
        _minimumTextHeight = 0;
        _regionOfInterest = CGRectMake(0, 0, 1, 1);
    }
    return self;
}

+ (NSArray<NSString *> *)supportedRecognitionLanguagesForTextRecognitionLevel:(VNRequestTextRecognitionLevel)recognitionLevel revision:(NSUInteger)requestRevision error:(NSError **)error
{
    if (![[self supportedRevisions] containsIndex:requestRevision]) {
        if (error)
            *error = revenant_vision_error(VNErrorUnsupportedRevision, [NSString stringWithFormat:@"%@ does not support Revision%lu",
                                                                           NSStringFromClass(self), (unsigned long)requestRevision]);
        return nil;
    }
    return RevenantVisionTextLanguages(RevenantVisionTextModelRoot(), requestRevision, recognitionLevel == VNRequestTextRecognitionLevelFast);
}

- (NSArray<NSString *> *)supportedRecognitionLanguagesAndReturnError:(NSError **)error
{
    return [[self class] supportedRecognitionLanguagesForTextRecognitionLevel:self.recognitionLevel revision:self.revision error:error];
}

- (BOOL)indeterminate
{
    return NO;
}

@end

@implementation VNRecognizedTextObservation {
    NSArray<VNRecognizedText *> *_candidates;
}

- (NSArray<VNRecognizedText *> *)topCandidates:(NSUInteger)maxCandidateCount
{
    if (maxCandidateCount >= _candidates.count)
        return _candidates;
    return [_candidates subarrayWithRange:NSMakeRange(0, maxCandidateCount)];
}

- (void)revenant_setCandidates:(NSArray<VNRecognizedText *> *)candidates
{
    _candidates = [candidates copy];
}

@end

@implementation VNFeaturePrintObservation

- (BOOL)computeDistance:(float *)outDistance toFeaturePrintObservation:(VNFeaturePrintObservation *)featurePrint error:(NSError **)error
{
    return NO;
}

@end

@implementation VNSaliencyImageObservation
@end

@implementation VNRecognizedText {
    NSArray<NSDictionary *> *_words;
}

@synthesize requestRevision = _requestRevision;

+ (instancetype)revenant_textWithString:(NSString *)string confidence:(float)confidence requestRevision:(NSUInteger)requestRevision words:(NSArray<NSDictionary *> *)words
{
    VNRecognizedText *text = [[self alloc] init];
    text->_string = [string copy];
    text->_confidence = confidence;
    text->_requestRevision = requestRevision;
    text->_words = [words copy];
    return text;
}

- (VNRectangleObservation *)boundingBoxForRange:(NSRange)range error:(NSError **)error
{
    if (range.location == NSNotFound || NSMaxRange(range) > _string.length) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidArgument, @"the range is outside the recognized string");
        return nil;
    }
    CGRect box = CGRectNull;
    for (NSDictionary *word in _words) {
        NSRange wordRange = [word[@"range"] rangeValue];
        if (NSIntersectionRange(range, wordRange).length > 0)
            box = CGRectUnion(box, RevenantVisionRectFromValue(word[@"bounds"]));
    }
    if (CGRectIsNull(box)) {
        if (error)
            *error = revenant_vision_error(VNErrorOperationFailed, @"no text in the range could be located");
        return nil;
    }
    VNRectangleObservation *observation = [VNRectangleObservation observationWithRequestRevision:_requestRevision boundingBox:box];
    [observation revenant_setCornersTopLeft:CGPointMake(CGRectGetMinX(box), CGRectGetMaxY(box))
                                   topRight:CGPointMake(CGRectGetMaxX(box), CGRectGetMaxY(box))
                                bottomRight:CGPointMake(CGRectGetMaxX(box), CGRectGetMinY(box))
                                 bottomLeft:CGPointMake(CGRectGetMinX(box), CGRectGetMinY(box))];
    return observation;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_string forKey:@"VNRecognizedText.string"];
    [coder encodeFloat:_confidence forKey:@"VNRecognizedText.confidence"];
    [coder encodeInteger:(NSInteger)_requestRevision forKey:@"VNRecognizedText.requestRevision"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _string = [[coder decodeObjectOfClass:[NSString class] forKey:@"VNRecognizedText.string"] copy];
        _confidence = [coder decodeFloatForKey:@"VNRecognizedText.confidence"];
        _requestRevision = (NSUInteger)[coder decodeIntegerForKey:@"VNRecognizedText.requestRevision"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNRecognizedText *copy = [[VNRecognizedText allocWithZone:zone] init];
    copy->_string = _string;
    copy->_confidence = _confidence;
    copy->_requestRevision = _requestRevision;
    return copy;
}

@end
