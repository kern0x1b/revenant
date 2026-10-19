#import "CharonMPS.h"


@implementation MPSMatrixDescriptor {
    NSUInteger _rows, _columns, _matrices, _rowBytes, _matrixBytes;
    MPSDataType _dataType;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _dataType = MPSDataTypeInvalid;
    }
    return self;
}

+ (instancetype)matrixDescriptorWithDimensions:(NSUInteger)rows columns:(NSUInteger)columns rowBytes:(NSUInteger)rowBytes dataType:(MPSDataType)dataType
{
    return [self matrixDescriptorWithRows:rows columns:columns rowBytes:rowBytes dataType:dataType];
}

+ (instancetype)matrixDescriptorWithRows:(NSUInteger)rows columns:(NSUInteger)columns rowBytes:(NSUInteger)rowBytes dataType:(MPSDataType)dataType
{
    MPSMatrixDescriptor *descriptor = [[self alloc] init];
    descriptor.rows = rows;
    descriptor.columns = columns;
    descriptor.rowBytes = rowBytes;
    descriptor.dataType = dataType;
    descriptor->_matrices = 1;
    descriptor->_matrixBytes = rows * rowBytes;
    return descriptor;
}

+ (instancetype)matrixDescriptorWithRows:(NSUInteger)rows columns:(NSUInteger)columns matrices:(NSUInteger)matrices rowBytes:(NSUInteger)rowBytes matrixBytes:(NSUInteger)matrixBytes dataType:(MPSDataType)dataType
{
    MPSMatrixDescriptor *descriptor = [self matrixDescriptorWithRows:rows columns:columns rowBytes:rowBytes dataType:dataType];
    descriptor->_matrices = matrices;
    descriptor->_matrixBytes = matrixBytes;
    return descriptor;
}

+ (size_t)rowBytesFromColumns:(NSUInteger)columns dataType:(MPSDataType)dataType
{
    return CharonMPSRowBytesForColumns(columns, dataType);
}

+ (size_t)rowBytesForColumns:(NSUInteger)columns dataType:(MPSDataType)dataType
{
    return CharonMPSRowBytesForColumns(columns, dataType);
}

- (NSUInteger)rows
{
    return _rows;
}

- (void)setRows:(NSUInteger)rows
{
    _rows = rows;
}

- (NSUInteger)columns
{
    return _columns;
}

- (void)setColumns:(NSUInteger)columns
{
    _columns = columns;
}

- (NSUInteger)matrices
{
    return _matrices;
}

- (NSUInteger)rowBytes
{
    return _rowBytes;
}

- (void)setRowBytes:(NSUInteger)rowBytes
{
    _rowBytes = rowBytes;
}

- (NSUInteger)matrixBytes
{
    return _matrixBytes;
}

- (MPSDataType)dataType
{
    return _dataType;
}

- (void)setDataType:(MPSDataType)dataType
{
    _dataType = dataType;
}

@end
