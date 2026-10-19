// MPSVectorDescriptor, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSVectorDescriptor {
    NSUInteger _length, _vectors, _vectorBytes;
    MPSDataType _dataType;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _dataType = MPSDataTypeInvalid;
    }
    return self;
}

+ (instancetype)vectorDescriptorWithLength:(NSUInteger)length dataType:(MPSDataType)dataType
{
    return [self vectorDescriptorWithLength:length vectors:1 vectorBytes:CharonMPSRowBytesForColumns(length, dataType) dataType:dataType];
}

+ (instancetype)vectorDescriptorWithLength:(NSUInteger)length vectors:(NSUInteger)vectors vectorBytes:(NSUInteger)vectorBytes dataType:(MPSDataType)dataType
{
    MPSVectorDescriptor *descriptor = [[self alloc] init];
    descriptor.length = length;
    descriptor.dataType = dataType;
    descriptor->_vectors = vectors;
    descriptor->_vectorBytes = vectorBytes;
    return descriptor;
}

+ (size_t)vectorBytesForLength:(NSUInteger)length dataType:(MPSDataType)dataType
{
    return CharonMPSRowBytesForColumns(length, dataType);
}

- (NSUInteger)length
{
    return _length;
}

- (void)setLength:(NSUInteger)length
{
    _length = length;
}

- (NSUInteger)vectors
{
    return _vectors;
}

- (NSUInteger)vectorBytes
{
    return _vectorBytes;
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
