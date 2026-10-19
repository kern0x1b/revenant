#import "RevenantAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

@implementation PHASEEnvelope {
    simd_double2 _revenant_startPoint;
    NSArray<PHASEEnvelopeSegment *> *_revenant_segments;
    PHASENumericPair *_revenant_domain;
    PHASENumericPair *_revenant_range;
}

static double RevenantCurve(PHASECurveType type, double t)
{
    switch (type) {
        case PHASECurveTypeLinear:
            return t;
        case PHASECurveTypeSquared:
            return t * t;
        case PHASECurveTypeInverseSquared:
            return 1.0 - (1.0 - t) * (1.0 - t);
        case PHASECurveTypeCubed:
            return t * t * t;
        case PHASECurveTypeInverseCubed:
            double cube = 1.0 - t;
            return 1.0 - cube * cube * cube;
        case PHASECurveTypeSine:
            return sin(t * M_PI_2);
        case PHASECurveTypeInverseSine:
            return 1.0 - cos(t * M_PI_2);
        case PHASECurveTypeSigmoid:
            return (1.0 - cos(M_PI * t)) / 2.0;
        case PHASECurveTypeInverseSigmoid:
            return t <= 0.5 ? 0.5 * sin(M_PI * t) : 1.0 - 0.5 * sin(M_PI * (1.0 - t));
        case PHASECurveTypeHoldStartValue:
            return 0.0;
        case PHASECurveTypeJumpToEndValue:
            return 1.0;
    }
    return t;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (instancetype)new
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithStartPoint:(simd_double2)startPoint segments:(NSArray<PHASEEnvelopeSegment *> *)segments
{
    if ((self = [super init])) {
        _revenant_startPoint = startPoint;
        _revenant_segments = [segments copy] ?: @[];
        double firstX = startPoint.x, lastX = startPoint.x;
        double firstY = startPoint.y, lastY = startPoint.y;
        for (PHASEEnvelopeSegment *segment in _revenant_segments) {
            lastX = segment.endPoint.x;
            lastY = segment.endPoint.y;
        }
        _revenant_domain = [[PHASENumericPair alloc] initWithFirstValue:firstX secondValue:lastX];
        _revenant_range = [[PHASENumericPair alloc] initWithFirstValue:firstY secondValue:lastY];
    }
    return self;
}

- (double)evaluateForValue:(double)x
{
    double xStart = _revenant_startPoint.x;
    double y = _revenant_startPoint.y;
    for (PHASEEnvelopeSegment *segment in _revenant_segments) {
        double xEnd = segment.endPoint.x;
        if (x < xStart) {
            break;
        }
        if (x > xEnd) {
            y = segment.endPoint.y;
            xStart = xEnd;
            continue;
        }
        double span = xEnd - xStart;
        double t = span > 0 ? (x - xStart) / span : 1.0;
        double from = y;
        return from + (segment.endPoint.y - from) * RevenantCurve(segment.curveType, t);
    }
    return y;
}

- (simd_double2)startPoint
{
    return _revenant_startPoint;
}

- (NSArray<PHASEEnvelopeSegment *> *)segments
{
    return [_revenant_segments copy];
}

- (PHASENumericPair *)domain
{
    return _revenant_domain;
}

- (PHASENumericPair *)range
{
    return _revenant_range;
}

@end
