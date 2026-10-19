#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The meshes of the port's own generators. Every one of them lays down real vertices - a position, a
// normal and a texture coordinate each - in one interleaved buffer of three floats, twelve and eight
// bytes, and real indices into it, so what comes out is a mesh a caller can measure and draw rather
// than a count of something.

// The interleaved buffer the generators write, and the mesh around it. The normals of a generator
// that is asked for inward normals are the ones turned the other way, which is a change of the
// triangles' order, not of the directions, so the surface stays the same one.
typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 uv;
} CharonMDLGeneratedVertex;

@interface MDLMesh (CharonGenerators)
- (instancetype)charon_meshWithVertices:(NSData *)vertices
                             vertexCount:(NSUInteger)vertexCount
                                indices:(NSData *)indices
                             indexCount:(NSUInteger)indexCount
                            geometryType:(MDLGeometryType)geometryType
                                   name:(NSString *)name;
@end

@implementation MDLMesh (CharonGenerators)

- (instancetype)charon_meshWithVertices:(NSData *)vertices
                             vertexCount:(NSUInteger)vertexCount
                                indices:(NSData *)indices
                             indexCount:(NSUInteger)indexCount
                            geometryType:(MDLGeometryType)geometryType
                                   name:(NSString *)name
{
    id<MDLMeshBufferAllocator> allocator = self.allocator ?: [[MDLMeshBufferDataAllocator alloc] init];
    id<MDLMeshBuffer> vertexBuffer = [allocator newBuffer:vertices.length type:MDLMeshBufferTypeVertex];
    id<MDLMeshBuffer> indexBuffer = [allocator newBuffer:indices.length type:MDLMeshBufferTypeIndex];
    if (!vertexBuffer || !indexBuffer)
        return nil;
    [vertexBuffer fillData:vertices offset:0];
    [indexBuffer fillData:indices offset:0];

    MDLVertexDescriptor *descriptor = [[MDLVertexDescriptor alloc] init];
    MDLVertexAttribute *position = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributePosition format:MDLVertexFormatFloat3
                                                                       offset:0 bufferIndex:0];
    MDLVertexAttribute *normal = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributeNormal format:MDLVertexFormatFloat3
                                                                     offset:sizeof(vector_float3) bufferIndex:0];
    MDLVertexAttribute *uv = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributeTextureCoordinate format:MDLVertexFormatFloat2
                                                                offset:sizeof(vector_float3) * 2 bufferIndex:0];
    [descriptor addOrReplaceAttribute:position];
    [descriptor addOrReplaceAttribute:normal];
    [descriptor addOrReplaceAttribute:uv];
    [descriptor.layouts addObject:[[MDLVertexBufferLayout alloc] initWithStride:sizeof(CharonMDLGeneratedVertex)]];

    MDLMaterial *material = [[MDLMaterial alloc] initWithName:@""
                                          scatteringFunction:[[MDLPhysicallyPlausibleScatteringFunction alloc] init]];
    MDLSubmesh *submesh = [[MDLSubmesh alloc] initWithName:name ?: @"" indexBuffer:indexBuffer indexCount:indexCount
                                                    indexType:MDLIndexBitDepthUInt32 geometryType:geometryType material:material];
    MDLMesh *mesh = [[MDLMesh alloc] initWithVertexBuffers:@[vertexBuffer] vertexCount:vertexCount descriptor:descriptor
                                                  submeshes:@[submesh]];
    return mesh;
}

@end

// The append-only side of a generated surface: a vertex per position, normal and coordinate, and
// triangles or quads over them.
typedef struct {
    CharonMDLGeneratedVertex *vertex;
    NSUInteger vertexCount, vertexCapacity;
    uint32_t *index;
    NSUInteger indexCount, indexCapacity;
} CharonMDLBuilder;

static void CharonMDLBuilderVertex(CharonMDLBuilder *builder, vector_float3 position, vector_float3 normal, vector_float2 uv)
{
    if (builder->vertexCount == builder->vertexCapacity) {
        builder->vertexCapacity = builder->vertexCapacity ? builder->vertexCapacity * 2 : 64;
        builder->vertex = realloc(builder->vertex, builder->vertexCapacity * sizeof(CharonMDLGeneratedVertex));
    }
    CharonMDLGeneratedVertex *at = builder->vertex + builder->vertexCount++;
    at->position = position;
    at->normal = normal;
    at->uv = uv;
}

