#import "RevenantVision.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface VNRectangleObservation (RevenantCorners)
- (void)revenant_setCornersTopLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft;
@end

static NSSet *revenant_vision_coded_classes(void)
{
    static NSSet *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        classes = [NSSet setWithObjects:[NSValue class], [NSNumber class], [NSString class], [NSUUID class], [NSArray class], [NSData class], [VNObservation class], [VNRectangleObservation class], [VNClassificationObservation class], nil];
    });
    return classes;
}

static void revenant_vision_encode(id object, NSCoder *coder)
{
    for (Class cls = [object class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned index = 0; index < count; index++) {
            const char *type = ivar_getTypeEncoding(ivars[index]);
            NSString *key = [NSString stringWithFormat:@"%s.%s", class_getName(cls), ivar_getName(ivars[index])];
            if (type[0] == '@') {
                id value = object_getIvar(object, ivars[index]);
                if (value)
                    [coder encodeObject:value forKey:key];
            } else if (type[0] != '^') {
                NSUInteger size;
                NSGetSizeAndAlignment(type, &size, NULL);
                [coder encodeObject:[NSData dataWithBytes:(const char *)(__bridge void *)object + ivar_getOffset(ivars[index]) length:size] forKey:key];
            }
        }
        free(ivars);
    }
}

static void revenant_vision_decode(id object, NSCoder *coder)
{
    for (Class cls = [object class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned index = 0; index < count; index++) {
            const char *type = ivar_getTypeEncoding(ivars[index]);
            NSString *key = [NSString stringWithFormat:@"%s.%s", class_getName(cls), ivar_getName(ivars[index])];
            if (type[0] == '@') {
                id value = [coder decodeObjectOfClasses:revenant_vision_coded_classes() forKey:key];
                if (value)
                    object_setIvar(object, ivars[index], value);
            } else if (type[0] != '^') {
                NSUInteger size;
                NSGetSizeAndAlignment(type, &size, NULL);
                NSData *bytes = [coder decodeObjectOfClass:[NSData class] forKey:key];
                if (bytes.length == size)
                    memcpy((char *)(__bridge void *)object + ivar_getOffset(ivars[index]), bytes.bytes, size);
            }
        }
        free(ivars);
    }
}

@implementation VNObservation {
    NSUInteger _requestRevision;
    float _confidence;
    NSUUID *_uuid;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithRequestRevision:(NSUInteger)requestRevision
{
    if ((self = [super init])) {
        _uuid = [NSUUID UUID];
        _requestRevision = requestRevision;
        _confidence = 1;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithRequestRevision:0];
}

- (NSUInteger)requestRevision
{
    return _requestRevision;
}

- (NSUUID *)uuid
{
    return _uuid;
}

- (float)confidence
{
    return _confidence;
}

- (void)setConfidence:(float)confidence
{
    _confidence = confidence;
}

- (id)copyWithZone:(NSZone *)zone
{
    return revenant_vision_clone(self, zone);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_vision_encode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init]))
        revenant_vision_decode(self, coder);
    return self;
}

@end

@implementation VNDetectedObjectObservation {
    CGRect _boundingBox;
}

- (CGRect)boundingBox
{
    return _boundingBox;
}

+ (instancetype)observationWithBoundingBox:(CGRect)boundingBox
{
    return [self observationWithRequestRevision:0 boundingBox:boundingBox];
}

+ (instancetype)observationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox
{
    VNDetectedObjectObservation *observation = [[self alloc] initWithRequestRevision:requestRevision];
    if (observation)
        observation->_boundingBox = boundingBox;
    return observation;
}

@end

@implementation VNFaceObservation {
    NSNumber *_roll;
    NSNumber *_yaw;
    VNFaceLandmarks2D *_landmarks;
}

+ (instancetype)faceObservationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox roll:(NSNumber *)roll yaw:(NSNumber *)yaw
{
    if (!roll || !yaw || roll.floatValue < -M_PI || roll.floatValue >= M_PI || yaw.floatValue < -M_PI_2 || yaw.floatValue >= M_PI_2)
        return nil;
    VNFaceObservation *observation = [self observationWithRequestRevision:requestRevision boundingBox:boundingBox];
    if (observation) {
        observation->_roll = roll;
        observation->_yaw = yaw;
    }
    return observation;
}

@end

@implementation VNClassificationObservation {
    NSString *_identifier;
}

- (instancetype)revenant_initWithIdentifier:(NSString *)identifier confidence:(float)confidence
{
    VNClassificationObservation *built = [super init];
    if (built != nil) {
        built->_identifier = [identifier copy];
        built.confidence = confidence;
    }
    return built;
}

- (NSString *)identifier
{
    return _identifier;
}
@end

@implementation VNCoreMLFeatureValueObservation {
    MLFeatureValue *_featureValue;
    NSString *_featureName;
}

