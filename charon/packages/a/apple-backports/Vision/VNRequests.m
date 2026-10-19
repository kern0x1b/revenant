#import "CharonVision.h"
#import <ImageIO/ImageIO.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSArray<NSNumber *> *charon_vision_revisions(Class cls)
{
    if ([cls isSubclassOfClass:[VNDetectFaceRectanglesRequest class]] || [cls isSubclassOfClass:[VNDetectFaceLandmarksRequest class]] || [cls isSubclassOfClass:[VNTrackObjectRequest class]])
        return @[@1, @2];
    return @[@1];
}

@implementation VNRequest {
    BOOL _preferBackgroundProcessing;
    BOOL _usesCPUOnly;
    NSUInteger _revision;
    NSArray *_results;
    VNRequestCompletionHandler _completionHandler;
}

+ (NSIndexSet *)supportedRevisions
{
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    for (NSNumber *revision in charon_vision_revisions(self))
        [set addIndex:revision.unsignedIntegerValue];
    return set;
}

+ (NSUInteger)currentRevision
{
    return [self supportedRevisions].lastIndex;
}

+ (NSUInteger)defaultRevision
{
    return [self currentRevision];
}

- (instancetype)init
{
    return [self initWithCompletionHandler:nil];
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super init])) {
        _completionHandler = [completionHandler copy];
        _revision = [[self class] defaultRevision];
    }
    return self;
}

- (BOOL)preferBackgroundProcessing
{
    return _preferBackgroundProcessing;
}

- (void)setPreferBackgroundProcessing:(BOOL)preferBackgroundProcessing
{
    _preferBackgroundProcessing = preferBackgroundProcessing;
}

- (BOOL)usesCPUOnly
{
    return _usesCPUOnly;
}

- (void)setUsesCPUOnly:(BOOL)usesCPUOnly
{
    _usesCPUOnly = usesCPUOnly;
}

- (NSUInteger)revision
{
    return _revision;
}

- (void)setRevision:(NSUInteger)revision
{
    _revision = revision;
}

/* The results a request answers with. Vision's own request path fills this in; there is no public
 * setter, and an application reads the results rather than writing them. */
- (void)charon_setResults:(NSArray *)results
{
    _results = [results copy];
}

- (NSArray *)results
{
    return _results;
}

- (VNRequestCompletionHandler)completionHandler
{
    return _completionHandler;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNRequest *copy = charon_vision_clone(self, zone);
    copy->_results = nil;
    return copy;
}

@end

@implementation VNImageBasedRequest {
    CGRect _regionOfInterest;
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler]))
        _regionOfInterest = CGRectMake(0, 0, 1, 1);
    return self;
}

@end

@implementation VNDetectRectanglesRequest {
    float _minimumAspectRatio;
    float _maximumAspectRatio;
    float _quadratureTolerance;
    float _minimumSize;
    float _minimumConfidence;
    NSUInteger _maximumObservations;
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _minimumAspectRatio = 0.5f;
        _maximumAspectRatio = 1;
        _quadratureTolerance = 30;
        _minimumSize = 0.2f;
        _minimumConfidence = 0;
        _maximumObservations = 1;
    }
    return self;
}

@end

@implementation VNDetectBarcodesRequest {
    NSArray *_symbologies;
}

+ (NSArray *)supportedSymbologies
{
    return @[VNBarcodeSymbologyAztec, VNBarcodeSymbologyCode128, VNBarcodeSymbologyCode39, VNBarcodeSymbologyCode39Checksum, VNBarcodeSymbologyCode39FullASCII,
             VNBarcodeSymbologyCode39FullASCIIChecksum, VNBarcodeSymbologyCode93, VNBarcodeSymbologyCode93i, VNBarcodeSymbologyDataMatrix, VNBarcodeSymbologyEAN13,
             VNBarcodeSymbologyEAN8, VNBarcodeSymbologyI2of5, VNBarcodeSymbologyI2of5Checksum, VNBarcodeSymbologyITF14, VNBarcodeSymbologyPDF417,
             VNBarcodeSymbologyQR, VNBarcodeSymbologyUPCE];
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler]))
        _symbologies = [[self class] supportedSymbologies];
    return self;
}

- (NSArray *)symbologies
{
    return _symbologies;
}

- (void)setSymbologies:(NSArray *)symbologies
{
    _symbologies = [symbologies copy];
}

@end

@implementation VNDetectFaceRectanglesRequest
@end

@implementation VNDetectFaceLandmarksRequest {
    NSArray *_inputFaceObservations;
}

