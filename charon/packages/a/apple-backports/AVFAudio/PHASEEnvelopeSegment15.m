#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

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
