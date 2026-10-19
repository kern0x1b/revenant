#import <CoreGraphics/CoreGraphics.h>
#import <Vision/Vision.h>
#import "vision-cases.h"

#import <CoreML/CoreML.h>
#import <CoreVideo/CoreVideo.h>

@interface VNCoreMLModel (CharonModel)
- (MLModel *)model;
@end
#import <CoreGraphics/CoreGraphics.h>

static NSString *rect(CGRect r)
{
    return [NSString stringWithFormat:@"%.6f,%.6f,%.6f,%.6f", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

static NSString *point(CGPoint p)
{
    return [NSString stringWithFormat:@"%.6f,%.6f", p.x, p.y];
}

static CGImageRef white_image(void)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 64, 64, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 64, 64));
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return image;
}

static void constants(VisionRecorder record)
{
    NSArray *symbologies = @[VNBarcodeSymbologyAztec, VNBarcodeSymbologyCode39, VNBarcodeSymbologyCode39Checksum, VNBarcodeSymbologyCode39FullASCII, VNBarcodeSymbologyCode39FullASCIIChecksum,
                             VNBarcodeSymbologyCode93, VNBarcodeSymbologyCode93i, VNBarcodeSymbologyCode128, VNBarcodeSymbologyDataMatrix, VNBarcodeSymbologyEAN8, VNBarcodeSymbologyEAN13,
                             VNBarcodeSymbologyI2of5, VNBarcodeSymbologyI2of5Checksum, VNBarcodeSymbologyITF14, VNBarcodeSymbologyPDF417, VNBarcodeSymbologyQR, VNBarcodeSymbologyUPCE];
    record(@"symbologies", [symbologies componentsJoinedByString:@","]);
    record(@"options", [@[VNImageOptionProperties, VNImageOptionCameraIntrinsics, VNImageOptionCIContext] componentsJoinedByString:@","]);
    record(@"identity", rect(VNNormalizedIdentityRect));
    record(@"identity.is", [NSString stringWithFormat:@"%d %d %d", VNNormalizedRectIsIdentityRect(CGRectMake(0, 0, 1, 1)), VNNormalizedRectIsIdentityRect(CGRectMake(0, 0, 1, 0.5)), VNNormalizedRectIsIdentityRect(CGRectZero)]);
}

static void geometry(VisionRecorder record)
{
    size_t sizes[][2] = {{640, 480}, {1, 1}, {0, 0}, {0, 100}, {100, 0}, {3000, 2000}};
    NSMutableArray *lines = [NSMutableArray array];
    for (size_t index = 0; index < sizeof sizes / sizeof sizes[0]; index++) {
        size_t w = sizes[index][0], h = sizes[index][1];
        NSMutableArray *parts = [NSMutableArray array];
        [parts addObject:point(VNImagePointForNormalizedPoint(CGPointMake(0.25, 0.75), w, h))];
        [parts addObject:point(VNImagePointForNormalizedPoint(CGPointMake(-0.5, 1.5), w, h))];
        [parts addObject:rect(VNImageRectForNormalizedRect(CGRectMake(0.1, 0.2, 0.3, 0.4), w, h))];
        [parts addObject:rect(VNImageRectForNormalizedRect(CGRectMake(-1, 2, 0, 1), w, h))];
        [parts addObject:rect(VNNormalizedRectForImageRect(CGRectMake(32, 24, 320, 240), w, h))];
        [parts addObject:rect(VNNormalizedRectForImageRect(CGRectMake(-5, 7, 0.5, 9), w, h))];
        [lines addObject:[parts componentsJoinedByString:@" "]];
    }
    record(@"geometry", [lines componentsJoinedByString:@";"]);
    NSMutableArray *faces = [NSMutableArray array];
    CGRect boxes[] = {CGRectMake(0.1, 0.2, 0.3, 0.4), CGRectMake(0, 0, 1, 1), CGRectMake(0.5, 0.25, 0.125, 0.75)};
    vector_float2 landmarks[] = {{0, 0}, {0.5, 0.5}, {1, 1}, {0.25, 0.75}, {-0.5, 2}};
    for (size_t bi = 0; bi < 3; bi++)
        for (size_t li = 0; li < 5; li++) {
            [faces addObject:point(VNImagePointForFaceLandmarkPoint(landmarks[li], boxes[bi], 640, 480))];
            [faces addObject:point(VNNormalizedFaceBoundingBoxPointForLandmarkPoint(landmarks[li], boxes[bi], 640, 480))];
        }
    record(@"faces", [faces componentsJoinedByString:@" "]);
}