- (NSArray *)inputFaceObservations
{
    return _inputFaceObservations;
}

- (void)setInputFaceObservations:(NSArray *)inputFaceObservations
{
    _inputFaceObservations = [inputFaceObservations copy];
}

@end

@implementation VNDetectTextRectanglesRequest {
    BOOL _reportCharacterBoxes;
}

- (BOOL)reportCharacterBoxes
{
    return _reportCharacterBoxes;
}

- (void)setReportCharacterBoxes:(BOOL)reportCharacterBoxes
{
    _reportCharacterBoxes = reportCharacterBoxes;
}

@end

@implementation VNDetectHorizonRequest
@end

/* A model prepared for use with VNCoreMLRequests, which is a Core ML model Vision can hand an
 * image to.
 *
 * The wrapper exists because Vision needs three things a bare MLModel does not give it: a check
 * that the model takes an image at all, the name of the input to put the image under, and room
 * for the other inputs a model with more than one needs. All three are answered from the model's
 * own description -- read out of the Core ML specification's fields by the CoreML backport -- so a
 * model Vision cannot run is refused here, by name, before a request is ever made. */
@implementation VNCoreMLModel {
    MLModel *_model;
    NSString *_inputImageFeatureName;
    id<MLFeatureProvider> _featureProvider;
}

/* The model as Core ML has it. Vision's own request path needs it; nothing outside this file
 * should, which is why the name is this port's own. */
- (MLModel *)charon_coreml_model
{
    return _model;
}

/* The name of the input the image goes under: the one Vision chose, or the one the caller named,
 * or the first input of the image type in the model's own description. */
- (NSString *)charon_coreml_image_feature
{
    if (_inputImageFeatureName != nil) {
        return _inputImageFeatureName;
    }
    NSDictionary<NSString *, MLFeatureDescription *> *inputs = _model.modelDescription.inputDescriptionsByName;
    NSEnumerator *names = [inputs keyEnumerator];
    NSString *name;
    while ((name = [names nextObject]) != nil) {
        if (inputs[name].type == MLFeatureTypeImage) {
            return name;
        }
    }
    return nil;
}

+ (instancetype)modelForMLModel:(MLModel *)model error:(NSError **)error
{
    VNCoreMLModel *wrapper;
    if (model == nil) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidModel, @"there is no Core ML model to prepare");
        return nil;
    }
    wrapper = [[VNCoreMLModel alloc] init];
    if (wrapper == nil) {
        return nil;
    }
    wrapper->_model = model;
    if ([wrapper charon_coreml_image_feature] == nil) {
        /* The case Core ML's own documentation names as an example of a model Vision cannot use:
         * a model that takes no image as any of its inputs. */
        if (error)
            *error = charon_vision_error(VNErrorInvalidModel,
                                         @"the model does not have an input feature of type image");
        return nil;
    }
    return wrapper;
}

- (NSString *)inputImageFeatureName
{
    return [self charon_coreml_image_feature];
}

- (void)setInputImageFeatureName:(NSString *)inputImageFeatureName
{
    _inputImageFeatureName = [inputImageFeatureName copy];
}

- (id<MLFeatureProvider>)featureProvider
{
    return _featureProvider;
}

- (void)setFeatureProvider:(id<MLFeatureProvider>)featureProvider
{
    _featureProvider = featureProvider;
}

@end

@implementation VNCoreMLRequest {
    VNCoreMLModel *_model;
    VNImageCropAndScaleOption _imageCropAndScaleOption;
}

- (instancetype)initWithModel:(VNCoreMLModel *)model
{
    return [self initWithModel:model completionHandler:nil];
}

- (instancetype)initWithModel:(VNCoreMLModel *)model completionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _model = model;
        _imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    }
    return self;
}

- (VNCoreMLModel *)model
{
    return _model;
}

- (VNImageCropAndScaleOption)imageCropAndScaleOption
{
    return _imageCropAndScaleOption;
}

- (void)setImageCropAndScaleOption:(VNImageCropAndScaleOption)option
{
    _imageCropAndScaleOption = option;
}

@end

@interface VNTrackingRequest ()
- (instancetype)initWithDetectedObjectObservation:(VNDetectedObjectObservation *)observation completionHandler:(VNRequestCompletionHandler)completionHandler;
@end

@implementation VNTrackingRequest {
    VNDetectedObjectObservation *_inputObservation;
    VNRequestTrackingLevel _trackingLevel;
    BOOL _lastFrame;
}

