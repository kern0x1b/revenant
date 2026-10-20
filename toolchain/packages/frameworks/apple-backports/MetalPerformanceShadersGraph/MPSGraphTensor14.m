#import "RevenantMPSGraph.h"

@implementation MPSGraphTensor {
    NSArray<NSNumber *> *_shape;
    MPSDataType _dataType;
    MPSGraphOperation *_operation;
    NSUInteger _index;
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                    dataType:(MPSDataType)dataType
                   operation:(MPSGraphOperation *)operation
                       index:(NSUInteger)index
{
    if ((self = [super init])) {
        _shape = [shape copy];
        _dataType = dataType;
        _operation = operation;
        _index = index;
    }
    return self;
}

- (instancetype)init
{
    NSLog(@"MPSGraphTensor: -init makes a tensor of no shape and no operation; make one through MPSGraph's placeholder, constant or operation methods");
    return nil;
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

- (MPSDataType)dataType
{
    return _dataType;
}

- (void)revenant_mps_setShape:(NSArray<NSNumber *> *)shape
{
    _shape = [shape copy];
}

- (MPSGraphOperation *)operation
{
    return _operation;
}

- (NSUInteger)revenant_mps_index
{
    return _index;
}

- (NSUInteger)revenant_mps_elementCount
{
    return RevenantMPSGraphElementCount(_shape);
}

- (MPSGraphDevice *)device
{
    return [_operation graph].revenant_mps_device;
}

- (BOOL)isEqualToTensor:(MPSGraphTensor *)tensor
{
    if (self == tensor)
        return YES;
    if (![tensor isKindOfClass:[MPSGraphTensor class]])
        return NO;
    return _operation == tensor.operation && _index == tensor.revenant_mps_index;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