static void defaults(VisionRecorder record)
{
    VNDetectRectanglesRequest *rectangles = [[VNDetectRectanglesRequest alloc] init];
    record(@"rectangles", [NSString stringWithFormat:@"%.4f %.4f %.4f %.4f %.4f %lu %@ rev=%lu %@", rectangles.minimumAspectRatio, rectangles.maximumAspectRatio, rectangles.quadratureTolerance, rectangles.minimumSize,
                           rectangles.minimumConfidence, (unsigned long)rectangles.maximumObservations, rect(rectangles.regionOfInterest), (unsigned long)rectangles.revision, [[VNDetectRectanglesRequest supportedRevisions] description] ? @"ok" : @"?"]);
    rectangles.minimumAspectRatio = 0.25f;
    rectangles.maximumAspectRatio = 0.75f;
    rectangles.quadratureTolerance = 10;
    rectangles.minimumSize = 0.5f;
    rectangles.minimumConfidence = 0.5f;
    rectangles.maximumObservations = 4;
    rectangles.regionOfInterest = CGRectMake(0.1, 0.2, 0.5, 0.5);
    VNDetectRectanglesRequest *copy = [rectangles copy];
    record(@"rectangles.set", [NSString stringWithFormat:@"%.4f %.4f %.4f %.4f %.4f %lu %@ | %.4f %.4f %lu %@ %d", rectangles.minimumAspectRatio, rectangles.maximumAspectRatio, rectangles.quadratureTolerance, rectangles.minimumSize,
                               rectangles.minimumConfidence, (unsigned long)rectangles.maximumObservations, rect(rectangles.regionOfInterest), copy.minimumAspectRatio, copy.minimumConfidence, (unsigned long)copy.maximumObservations,
                               rect(copy.regionOfInterest), copy != rectangles]);
    VNDetectBarcodesRequest *barcodes = [[VNDetectBarcodesRequest alloc] init];
    record(@"barcodes", [NSString stringWithFormat:@"%@ %@ %@", [barcodes.symbologies containsObject:VNBarcodeSymbologyQR] ? @"QR" : @"-", [barcodes.symbologies containsObject:VNBarcodeSymbologyPDF417] ? @"PDF417" : @"-", [barcodes.symbologies containsObject:VNBarcodeSymbologyEAN13] ? @"EAN13" : @"-"]);
    barcodes.symbologies = @[VNBarcodeSymbologyQR, VNBarcodeSymbologyPDF417];
    record(@"barcodes.set", [barcodes.symbologies componentsJoinedByString:@","]);
    VNDetectTextRectanglesRequest *text = [[VNDetectTextRectanglesRequest alloc] init];
    record(@"text", [NSString stringWithFormat:@"%d", text.reportCharacterBoxes]);
    text.reportCharacterBoxes = YES;
    record(@"text.set", [NSString stringWithFormat:@"%d", text.reportCharacterBoxes]);
    VNRequest *base = [[VNRequest alloc] init];
    record(@"base", [NSString stringWithFormat:@"bg=%d cpu=%d results=%d handler=%d", base.preferBackgroundProcessing, base.usesCPUOnly, base.results == nil, base.completionHandler == nil]);
    base.preferBackgroundProcessing = YES;
    base.usesCPUOnly = YES;
    record(@"base.set", [NSString stringWithFormat:@"bg=%d cpu=%d", base.preferBackgroundProcessing, base.usesCPUOnly]);
    VNRequest *copied = [base copy];
    record(@"base.copy", [NSString stringWithFormat:@"bg=%d cpu=%d rev=%lu handler=%d results=%d same=%d", copied.preferBackgroundProcessing, copied.usesCPUOnly, (unsigned long)copied.revision, copied.completionHandler == nil, copied.results == nil, copied == base]);
    VNRequest *withHandler = [[VNRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {}];
    record(@"handler", [NSString stringWithFormat:@"%d", withHandler.completionHandler != nil]);
    VNDetectedObjectObservation *object = [VNDetectedObjectObservation observationWithBoundingBox:CGRectMake(0.1, 0.1, 0.5, 0.5)];
    VNTrackObjectRequest *track = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:object];
    record(@"track", [NSString stringWithFormat:@"level=%lu last=%d input=%d", (unsigned long)track.trackingLevel, track.lastFrame, track.inputObservation == object]);
    track.lastFrame = YES;
    record(@"track.set", [NSString stringWithFormat:@"last=%d", track.lastFrame]);
    VNRectangleObservation *rectangle = [VNRectangleObservation observationWithBoundingBox:CGRectMake(0, 0, 1, 1)];
    VNTrackRectangleRequest *rectangleTrack = [[VNTrackRectangleRequest alloc] initWithRectangleObservation:rectangle];
    record(@"track.rectangle", [NSString stringWithFormat:@"level=%lu input=%d class=%d", (unsigned long)rectangleTrack.trackingLevel, rectangleTrack.inputObservation == rectangle, [rectangle isKindOfClass:[VNRectangleObservation class]]]);
    VNFaceObservation *face = [VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:CGRectMake(0.1, 0.2, 0.3, 0.4) roll:@0.5 yaw:@0.25];
    VNDetectFaceLandmarksRequest *landmarks = [[VNDetectFaceLandmarksRequest alloc] init];
    record(@"landmarks", [NSString stringWithFormat:@"%d", landmarks.inputFaceObservations == nil]);
    landmarks.inputFaceObservations = @[face];
    record(@"landmarks.set", [NSString stringWithFormat:@"%lu", (unsigned long)landmarks.inputFaceObservations.count]);
    record(@"errorDomain", VNErrorDomain);
    VNCoreMLRequest *coreml = [[VNCoreMLRequest alloc] initWithModel:nil];
    record(@"coreml", [NSString stringWithFormat:@"crop=%lu model=%d", (unsigned long)coreml.imageCropAndScaleOption, coreml.model == nil]);
    coreml.imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;
    record(@"coreml.set", [NSString stringWithFormat:@"%lu", (unsigned long)coreml.imageCropAndScaleOption]);
}

