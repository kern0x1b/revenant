#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

// PHASEEnvelope: a segmented envelope, and the one place PHASE evaluates a curve of its own.
//
// The envelope is a start point and an ordered list of segments, each of which the header says carries
// no start point of its own (PHASEEnvelope.h:58-62): the segments join end to end and stay continuous along the x
// and y axes, so they partition the domain, and the value at a point is
// the start point, or one segment's linear or curved run out of the previous one's end.
//
// evaluateForValue: maps a domain value onto the range by finding the segment whose x extent holds it
// and applying that segment's curve across it. The curves are the eleven cases of PHASECurveType, and
// each is a closed form from its own name: the powers are t^n and 1-(1-t)^n, the trigonometry is
// sin(t*pi/2) and 1-cos(t*pi/2), the logistics are a logistic in t normalised onto [0, 1], and the two
// steps are the values their names say.

@implementation PHASEEnvelope {
    simd_double2 _charon_startPoint;
    NSArray<PHASEEnvelopeSegment *> *_charon_segments;
    PHASENumericPair *_charon_domain;
    PHASENumericPair *_charon_range;
}

// The eleven cases as a closed form, t in [0, 1] across the segment.
static double CharonCurve(PHASECurveType type, double t)
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
            // The header names this "Sigmoid" and says nothing about its shape, so the shape was
            // measured rather than assumed: the host's own PHASEEnvelope at t = 0, 0.125, 0.25, 0.5,
            // 0.75, 0.875 and 1 gives 0, 0.038060234, 0.146446609, 0.5, 0.853553391, 0.961939766, 1 -
            // which is exactly (1 - cos(pi*t)) / 2 at every one of them. It is not a logistic: fitting
            // a logistic to the same numbers gives a different sharpness at t = 0.25 and at t = 0.125,
            // which is how the two were told apart. So it is a raised cosine, and it is written as
            // one.
            return (1.0 - cos(M_PI * t)) / 2.0;
        case PHASECurveTypeInverseSigmoid:
            // Measured the same way: 0, 0.191341716, 0.353553391, 0.5, 0.646446609, 0.808658284, 1,
            // which is a half sine on the first half of the segment and its mirror on the second.
            return t <= 0.5 ? 0.5 * sin(M_PI * t) : 1.0 - 0.5 * sin(M_PI * (1.0 - t));
        case PHASECurveTypeHoldStartValue:
            return 0.0;
        case PHASECurveTypeJumpToEndValue:
            return 1.0;
    }
    return t;
}

// -init and +new are NS_UNAVAILABLE (PHASEEnvelope.h:107-108), and the host answers them by raising, not by
// making an envelope: on macOS [[PHASEEnvelope alloc] init] and [PHASEEnvelope new] both raise
// NSInvalidArgumentException "unrecognized selector sent to instance" (and "to class"), while respondsToSelector:
// still answers yes. NSObject's own -init would return an empty envelope here, so the port says what the host says.
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
        _charon_startPoint = startPoint;
        _charon_segments = [segments copy] ?: @[];
        // The domain and the range are the envelope's own extent: the first is from the start point's
        // x to the last segment's end point x, the second the same in y. An envelope with no segment
        // is a point, and both extents are that point.
        double firstX = startPoint.x, lastX = startPoint.x;
        double firstY = startPoint.y, lastY = startPoint.y;
        for (PHASEEnvelopeSegment *segment in _charon_segments) {
            lastX = segment.endPoint.x;
            lastY = segment.endPoint.y;
        }
        _charon_domain = [[PHASENumericPair alloc] initWithFirstValue:firstX secondValue:lastX];
        _charon_range = [[PHASENumericPair alloc] initWithFirstValue:firstY secondValue:lastY];
    }
    return self;
}

- (double)evaluateForValue:(double)x
{
    // The start point holds every value before the first segment, and the last end point every value
    // after the last, which is what "guarantee continuity" means at the ends: the envelope is defined
    // outside its domain by its own end values rather than by an extrapolation nobody asked for.
    double xStart = _charon_startPoint.x;
    double y = _charon_startPoint.y;
    for (PHASEEnvelopeSegment *segment in _charon_segments) {
        double xEnd = segment.endPoint.x;
        if (x < xStart) {
            break;                      // before this segment: the start value holds
        }
        if (x > xEnd) {
            y = segment.endPoint.y;     // past this segment: its end value holds
            xStart = xEnd;
            continue;
        }
        double span = xEnd - xStart;
        double t = span > 0 ? (x - xStart) / span : 1.0;
        double from = y;
        return from + (segment.endPoint.y - from) * CharonCurve(segment.curveType, t);
    }
    return y;
}

- (simd_double2)startPoint
{
    return _charon_startPoint;
}

- (NSArray<PHASEEnvelopeSegment *> *)segments
{
    return [_charon_segments copy];
}

- (PHASENumericPair *)domain
{
    return _charon_domain;
}

- (PHASENumericPair *)range
{
    return _charon_range;
}

@end