static void CharonMDLBuilderIndex(CharonMDLBuilder *builder, uint32_t value)
{
    if (builder->indexCount == builder->indexCapacity) {
        builder->indexCapacity = builder->indexCapacity ? builder->indexCapacity * 2 : 96;
        builder->index = realloc(builder->index, builder->indexCapacity * sizeof(uint32_t));
    }
    builder->index[builder->indexCount++] = value;
}

static NSData *CharonMDLBuilderVertices(CharonMDLBuilder *builder, NSUInteger *count)
{
    *count = builder->vertexCount;
    return [NSData dataWithBytes:builder->vertex length:builder->vertexCount * sizeof(CharonMDLGeneratedVertex)];
}

static NSData *CharonMDLBuilderIndices(CharonMDLBuilder *builder, NSUInteger *count)
{
    *count = builder->indexCount;
    return [NSData dataWithBytes:builder->index length:builder->indexCount * sizeof(uint32_t)];
}

static void CharonMDLBuilderFree(CharonMDLBuilder *builder)
{
    free(builder->vertex);
    free(builder->index);
}

@implementation MDLMesh (Generators)

// A grid over the XZ plane, centred on the origin, its normal up the Y axis: the plane ModelIO makes
// lies flat with Y up, and the winding of the quads is the one that faces upwards.
+ (instancetype)newPlaneWithDimensions:(vector_float2)dimensions
                              segments:(vector_uint2)segments
                          geometryType:(MDLGeometryType)geometryType
                        inwardNormals:(BOOL)inwardNormals
                            allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMDLBuilder builder = {0};
    NSUInteger across = MAX((NSUInteger)1, segments.x), up = MAX((NSUInteger)1, segments.y);
    for (NSUInteger row = 0; row <= up; row++) {
        for (NSUInteger column = 0; column <= across; column++) {
            vector_float2 uv = {(float)column / (float)across, (float)row / (float)up};
            vector_float3 position = {(uv.x - 0.5f) * dimensions.x, 0, (0.5f - uv.y) * dimensions.y};
            vector_float3 normal = inwardNormals ? (vector_float3){0, -1, 0} : (vector_float3){0, 1, 0};
            CharonMDLBuilderVertex(&builder, position, normal, uv);
        }
    }
    for (NSUInteger row = 0; row < up; row++)
        for (NSUInteger column = 0; column < across; column++) {
            uint32_t a = (uint32_t)(row * (across + 1) + column), b = a + 1, c = a + (uint32_t)(across + 1), d = c + 1;
            if (geometryType == MDLGeometryTypeQuads) {
                CharonMDLBuilderIndex(&builder, a);
                CharonMDLBuilderIndex(&builder, c);
                CharonMDLBuilderIndex(&builder, d);
                CharonMDLBuilderIndex(&builder, a);
                CharonMDLBuilderIndex(&builder, d);
                CharonMDLBuilderIndex(&builder, b);
            } else {
                CharonMDLBuilderIndex(&builder, a);
                CharonMDLBuilderIndex(&builder, c);
                CharonMDLBuilderIndex(&builder, b);
                CharonMDLBuilderIndex(&builder, b);
                CharonMDLBuilderIndex(&builder, c);
                CharonMDLBuilderIndex(&builder, d);
            }
        }
    NSUInteger vertexCount, indexCount;
    NSData *vertices = CharonMDLBuilderVertices(&builder, &vertexCount), *indices = CharonMDLBuilderIndices(&builder, &indexCount);
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    mesh = [mesh charon_meshWithVertices:vertices vertexCount:vertexCount indices:indices indexCount:indexCount
                            geometryType:geometryType name:@"plane"];
    CharonMDLBuilderFree(&builder);
    return mesh;
}

- (instancetype)initPlaneWithExtent:(vector_float3)extent
                           segments:(vector_uint2)segments
                       geometryType:(MDLGeometryType)geometryType
                          allocator:(id<MDLMeshBufferAllocator>)allocator
{
    MDLMesh *mesh = [MDLMesh newPlaneWithDimensions:(vector_float2){extent.x, extent.z} segments:segments geometryType:geometryType
                                       inwardNormals:NO allocator:allocator];
    return [self initWithVertexBuffers:mesh.vertexBuffers ?: @[] vertexCount:mesh.vertexCount descriptor:mesh.vertexDescriptor
                             submeshes:mesh.submeshes];
}