static BOOL file_exists(NSURL *url)
{
    return url != nil && [[NSFileManager defaultManager] fileExistsAtPath:url.path];
}

static BOOL compile_failure_expected(NSString *container)
{
    if ([container isEqualToString:@"vision_image"]) {
        return YES;
    }
    return NO;
}

static NSString *compile_outcome(NSString *container, NSError *failure, VisionRecorder record)
{
    record([NSString stringWithFormat:@"coreml.compile.%@", container],
           [NSString stringWithFormat:@"failed domain=%@ code=%ld", failure.domain ?: @"(none)",
                                      (long)failure.code]);
    if (!compile_failure_expected(container)) {
        record(@"coreml.compile.unexpected", container);
    }
    return @"failed";
}

static void coreml_model(CoreMLModels models, VisionRecorder record)
{
    VNCoreMLModel *wrapper;
    VNCoreMLRequest *request;
    VNImageRequestHandler *handler;
    NSError *failure = nil;
    NSURL *compiled;
    NSMutableString *said = [NSMutableString string];

    if (models.glm_classifier == nil || !file_exists(models.glm_classifier)) {
        record(@"coreml.model.absent.glm_classifier", @"absent");
        return;
    }
    compiled = [MLModel compileModelAtURL:models.glm_classifier error:&failure];
    if (compiled == nil) {
        compile_outcome(@"glm_classifier", failure, record);
        return;
    }
    wrapper = [VNCoreMLModel modelForMLModel:[MLModel modelWithContentsOfURL:compiled error:&failure]
                                        error:&failure];
    record(@"coreml.model", [NSString stringWithFormat:@"%d input=%@", wrapper != nil,
                                                       wrapper.inputImageFeatureName ?: @"(nil)"]);
    record(@"coreml.nosuchmodel", [VNCoreMLModel modelForMLModel:nil error:&failure] == nil ? @"refused" : @"made");
    {
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:vision_picture(8, 8)
                                                                                options:@{}];
        VNCoreMLRequest *bare = [[VNCoreMLRequest alloc] initWithModel:nil];
        NSError *runFailure = nil;
        BOOL ok = [handler performRequests:@[ bare ] error:&runFailure];
        record(@"coreml.perform", [NSString stringWithFormat:@"%d %@/%ld", ok,
                                                             runFailure.domain ?: @"(none)", (long)runFailure.code]);
        record(@"coreml.perform.results", [NSString stringWithFormat:@"%lu", (unsigned long)bare.results.count]);
        ok = [handler performRequests:@[ [[VNCoreMLRequest alloc] initWithModel:wrapper] ] error:&runFailure];
        record(@"coreml.perform.vector", [NSString stringWithFormat:@"%d %@/%ld", ok,
                                                                         runFailure.domain ?: @"(none)",
                                                                         (long)runFailure.code]);
    }
    record(@"coreml.vectormodel", [VNCoreMLModel modelForMLModel:[MLModel modelWithContentsOfURL:compiled
                                                                                               error:NULL]
                                                          error:&failure] == nil
                                            ? @"refused"
                                            : @"made");
    request = [[VNCoreMLRequest alloc] initWithModel:wrapper];
    record(@"coreml.request", [NSString stringWithFormat:@"%d crop=%lu", request.model == wrapper,
                                                         (unsigned long)request.imageCropAndScaleOption]);
    handler = [[VNImageRequestHandler alloc] initWithCGImage:vision_picture(8, 8) options:@{}];
    [handler performRequests:@[request] error:&failure];
    for (VNObservation *observation in request.results) {
        [said appendFormat:@"%@:%.3f ", NSStringFromClass([observation class]), (double)observation.confidence];
        if ([observation isKindOfClass:[VNClassificationObservation class]]) {
            [said appendFormat:@"(%@) ", ((VNClassificationObservation *)observation).identifier];
        }
        if ([observation isKindOfClass:[VNCoreMLFeatureValueObservation class]]) {
            MLFeatureValue *value = ((VNCoreMLFeatureValueObservation *)observation).featureValue;
            [said appendFormat:@"<%@ %@ type=%ld> ", ((VNCoreMLFeatureValueObservation *)observation).featureName,
                                 value.stringValue ?: @"(nil)", (long)value.type];
        }
    }
    record(@"coreml.results", said.length > 0 ? said : @"(none)");
    record(@"coreml.completion", [NSString stringWithFormat:@"%lu",
                                                           (unsigned long)request.results.count]);
}

