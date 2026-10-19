#import "RevenantAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

@implementation PHASEEnvelopeSegment {
    simd_double2 _revenant_endPoint;
    PHASECurveType _revenant_curveType;
}

- (instancetype)initWithEndPoint:(simd_double2)endPoint curveType:(PHASECurveType)curveType
{
    if ((self = [super init])) {
        _revenant_endPoint = endPoint;
        _revenant_curveType = curveType;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithEndPoint:simd_make_double2(0.0, 0.0) curveType:PHASECurveTypeLinear];
}

- (simd_double2)endPoint
{
    return _revenant_endPoint;
}

- (void)setEndPoint:(simd_double2)endPoint
{
    _revenant_endPoint = endPoint;
}

- (PHASECurveType)curveType
{
    return _revenant_curveType;
}

- (void)setCurveType:(PHASECurveType)curveType
{
    _revenant_curveType = curveType;
}

@end
