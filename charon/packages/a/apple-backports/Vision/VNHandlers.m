#import "CharonVision.h"
#import "CharonVisionImage.h"
#import <ImageIO/ImageIO.h>

/* The two things a request needs out of the model it was made with: the model, and the name of
 * the input the image goes under. They are the port's own accessors (VNCoreMLModel in
 * VNRequests.m), declared here because this is the other file that asks. */
/* The three initialisers the observations are built with, in VNObservations.m. They are this
 * port's own -- a caller makes an observation through its own initialisers, not these -- so they
 * are declared here for the request path and the registry does not carry them. */
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



/* One Core ML request, run over the image a handler holds: the image under the model's own image
 * input, the model's other inputs from the provider the caller gave it, the prediction, and the
 * answers as the request's results.
 *
 * The mapping is Core ML's own, and it is decided by what the model's description says an answer
 * is rather than by what the numbers happen to be:
 *   - the name a classifier answers its label under is a string, and the probabilities beside it
 *     are a dictionary of class to score: one VNClassificationObservation per class, highest
 *     score first, which is what a caller reading a model's answer expects;
 *   - an image answer is a VNPixelBufferObservation under the name of the output it came from;
 *   - anything else is a VNCoreMLFeatureValueObservation holding the value whole.
 */
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
    /* The size the model wants, which is what its own constraint says. A model that names no size
     * takes the image as it is, which is the case a model over a multi array input would be. */
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
        /* A CGImage is drawn into a buffer of the model's own size, which is also where the two
         * crop-and-scale options are applied: Core ML's feature value of the image type takes a
         * buffer, and this port carries no image feature value that takes a CGImage. */
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
    /* The other inputs, from the provider the caller gave for a model with more than one input;
     * a model with one image input does not need one, and Vision's own documentation says so. */
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
            /* A prediction the model will not make is the operation failing, which is the code
             * Vision's own enumeration gives for it; the model's own error is in the text. */
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
                continue;   /* answered below, with the label, in the order a caller reads them */
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
    // the contour request runs on the port: its answer is made from the picture and needs no model
    if ([request isKindOfClass:[VNDetectContoursRequest class]])
        return nil;
    /* A Core ML request with no model behind it: the framework's own answer, measured against the
     * Vision of this host, is the operation-failed code rather than the invalid-model one, and the
     * two are different cases a caller may handle differently. */
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
            /* The one request this port really runs, and the one that used to be refused with
             * VNErrorNotImplemented: the image through the model, and the model's answers back as
             * the request's results, which is what a caller of VNCoreMLRequest reads. */
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
    /* A CIImage is already an object, and a Core ML image input takes a pixel buffer: the request
     * path says so through the same failure any other unusable image reaches, rather than
     * pretending the picture was something it is not. */
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