- (instancetype)initWithDetectedObjectObservation:(VNDetectedObjectObservation *)observation completionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _inputObservation = observation;
        _trackingLevel = VNRequestTrackingLevelFast;
    }
    return self;
}

- (VNDetectedObjectObservation *)inputObservation
{
    return _inputObservation;
}

- (void)setInputObservation:(VNDetectedObjectObservation *)inputObservation
{
    _inputObservation = inputObservation;
}

- (VNRequestTrackingLevel)trackingLevel
{
    return _trackingLevel;
}

- (void)setTrackingLevel:(VNRequestTrackingLevel)trackingLevel
{
    _trackingLevel = trackingLevel;
}

- (BOOL)isLastFrame
{
    return _lastFrame;
}

- (void)setLastFrame:(BOOL)lastFrame
{
    _lastFrame = lastFrame;
}

@end

@implementation VNTrackObjectRequest

- (instancetype)initWithDetectedObjectObservation:(VNDetectedObjectObservation *)observation
{
    return [self initWithDetectedObjectObservation:observation completionHandler:nil];
}

- (instancetype)initWithDetectedObjectObservation:(VNDetectedObjectObservation *)observation completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [super initWithDetectedObjectObservation:observation completionHandler:completionHandler];
}

@end

@implementation VNTrackRectangleRequest

- (instancetype)initWithRectangleObservation:(VNRectangleObservation *)observation
{
    return [self initWithRectangleObservation:observation completionHandler:nil];
}

- (instancetype)initWithRectangleObservation:(VNRectangleObservation *)observation completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [super initWithDetectedObjectObservation:observation completionHandler:completionHandler];
}

@end

@implementation VNTargetedImageRequest {
    id _targetedImage;
    CGImagePropertyOrientation _orientation;
    NSDictionary *_options;
}

- (instancetype)initWithTargeted:(id)image orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _targetedImage = image;
        _orientation = orientation;
        _options = [options copy];
    }
    return self;
}

- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer options:(NSDictionary *)options
{
    return [self initWithTargetedCVPixelBuffer:pixelBuffer orientation:kCGImagePropertyOrientationUp options:options completionHandler:nil];
}

- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargetedCVPixelBuffer:pixelBuffer orientation:kCGImagePropertyOrientationUp options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithTargetedCVPixelBuffer:pixelBuffer orientation:orientation options:options completionHandler:nil];
}

- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargeted:(__bridge id)pixelBuffer orientation:orientation options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage options:(NSDictionary *)options
{
    return [self initWithTargetedCGImage:cgImage orientation:kCGImagePropertyOrientationUp options:options completionHandler:nil];
}

- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargetedCGImage:cgImage orientation:kCGImagePropertyOrientationUp options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithTargetedCGImage:cgImage orientation:orientation options:options completionHandler:nil];
}

- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargeted:(__bridge id)cgImage orientation:orientation options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage options:(NSDictionary *)options
{
    return [self initWithTargetedCIImage:ciImage orientation:kCGImagePropertyOrientationUp options:options completionHandler:nil];
}

- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargetedCIImage:ciImage orientation:kCGImagePropertyOrientationUp options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithTargetedCIImage:ciImage orientation:orientation options:options completionHandler:nil];
}

- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargeted:ciImage orientation:orientation options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL options:(NSDictionary *)options
{
    return [self initWithTargetedImageURL:imageURL orientation:kCGImagePropertyOrientationUp options:options completionHandler:nil];
}

- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargetedImageURL:imageURL orientation:kCGImagePropertyOrientationUp options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithTargetedImageURL:imageURL orientation:orientation options:options completionHandler:nil];
}

- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargeted:imageURL orientation:orientation options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedImageData:(NSData *)imageData options:(NSDictionary *)options
{
    return [self initWithTargetedImageData:imageData orientation:kCGImagePropertyOrientationUp options:options completionHandler:nil];
}

- (instancetype)initWithTargetedImageData:(NSData *)imageData options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargetedImageData:imageData orientation:kCGImagePropertyOrientationUp options:options completionHandler:completionHandler];
}

- (instancetype)initWithTargetedImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options
{
    return [self initWithTargetedImageData:imageData orientation:orientation options:options completionHandler:nil];
}

- (instancetype)initWithTargetedImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary *)options completionHandler:(VNRequestCompletionHandler)completionHandler
{
    return [self initWithTargeted:imageData orientation:orientation options:options completionHandler:completionHandler];
}

@end

@implementation VNImageRegistrationRequest
@end

@implementation VNTranslationalImageRegistrationRequest
@end

@implementation VNHomographicImageRegistrationRequest
@end
