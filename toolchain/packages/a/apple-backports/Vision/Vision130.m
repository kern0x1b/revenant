#import "RevenantVision.h"

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
}
@synthesize progressHandler = _progressHandler;

- (BOOL)indeterminate
{
    return NO;
}

@end

@implementation VNRecognizedTextObservation

- (NSArray<VNRecognizedText *> *)topCandidates:(NSUInteger)maxCandidateCount
{
    return @[];
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

@implementation VNRecognizedText

@synthesize requestRevision = _requestRevision;

- (VNRectangleObservation *)boundingBoxForRange:(NSRange)range error:(NSError **)error
{
    return nil;
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