- (instancetype)revenant_initWithFeatureValue:(MLFeatureValue *)featureValue featureName:(NSString *)featureName
{
    VNCoreMLFeatureValueObservation *built = [super init];
    if (built != nil) {
        built->_featureValue = featureValue;
        built->_featureName = [featureName copy];
    }
    return built;
}

- (MLFeatureValue *)featureValue
{
    return _featureValue;
}

- (NSString *)featureName
{
    return _featureName;
}
@end

@implementation VNPixelBufferObservation {
    CVPixelBufferRef _pixelBuffer;
    NSString *_featureName;
}

- (instancetype)revenant_initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer featureName:(NSString *)featureName
{
    VNPixelBufferObservation *built = [super init];
    if (built != nil) {
        built->_pixelBuffer = (CVPixelBufferRef)CVPixelBufferRetain(pixelBuffer);
        built->_featureName = [featureName copy];
    }
    return built;
}

- (NSString *)featureName
{
    return _featureName;
}

- (CVPixelBufferRef)pixelBuffer
{
    return _pixelBuffer;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNPixelBufferObservation *copy = [super copyWithZone:zone];
    if (copy->_pixelBuffer)
        CVPixelBufferRetain(copy->_pixelBuffer);
    return copy;
}

- (void)dealloc
{
    if (_pixelBuffer)
        CVPixelBufferRelease(_pixelBuffer);
}

@end

@implementation VNRectangleObservation {
    CGPoint _topLeft;
    CGPoint _bottomLeft;
    CGPoint _bottomRight;
    CGPoint _topRight;
}

- (CGPoint)topLeft
{
    return _topLeft;
}

- (CGPoint)topRight
{
    return _topRight;
}

- (CGPoint)bottomRight
{
    return _bottomRight;
}

- (CGPoint)bottomLeft
{
    return _bottomLeft;
}

- (void)revenant_setCornersTopLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft
{
    _topLeft = topLeft;
    _topRight = topRight;
    _bottomRight = bottomRight;
    _bottomLeft = bottomLeft;
}
@end

@implementation VNTextObservation {
    NSArray *_characterBoxes;
}
@end

@implementation VNBarcodeObservation {
    NSString *_symbology;
    NSString *_payloadStringValue;
    CIBarcodeDescriptor *_barcodeDescriptor;
}

+ (instancetype)revenant_observationWithPayload:(NSString *)payload symbology:(VNBarcodeSymbology)symbology boundingBox:(CGRect)boundingBox topLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft requestRevision:(NSUInteger)revision
{
    VNBarcodeObservation *observation = [self observationWithRequestRevision:revision boundingBox:boundingBox];
    if (observation) {
        observation->_payloadStringValue = [payload copy];
        observation->_symbology = [symbology copy];
        [observation revenant_setCornersTopLeft:topLeft topRight:topRight bottomRight:bottomRight bottomLeft:bottomLeft];
    }
    return observation;
}

- (NSString *)payloadStringValue
{
    return _payloadStringValue;
}

- (VNBarcodeSymbology)symbology
{
    return _symbology;
}
@end

@implementation VNHorizonObservation {
    CGAffineTransform _transform;
    CGFloat _angle;
}
@end

@implementation VNImageAlignmentObservation
@end

@implementation VNImageTranslationAlignmentObservation {
    CGAffineTransform _alignmentTransform;
}
@end

@implementation VNImageHomographicAlignmentObservation {
    matrix_float3x3 _warpTransform;
}
@end

@implementation VNFaceLandmarkRegion {
    NSUInteger _pointCount;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

@end

@implementation VNFaceLandmarkRegion2D {
    const CGPoint *_normalizedPoints;
}

- (const CGPoint *)pointsInImageOfSize:(CGSize)imageSize
{
    return NULL;
}

@end

@implementation VNFaceLandmarks {
    VNConfidence _confidence;
}
@end

@implementation VNFaceLandmarks2D {
    VNFaceLandmarkRegion2D *_allPoints;
    VNFaceLandmarkRegion2D *_faceContour;
    VNFaceLandmarkRegion2D *_leftEye;
    VNFaceLandmarkRegion2D *_rightEye;
    VNFaceLandmarkRegion2D *_leftEyebrow;
    VNFaceLandmarkRegion2D *_rightEyebrow;
    VNFaceLandmarkRegion2D *_nose;
    VNFaceLandmarkRegion2D *_noseCrest;
    VNFaceLandmarkRegion2D *_medianLine;
    VNFaceLandmarkRegion2D *_outerLips;
    VNFaceLandmarkRegion2D *_innerLips;
    VNFaceLandmarkRegion2D *_leftPupil;
    VNFaceLandmarkRegion2D *_rightPupil;
}
@end
