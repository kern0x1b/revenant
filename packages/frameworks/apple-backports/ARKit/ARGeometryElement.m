#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARGeometryElement

@synthesize buffer = _buffer;
@synthesize count = _count;
@synthesize bytesPerIndex = _bytesPerIndex;
@synthesize primitiveType = _primitiveType;

- (NSInteger)indexCountPerPrimitive
{
    switch (_primitiveType) {
        case ARGeometryPrimitiveTypeLine: return 2;
        case ARGeometryPrimitiveTypeTriangle: return 3;
    }
    return 0;
}

@end

NS_ASSUME_NONNULL_END
