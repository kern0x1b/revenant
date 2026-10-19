#import "CharonSCN.h"

@implementation SCNGeometrySource

+ (instancetype)geometrySourceWithData:(NSData *)data
                               semantic:(SCNGeometrySourceSemantic)semantic
                            vectorCount:(NSInteger)vectorCount
                        floatComponents:(BOOL)floatComponents
                    componentsPerVector:(NSInteger)componentsPerVector
                      bytesPerComponent:(NSInteger)bytesPerComponent
                             dataOffset:(NSInteger)offset
                             dataStride:(NSInteger)stride
{
    SCNGeometrySource *source = [[self alloc] init];
    source->_data = [data copy];
    source->_semantic = semantic;
    source->_vectorCount = vectorCount;
    source->_floatComponents = floatComponents;
    source->_componentsPerVector = componentsPerVector;
    source->_bytesPerComponent = bytesPerComponent;
    source->_dataOffset = offset;
    source->_dataStride = stride;
    return source;
}

@synthesize data = _data;
@synthesize semantic = _semantic;
@synthesize vectorCount = _vectorCount;
@synthesize floatComponents = _floatComponents;
@synthesize componentsPerVector = _componentsPerVector;
@synthesize bytesPerComponent = _bytesPerComponent;
@synthesize dataOffset = _dataOffset;
@synthesize dataStride = _dataStride;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _data = [coder decodeObjectOfClass:[NSData class] forKey:@"data"];
        _semantic = [coder decodeObjectOfClass:[NSString class] forKey:@"semantic"];
        _vectorCount = [coder decodeIntegerForKey:@"vectorCount"];
        _floatComponents = [CharonSCNCoding decodeBool:coder forKey:@"floatComponents" default:YES];
        _componentsPerVector = [coder decodeIntegerForKey:@"componentsPerVector"];
        _bytesPerComponent = [coder decodeIntegerForKey:@"bytesPerComponent"];
        _dataOffset = [coder decodeIntegerForKey:@"dataOffset"];
        _dataStride = [coder decodeIntegerForKey:@"dataStride"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_data forKey:@"data"];
    [coder encodeObject:_semantic forKey:@"semantic"];
    [coder encodeInteger:_vectorCount forKey:@"vectorCount"];
    [coder encodeBool:_floatComponents forKey:@"floatComponents"];
    [coder encodeInteger:_componentsPerVector forKey:@"componentsPerVector"];
    [coder encodeInteger:_bytesPerComponent forKey:@"bytesPerComponent"];
    [coder encodeInteger:_dataOffset forKey:@"dataOffset"];
    [coder encodeInteger:_dataStride forKey:@"dataStride"];
}

@end
