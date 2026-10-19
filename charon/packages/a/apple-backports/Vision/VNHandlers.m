#import "CharonVision.h"
#import "CharonVisionImage.h"
#import <ImageIO/ImageIO.h>

@interface VNClassificationObservation (CharonCoreml)
- (instancetype)charon_initWithIdentifier:(NSString *)identifier confidence:(float)confidence;
@end

@interface VNCoreMLFeatureValueObservation (CharonCoreml)
- (instancetype)charon_initWithFeatureValue:(MLFeatureValue *)featureValue featureName:(NSString *)featureName;
@end

@interface VNPixelBufferObservation (CharonCoreml)
- (instancetype)charon_initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer featureName:(NSString *)featureName;
@end

@interface VNRequest (CharonResults)
- (void)charon_setResults:(NSArray *)results;
@end

@interface VNCoreMLModel (CharonRequest)
- (MLModel *)charon_coreml_model;
- (NSString *)charon_coreml_image_feature;
@end

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#import "CharonVisionImage.h"



static NSArray *charon_vision_coreml(VNCoreMLRequest *request, id image, NSError **error)
{
    VNCoreMLModel *wrapper = request.model;
    MLModel *model = wrapper != nil ? [wrapper charon_coreml_model] : nil;
    MLFeatureDescription *described = nil;
    NSDictionary<NSString *, MLFeatureDescription *> *inputs;
    NSMutableDictionary *values;
    NSEnumerator *names;
    NSString *name;
    NSError *failure = nil;
    id<MLFeatureProvider> answer;
    NSMutableArray *observations;
    CVPixelBufferRef pixels = NULL;
    size_t wide, high;

    if (model == nil) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidModel, @"there is no Core ML model in the request");
        return nil;
    }
    inputs = model.modelDescription.inputDescriptionsByName;
    name = [wrapper charon_coreml_image_feature];
    described = name != nil ? inputs[name] : nil;
    if (described == nil || described.type != MLFeatureTypeImage) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidModel,
                                         @"the model does not have an input feature of type image");
        return nil;
    }
    wide = (size_t)described.imageConstraint.pixelsWide;
    high = (size_t)described.imageConstraint.pixelsHigh;
    if (image != NULL && CFGetTypeID((__bridge CFTypeRef)image) == CVPixelBufferGetTypeID()) {
        CVPixelBufferRef given = (__bridge CVPixelBufferRef)image;
        if (wide == 0 || high == 0) {
            wide = CVPixelBufferGetWidth(given);
            high = CVPixelBufferGetHeight(given);
        }
        pixels = charon_vision_pixels(given, wide, high, request.imageCropAndScaleOption);
    } else if (image != NULL && CFGetTypeID((__bridge CFTypeRef)image) == CGImageGetTypeID()) {
        if (wide == 0 || high == 0) {
            wide = CGImageGetWidth((__bridge CGImageRef)image);
            high = CGImageGetHeight((__bridge CGImageRef)image);
        }
        pixels = charon_vision_pixels(charon_vision_buffer_of_image((__bridge CGImageRef)image), wide, high,
                                      request.imageCropAndScaleOption);
    }
    if (pixels == NULL) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidImage,
                                         @"the image could not be brought to the size the model wants");
        return nil;
    }
    values = [NSMutableDictionary dictionary];
    values[name] = [MLFeatureValue featureValueWithPixelBuffer:pixels];
    if (wrapper.featureProvider != nil) {
        NSEnumerator *given = [wrapper.featureProvider.featureNames objectEnumerator];
        NSString *feature;
        while ((feature = [given nextObject]) != nil) {
            MLFeatureValue *value = [wrapper.featureProvider featureValueForName:feature];
            if (value != nil && ![feature isEqualToString:name]) {
                values[feature] = value;
            }
        }
    }
    answer = [model predictionFromFeatures:[[MLDictionaryFeatureProvider alloc] initWithDictionary:values
                                                                                                 error:&failure]
                                      error:&failure];
    CVPixelBufferRelease(pixels);
    if (answer == nil) {
        if (error)
            *error = charon_vision_error(VNErrorOperationFailed,
                                         failure.localizedDescription ?: @"the model could not be run");
        return nil;
    }
    observations = [NSMutableArray array];
    {
        NSString *label = model.modelDescription.predictedFeatureName;
        NSString *probabilities = model.modelDescription.predictedProbabilitiesName;
        NSDictionary<NSString *, MLFeatureDescription *> *outputs = model.modelDescription.outputDescriptionsByName;
        names = [answer.featureNames objectEnumerator];
        while ((name = [names nextObject]) != nil) {
            MLFeatureValue *value = [answer featureValueForName:name];
            if (value == nil) {
                continue;
            }
            if (probabilities != nil && [name isEqualToString:probabilities]) {
                continue;
            }
            if (label != nil && [name isEqualToString:label]) {
                NSString *identifier = value.stringValue;
                NSDictionary *scores = [answer featureValueForName:probabilities].dictionaryValue;
                NSArray *classes = [scores.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,
                                                                                                    NSString *b) {
                    double left = [scores[a] doubleValue], right = [scores[b] doubleValue];
                    return left == right ? [a compare:b] : (left > right ? NSOrderedAscending
                                                                          : NSOrderedDescending);
                }];
                NSUInteger index;
                for (index = 0; index < classes.count; index++) {
                    [observations addObject:[[VNClassificationObservation alloc]
                        charon_initWithIdentifier:classes[index]
                                      confidence:(float)[scores[classes[index]] doubleValue]]];
                }
                if (identifier.length > 0 && classes.count == 0) {
                    [observations addObject:[[VNClassificationObservation alloc]
                        charon_initWithIdentifier:identifier
                                      confidence:1.0f]];
                }
                continue;
            }
            if (outputs[name].type == MLFeatureTypeImage && value.imageBufferValue != NULL) {
                [observations addObject:[[VNPixelBufferObservation alloc]
                    charon_initWithPixelBuffer:value.imageBufferValue
                                  featureName:name]];
                continue;
            }
            [observations addObject:[[VNCoreMLFeatureValueObservation alloc] charon_initWithFeatureValue:value
                                                                                            featureName:name]];
        }
    }
    return observations;
}