// A sphere of the given radii, its rings of latitude from the pole to the pole and its columns of
// longitude around it, each vertex's normal the direction from the centre, so an ellipsoid of three
// different radii is the same surface with its normals turned accordingly.
+ (instancetype)newEllipsoidWithRadii:(vector_float3)radii
                       radialSegments:(NSUInteger)radialSegments
                     verticalSegments:(NSUInteger)verticalSegments
                         geometryType:(MDLGeometryType)geometryType
                        inwardNormals:(BOOL)inwardNormals
                           hemisphere:(BOOL)hemisphere
                            allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMDLBuilder builder = {0};
    NSUInteger around = MAX((NSUInteger)3, radialSegments), down = MAX((NSUInteger)2, verticalSegments);
    // The ring of quads, and one ring more than that at each end: at every size measured the system
    // has four rings of vertices for two rings of quads, five for three and eight for six, with the
    // index count of the quads alone. So the poles are rings of their own, and the ring after the last
    // ring of quads repeats the pole so the seam has a texture coordinate all the way round.
    NSUInteger rows = down + 2;
    for (NSUInteger row = 0; row < rows; row++) {
        BOOL pole = row == 0 || row >= down;
        float v = (float)row / (float)down;
        float phi = v * (float)M_PI, y = cosf(phi), ring = sinf(phi);
        for (NSUInteger column = 0; column <= around; column++) {
            float u = (float)column / (float)around, theta = u * 2 * (float)M_PI;
            vector_float3 sphere = {ring * cosf(theta), y, ring * sinf(theta)};
            vector_float3 position = {sphere.x * radii.x, sphere.y * radii.y, sphere.z * radii.z};
            // The normal of a sphere of radii r at a point p is (p.x/r.x, p.y/r.y, p.z/r.z), which for
            // equal radii is the point itself, and at a pole is the axis the pole is on.
            vector_float3 normal = radii.x && radii.y && radii.z
                                       ? simd_normalize((vector_float3){sphere.x / radii.x, sphere.y / radii.y, sphere.z / radii.z})
                                       : sphere;
            if (pole)
                normal = (vector_float3){0, y > 0 ? 1 : -1, 0};
            if (inwardNormals)
                normal = (vector_float3){-normal.x, -normal.y, -normal.z};
            CharonMDLBuilderVertex(&builder, position, normal, (vector_float2){u, v});
        }
    }
    // The quads run between the rings the poles bound, so the surface is down rings of them and the
    // index count is the one the system gives.
    for (NSUInteger row = 0; row < down; row++)
        for (NSUInteger column = 0; column < around; column++) {
            uint32_t a = (uint32_t)(row * (around + 1) + column), b = a + 1, c = a + (uint32_t)(around + 1), d = c + 1;
            CharonMDLBuilderIndex(&builder, a);
            CharonMDLBuilderIndex(&builder, c);
            CharonMDLBuilderIndex(&builder, b);
            CharonMDLBuilderIndex(&builder, b);
            CharonMDLBuilderIndex(&builder, c);
            CharonMDLBuilderIndex(&builder, d);
        }
    NSUInteger vertexCount, indexCount;
    NSData *vertices = CharonMDLBuilderVertices(&builder, &vertexCount), *indices = CharonMDLBuilderIndices(&builder, &indexCount);
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    mesh = [mesh charon_meshWithVertices:vertices vertexCount:vertexCount indices:indices indexCount:indexCount
                            geometryType:geometryType name:@"ellipsoid"];
    CharonMDLBuilderFree(&builder);
    return mesh;
}

