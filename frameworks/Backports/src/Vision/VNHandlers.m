#import "RevenantVision.h"
#import "VNRectangleImage.h"
#import "RevenantVisionImage.h"
#import "VNBarcodeDecoder.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

@interface VNClassificationObservation (RevenantCoreml)
- (instancetype)revenant_initWithIdentifier:(NSString *)identifier confidence:(float)confidence;
@end

@interface VNCoreMLFeatureValueObservation (RevenantCoreml)
- (instancetype)revenant_initWithFeatureValue:(MLFeatureValue *)featureValue featureName:(NSString *)featureName;
@end

@interface VNPixelBufferObservation (RevenantCoreml)
- (instancetype)revenant_initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer featureName:(NSString *)featureName;
@end

@interface VNRequest (RevenantResults)
- (void)revenant_setResults:(NSArray *)results;
@end

@interface VNBarcodeObservation (RevenantBarcodeConstruction)
+ (instancetype)revenant_observationWithPayload:(NSString *)payload symbology:(VNBarcodeSymbology)symbology boundingBox:(CGRect)boundingBox topLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft requestRevision:(NSUInteger)revision;
@end

@interface VNCoreMLModel (RevenantRequest)
- (MLModel *)revenant_coreml_model;
- (NSString *)revenant_coreml_image_feature;
@end

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#import "RevenantVisionImage.h"



static NSArray *revenant_vision_coreml(VNCoreMLRequest *request, id image, NSError **error)
{
    VNCoreMLModel *wrapper = request.model;
    MLModel *model = wrapper != nil ? [wrapper revenant_coreml_model] : nil;
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
            *error = revenant_vision_error(VNErrorInvalidModel, @"there is no Core ML model in the request");
        return nil;
    }
    inputs = model.modelDescription.inputDescriptionsByName;
    name = [wrapper revenant_coreml_image_feature];
    described = name != nil ? inputs[name] : nil;
    if (described == nil || described.type != MLFeatureTypeImage) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidModel,
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
        pixels = revenant_vision_pixels(given, wide, high, request.imageCropAndScaleOption);
    } else if (image != NULL && CFGetTypeID((__bridge CFTypeRef)image) == CGImageGetTypeID()) {
        if (wide == 0 || high == 0) {
            wide = CGImageGetWidth((__bridge CGImageRef)image);
            high = CGImageGetHeight((__bridge CGImageRef)image);
        }
        pixels = revenant_vision_pixels(revenant_vision_buffer_of_image((__bridge CGImageRef)image), wide, high,
                                      request.imageCropAndScaleOption);
    }
    if (pixels == NULL) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidImage,
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
            *error = revenant_vision_error(VNErrorOperationFailed,
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
                        revenant_initWithIdentifier:classes[index]
                                      confidence:(float)[scores[classes[index]] doubleValue]]];
                }
                if (identifier.length > 0 && classes.count == 0) {
                    [observations addObject:[[VNClassificationObservation alloc]
                        revenant_initWithIdentifier:identifier
                                      confidence:1.0f]];
                }
                continue;
            }
            if (outputs[name].type == MLFeatureTypeImage && value.imageBufferValue != NULL) {
                [observations addObject:[[VNPixelBufferObservation alloc]
                    revenant_initWithPixelBuffer:value.imageBufferValue
                                  featureName:name]];
                continue;
            }
            [observations addObject:[[VNCoreMLFeatureValueObservation alloc] revenant_initWithFeatureValue:value
                                                                                            featureName:name]];
        }
    }
    return observations;
}

static NSError *revenant_vision_failure(VNRequest *request)
{
    Class cls = [request class];
    if (![[cls supportedRevisions] containsIndex:request.revision])
        return revenant_vision_error(VNErrorUnsupportedRevision, [NSString stringWithFormat:@"%@ does not support %@Revision%lu", NSStringFromClass(cls), NSStringFromClass(cls), (unsigned long)request.revision]);
    if ([request isKindOfClass:[VNDetectContoursRequest class]])
        return nil;
    if ([request isKindOfClass:[VNDetectRectanglesRequest class]])
        return nil;
    if ([request isKindOfClass:[VNDetectFaceRectanglesRequest class]])
        return nil;
    if ([request isKindOfClass:[VNDetectBarcodesRequest class]])
        return nil;
    if ([request isKindOfClass:[VNCoreMLRequest class]] && ![(VNCoreMLRequest *)request model])
        return revenant_vision_error(VNErrorOperationFailed, @"The model does not have a valid input feature of type image");
    return revenant_vision_error(VNErrorUnsupportedRequest, [NSString stringWithFormat:@"%@ is not supported on this release", NSStringFromClass(cls)]);
}

