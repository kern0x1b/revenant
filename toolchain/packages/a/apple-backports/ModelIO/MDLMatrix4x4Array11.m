#import <ModelIO/ModelIO.h>
#import <ModelIO/MDLValueTypes.h>
#import <simd/simd.h>

@implementation MDLMatrix4x4Array {
    NSUInteger _elementCount;
    NSMutableData *_storage;
    BOOL _doublePrecision;
}

- (instancetype)initWithElementCount:(NSUInteger)arrayElementCount
{
    if ((self = [super init])) {
        _doublePrecision = NO;
        _elementCount = arrayElementCount;
        _storage = [NSMutableData dataWithLength:arrayElementCount * sizeof(matrix_float4x4)];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithElementCount:0];
}

- (void)dealloc
{
}

- (NSUInteger)elementCount
{
    return _elementCount;
}

- (MDLDataPrecision)precision
{
    return _doublePrecision ? MDLDataPrecisionDouble : MDLDataPrecisionFloat;
}

- (void)clear
{
    _elementCount = 0;
}

- (void)charon_reserve:(NSUInteger)count
{
    NSUInteger width = _doublePrecision ? sizeof(matrix_double4x4) : sizeof(matrix_float4x4);
    if (_storage.length < count * width) {
        _storage.length = count * width;
    }
    _elementCount = count;
}

- (void)setFloat4x4Array:(const matrix_float4x4 *)valuesArray count:(NSUInteger)count
{
    _doublePrecision = NO;
    [self charon_reserve:count];
    if (valuesArray && count)
        [_storage replaceBytesInRange:NSMakeRange(0, count * sizeof(matrix_float4x4))
                            withBytes:valuesArray
                               length:count * sizeof(matrix_float4x4)];
}

- (void)setDouble4x4Array:(const matrix_double4x4 *)valuesArray count:(NSUInteger)count
{
    _doublePrecision = YES;
    [self charon_reserve:count];
    if (valuesArray && count)
        [_storage replaceBytesInRange:NSMakeRange(0, count * sizeof(matrix_double4x4))
                            withBytes:valuesArray
                               length:count * sizeof(matrix_double4x4)];
}

- (NSUInteger)getFloat4x4Array:(matrix_float4x4 *)valuesArray maxCount:(NSUInteger)maxCount
{
    NSUInteger count = _elementCount < maxCount ? _elementCount : maxCount;
    if (valuesArray && count)
        memcpy(valuesArray, _storage.mutableBytes, count * sizeof(matrix_float4x4));
    return count;
}

- (NSUInteger)getDouble4x4Array:(matrix_double4x4 *)valuesArray maxCount:(NSUInteger)maxCount
{
    NSUInteger count = _elementCount < maxCount ? _elementCount : maxCount;
    if (valuesArray && count)
        memcpy(valuesArray, _storage.mutableBytes, count * sizeof(matrix_double4x4));
    return count;
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLMatrix4x4Array *copy = [[[self class] allocWithZone:zone] initWithElementCount:0];
    copy->_doublePrecision = _doublePrecision;
    copy->_storage = [_storage mutableCopy];
    copy->_elementCount = _elementCount;
    return copy;
}

@end