static void observations(VisionRecorder record)
{
    VNDetectedObjectObservation *plain = [VNDetectedObjectObservation observationWithBoundingBox:CGRectMake(0.1, 0.2, 0.3, 0.4)];
    record(@"observation", [NSString stringWithFormat:@"rev=%lu conf=%.2f box=%@ uuid=%d", (unsigned long)plain.requestRevision, plain.confidence, rect(plain.boundingBox), plain.uuid != nil]);
    VNDetectedObjectObservation *second = [VNDetectedObjectObservation observationWithRequestRevision:3 boundingBox:CGRectMake(0, 0, 1, 1)];
    record(@"observation.revision", [NSString stringWithFormat:@"rev=%lu different=%d", (unsigned long)second.requestRevision, ![second.uuid isEqual:plain.uuid]]);
    VNFaceObservation *face = [VNFaceObservation faceObservationWithRequestRevision:2 boundingBox:CGRectMake(0.1, 0.2, 0.3, 0.4) roll:@0.5 yaw:@-0.25];
    record(@"face", [NSString stringWithFormat:@"rev=%lu conf=%.2f box=%@ roll=%@ yaw=%@ landmarks=%d", (unsigned long)face.requestRevision, face.confidence, rect(face.boundingBox), face.roll, face.yaw, face.landmarks == nil]);
    VNFaceObservation *copy = [face copy];
    record(@"copy", [NSString stringWithFormat:@"class=%d uuid=%d box=%@ roll=%@ yaw=%@ rev=%lu", [copy isKindOfClass:[VNFaceObservation class]], [copy.uuid isEqual:face.uuid], rect(copy.boundingBox), copy.roll, copy.yaw, (unsigned long)copy.requestRevision]);
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:face requiringSecureCoding:YES error:NULL];
    VNFaceObservation *decoded = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:[VNFaceObservation class] fromData:archive error:NULL] : nil;
    record(@"coding", [NSString stringWithFormat:@"%d uuid=%d box=%@ roll=%@ yaw=%@ conf=%.2f rev=%lu", decoded != nil, [decoded.uuid isEqual:face.uuid], rect(decoded.boundingBox), decoded.roll, decoded.yaw, decoded.confidence, (unsigned long)decoded.requestRevision]);
    record(@"coding.secure", [NSString stringWithFormat:@"%d", [VNFaceObservation supportsSecureCoding]]);
}

