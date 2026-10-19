#import "RevenantMPSGraph.h"

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
    return RevenantMPSGraphElementCount(_shape);
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
