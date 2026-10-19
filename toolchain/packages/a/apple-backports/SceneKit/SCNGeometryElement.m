#import "CharonSCN.h"

@implementation SCNGeometryElement

+ (instancetype)geometryElementWithData:(NSData *)data
                           primitiveType:(SCNGeometryPrimitiveType)primitiveType
                          primitiveCount:(NSInteger)primitiveCount
                           bytesPerIndex:(NSInteger)bytesPerIndex
{
    SCNGeometryElement *element = [[self alloc] init];
    element->_data = [data copy];
    element->_primitiveType = primitiveType;
    element->_primitiveCount = primitiveCount;
    element->_bytesPerIndex = bytesPerIndex;
    return element;
}

@synthesize data = _data;
@synthesize primitiveType = _primitiveType;
@synthesize primitiveCount = _primitiveCount;
@synthesize bytesPerIndex = _bytesPerIndex;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _data = [coder decodeObjectOfClass:[NSData class] forKey:@"elementData"];
        _primitiveType = [coder decodeIntegerForKey:@"primitiveType"];
        _primitiveCount = [coder decodeIntegerForKey:@"primitiveCount"];
        _bytesPerIndex = [coder containsValueForKey:@"bytesPerIndex"] ? [coder decodeIntegerForKey:@"bytesPerIndex"] : 2;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_data forKey:@"elementData"];
    [coder encodeInteger:_primitiveType forKey:@"primitiveType"];
    [coder encodeInteger:_primitiveCount forKey:@"primitiveCount"];
    [coder encodeInteger:_bytesPerIndex forKey:@"bytesPerIndex"];
}

@end
