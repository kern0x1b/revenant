#import "RevenantSCN.h"

@implementation SCNPlane

- (instancetype)init
{
    if ((self = [super init])) {
        _width = 1;
        _height = 1;
        _widthSegmentCount = 1;
        _heightSegmentCount = 1;
        _cornerRadius = 0;
        _cornerSegmentCount = 10;
    }
    return self;
}

+ (instancetype)planeWithWidth:(CGFloat)width height:(CGFloat)height
{
    SCNPlane *plane = [[self alloc] init];
    plane->_width = width;
    plane->_height = height;
    return plane;
}

@synthesize width = _width;
@synthesize height = _height;
@synthesize widthSegmentCount = _widthSegmentCount;
@synthesize heightSegmentCount = _heightSegmentCount;
@synthesize cornerRadius = _cornerRadius;
@synthesize cornerSegmentCount = _cornerSegmentCount;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _width = [coder containsValueForKey:@"width"] ? [coder decodeDoubleForKey:@"width"] : 1;
        _height = [coder containsValueForKey:@"height"] ? [coder decodeDoubleForKey:@"height"] : 1;
        _widthSegmentCount = [coder containsValueForKey:@"widthSegmentCount"] ? [coder decodeIntegerForKey:@"widthSegmentCount"] : 1;
        _heightSegmentCount = [coder containsValueForKey:@"heightSegmentCount"] ? [coder decodeIntegerForKey:@"heightSegmentCount"] : 1;
        _cornerRadius = [coder decodeDoubleForKey:@"cornerRadius"];
        _cornerSegmentCount = [coder containsValueForKey:@"cornerSegmentCount"] ? [coder decodeIntegerForKey:@"cornerSegmentCount"] : 10;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_width forKey:@"width"];
    [coder encodeDouble:_height forKey:@"height"];
    [coder encodeInteger:_widthSegmentCount forKey:@"widthSegmentCount"];
    [coder encodeInteger:_heightSegmentCount forKey:@"heightSegmentCount"];
    [coder encodeDouble:_cornerRadius forKey:@"cornerRadius"];
    [coder encodeInteger:_cornerSegmentCount forKey:@"cornerSegmentCount"];
}

- (NSArray<SCNGeometrySource *> *)revenantSources
{
    NSUInteger columns = MAX(1, _widthSegmentCount) + 1;
    NSUInteger rows = MAX(1, _heightSegmentCount) + 1;
    NSUInteger count = columns * rows;
    NSMutableData *positions = [NSMutableData dataWithLength:count * 3 * sizeof(float)];
    NSMutableData *normals = [NSMutableData dataWithLength:count * 3 * sizeof(float)];
    NSMutableData *uvs = [NSMutableData dataWithLength:count * 2 * sizeof(float)];
    float *p = positions.mutableBytes;
    float *n = normals.mutableBytes;
    float *t = uvs.mutableBytes;
    for (NSUInteger row = 0; row < rows; row++) {
        for (NSUInteger column = 0; column < columns; column++) {
            NSUInteger index = row * columns + column;
            double u = (double)column / (columns - 1);
            double v = (double)row / (rows - 1);
            p[index * 3 + 0] = (float)((u - 0.5) * _width);
            p[index * 3 + 1] = (float)((0.5 - v) * _height);
            p[index * 3 + 2] = 0;
            n[index * 3 + 0] = 0;
            n[index * 3 + 1] = 0;
            n[index * 3 + 2] = 1;
            t[index * 2 + 0] = (float)u;
            t[index * 2 + 1] = (float)v;
        }
    }
    return @[
        [SCNGeometrySource geometrySourceWithData:positions semantic:SCNGeometrySourceSemanticVertex vectorCount:count floatComponents:YES componentsPerVector:3 bytesPerComponent:sizeof(float) dataOffset:0 dataStride:3 * sizeof(float)],
        [SCNGeometrySource geometrySourceWithData:normals semantic:SCNGeometrySourceSemanticNormal vectorCount:count floatComponents:YES componentsPerVector:3 bytesPerComponent:sizeof(float) dataOffset:0 dataStride:3 * sizeof(float)],
        [SCNGeometrySource geometrySourceWithData:uvs semantic:SCNGeometrySourceSemanticTexcoord vectorCount:count floatComponents:YES componentsPerVector:2 bytesPerComponent:sizeof(float) dataOffset:0 dataStride:2 * sizeof(float)]
    ];
}

- (SCNGeometryElement *)revenantElement
{
    NSUInteger segmentsWide = MAX(1, _widthSegmentCount);
    NSUInteger segmentsHigh = MAX(1, _heightSegmentCount);
    NSUInteger columns = segmentsWide + 1;
    NSUInteger count = columns * (segmentsHigh + 1);
    NSUInteger bytesPerIndex = count <= 65536 ? sizeof(uint16_t) : sizeof(uint32_t);
    NSMutableData *indices = [NSMutableData dataWithLength:segmentsWide * segmentsHigh * 6 * bytesPerIndex];
    for (NSUInteger row = 0; row < segmentsHigh; row++) {
        for (NSUInteger column = 0; column < segmentsWide; column++) {
            NSUInteger topLeft = row * columns + column;
            NSUInteger quad[6] = { topLeft, topLeft + columns, topLeft + 1, topLeft + 1, topLeft + columns, topLeft + columns + 1 };
            for (NSUInteger corner = 0; corner < 6; corner++) {
                NSUInteger at = (row * segmentsWide + column) * 6 + corner;
                if (bytesPerIndex == sizeof(uint16_t)) {
                    ((uint16_t *)indices.mutableBytes)[at] = (uint16_t)quad[corner];
                } else {
                    ((uint32_t *)indices.mutableBytes)[at] = (uint32_t)quad[corner];
                }
            }
        }
    }
    return [SCNGeometryElement geometryElementWithData:indices primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:segmentsWide * segmentsHigh * 2 bytesPerIndex:bytesPerIndex];
}

- (NSArray<SCNGeometrySource *> *)geometrySourcesForSemantic:(SCNGeometrySourceSemantic)semantic
{
    for (SCNGeometrySource *source in [self revenantSources]) {
        if ([source.semantic isEqualToString:semantic]) {
            return @[source];
        }
    }
    return @[];
}

- (NSArray<SCNGeometrySource *> *)geometrySources
{
    return [self revenantSources];
}

- (NSArray<SCNGeometryElement *> *)geometryElements
{
    return @[ [self revenantElement] ];
}

@end