// The box of an extent, the form every other generator has: the same six faces, built once here and
// reached from both the extent form and the dimensions form.
- (instancetype)initBoxWithExtent:(vector_float3)extent
                         segments:(vector_uint3)segments
                    inwardNormals:(BOOL)inwardNormals
                     geometryType:(MDLGeometryType)geometryType
                        allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMDLBuilder builder = {0};
    static const int normalAxis[6] = {0, 0, 1, 1, 2, 2};
    static const int normalSign[6] = {1, -1, 1, -1, 1, -1};
    static const int uAxis[6] = {1, 1, 2, 2, 0, 0};
    static const int vAxis[6] = {2, 2, 0, 0, 1, 1};
    for (int face = 0; face < 6; face++) {
        NSUInteger first = builder.vertexCount;
        int axis = normalAxis[face];
        vector_float3 normal = {0, 0, 0};
        normal[axis] = normalSign[face] * (inwardNormals ? -1 : 1);
        NSUInteger u = MAX((NSUInteger)1, segments[uAxis[face]]);
        NSUInteger v = MAX((NSUInteger)1, segments[vAxis[face]]);
        for (NSUInteger row = 0; row <= v; row++)
            for (NSUInteger column = 0; column <= u; column++) {
                vector_float2 uv = {(float)column / (float)u, (float)row / (float)v};
                vector_float3 position = {0, 0, 0};
                position[axis] = normalSign[face] * extent[axis] * 0.5f;
                position[uAxis[face]] = (uv.x - 0.5f) * extent[uAxis[face]];
                position[vAxis[face]] = (uv.y - 0.5f) * extent[vAxis[face]];
                CharonMDLBuilderVertex(&builder, position, normal, uv);
            }
        for (NSUInteger row = 0; row < v; row++)
            for (NSUInteger column = 0; column < u; column++) {
                uint32_t a = (uint32_t)(first + row * (u + 1) + column), b = a + 1, c = a + (uint32_t)(u + 1), d = c + 1;
                CharonMDLBuilderIndex(&builder, a);
                CharonMDLBuilderIndex(&builder, c);
                CharonMDLBuilderIndex(&builder, d);
                CharonMDLBuilderIndex(&builder, a);
                CharonMDLBuilderIndex(&builder, d);
                CharonMDLBuilderIndex(&builder, b);
            }
    }
    NSUInteger vertexCount, indexCount;
    NSData *vertices = CharonMDLBuilderVertices(&builder, &vertexCount), *indices = CharonMDLBuilderIndices(&builder, &indexCount);
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    mesh = [mesh charon_meshWithVertices:vertices vertexCount:vertexCount indices:indices indexCount:indexCount
                            geometryType:geometryType name:@"box"];
    CharonMDLBuilderFree(&builder);
    return [self initWithVertexBuffers:mesh.vertexBuffers vertexCount:mesh.vertexCount descriptor:mesh.vertexDescriptor
                             submeshes:mesh.submeshes];
}

// The sphere of an extent, which is the ellipsoid of the half-extent on each axis.
- (instancetype)initSphereWithExtent:(vector_float3)extent
                            segments:(vector_uint2)segments
                       inwardNormals:(BOOL)inwardNormals
                        geometryType:(MDLGeometryType)geometryType
                           allocator:(id<MDLMeshBufferAllocator>)allocator
{
    vector_float3 radii = {extent.x * 0.5f, extent.y * 0.5f, extent.z * 0.5f};
    MDLMesh *mesh = [MDLMesh newEllipsoidWithRadii:radii radialSegments:segments.x verticalSegments:segments.y
                                      geometryType:geometryType inwardNormals:inwardNormals hemisphere:NO allocator:allocator];
    return [self initWithVertexBuffers:mesh.vertexBuffers vertexCount:mesh.vertexCount descriptor:mesh.vertexDescriptor
                             submeshes:mesh.submeshes];
}

+ (instancetype)newBoxWithDimensions:(vector_float3)dimensions
                            segments:(vector_uint3)segments
                        geometryType:(MDLGeometryType)geometryType
                       inwardNormals:(BOOL)inwardNormals
                           allocator:(id<MDLMeshBufferAllocator>)allocator
{
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    return [mesh initBoxWithExtent:dimensions segments:segments inwardNormals:inwardNormals geometryType:geometryType
                        allocator:allocator];
}

