// ARPlaneGeometry.m - the mesh of a plane, split from ARAnchor.m because an object carries the API
// of one release: the geometry arrived with 12.0, beside the image and object scanning
// configurations in ARConfiguration3.m and the reference object's constants in
// ARKitConstants12.m.

#import <ARKit/ARKit.h>
#import <string.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

@implementation ARPlaneGeometry
{
    simd_float3 *_vertices;
    simd_float2 *_textureCoordinates;
    int16_t *_triangleIndices;
    simd_float3 *_boundaryVertices;
}
    @synthesize vertices = _vertices;
    @synthesize textureCoordinates = _textureCoordinates;
    @synthesize triangleIndices = _triangleIndices;
    @synthesize boundaryVertices = _boundaryVertices;

    @synthesize vertexCount = _vertexCount;
    @synthesize textureCoordinateCount = _textureCoordinateCount;
    @synthesize triangleCount = _triangleCount;
    @synthesize boundaryVertexCount = _boundaryVertexCount;



/// The geometry of a plane is C buffers, not objects: the framework declares the vertices, the
/// texture coordinates and the triangle indices as pointers into memory a renderer reads in place,
/// and a caller walks them with the counts beside them. So the buffers are the storage, they are
/// filled from the plane the detector found, and they live as long as this object does.
- (instancetype)initWithPlaneValue:(CharonARValue *)value
{
    self = [super init];
    if (!self)
        return nil;
    CharonARPlane plane;
    if (![value getValue:&plane])
        return nil;

    // One plane is a quad, and a quad is what a plane detector's rectangle is: four corners, six
    // indices, and the four texture coordinates that go with the corners.
    _vertexCount = kPlaneQuadCorners;
    _textureCoordinateCount = kPlaneQuadCorners;
    _triangleCount = kPlaneQuadTriangles;
    _boundaryVertexCount = kPlaneQuadCorners;

    simd_float3 corners[kPlaneQuadCorners];
    simd_float2 coordinates[kPlaneQuadCorners] = {
        {0.0f, 0.0f}, {1.0f, 0.0f}, {0.0f, 1.0f}, {1.0f, 1.0f},
    };
    int16_t indices[kPlaneQuadTriangles] = {0, 2, 1, 1, 2, 3};
    // The detector gives a centre, a normal and a half-extent, and the quad's corners follow from an
    // orthonormal pair in the plane. The pair is built out of the normal by crossing it with the
    // world axis it is least parallel to, so the corners are in the plane for any normal at all.
    simd_float3 seed = fabsf(plane.normal.y) < 0.9f ? (simd_float3){0.0f, 1.0f, 0.0f}
                                                   : (simd_float3){1.0f, 0.0f, 0.0f};
    simd_float3 along = simd_normalize(simd_cross(plane.normal, seed));
    simd_float3 across = simd_normalize(simd_cross(plane.normal, along));
    for (size_t i = 0; i < kPlaneQuadCorners; i++) {
        float u = (i == 1 || i == 3) ? 1.0f : -1.0f;
        float v = (i >= 2) ? 1.0f : -1.0f;
        corners[i] = plane.center + along * (u * plane.extent.x) + across * (v * plane.extent.y);
    }

    _vertices = malloc(kPlaneQuadCorners * sizeof * _vertices);
    _textureCoordinates = malloc(kPlaneQuadCorners * sizeof * _textureCoordinates);
    _triangleIndices = malloc(kPlaneQuadTriangles * sizeof * _triangleIndices);
    _boundaryVertices = malloc(kPlaneQuadCorners * sizeof * _boundaryVertices);
    if (!_vertices || !_textureCoordinates || !_triangleIndices || !_boundaryVertices) {
        free(_vertices);
        free(_textureCoordinates);
        free(_triangleIndices);
        free(_boundaryVertices);
        return nil;
    }
    memcpy(_vertices, corners, sizeof corners);
    memcpy(_textureCoordinates, coordinates, sizeof coordinates);
    memcpy(_triangleIndices, indices, sizeof indices);
    memcpy(_boundaryVertices, corners, sizeof corners);
    return self;
}

- (void)dealloc
{
    free(_vertices);
    free(_textureCoordinates);
    free(_triangleIndices);
    free(_boundaryVertices);
}

- (const simd_float3 *)vertices { return _vertices; }
- (const simd_float2 *)textureCoordinates { return _textureCoordinates; }
- (const int16_t *)triangleIndices { return _triangleIndices; }
- (const simd_float3 *)boundaryVertices { return _boundaryVertices; }

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_vertexCount forKey:@"vertexCount"];
    [coder encodeInteger:(NSInteger)_triangleCount forKey:@"triangleCount"];
    CharonEncodeStruct(coder, @"vertices", _vertices, _vertexCount * sizeof * _vertices);
    CharonEncodeStruct(coder, @"textureCoordinates", _textureCoordinates,
                       _vertexCount * sizeof * _textureCoordinates);
    CharonEncodeStruct(coder, @"triangleIndices", _triangleIndices,
                       _triangleCount * sizeof * _triangleIndices);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _vertexCount = _textureCoordinateCount = _boundaryVertexCount =
            (NSUInteger)[coder decodeIntegerForKey:@"vertexCount"];
    _triangleCount = (NSUInteger)[coder decodeIntegerForKey:@"triangleCount"];
    if (!_vertexCount || !_triangleCount)
        return nil;
    _vertices = malloc(_vertexCount * sizeof * _vertices);
    _textureCoordinates = malloc(_vertexCount * sizeof * _textureCoordinates);
    _triangleIndices = malloc(_triangleCount * sizeof * _triangleIndices);
    _boundaryVertices = malloc(_vertexCount * sizeof * _boundaryVertices);
    if (!_vertices || !_textureCoordinates || !_triangleIndices || !_boundaryVertices) {
        free(_vertices);
        free(_textureCoordinates);
        free(_triangleIndices);
        free(_boundaryVertices);
        return nil;
    }
    if (!CharonDecodeStruct(coder, @"vertices", _vertices, _vertexCount * sizeof * _vertices) ||
        !CharonDecodeStruct(coder, @"textureCoordinates", _textureCoordinates,
                            _vertexCount * sizeof * _textureCoordinates) ||
        !CharonDecodeStruct(coder, @"triangleIndices", _triangleIndices,
                            _triangleCount * sizeof * _triangleIndices)) {
        free(_vertices);
        free(_textureCoordinates);
        free(_triangleIndices);
        free(_boundaryVertices);
        return nil;
    }
    memcpy(_boundaryVertices, _vertices, _vertexCount * sizeof * _vertices);
    return self;
}

@end
