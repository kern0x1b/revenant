#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

// PHASEEnvelopeSegment: one segment of a segmented envelope, an end point and a curve type.
//
// The header (PHASEEnvelope.h:58-62) is explicit that a segment carries no start point of its own, because
// the segments join end to end and stay continuous in both x and y directions. Continuity is the whole design, and it is why the curve type is
// what distinguishes a straight run from a curved one *within* the segment: the segment's start is the
// previous segment's end, and nothing here can disagree with it because nothing here knows it.
//
// PHASE arrived in iOS 15 and the port's releases are 6.1.3 and 4.3, so there is no PHASE.framework on
// either and this is the value the header documents rather than a translation of a class that exists.

@implementation PHASEEnvelopeSegment {
    simd_double2 _charon_endPoint;
    PHASECurveType _charon_curveType;
}

- (instancetype)initWithEndPoint:(simd_double2)endPoint curveType:(PHASECurveType)curveType
{
    if ((self = [super init])) {
        _charon_endPoint = endPoint;
        _charon_curveType = curveType;
    }
    return self;
}

- (instancetype)init
{
    // The header's own defaults, which the accessors state: the end point is [0.0, 0.0] and the
    // curve type is PHASECurveTypeLinear. A zeroed end point is a real point here, not the absence of
    // one, so nothing here is a sentinel.
    return [self initWithEndPoint:simd_make_double2(0.0, 0.0) curveType:PHASECurveTypeLinear];
}

- (simd_double2)endPoint
{
    return _charon_endPoint;
}

- (void)setEndPoint:(simd_double2)endPoint
{
    _charon_endPoint = endPoint;
}

- (PHASECurveType)curveType
{
    return _charon_curveType;
}

- (void)setCurveType:(PHASECurveType)curveType
{
    _charon_curveType = curveType;
}

@end