static NSError *charon_vision_failure(VNRequest *request)
{
    Class cls = [request class];
    if (![[cls supportedRevisions] containsIndex:request.revision])
        return charon_vision_error(VNErrorUnsupportedRevision, [NSString stringWithFormat:@"%@ does not support %@Revision%lu", NSStringFromClass(cls), NSStringFromClass(cls), (unsigned long)request.revision]);
    if ([request isKindOfClass:[VNDetectContoursRequest class]])
        return nil;
    if ([request isKindOfClass:[VNCoreMLRequest class]] && ![(VNCoreMLRequest *)request model])
        return charon_vision_error(VNErrorOperationFailed, @"The model does not have a valid input feature of type image");
    return charon_vision_error(VNErrorNotImplemented, [NSString stringWithFormat:@"%@ is not implemented on this release", NSStringFromClass(cls)]);
}

static BOOL charon_vision_perform(id image, NSArray<VNRequest *> *requests, NSError **error)
{
    BOOL succeeded = YES;
    NSError *first = nil;
    for (VNRequest *request in requests) {
        NSError *failure = charon_vision_failure(request);
        if (!failure && [request isKindOfClass:[VNCoreMLRequest class]]) {
            NSArray *observations = charon_vision_coreml((VNCoreMLRequest *)request, image, &failure);
            if (failure) {
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request charon_setResults:observations];
            }
            if (request.completionHandler) {
                request.completionHandler(request, failure);
            }
            continue;
        }
        if (!failure && [request isKindOfClass:[VNDetectContoursRequest class]]) {
            NSArray *observations = [(VNDetectContoursRequest *)request charon_observationsOnImage:image error:&failure];
            if (failure) {
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request charon_setResults:observations];
            }
            if (request.completionHandler)
                request.completionHandler(request, failure);
            continue;
        }
        if (failure) {
            succeeded = NO;
            first = first ?: failure;
        }
        VNRequestCompletionHandler handler = request.completionHandler;
        if (handler)
            handler(request, failure);
    }
    if (!succeeded && error)
        *error = first;
    return succeeded;
}

@implementation VNImageRequestHandler {
    id _image;
    CGImagePropertyOrientation _orientation;
    NSDictionary *_options;
}

- (instancetype)initWithImage:(id)image orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    if ((self = [super init])) {
        _image = image;
        _orientation = orientation;
        _options = [options copy];
    }
    return self;
}

- (instancetype)initWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer options:(NSDictionary *)options
{
    return [self initWithCVPixelBuffer:pixelBuffer orientation:kCGImagePropertyOrientationUp options:options];
}

- (instancetype)initWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithImage:(__bridge id)pixelBuffer orientation:orientation options:options];
}

- (instancetype)initWithCGImage:(CGImageRef)image options:(NSDictionary *)options
{
    return [self initWithCGImage:image orientation:kCGImagePropertyOrientationUp options:options];
}

- (instancetype)initWithCGImage:(CGImageRef)image orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithImage:(__bridge id)image orientation:orientation options:options];
}

- (instancetype)initWithCIImage:(CIImage *)image options:(NSDictionary *)options
{
    return [self initWithCIImage:image orientation:kCGImagePropertyOrientationUp options:options];
}

- (instancetype)initWithCIImage:(CIImage *)image orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithImage:image orientation:orientation options:options];
}

- (instancetype)initWithURL:(NSURL *)imageURL options:(NSDictionary *)options
{
    return [self initWithURL:imageURL orientation:kCGImagePropertyOrientationUp options:options];
}

- (instancetype)initWithURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithImage:imageURL orientation:orientation options:options];
}

- (instancetype)initWithData:(NSData *)imageData options:(NSDictionary *)options
{
    return [self initWithData:imageData orientation:kCGImagePropertyOrientationUp options:options];
}

- (instancetype)initWithData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithImage:imageData orientation:orientation options:options];
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests error:(NSError **)error
{
    return charon_vision_perform(self->_image, requests, error);
}

@end

@implementation VNSequenceRequestHandler

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCVPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error
{
    return charon_vision_perform((__bridge id)pixelBuffer, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return charon_vision_perform((__bridge id)pixelBuffer, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCGImage:(CGImageRef)image error:(NSError **)error
{
    return charon_vision_perform((__bridge id)image, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCGImage:(CGImageRef)image orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return charon_vision_perform((__bridge id)image, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCIImage:(CIImage *)image error:(NSError **)error
{
    return charon_vision_perform(nil, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCIImage:(CIImage *)image orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return charon_vision_perform(nil, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageURL:(NSURL *)imageURL error:(NSError **)error
{
    return charon_vision_perform(nil, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return charon_vision_perform(nil, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageData:(NSData *)imageData error:(NSError **)error
{
    return charon_vision_perform(nil, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return charon_vision_perform(nil, requests, error);
}

@end