// A tube between two radii, of the height given, with the caps it is asked for: a ring of vertices at
// each end, a fan of triangles over the tube and one over each cap. The cylinder of the public surface
// is this, with its own radii and caps.
static void CharonMDLTaperedTube(CharonMDLBuilder *builder, float lower, float upper, float height, NSUInteger around,
                                 NSUInteger up, BOOL inwardNormals, BOOL topCap, BOOL bottomCap)
{
    float halfHeight = height * 0.5f;
    // The same sharing the ellipsoid has: one ring more than the number of rings of quads at each end,
    // and one ring of quads more than the caller asked for. Fitted to the system's own counts over ten
    // sizes, where rings = vertical + 3 and columns = radial + 1 give every one of them exactly.
    NSUInteger rings = up + 3;
    for (NSUInteger ring = 0; ring < rings; ring++) {
        BOOL pole = ring == 0 || ring >= up + 1;
        // v runs 0 .. (up+2)/(up+1) over the rings, because there is a pole ring beyond each end,
        // and the extra rings are AT the ends and not past them: a cylinder of height 4 measured
        // 5.33333 tall against the system's 4.00000, which is (4/3 - 1/2) * 4 - the fourth ring of
        // five placed a third of a height above the top of the tube. Clamped, the last ring is the
        // top one and the cylinder is the height that was asked for.
        float v = (float)ring / (float)(up + 1), y, radius;
        if (v > 1.0f)
            v = 1.0f;
        y = (v - 0.5f) * height;
        radius = lower + (upper - lower) * v;
        for (NSUInteger column = 0; column <= around; column++) {
            float u = (float)column / (float)around, theta = u * 2 * (float)M_PI;
            vector_float3 outward = {cosf(theta), 0, sinf(theta)};
            vector_float3 normal = inwardNormals ? (vector_float3){-outward.x, -outward.y, -outward.z} : outward;
            if (pole)
                normal = (vector_float3){0, y > 0 ? 1 : (y < 0 ? -1 : 0), 0};
            CharonMDLBuilderVertex(builder, (vector_float3){outward.x * radius, y, outward.z * radius}, normal, (vector_float2){u, v});
        }
    }
    for (NSUInteger ring = 0; ring < up + 1; ring++)
        for (NSUInteger column = 0; column < around; column++) {
            uint32_t a = (uint32_t)(ring * (around + 1) + column), b = a + 1, c = a + (uint32_t)(around + 1), d = c + 1;
            CharonMDLBuilderIndex(builder, a);
            CharonMDLBuilderIndex(builder, c);
            CharonMDLBuilderIndex(builder, b);
            CharonMDLBuilderIndex(builder, b);
            CharonMDLBuilderIndex(builder, c);
            CharonMDLBuilderIndex(builder, d);
        }
    // A cap is a centre vertex on the axis and a fan of triangles over the ring at that end. The two
    // centre vertices are what the vertex count is short of the rings by, and they are the two the
    // system has.
    for (int end = 0; end < 2; end++) {
        if (end ? !topCap : !bottomCap)
            continue;
        float sign = end ? 1 : -1;
        vector_float3 normal = {0, inwardNormals ? -sign : sign, 0};
        uint32_t centre = (uint32_t)builder->vertexCount;
        CharonMDLBuilderVertex(builder, (vector_float3){0, sign * halfHeight, 0}, normal, (vector_float2){0.5f, 0.5f});
        uint32_t ring = (uint32_t)(end ? up + 1 : 0) * (uint32_t)(around + 1);
        for (NSUInteger column = 0; column < around; column++) {
            CharonMDLBuilderIndex(builder, ring + (uint32_t)column);
            CharonMDLBuilderIndex(builder, ring + (uint32_t)column + 1);
            CharonMDLBuilderIndex(builder, centre);
        }
    }
}

+ (instancetype)newCylinderWithHeight:(float)height
                                radii:(vector_float2)radii
                       radialSegments:(NSUInteger)radialSegments
                     verticalSegments:(NSUInteger)verticalSegments
                         geometryType:(MDLGeometryType)geometryType
                        inwardNormals:(BOOL)inwardNormals
                            allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMDLBuilder builder = {0};
    CharonMDLTaperedTube(&builder, radii.x, radii.y, height, MAX((NSUInteger)3, radialSegments), MAX((NSUInteger)1, verticalSegments),
                         inwardNormals, radii.y > 0, radii.x > 0);
    NSUInteger vertexCount, indexCount;
    NSData *vertices = CharonMDLBuilderVertices(&builder, &vertexCount), *indices = CharonMDLBuilderIndices(&builder, &indexCount);
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    mesh = [mesh charon_meshWithVertices:vertices vertexCount:vertexCount indices:indices indexCount:indexCount
                            geometryType:geometryType name:@"cylinder"];
    CharonMDLBuilderFree(&builder);
    return mesh;
}

