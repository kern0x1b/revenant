#import "RevenantMPS.h"


@implementation MPSMatrixBinaryKernel {
    MTLOrigin _primarySourceMatrixOrigin, _secondarySourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _primarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _secondarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
        _batchStart = 0;
        _batchSize = 0;
    }
    return self;
}

- (MTLOrigin)primarySourceMatrixOrigin
{
    return _primarySourceMatrixOrigin;
}

- (void)setPrimarySourceMatrixOrigin:(MTLOrigin)origin
{
    _primarySourceMatrixOrigin = origin;
}

- (MTLOrigin)secondarySourceMatrixOrigin
{
    return _secondarySourceMatrixOrigin;
}

- (void)setSecondarySourceMatrixOrigin:(MTLOrigin)origin
{
    _secondarySourceMatrixOrigin = origin;
}

- (MTLOrigin)resultMatrixOrigin
{
    return _resultMatrixOrigin;
}

- (void)setResultMatrixOrigin:(MTLOrigin)origin
{
    _resultMatrixOrigin = origin;
}

- (NSUInteger)batchStart
{
    return _batchStart;
}

- (void)setBatchStart:(NSUInteger)batchStart
{
    _batchStart = batchStart;
}

- (NSUInteger)batchSize
{
    return _batchSize;
}

- (void)setBatchSize:(NSUInteger)batchSize
{
    _batchSize = batchSize;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _primarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _secondarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
    }
    return self;
}

@end
