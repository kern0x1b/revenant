#import "RevenantVision.h"
#import "RevenantVisionContours.h"
#import <simd/simd.h>
#import <math.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wprotocol"

static double revenant_vision_squared_distance(double x1, double y1, double x2, double y2)
{
    double dx = x1 - x2, dy = y1 - y2;
    return dx * dx + dy * dy;
}

typedef struct {
    double x;
    double y;
} RevenantVisionXY;

typedef struct {
    RevenantVisionXY center;
    double radius;
    int count;
} RevenantVisionCircle;

static RevenantVisionCircle revenant_vision_circle_of_one(RevenantVisionXY point)
{
    RevenantVisionCircle circle = {{point.x, point.y}, 0.0, 1};
    return circle;
}

static RevenantVisionCircle revenant_vision_circle_of_two(RevenantVisionXY a, RevenantVisionXY b)
{
    RevenantVisionCircle circle;
    circle.center.x = (a.x + b.x) / 2.0;
    circle.center.y = (a.y + b.y) / 2.0;
    circle.radius = sqrt(revenant_vision_squared_distance(a.x, a.y, b.x, b.y)) / 2.0;
    circle.count = 2;
    return circle;
}

static RevenantVisionCircle revenant_vision_circle_of_three(RevenantVisionXY a, RevenantVisionXY b, RevenantVisionXY c)
{
    RevenantVisionCircle circle;
    double d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
    if (fabs(d) < 1e-18) {
        double ab = revenant_vision_squared_distance(a.x, a.y, b.x, b.y);
        double ac = revenant_vision_squared_distance(a.x, a.y, c.x, c.y);
        double bc = revenant_vision_squared_distance(b.x, b.y, c.x, c.y);
        if (ab >= ac && ab >= bc)
            return revenant_vision_circle_of_two(a, b);
        if (ac >= bc)
            return revenant_vision_circle_of_two(a, c);
        return revenant_vision_circle_of_two(b, c);
    }
    double a2 = a.x * a.x + a.y * a.y;
    double b2 = b.x * b.x + b.y * b.y;
    double c2 = c.x * c.x + c.y * c.y;
    circle.center.x = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d;
    circle.center.y = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d;
    circle.radius = sqrt(revenant_vision_squared_distance(circle.center.x, circle.center.y, a.x, a.y));
    circle.count = 3;
    return circle;
}

static BOOL revenant_vision_circle_holds(RevenantVisionCircle circle, RevenantVisionXY point)
{
    if (circle.count == 0)
        return NO;
    return revenant_vision_squared_distance(circle.center.x, circle.center.y, point.x, point.y)
        <= circle.radius * circle.radius + 1e-12;
}

static void revenant_vision_shuffle(RevenantVisionXY *points, NSInteger count)
{
    uint32_t seed = 0x5f3759dfu;
    for (NSInteger index = count - 1; index > 0; index--) {
        RevenantVisionXY swap;
        seed = seed * 1664525u + 1013904223u;
        NSInteger other = (NSInteger)(seed % (uint32_t)(index + 1));
        swap = points[index];
        points[index] = points[other];
        points[other] = swap;
    }
}

static RevenantVisionCircle revenant_vision_bounding_circle(RevenantVisionXY *points, NSInteger count)
{
    RevenantVisionCircle circle = {{0.0, 0.0}, 0.0, 0};
    if (count <= 0)
        return circle;
    revenant_vision_shuffle(points, count);
    for (NSInteger i = 0; i < count; i++) {
        if (revenant_vision_circle_holds(circle, points[i]))
            continue;
        circle = revenant_vision_circle_of_one(points[i]);
        for (NSInteger j = 0; j < i; j++) {
            if (revenant_vision_circle_holds(circle, points[j]))
                continue;
            circle = revenant_vision_circle_of_two(points[i], points[j]);
            for (NSInteger k = 0; k < j; k++) {
                if (revenant_vision_circle_holds(circle, points[k]))
                    continue;
                circle = revenant_vision_circle_of_three(points[i], points[j], points[k]);
            }
        }
    }
    return circle;
}

@implementation VNPoint {
    double _x;
    double _y;
}

+ (VNPoint *)zeroPoint
{
    static VNPoint *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        zero = [[VNPoint alloc] initWithX:0.0 y:0.0];
    });
    return zero;
}

