#import <ModelIO/ModelIO.h>
#import <ModelIO/MDLValueTypes.h>
#import <simd/simd.h>

// A flat array of matrices, one of the four MDLAnimated*Array shapes. It is not the animated value:
// an MDLAnimatedMatrix4x4 carries a time per sample and interpolates between samples, while this one
// carries `elementCount` matrices and nothing else, and its header gives it no time at all. So the
// storage here is the matrices themselves, in the precision the last set named, and the count is the
// number of them.
//
// The header gives neither setter a document, so the shape is the one the selectors themselves name
// and the one an MDLAnimatedScalarArray of the same family answers with: setFloat4x4Array:count:
// REPLACES the contents with the count matrices given (which is what makes elementCount move), and
// getFloat4x4Array:maxCount: copies at most maxCount of them out and answers how many it copied. A
// caller that never sets reads zeros, which is what a buffer of that many matrices holds.

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

// The room the array needs for count matrices in the precision it now holds, keeping what is already
// there: a set of fewer matrices than the array has keeps the larger count, and a set of more grows it.
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