static CIDetector *revenant_vision_face_detector(void)
{
    static CIDetector *detector;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                      context:nil
                                      options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    });
    return detector;
}

static NSArray<VNFaceObservation *> *revenant_vision_faces(id image, CGImagePropertyOrientation orientation, NSUInteger revision, NSError **error)
{
    CIImage *ciImage = nil;
    CFTypeID type = image != nil ? CFGetTypeID((__bridge CFTypeRef)image) : 0;
    if ([image isKindOfClass:[CIImage class]])
        ciImage = image;
    else if ([image isKindOfClass:[NSURL class]])
        ciImage = [CIImage imageWithContentsOfURL:image];
    else if ([image isKindOfClass:[NSData class]])
        ciImage = [CIImage imageWithData:image];
    else if (type == CGImageGetTypeID())
        ciImage = [CIImage imageWithCGImage:(__bridge CGImageRef)image];
    else if (type == CVPixelBufferGetTypeID())
        ciImage = [CIImage imageWithCVPixelBuffer:(__bridge CVPixelBufferRef)image];
    CGRect extent = ciImage.extent;
    if (CGRectIsEmpty(extent) || !isfinite(extent.size.width) || !isfinite(extent.size.height)) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidImage, @"the image has no pixels");
        return nil;
    }
    CIDetector *detector = revenant_vision_face_detector();
    if (detector == nil) {
        if (error)
            *error = revenant_vision_error(VNErrorOperationFailed, @"Core Image could not create a face detector");
        return nil;
    }
    NSMutableArray *observations = [NSMutableArray array];
    for (CIFaceFeature *feature in [detector featuresInImage:ciImage options:@{CIDetectorImageOrientation: @(orientation)}]) {
        CGRect bounds = feature.bounds;
        CGRect normalized = CGRectMake((bounds.origin.x - extent.origin.x) / extent.size.width,
                                       (bounds.origin.y - extent.origin.y) / extent.size.height,
                                       bounds.size.width / extent.size.width,
                                       bounds.size.height / extent.size.height);
        NSNumber *roll = feature.hasFaceAngle ? @(feature.faceAngle * M_PI / 180.0) : @0;
        VNFaceObservation *observation = [VNFaceObservation faceObservationWithRequestRevision:revision
                                                                                   boundingBox:normalized
                                                                                           roll:roll
                                                                                            yaw:@0];
        if (observation)
            [observations addObject:observation];
    }
    return observations;
}