+ (VNPoint *)pointByApplyingVector:(VNVector *)vector toPoint:(VNPoint *)point
{
    if (vector == nil || point == nil) {
        return nil;
    }
    return [[self alloc] initWithX:point.x + vector.x y:point.y + vector.y];
}

+ (double)distanceBetweenPoint:(VNPoint *)point1 point:(VNPoint *)point2
{
    if (point1 == nil || point2 == nil) {
        return NAN;
    }
    return [point1 distanceToPoint:point2];
}

- (instancetype)initWithX:(double)x y:(double)y
{
    if ((self = [super init])) {
        _x = x;
        _y = y;
    }
    return self;
}

- (instancetype)initWithLocation:(CGPoint)location
{
    return [self initWithX:(double)location.x y:(double)location.y];
}

- (double)distanceToPoint:(VNPoint *)point
{
    if (point == nil) {
        return NAN;
    }
    return hypot(_x - point.x, _y - point.y);
}

- (CGPoint)location
{
    return CGPointMake((CGFloat)_x, (CGFloat)_y);
}

- (double)x
{
    return _x;
}

- (double)y
{
    return _y;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNPoint *copy = revenant_vision_clone(self, zone);
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_x forKey:@"x"];
    [coder encodeDouble:_y forKey:@"y"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithX:[coder decodeDoubleForKey:@"x"] y:[coder decodeDoubleForKey:@"y"]];
}

@end

@interface VNDetectedPoint (RevenantFactory)
+ (instancetype)revenant_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence;
@end

@interface VNRecognizedPoint (RevenantFactory)
+ (instancetype)revenant_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence identifier:(VNRecognizedPointKey)identifier;
@end

@implementation VNDetectedPoint {
    VNConfidence _confidence;
}

+ (instancetype)revenant_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence
{
    VNDetectedPoint *point = [[self alloc] initWithX:x y:y];
    point->_confidence = confidence;
    return point;
}

- (VNConfidence)confidence
{
    return _confidence;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeFloat:_confidence forKey:@"confidence"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _confidence = [coder decodeFloatForKey:@"confidence"];
    }
    return self;
}

@end

@implementation VNRecognizedPoint {
    VNRecognizedPointKey _identifier;
}

+ (instancetype)revenant_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence identifier:(VNRecognizedPointKey)identifier
{
    VNRecognizedPoint *point = [super revenant_pointWithX:x y:y confidence:confidence];
    point->_identifier = [identifier copy];
    return point;
}

- (VNRecognizedPointKey)identifier
{
    return _identifier;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_identifier forKey:@"identifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
    }
    return self;
}

@end

@implementation VNVector {
    double _x;
    double _y;
}

+ (VNVector *)zeroVector
{
    static VNVector *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        zero = [[VNVector alloc] initWithXComponent:0.0 yComponent:0.0];
    });
    return zero;
}

+ (VNVector *)unitVectorForVector:(VNVector *)vector
{
    double length;
    if (vector == nil) {
        return nil;
    }
    length = vector.length;
    if (length == 0.0) {
        return [self zeroVector];
    }
    return [[self alloc] initWithXComponent:vector.x / length yComponent:vector.y / length];
}

+ (VNVector *)vectorByMultiplyingVector:(VNVector *)vector byScalar:(double)scalar
{
    if (vector == nil) {
        return nil;
    }
    return [[self alloc] initWithXComponent:vector.x * scalar yComponent:vector.y * scalar];
}

+ (VNVector *)vectorByAddingVector:(VNVector *)v1 toVector:(VNVector *)v2
{
    if (v1 == nil || v2 == nil) {
        return nil;
    }
    return [[self alloc] initWithXComponent:v1.x + v2.x yComponent:v1.y + v2.y];
}

+ (VNVector *)vectorBySubtractingVector:(VNVector *)v1 fromVector:(VNVector *)v2
{
    if (v1 == nil || v2 == nil) {
        return nil;
    }
    return [[self alloc] initWithXComponent:v2.x - v1.x yComponent:v2.y - v1.y];
}

+ (double)dotProductOfVector:(VNVector *)v1 vector:(VNVector *)v2
{
    if (v1 == nil || v2 == nil) {
        return NAN;
    }
    return v1.x * v2.x + v1.y * v2.y;
}

- (instancetype)initWithXComponent:(double)x yComponent:(double)y
{
    if ((self = [super init])) {
        _x = x;
        _y = y;
    }
    return self;
}