static void handlers(VisionRecorder record)
{
    CGImageRef image = white_image();
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
    NSError *error = nil;
    BOOL ok = [handler performRequests:@[] error:&error];
    record(@"perform.empty", [NSString stringWithFormat:@"%d err=%d", ok, error != nil]);
    __block int called = 0;
    __block NSInteger code = 0;
    VNDetectRectanglesRequest *unsupported = [[VNDetectRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *failure) {
        called++;
        code = failure.code;
    }];
    unsupported.revision = 99;
    error = nil;
    ok = [handler performRequests:@[unsupported] error:&error];
    record(@"perform.revision", [NSString stringWithFormat:@"ok=%d code=%ld called=%d completion=%ld results=%d", ok, (long)error.code, called, (long)code, unsupported.results == nil]);
    VNSequenceRequestHandler *sequence = [[VNSequenceRequestHandler alloc] init];
    VNDetectFaceRectanglesRequest *faces = [[VNDetectFaceRectanglesRequest alloc] init];
    faces.revision = 99;
    error = nil;
    ok = [sequence performRequests:@[faces] onCGImage:image error:&error];
    record(@"sequence.revision", [NSString stringWithFormat:@"ok=%d code=%ld", ok, (long)error.code]);
    error = nil;
    ok = [sequence performRequests:@[] onCGImage:image error:&error];
    record(@"sequence.empty", [NSString stringWithFormat:@"%d", ok]);
    CGImageRelease(image);
}

CGImageRef vision_picture(size_t wide, size_t high)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, wide, high, 8, 0, space, kCGImageAlphaNone);
    CGImageRef image;
    CGColorSpaceRelease(space);
    if (context == NULL) {
        return NULL;
    }
    CGContextSetRGBFillColor(context, 0.5, 0.25, 0.75, 1.0);
    CGContextFillRect(context, CGRectMake(0, 0, (CGFloat)wide, (CGFloat)high));
    image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

CoreMLModels vision_coreml_models(void)
{
    CoreMLModels models;
    NSString *directory = @(getenv("VISION_COREML_MODELS") ?: "");
    models.glm_classifier = directory.length > 0
                                ? [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:
                                                                             @"glm_classifier.mlmodel"]]
                                : nil;
    models.image = directory.length > 0
                       ? [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"nn_image.mlmodel"]]
                       : nil;
    models.vision = directory.length > 0
                        ? [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"vision_image.mlmodel"]]
                        : nil;
    return models;
}