- (instancetype)initCylinderWithExtent:(vector_float3)extent
                              segments:(vector_uint2)segments
                         inwardNormals:(BOOL)inwardNormals
                                topCap:(BOOL)topCap
                             bottomCap:(BOOL)bottomCap
                          geometryType:(MDLGeometryType)geometryType
                             allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMDLBuilder builder = {0};
    CharonMDLTaperedTube(&builder, extent.x * 0.5f, extent.z * 0.5f, extent.y, MAX((NSUInteger)3, segments.x),
                         MAX((NSUInteger)1, segments.y), inwardNormals, topCap, bottomCap);
    NSUInteger vertexCount, indexCount;
    NSData *vertices = CharonMDLBuilderVertices(&builder, &vertexCount), *indices = CharonMDLBuilderIndices(&builder, &indexCount);
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    mesh = [mesh charon_meshWithVertices:vertices vertexCount:vertexCount indices:indices indexCount:indexCount
                            geometryType:geometryType name:@"cylinder"];
    CharonMDLBuilderFree(&builder);
    return [self initWithVertexBuffers:mesh.vertexBuffers vertexCount:mesh.vertexCount descriptor:mesh.vertexDescriptor
                             submeshes:mesh.submeshes];
}

// A cone: a tube whose upper radius is nothing, which is the same fan over the ring and the one
// vertex at the apex, with the optional cap at its base.
- (instancetype)initConeWithExtent:(vector_float3)extent
                          segments:(vector_uint2)segments
                     inwardNormals:(BOOL)inwardNormals
                               cap:(BOOL)cap
                      geometryType:(MDLGeometryType)geometryType
                         allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMDLBuilder builder = {0};
    float radius = (extent.x > extent.z ? extent.x : extent.z) * 0.5f, halfHeight = extent.y * 0.5f;
    NSUInteger around = MAX((NSUInteger)3, segments.x);
    for (NSUInteger column = 0; column <= around; column++) {
        float u = (float)column / (float)around, theta = u * 2 * (float)M_PI;
        vector_float3 outward = {cosf(theta), 0, sinf(theta)};
        // A cone's own normal leans out of its slope, by the angle the slope makes with the axis.
        vector_float3 normal = simd_normalize((vector_float3){outward.x, radius / halfHeight, outward.z});
        if (inwardNormals)
            normal = (vector_float3){-normal.x, -normal.y, -normal.z};
        CharonMDLBuilderVertex(&builder, (vector_float3){outward.x * radius, -halfHeight, outward.z * radius}, normal, (vector_float2){u, 1});
    }
    CharonMDLBuilderVertex(&builder, (vector_float3){0, halfHeight, 0}, (vector_float3){0, inwardNormals ? -1 : 1, 0},
                           (vector_float2){0.5f, 0});
    uint32_t apex = (uint32_t)(around + 1);
    for (NSUInteger column = 0; column < around; column++) {
        CharonMDLBuilderIndex(&builder, (uint32_t)column);
        CharonMDLBuilderIndex(&builder, (uint32_t)column + 1);
        CharonMDLBuilderIndex(&builder, apex);
    }
    if (cap) {
        uint32_t centre = (uint32_t)builder.vertexCount;
        CharonMDLBuilderVertex(&builder, (vector_float3){0, -halfHeight, 0}, (vector_float3){0, inwardNormals ? 1 : -1, 0},
                               (vector_float2){0.5f, 0.5f});
        for (NSUInteger column = 0; column < around; column++) {
            CharonMDLBuilderIndex(&builder, (uint32_t)column);
            CharonMDLBuilderIndex(&builder, apex - 1 - (uint32_t)column);
            CharonMDLBuilderIndex(&builder, centre);
        }
    }
    NSUInteger vertexCount, indexCount;
    NSData *vertices = CharonMDLBuilderVertices(&builder, &vertexCount), *indices = CharonMDLBuilderIndices(&builder, &indexCount);
    MDLMesh *mesh = [[MDLMesh alloc] initWithBufferAllocator:allocator];
    mesh = [mesh charon_meshWithVertices:vertices vertexCount:vertexCount indices:indices indexCount:indexCount
                            geometryType:geometryType name:@"cone"];
    CharonMDLBuilderFree(&builder);
    return [self initWithVertexBuffers:mesh.vertexBuffers vertexCount:mesh.vertexCount descriptor:mesh.vertexDescriptor
                             submeshes:mesh.submeshes];
}

@end