- (instancetype)initWithR:(double)r theta:(double)theta
{
    return [self initWithXComponent:r * cos(theta) yComponent:r * sin(theta)];
}

- (instancetype)initWithVectorHead:(VNPoint *)head tail:(VNPoint *)tail
{
    if (head == nil || tail == nil) {
        return nil;
    }
    return [self initWithXComponent:head.x - tail.x yComponent:head.y - tail.y];
}

- (double)x
{
    return _x;
}

- (double)y
{
    return _y;
}

- (double)r
{
    return self.length;
}

- (double)theta
{
    if (_x == 0.0 && _y == 0.0) {
        return NAN;
    }
    return atan2(_y, _x);
}

- (double)length
{
    return hypot(_x, _y);
}

- (double)squaredLength
{
    return _x * _x + _y * _y;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVector *copy = revenant_vision_clone(self, zone);
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_x forKey:@"x"];
    [coder encodeDouble:_y forKey:@"y"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithXComponent:[coder decodeDoubleForKey:@"x"] yComponent:[coder decodeDoubleForKey:@"y"]];
}

@end

@implementation VNCircle {
    VNPoint *_center;
    double _radius;
}

+ (VNCircle *)zeroCircle
{
    static VNCircle *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        zero = [[VNCircle alloc] initWithCenter:[VNPoint zeroPoint] radius:0.0];
    });
    return zero;
}

- (instancetype)initWithCenter:(VNPoint *)center radius:(double)radius
{
    if ((self = [super init]) && center != nil) {
        _center = center;
        _radius = radius;
    }
    return self;
}

- (instancetype)initWithCenter:(VNPoint *)center diameter:(double)diameter
{
    return [self initWithCenter:center radius:diameter / 2.0];
}

- (BOOL)containsPoint:(VNPoint *)point
{
    if (point == nil || _center == nil) {
        return NO;
    }
    return [_center distanceToPoint:point] <= _radius;
}

- (BOOL)containsPoint:(VNPoint *)point inCircumferentialRingOfWidth:(double)ringWidth
{
    double distance;
    if (point == nil || _center == nil) {
        return NO;
    }
    distance = [_center distanceToPoint:point];
    return distance >= _radius - ringWidth / 2.0 && distance <= _radius + ringWidth / 2.0;
}

- (VNPoint *)center
{
    return _center;
}

- (double)radius
{
    return _radius;
}

- (double)diameter
{
    return _radius * 2.0;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNCircle *copy = revenant_vision_clone(self, zone);
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_center forKey:@"center"];
    [coder encodeDouble:_radius forKey:@"radius"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    VNPoint *center = [coder decodeObjectOfClass:[VNPoint class] forKey:@"center"];
    if (center == nil) {
        return nil;
    }
    return [self initWithCenter:center radius:[coder decodeDoubleForKey:@"radius"]];
}

@end

@implementation VNGeometryUtils

+ (VNCircle *)boundingCircleForPoints:(NSArray<VNPoint *> *)points error:(NSError **)error
{
    NSInteger count = (NSInteger)points.count;
    RevenantVisionXY *buffer;
    RevenantVisionCircle circle;
    VNCircle *answer;
    if (count == 0) {
        if (error) {
            *error = revenant_vision_error(VNErrorInvalidArgument, @"there are no points to draw a circle around");
        }
        return nil;
    }
    buffer = malloc(sizeof(RevenantVisionXY) * (size_t)count);
    if (buffer == NULL) {
        if (error) {
            *error = revenant_vision_error(VNErrorOutOfMemory, @"the points would not fit in memory");
        }
        return nil;
    }
    for (NSInteger index = 0; index < count; index++) {
        VNPoint *point = points[(NSUInteger)index];
        if (point == nil) {
            free(buffer);
            if (error) {
                *error = revenant_vision_error(VNErrorInvalidArgument, @"one of the points is not a VNPoint");
            }
            return nil;
        }
        buffer[index].x = point.x;
        buffer[index].y = point.y;
    }
    circle = revenant_vision_bounding_circle(buffer, count);
    free(buffer);
    answer = [[VNCircle alloc] initWithCenter:[[VNPoint alloc] initWithX:circle.center.x y:circle.center.y]
                                       radius:circle.radius];
    return answer;
}