static void picture_case(CoreMLModels models, VisionRecorder record)
{
    NSError *failure = nil;
    NSURL *compiled;
    VNCoreMLModel *model;

    if (models.vision == nil || !file_exists(models.vision)) {
        record(@"coreml.model.absent.vision_image", @"absent");
        return;
    }
    compiled = [MLModel compileModelAtURL:models.vision error:&failure];
    model = compiled != nil ? [VNCoreMLModel modelForMLModel:[MLModel modelWithContentsOfURL:compiled error:&failure]
                                               error:&failure]
                            : nil;
    record(@"picture/model", model != nil ? @"made" : @"refused");
    if (model == nil) {
        record(@"picture/error", [NSString stringWithFormat:@"%@/%ld", failure.domain ?: @"(none)",
                                                        (long)failure.code]);
        if (!compile_failure_expected(@"vision_image")) {
            record(@"coreml.compile.unexpected", @"vision_image");
        }
        return;
    }
    record(@"picture/input", model.inputImageFeatureName ?: @"(nil)");
    {
        MLModel *carried = [model model];
        MLFeatureDescription *described =
            carried.modelDescription.inputDescriptionsByName[model.inputImageFeatureName];
        MLImageConstraint *constraint = described.imageConstraint;
        record(@"picture/type", [NSString stringWithFormat:@"%ld", (long)described.type]);
        record(@"picture/size", [NSString stringWithFormat:@"%ldx%ld", (long)constraint.pixelsWide,
                                                            (long)constraint.pixelsHigh]);
        record(@"picture/format", [NSString stringWithFormat:@"%u", (unsigned)constraint.pixelFormatType]);
    }
    {
        VNCoreMLRequest *request = [[VNCoreMLRequest alloc] initWithModel:model];
        VNImageRequestHandler *handler =
            [[VNImageRequestHandler alloc] initWithCGImage:vision_picture(64, 64) options:@{}];
        NSMutableArray *seen = [NSMutableArray array];
        NSError *runFailure = nil;
        BOOL ran = [handler performRequests:@[ request ] error:&runFailure];
        NSUInteger index;
        for (index = 0; index < request.results.count; index++) {
            VNObservation *observation = request.results[index];
            [seen addObject:NSStringFromClass([observation class])];
            if ([observation isKindOfClass:[VNClassificationObservation class]]) {
                [seen addObject:[NSString stringWithFormat:@"(%@/%.4f)",
                                                           ((VNClassificationObservation *)observation).identifier,
                                                           (double)observation.confidence]];
            } else if ([observation isKindOfClass:[VNPixelBufferObservation class]]) {
                CVPixelBufferRef buffer = ((VNPixelBufferObservation *)observation).pixelBuffer;
                [seen addObject:[NSString stringWithFormat:@"[%@ %lux%lu]",
                                                           ((VNPixelBufferObservation *)observation).featureName,
                                                           (unsigned long)CVPixelBufferGetWidth(buffer),
                                                           (unsigned long)CVPixelBufferGetHeight(buffer)]];
            } else if ([observation isKindOfClass:[VNCoreMLFeatureValueObservation class]]) {
                MLFeatureValue *value = ((VNCoreMLFeatureValueObservation *)observation).featureValue;
                if (value.multiArrayValue != nil) {
                    MLMultiArray *array = value.multiArrayValue;
                    NSMutableArray *read = [NSMutableArray array];
                    NSInteger element;
                    for (element = 0; element < MIN((NSInteger)array.count, 4); element++) {
                        [read addObject:[NSString stringWithFormat:@"%.4f",
                                                              [[array objectAtIndexedSubscript:element] doubleValue]]];
                    }
                    [seen addObject:[NSString stringWithFormat:@"<%@ %@ %@>",
                                                       ((VNCoreMLFeatureValueObservation *)observation).featureName,
                                                       [[array.shape valueForKey:@"description"]
                                                           componentsJoinedByString:@","],
                                                       [read componentsJoinedByString:@","]]];
                } else {
                    [seen addObject:[NSString stringWithFormat:@"<%@ %@ type=%ld>",
                                                       ((VNCoreMLFeatureValueObservation *)observation).featureName,
                                                       value.stringValue ?: @"(nil)", (long)value.type]];
                }
            } else if ([observation isKindOfClass:[VNDetectedObjectObservation class]]) {
                VNDetectedObjectObservation *detected = (VNDetectedObjectObservation *)observation;
                [seen addObject:[NSString stringWithFormat:@"{%ld %ld %ld %ld}",
                                                           (long)(detected.boundingBox.origin.x * 1000),
                                                           (long)(detected.boundingBox.origin.y * 1000),
                                                           (long)(detected.boundingBox.size.width * 1000),
                                                           (long)(detected.boundingBox.size.height * 1000)]];
            }
        }
        record(@"picture/ran", [NSString stringWithFormat:@"%d %@/%ld", ran, runFailure.domain ?: @"(none)",
                                                          (long)runFailure.code]);
        record(@"picture/text", runFailure.localizedDescription ?: @"(none)");
        record(@"picture/observations", [seen componentsJoinedByString:@" "]);
    }
}

void vision_run(VisionRecorder record, CoreMLModels models)
{
    constants(record);
    geometry(record);
    defaults(record);
    observations(record);
    handlers(record);
    coreml_model(models, record);
    picture_case(models, record);
}
