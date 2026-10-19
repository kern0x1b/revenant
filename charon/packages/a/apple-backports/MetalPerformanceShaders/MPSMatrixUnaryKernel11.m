// MPSMatrixUnaryKernel, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixUnaryKernel {
    MTLOrigin _sourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _sourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
        _batchStart = 0;
        _batchSize = 0;
    }
    return self;
}

- (MTLOrigin)sourceMatrixOrigin
{
    return _sourceMatrixOrigin;
}

- (void)setSourceMatrixOrigin:(MTLOrigin)origin
{
    _sourceMatrixOrigin = origin;
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
        _sourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
    }
    return self;
}

@end