+ (VNCircle *)boundingCircleForSIMDPoints:(simd_float2 const *)points
                               pointCount:(NSInteger)pointCount
                                    error:(NSError **)error
{
    RevenantVisionXY *buffer;
    RevenantVisionCircle circle;
    VNCircle *answer;
    if (pointCount <= 0 || points == NULL) {
        if (error) {
            *error = revenant_vision_error(VNErrorInvalidArgument, @"there are no points to draw a circle around");
        }
        return nil;
    }
    buffer = malloc(sizeof(RevenantVisionXY) * (size_t)pointCount);
    if (buffer == NULL) {
        if (error) {
            *error = revenant_vision_error(VNErrorOutOfMemory, @"the points would not fit in memory");
        }
        return nil;
    }
    for (NSInteger index = 0; index < pointCount; index++) {
        buffer[index].x = (double)points[index].x;
        buffer[index].y = (double)points[index].y;
    }
    circle = revenant_vision_bounding_circle(buffer, pointCount);
    free(buffer);
    answer = [[VNCircle alloc] initWithCenter:[[VNPoint alloc] initWithX:circle.center.x y:circle.center.y]
                                       radius:circle.radius];
    return answer;
}

@end

@implementation VNStatefulRequest {
    CMTime _frameAnalysisSpacing;
}

- (instancetype)initWithFrameAnalysisSpacing:(CMTime)frameAnalysisSpacing
                           completionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _frameAnalysisSpacing = frameAnalysisSpacing;
    }
    return self;
}

- (NSInteger)minimumLatencyFrameCount
{
    return 0;
}

- (CMTime)frameAnalysisSpacing
{
    return _frameAnalysisSpacing;
}

- (CMTime)requestFrameAnalysisSpacing
{
    return _frameAnalysisSpacing;
}

@end

@implementation VNVideoProcessorCadence

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorCadence *copy = revenant_vision_clone(self, zone);
    return copy;
}

@end

@implementation VNVideoProcessorFrameRateCadence {
    NSInteger _frameRate;
}

- (instancetype)initWithFrameRate:(NSInteger)frameRate
{
    if ((self = [super init])) {
        _frameRate = frameRate;
    }
    return self;
}

- (NSInteger)frameRate
{
    return _frameRate;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorFrameRateCadence *copy = revenant_vision_clone(self, zone);
    return copy;
}

@end

@implementation VNVideoProcessorTimeIntervalCadence {
    CFTimeInterval _timeInterval;
}

- (instancetype)initWithTimeInterval:(CFTimeInterval)timeInterval
{
    if ((self = [super init])) {
        _timeInterval = timeInterval;
    }
    return self;
}

- (CFTimeInterval)timeInterval
{
    return _timeInterval;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorTimeIntervalCadence *copy = revenant_vision_clone(self, zone);
    return copy;
}

@end

@implementation VNVideoProcessorRequestProcessingOptions {
    VNVideoProcessorCadence *_cadence;
}

- (VNVideoProcessorCadence *)cadence
{
    return _cadence;
}