static BOOL revenant_vision_perform(id image, CGImagePropertyOrientation orientation, NSArray<VNRequest *> *requests, NSError **error)
{
    BOOL succeeded = YES;
    NSError *first = nil;
    for (VNRequest *request in requests) {
        NSError *failure = revenant_vision_failure(request);
        if (!failure && [request isKindOfClass:[VNCoreMLRequest class]]) {
            NSArray *observations = revenant_vision_coreml((VNCoreMLRequest *)request, image, &failure);
            if (failure) {
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request revenant_setResults:observations];
            }
            if (request.completionHandler) {
                request.completionHandler(request, failure);
            }
            continue;
        }
        if (!failure && [request isKindOfClass:[VNDetectContoursRequest class]]) {
            NSArray *observations = [(VNDetectContoursRequest *)request revenant_observationsOnImage:image error:&failure];
            if (failure) {
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request revenant_setResults:observations];
            }
            if (request.completionHandler)
                request.completionHandler(request, failure);
            continue;
        }
        if (!failure && [request isKindOfClass:[VNDetectFaceRectanglesRequest class]]) {
            NSArray *observations = revenant_vision_faces(image, orientation, request.revision, &failure);
            if (failure) {
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request revenant_setResults:observations];
            }
            if (request.completionHandler)
                request.completionHandler(request, failure);
            continue;
        }
        if (!failure && [request isKindOfClass:[VNDetectRectanglesRequest class]]) {
            NSError *detectorError = nil;
            NSArray *observations = RevenantVisionRectangles(image, orientation, request, &detectorError);
            if (detectorError) {
                failure = revenant_vision_error(VNErrorOperationFailed, detectorError.localizedDescription);
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request revenant_setResults:observations];
            }
            if (request.completionHandler)
                request.completionHandler(request, failure);
            continue;
        }
        if (!failure && [request isKindOfClass:[VNDetectBarcodesRequest class]]) {
            VNDetectBarcodesRequest *barcodeRequest = (VNDetectBarcodesRequest *)request;
            NSArray *supported = [VNDetectBarcodesRequest supportedSymbologies];
            for (VNBarcodeSymbology symbology in barcodeRequest.symbologies) {
                if (![supported containsObject:symbology]) {
                    failure = revenant_vision_error(VNErrorUnsupportedRequest,
                                                    [NSString stringWithFormat:@"barcode symbology %@ is not supported on this release", symbology]);
                    break;
                }
            }
            NSError *decodeFailure = nil;
            NSArray *decoded = failure ? nil : RevenantVisionBarcodes(image, orientation, barcodeRequest.symbologies, &decodeFailure);
            if (!failure && decodeFailure)
                failure = revenant_vision_error(VNErrorInvalidImage, decodeFailure.localizedDescription);
            NSMutableArray *observations = decoded ? [NSMutableArray arrayWithCapacity:decoded.count] : nil;
            for (NSDictionary *item in decoded) {
                NSArray *bounds = item[@"bounds"];
                NSArray *corners = item[@"corners"];
                VNBarcodeObservation *observation = [VNBarcodeObservation revenant_observationWithPayload:item[@"payload"]
                                                                                                  symbology:item[@"symbology"]
                                                                                                boundingBox:CGRectMake([bounds[0] doubleValue], [bounds[1] doubleValue], [bounds[2] doubleValue], [bounds[3] doubleValue])
                                                                                                      topLeft:CGPointMake([corners[0][0] doubleValue], [corners[0][1] doubleValue])
                                                                                                     topRight:CGPointMake([corners[1][0] doubleValue], [corners[1][1] doubleValue])
                                                                                                  bottomRight:CGPointMake([corners[2][0] doubleValue], [corners[2][1] doubleValue])
                                                                                                   bottomLeft:CGPointMake([corners[3][0] doubleValue], [corners[3][1] doubleValue])
                                                                                              requestRevision:request.revision];
                if (observation)
                    [observations addObject:observation];
            }
            if (failure) {
                succeeded = NO;
                first = first ?: failure;
            } else {
                [(VNRequest *)request revenant_setResults:observations];
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
    return revenant_vision_perform(self->_image, self->_orientation, requests, error);
}

@end

@implementation VNSequenceRequestHandler

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCVPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error
{
    return revenant_vision_perform((__bridge id)pixelBuffer, kCGImagePropertyOrientationUp, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return revenant_vision_perform((__bridge id)pixelBuffer, orientation, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCGImage:(CGImageRef)image error:(NSError **)error
{
    return revenant_vision_perform((__bridge id)image, kCGImagePropertyOrientationUp, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCGImage:(CGImageRef)image orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return revenant_vision_perform((__bridge id)image, orientation, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCIImage:(CIImage *)image error:(NSError **)error
{
    return revenant_vision_perform(image, kCGImagePropertyOrientationUp, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCIImage:(CIImage *)image orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return revenant_vision_perform(image, orientation, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageURL:(NSURL *)imageURL error:(NSError **)error
{
    return revenant_vision_perform(imageURL, kCGImagePropertyOrientationUp, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return revenant_vision_perform(imageURL, orientation, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageData:(NSData *)imageData error:(NSError **)error
{
    return revenant_vision_perform(imageData, kCGImagePropertyOrientationUp, requests, error);
}

- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error
{
    return revenant_vision_perform(imageData, orientation, requests, error);
}

@end
