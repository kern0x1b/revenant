// MPSGraphTensor, from the header of MPSGraphTensor.h in the SDK of iOS 16.4: a shape, a data type and
// the operation that produces it. The root is MPSGraphObject, which is what the 26.2 headers give it and
// what the 16.4 SDK this package compiles against predates.

#import "CharonMPSGraph.h"

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
    // The header marks it unavailable: a tensor with no shape, no data type and no operation is not a
    // tensor, it is nothing. Said here rather than left to a caller that finds out at run time.
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

- (void)charon_mps_setShape:(NSArray<NSNumber *> *)shape
{
    // Only an operation whose shape is the caller's to feed - a broadcast into a shape that is fed, a flatten
    // along an axis that is fed, a squeeze of a set of axes that is fed - has its shape decided when the
    // graph runs and not when it is built, and then this is where the walk puts it. It says nothing about
    // the tensor's element count, which is a function of the shape.
    _shape = [shape copy];
}

- (MPSGraphOperation *)operation
{
    return _operation;
}

- (NSUInteger)charon_mps_index
{
    return _index;
}

- (NSUInteger)charon_mps_elementCount
{
    return CharonMPSGraphElementCount(_shape);
}

// The device a tensor's values live on. MPSGraphTensor has no -device in the iPhoneOS 16.4 SDK this
// package compiles against, so it is answered from the graph: a tensor made by an operation takes the
// device of the graph that operation is in, and a placeholder - whose operation is the graph's own
// placeholder operation - takes the graph's device too.
- (MPSGraphDevice *)device
{
    return [_operation graph].charon_mps_device;
}

- (BOOL)isEqualToTensor:(MPSGraphTensor *)tensor
{
    // A tensor is identified by the operation that produced it and which of that operation's outputs it
    // is: two tensors of the same shape and data type from different operations are different tensors,
    // and the same output of the same operation is the same tensor however it was reached.
    if (self == tensor)
        return YES;
    if (![tensor isKindOfClass:[MPSGraphTensor class]])
        return NO;
    return _operation == tensor.operation && _index == tensor.charon_mps_index;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