- (void)setCadence:(VNVideoProcessorCadence *)cadence
{
    _cadence = [cadence copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorRequestProcessingOptions *copy = revenant_vision_clone(self, zone);
    return copy;
}

@end

CGPoint VNNormalizedPointForImagePoint(CGPoint imagePoint, size_t imageWidth, size_t imageHeight)
{
    if (imageWidth == 0 || imageHeight == 0) {
        return CGPointZero;
    }
    return CGPointMake(imagePoint.x / (double)imageWidth, imagePoint.y / (double)imageHeight);
}

@interface RevenantVisionPath : NSObject
- (instancetype)initWithPoints:(NSData *)points;
- (CGPathRef)path;
@end

@implementation RevenantVisionPath {
    CGMutablePathRef _path;
}

- (instancetype)initWithPoints:(NSData *)points
{
    if ((self = [super init])) {
        const simd_float2 *values = (const simd_float2 *)points.bytes;
        NSUInteger count = points.length / sizeof(simd_float2);
        _path = CGPathCreateMutable();
        for (NSUInteger i = 0; i < count; i++) {
            CGPoint point = CGPointMake(values[i].x, values[i].y);
            if (i == 0)
                CGPathMoveToPoint(_path, NULL, point.x, point.y);
            else
                CGPathAddLineToPoint(_path, NULL, point.x, point.y);
        }
        if (count > 0)
            CGPathCloseSubpath(_path);
    }
    return self;
}

- (CGPathRef)path
{
    return _path;
}

- (void)dealloc
{
    CGPathRelease(_path);
}

@end

@implementation VNContour {
    NSIndexPath *_indexPath;
    NSArray<VNContour *> *_childContours;
    NSData *_points;
    RevenantVisionPath *_path;
    float _aspectRatio;
}

- (instancetype)initRevenantWithIndexPath:(NSIndexPath *)indexPath points:(NSData *)points aspectRatio:(float)aspectRatio
{
    if ((self = [super init])) {
        _indexPath = indexPath;
        _childContours = @[];
        _points = [points copy];
        _path = [[RevenantVisionPath alloc] initWithPoints:_points];
        _aspectRatio = aspectRatio;
    }
    return self;
}

- (void)revenant_setChildContours:(NSArray<VNContour *> *)childContours
{
    _childContours = [childContours copy];
}

- (NSIndexPath *)indexPath
{
    return _indexPath;
}

- (NSInteger)pointCount
{
    return (NSInteger)(_points.length / sizeof(simd_float2));
}

- (const simd_float2 *)normalizedPoints
{
    return (const simd_float2 *)_points.bytes;
}

- (CGPathRef)normalizedPath
{
    return [_path path];
}

- (float)aspectRatio
{
    return _aspectRatio;
}

- (NSInteger)childContourCount
{
    return (NSInteger)_childContours.count;
}

- (NSArray<VNContour *> *)childContours
{
    return _childContours;
}

- (nullable VNContour *)childContourAtIndex:(NSUInteger)childContourIndex error:(NSError **)error
{
    if (childContourIndex >= _childContours.count) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidArgument, @"the contour has no child at that index");
        return nil;
    }
    return _childContours[childContourIndex];
}

- (nullable VNContour *)polygonApproximationWithEpsilon:(float)epsilon error:(NSError **)error
{
    NSInteger count = self.pointCount;
    const simd_float2 *values = self.normalizedPoints;
    if (count < 3) {
        return [[VNContour alloc] initRevenantWithIndexPath:_indexPath points:_points aspectRatio:_aspectRatio];
    }
    BOOL *keep = calloc((size_t)count, sizeof(BOOL));
    NSInteger *stack = malloc(sizeof(NSInteger) * (size_t)count * 2);
    NSInteger top = 0;
    keep[0] = keep[count - 1] = YES;
    stack[top++] = 0;
    stack[top++] = count - 1;
    while (top > 0) {
        NSInteger last = stack[--top], first = stack[--top];
        double bestDistance = -1;
        NSInteger bestIndex = -1;
        for (NSInteger i = first + 1; i < last; i++) {
            double ax = values[first].x, ay = values[first].y, bx = values[last].x, by = values[last].y;
            double dx = bx - ax, dy = by - ay, length = hypot(dx, dy);
            double distance = length > 0 ? fabs(dy * (values[i].x - ax) - dx * (values[i].y - ay)) / length
                                         : hypot(values[i].x - ax, values[i].y - ay);
            if (distance > bestDistance) {
                bestDistance = distance;
                bestIndex = i;
            }
        }
        if (bestIndex >= 0 && bestDistance > epsilon) {
            keep[bestIndex] = YES;
            stack[top++] = first;
            stack[top++] = bestIndex;
            stack[top++] = bestIndex;
            stack[top++] = last;
        }
    }
    NSMutableData *kept = [NSMutableData data];
    for (NSInteger i = 0; i < count; i++) {
        if (keep[i])
            [kept appendBytes:&values[i] length:sizeof(simd_float2)];
    }
    free(keep);
    free(stack);
    return [[VNContour alloc] initRevenantWithIndexPath:_indexPath points:kept aspectRatio:_aspectRatio];
}

@end

@implementation VNContoursObservation {
    NSArray<VNContour *> *_topLevelContours;
    NSArray<VNContour *> *_allContours;
    RevenantVisionPath *_path;
}

- (instancetype)initRevenantWithTopLevelContours:(NSArray<VNContour *> *)topLevelContours allContours:(NSArray<VNContour *> *)allContours
                                      normalizedPoints:(NSData *)points
{
    if ((self = [super init])) {
        _topLevelContours = [topLevelContours copy];
        _allContours = [allContours copy];
        _path = [[RevenantVisionPath alloc] initWithPoints:points];
    }
    return self;
}

- (NSInteger)contourCount
{
    return (NSInteger)_allContours.count;
}

- (NSInteger)topLevelContourCount
{
    return (NSInteger)_topLevelContours.count;
}

