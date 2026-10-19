// MPSGraphShapedType, from the header of MPSGraphCore.h in the SDK of iOS 16.4: a shape and a data type,
// which is what every tensor in a graph carries.

#import "CharonMPSGraph.h"

@implementation MPSGraphShapedType {
    NSArray<NSNumber *> *_shape;
    NSArray<NSNumber *> *_strides;
    NSUInteger _offset;
    MPSDataType _dataType;
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape dataType:(MPSDataType)dataType
{
    if ((self = [super init])) {
        _shape = [shape copy];
        _dataType = dataType;
    }
    return self;
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                      strides:(NSArray<NSNumber *> *)strides
                     dataType:(MPSDataType)dataType
{
    // The strides are how a caller names a window of a larger buffer, which is what the run methods
    // below take; the shape and the data type are the whole of what a shaped type answers, so the
    // strides are kept only to be read back.
    if ((self = [self initWithShape:shape dataType:dataType])) {
        _strides = [strides copy];
    }
    return self;
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

- (void)setShape:(NSArray<NSNumber *> *)shape
{
    _shape = [shape copy];
}

- (MPSDataType)dataType
{
    return _dataType;
}

- (void)setDataType:(MPSDataType)dataType
{
    _dataType = dataType;
}

- (NSUInteger)rank
{
    return _shape.count;
}

- (NSUInteger)elementCount
{
    return CharonMPSGraphElementCount(_shape);
}

- (NSUInteger)offset
{
    return _offset;
}

- (BOOL)isEmpty
{
    return _shape == nil;
}

- (BOOL)isEqualTo:(MPSGraphShapedType *)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[MPSGraphShapedType class]])
        return NO;
    // A nil shape and an empty one are the same shape: both say "however the caller reads it", which
    // is what a placeholder whose shape is not known until it is fed comes to.
    NSUInteger mine = _shape.count, theirs = object.shape.count;
    if (mine != theirs)
        return NO;
    for (NSUInteger i = 0; i < mine; i++)
        if (_shape[i].unsignedIntegerValue != object.shape[i].unsignedIntegerValue)
            return NO;
    return _dataType == object.dataType;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)_dataType;
    for (NSNumber *dimension in _shape)
        hash = hash * 31 + dimension.unsignedIntegerValue;
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSGraphShapedType *copy = [[[self class] allocWithZone:zone] initWithShape:_shape dataType:_dataType];
    copy->_strides = _strides;
    copy->_offset = _offset;
    return copy;
}

@end