- (NSArray<VNContour *> *)topLevelContours
{
    return _topLevelContours;
}

- (CGPathRef)normalizedPath
{
    return [_path path];
}

- (nullable VNContour *)contourAtIndex:(NSInteger)contourIndex error:(NSError **)error
{
    if (contourIndex < 0 || (NSUInteger)contourIndex >= _allContours.count) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidArgument, @"the observation has no contour at that index");
        return nil;
    }
    return _allContours[(NSUInteger)contourIndex];
}

- (nullable VNContour *)contourAtIndexPath:(NSIndexPath *)indexPath error:(NSError **)error
{
    VNContour *contour = nil;
    if (indexPath.length > 0) {
        NSArray<VNContour *> *level = _topLevelContours;
        for (NSUInteger depth = 0; depth < indexPath.length; depth++) {
            NSUInteger index = [indexPath indexAtPosition:depth];
            if (index >= level.count) {
                level = nil;
                break;
            }
            contour = level[index];
            level = contour.childContours;
        }
    }
    if (contour == nil && error)
        *error = revenant_vision_error(VNErrorInvalidArgument, @"the observation has no contour at that index path");
    return contour;
}

@end

static uint8_t *revenant_contours_grey(id image, size_t wide, size_t high)
{
    uint8_t *grey = malloc(wide * high);
    if (grey == NULL)
        return NULL;
    if (CFGetTypeID((__bridge CFTypeRef)image) == CGImageGetTypeID()) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(grey, wide, high, 8, wide, space, kCGImageAlphaNone);
        CGColorSpaceRelease(space);
        if (context == NULL) {
            free(grey);
            return NULL;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, wide, high), (__bridge CGImageRef)image);
        CGContextRelease(context);
        return grey;
    }
    CVPixelBufferRef buffer = (__bridge CVPixelBufferRef)image;
    if (CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        free(grey);
        return NULL;
    }
    const uint8_t *bytes = CVPixelBufferGetBaseAddress(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    size_t sourceWide = CVPixelBufferGetWidth(buffer), sourceHigh = CVPixelBufferGetHeight(buffer);
    for (size_t y = 0; y < high; y++) {
        for (size_t x = 0; x < wide; x++) {
            const uint8_t *pixel = bytes + (y * sourceHigh / high) * stride + (x * sourceWide / wide) * 4;
            grey[y * wide + x] = (uint8_t)((pixel[0] * 114 + pixel[1] * 587 + pixel[2] * 299) / 1000);
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return grey;
}

@implementation VNDetectContoursRequest {
    float _contrastAdjustment;
    BOOL _detectsDarkOnLight;
    NSUInteger _maximumImageDimension;
    NSNumber *_contrastPivotValue;
}

@dynamic results;

+ (NSIndexSet *)supportedRevisions
{
    return [NSIndexSet indexSetWithIndex:1];
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _contrastAdjustment = 2;
        _detectsDarkOnLight = YES;
        _maximumImageDimension = 512;
    }
    return self;
}

- (float)contrastAdjustment
{
    return _contrastAdjustment;
}

- (void)setContrastAdjustment:(float)contrastAdjustment
{
    _contrastAdjustment = contrastAdjustment;
}

- (BOOL)detectsDarkOnLight
{
    return _detectsDarkOnLight;
}

- (void)setDetectsDarkOnLight:(BOOL)detectsDarkOnLight
{
    _detectsDarkOnLight = detectsDarkOnLight;
}

- (BOOL)detectDarkOnLight
{
    return _detectsDarkOnLight;
}

- (void)setDetectDarkOnLight:(BOOL)detectDarkOnLight
{
    _detectsDarkOnLight = detectDarkOnLight;
}

- (NSUInteger)maximumImageDimension
{
    return _maximumImageDimension;
}

- (void)setMaximumImageDimension:(NSUInteger)maximumImageDimension
{
    _maximumImageDimension = maximumImageDimension;
}

- (NSNumber *)revenant_contrastPivotValue
{
    return _contrastPivotValue;
}

- (void)revenant_setContrastPivotValue:(NSNumber *)value
{
    _contrastPivotValue = [value copy];
}

- (NSArray<VNContoursObservation *> *)revenant_observationsOnImage:(id)image error:(NSError **)error
{
    size_t wide = 0, high = 0;
    CFTypeID type = CFGetTypeID((__bridge CFTypeRef)image);
    if (type == CGImageGetTypeID()) {
        wide = CGImageGetWidth((__bridge CGImageRef)image);
        high = CGImageGetHeight((__bridge CGImageRef)image);
    } else {
        wide = CVPixelBufferGetWidth((__bridge CVPixelBufferRef)image);
        high = CVPixelBufferGetHeight((__bridge CVPixelBufferRef)image);
    }
    if (wide == 0 || high == 0) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidImage, @"the image has no pixels");
        return nil;
    }
    size_t largest = wide > high ? wide : high;
    if (largest > _maximumImageDimension && _maximumImageDimension > 0) {
        wide = wide * _maximumImageDimension / largest;
        high = high * _maximumImageDimension / largest;
        if (wide == 0) wide = 1;
        if (high == 0) high = 1;
    }
    uint8_t *grey = revenant_contours_grey(image, wide, high);
    if (grey == NULL) {
        if (error)
            *error = revenant_vision_error(VNErrorInvalidImage, @"the image could not be read");
        return nil;
    }
    double pivot = _contrastPivotValue ? _contrastPivotValue.doubleValue : 0.5;
    uint8_t *foreground = malloc(wide * high);
    for (size_t i = 0; i < wide * high; i++) {
        double value = (grey[i] / 255.0 - 0.5) * _contrastAdjustment + 0.5;
        foreground[i] = _detectsDarkOnLight ? value < pivot : value > pivot;
    }
    free(grey);
    int count = 0;
    revenant_contour *curves = revenant_contours_trace(foreground, (int)wide, (int)high, &count);
    free(foreground);

    float aspect = (float)wide / (float)high;
    NSMutableArray<NSMutableArray<NSNumber *> *> *children = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *roots = [NSMutableArray array];
    for (int i = 0; i < count; i++)
        [children addObject:[NSMutableArray array]];
    for (int i = 0; i < count; i++) {
        if (curves[i].parent < 0)
            [roots addObject:@(i)];
        else
            [children[curves[i].parent] addObject:@(i)];
    }
    NSComparator byPixel = ^NSComparisonResult(NSNumber *a, NSNumber *b) {
        const revenant_contour *ca = &curves[a.intValue], *cb = &curves[b.intValue];
        if (ca->sampleY != cb->sampleY)
            return ca->sampleY < cb->sampleY ? NSOrderedAscending : NSOrderedDescending;
        return ca->sampleX < cb->sampleX ? NSOrderedAscending : (ca->sampleX > cb->sampleX ? NSOrderedDescending : NSOrderedSame);
    };
    [roots sortUsingComparator:byPixel];
    for (NSMutableArray *list in children)
        [list sortUsingComparator:byPixel];

    NSMutableArray<VNContour *> *all = [NSMutableArray array];
    NSMutableArray<VNContour *> *top = [NSMutableArray array];
    NSMutableData *allPoints = [NSMutableData data];
    __block void (^build)(NSNumber *, NSIndexPath *, NSMutableArray<VNContour *> *);
    build = ^(NSNumber *index, NSIndexPath *path, NSMutableArray<VNContour *> *into) {
        const revenant_contour *c = &curves[index.intValue];
        NSMutableData *points = [NSMutableData dataWithLength:sizeof(simd_float2) * (NSUInteger)c->count];
        simd_float2 *values = (simd_float2 *)points.mutableBytes;
        for (int i = 0; i < c->count; i++) {
            double mx, my;
            revenant_contour_midpoint(c, i, &mx, &my);
            values[i].x = (float)(mx / (double)wide);
            values[i].y = (float)((high - my) / (double)high);
        }
        VNContour *contour = [[VNContour alloc] initRevenantWithIndexPath:path points:points aspectRatio:aspect];
        [into addObject:contour];
        [all addObject:contour];
        [allPoints appendData:points];
        NSMutableArray<VNContour *> *kids = [NSMutableArray array];
        NSUInteger position = 0;
        for (NSNumber *child in children[index.intValue]) {
            build(child, [path indexPathByAddingIndex:position++], kids);
        }
        [contour revenant_setChildContours:kids];
    };
    NSUInteger root = 0;
    for (NSNumber *index in roots)
        build(index, [NSIndexPath indexPathWithIndex:root++], top);
    free(curves);
    VNContoursObservation *observation = [[VNContoursObservation alloc] initRevenantWithTopLevelContours:top allContours:all normalizedPoints:allPoints];
    return @[observation];
}

@end
