// One probe, two processes. Built once against the system's ModelIO and once against the port's own
// sources, it is run on the same generated inputs in both, and each writes what it computed as
// canonical text: the vertices, indices and bounds of every mesh it loaded, the transforms and
// animated values, the texels of a texture, the voxels of an array, the properties of a material.
// run.sh then compares the two files line by line.
//
// Nothing here is tuned to agree. A line that differs is a line where the port and the system answer
// differently, and it is reported as it is: that is the measurement.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <string.h>
#include <stdint.h>
#import <ModelIO/ModelIO.h>
#import <simd/simd.h>
#import <string.h>

#if !MDL_TEXTURE_TAKES_IS_CUBE
#import "port-support.h"
#endif

static void put(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
// WHICH IMAGE ANSWERED, proved at runtime rather than inferred from link flags. The port process does not
// link the system ModelIO, which already guarantees the two never meet in one runtime - but that is a fact
// about the build, and a build can be edited. dladdr on the class pointer returns the Mach-O that defined
// it, so every answer carries the path it came from and run.sh can refuse a port answer that came from
// ModelIO.framework. A differential that compares two runtimes cannot tell from its own output which one it
// measured; this can.
static void report_image(NSString *cls)
{
    Class k = NSClassFromString(cls);
    Dl_info info;
    memset(&info, 0, sizeof(info));
    const char *path = k && dladdr((const void *)(uintptr_t)k, &info) ? info.dli_fname : "unknown";
    // stderr, NEVER answers.txt. That file is compared LINE BY LINE, and an IMAGE line is not a
    // measurement: it is asymmetric by construction - a family prints one only when that family ran, so the
    // two sides legitimately differ - and the absolute path differs too. Putting it in answers.txt made
    // compare.py report every one as "only one side". run.sh reads the two stderr streams instead.
    fprintf(stderr, "image %s %s %s\n", cls.UTF8String, path ? path : "unknown",
            path && strstr(path, "ModelIO") ? "system-modelio" : "port");
}

static void put(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    printf("%s\n", line.UTF8String);
}

// A section the system refuses is an answer, not the end of the run: what it said is printed and the
// rest of the probe still runs.
static void guard(NSString *key, void (^body)(void));

static void guard(NSString *key, void (^body)(void))
{
    @try {
        body();
    } @catch (NSException *exception) {
        put(@"%@ this side does not answer: %@: %@", key, exception.name, exception.reason);
    }
}

static void put3(NSString *key, vector_float3 v)
{
    put(@"%@ %.5f %.5f %.5f", key, v.x, v.y, v.z);
}

static void put_box(NSString *key, MDLAxisAlignedBoundingBox box)
{
    put(@"%@ min %.5f %.5f %.5f max %.5f %.5f %.5f", key, box.minBounds.x, box.minBounds.y, box.minBounds.z, box.maxBounds.x, box.maxBounds.y, box.maxBounds.z);
}

// The bytes of a block, as a length and a checksum, so a difference anywhere in it is named without
// printing a megabyte of hex.
static void put_bytes(NSString *key, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    uint32_t sum = 2166136261u;
    for (NSUInteger k = 0; k < data.length; k++) {
        sum ^= bytes[k];
        sum *= 16777619u;
    }
    put(@"%@ %lu %08x", key, (unsigned long)data.length, sum);
}

#pragma mark - the inputs both processes are given

// A Wavefront object: two groups, a quad, a triangle, normals, texture coordinates and a material
// name, so a reader is measured on its sharing of its vertices and on the order of its faces.
static void writeOBJ(NSString *path)
{
    NSArray<NSString *> *lines = @[
        @"# a cube of two faces, one of them a quad",
        @"mtllib cube.mtl",
        @"o solid",
        @"v -1 -1 0", @"v 1 -1 0", @"v 1 1 0", @"v -1 1 0", @"v 0 0 1",
        // DISTINCTIVE uv pairs, so whether the two sides flip V is visible in the numbers instead of
        // being inferred from the code. Every y is 0.75: if a side answers 0.25 it is reading the file, and
        // if it answers 0.75 for a y of 0.25 it has flipped. The x values 0.25/0.50/0.75 are distinct too,
        // so a shifted read cannot pass as a flipped one.
        @"vt 0.25 0.25", @"vt 0.50 0.25", @"vt 0.75 0.25", @"vt 0.25 0.75",
        @"vn 0 0 1", @"vn 0 0 -1",
        @"usemtl red",
        @"f 1/1/1 2/2/1 4/4/1 3/3/1",
        @"g lid",
        @"f 1/1/1 3/3/1 5",
    ];
    [[lines componentsJoinedByString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

// The same shape as a polygon file in its ASCII form, with a colour per vertex and a face list of
// three, so the reader is measured over its header's properties and its fan of a face.
// The same body as writePLYAscii with one line inserted inside the face element s data.
static void writePLYAsciiWithMidDataComment(NSString *path)
{
    NSArray *lines = @[
        @"ply", @"format ascii 1.0", @"comment a triangle with a colour",
        @"element vertex 4",
        @"property float x", @"property float y", @"property float z",
        @"property float nx", @"property float ny", @"property float nz",
        @"property uchar red", @"property uchar green", @"property uchar blue",
        @"element face 2", @"property list uchar int vertex_indices", @"end_header",
        @"0 0 0 0 0 1 255 0 0", @"1 0 0 0 0 1 0 255 0",
        @"1 1 0 0 0 1 0 0 255", @"0 1 0 0 0 1 255 255 0",
        @"# the two faces of the plate",
        @"3 0 1 2", @"3 0 2 3",
    ];
    [[lines componentsJoinedByString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void writePLYAscii(NSString *path)
{
    NSArray<NSString *> *lines = @[
        @"ply", @"format ascii 1.0", @"comment a triangle with a colour", @"element vertex 4",
        @"property float x", @"property float y", @"property float z", @"property float nx",
        @"property float ny", @"property float nz", @"property uchar red", @"property uchar green",
        @"property uchar blue", @"element face 2", @"property list uchar int vertex_indices", @"end_header",
        @"0 0 0 0 0 1 255 0 0", @"1 0 0 0 0 1 0 255 0", @"1 1 0 0 0 1 0 0 255", @"0 1 0 0 0 1 255 255 0",
        // NO COMMENT HERE, and that is a MEASURED change. A comment inside the face element s DATA makes
        // the system read this file as a point cloud - 12 indices, geometry 0 - where it plainly holds two
        // triangles, 6 indices, geometry 2. Four variants of the same bytes, measured:
        //
        //   no comment                      6 indices  geometry 2  triangle     <- what the file says
        //   comment before the first face   3 indices  geometry 2  triangle     <- a face is DROPPED
        //   comment between two faces       6 indices  geometry 2  triangle     <- ignored
        //   comment in the HEADER          12 indices  geometry 0  point cloud  <- the shape changes
        //
        // The behaviour is POSITION-dependent, not comment-dependent, and no single consistent rule fits:
        // the second variant loses a face SILENTLY, which is not something to copy. So tri.ply is written
        // comment-free so both sides measure the same file, the port keeps its correct reading of the faces,
        // and the divergence lives in its own fixture - tri-comment.ply - recorded in the facts file.
        @"3 0 1 2", @"3 0 2 3",
    ];
    [[lines componentsJoinedByString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

// The same file in its binary little-endian form, so the reader is measured on reading a body at the
// layout the header states rather than at the header's own words.
static void writePLYBinary(NSString *path)
{
    NSMutableData *data = [NSMutableData data];
    const char *header = "ply\nformat binary_little_endian 1.0\nelement vertex 4\nproperty float x\nproperty float y\n"
                         "property float z\nproperty float nx\nproperty float ny\nproperty float nz\n"
                         "property uchar red\nproperty uchar green\nproperty uchar blue\n"
                         "element face 2\nproperty list uchar int vertex_indices\nend_header\n";
    [data appendBytes:header length:strlen(header)];
    const float positions[4][3] = {{0, 0, 0}, {1, 0, 0}, {1, 1, 0}, {0, 1, 0}};
    const uint8_t colours[4][3] = {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0}};
    for (int k = 0; k < 4; k++) {
        [data appendBytes:positions[k] length:12];
        float normal[3] = {0, 0, 1};
        [data appendBytes:normal length:12];
        [data appendBytes:colours[k] length:3];
    }
    for (int face = 0; face < 2; face++) {
        uint8_t count = 3;
        [data appendBytes:&count length:1];
        int32_t indices[3] = {face, face + 1, face + 2};
        [data appendBytes:indices length:12];
    }
    [data writeToFile:path atomically:YES];
}

// A mesh prim of the ASCII scene description, written the way a writer writes one: a header, a def
// Mesh, its extents, its points, and a face count and index run per face. The band's first fixture
// was not one the system could read - it read zero objects - so this one is measured first and the
// reader is held to a file with content in it.
static void writeUSDA(NSString *path)
{
    // A mesh prim written the way a writer writes one: a header, a def Mesh with braces, its extent,
    // its points, and a face count and index run per face. The first fixture here had no braces and the
    // system read zero objects out of it, so the two sides agreed on nothing and the reader was never
    // measured; this one is checked with the system before it is used.
    NSArray<NSString *> *lines = @[
        @"#usda 1.0",
        @"(",
        @"    defaultPrim = \"Plate\"",
        @"    metersPerUnit = 1",
        @"    upAxis = \"Y\"",
        @")",
        @"def Mesh \"Plate\"",
        @"{",
        @"    float3[] extent = [(0, 0, 0), (1, 1, 1)]",
        @"    int[] faceVertexCounts = [4, 3]",
        @"    int[] faceVertexIndices = [0, 1, 3, 2, 2, 3, 4]",
        @"    point3f[] points = [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0), (0.5, 0.5, 1)]",
        @"    uniform token subdivisionScheme = \"none\"",
        @"}",
        @"",
    ];
    [[lines componentsJoinedByString:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

#pragma mark - the measurements

static void reportMesh(MDLMesh *mesh, NSString *key)
{
    put(@"%@ name %@", key, mesh.name);
    put(@"%@ vertices %lu", key, (unsigned long)mesh.vertexCount);
    put(@"%@ submeshes %lu", key, (unsigned long)mesh.submeshes.count);
    for (MDLSubmesh *submesh in mesh.submeshes) {
        put(@"%@ submesh %@ indices %lu depth %lu geometry %ld", key, submesh.name, (unsigned long)submesh.indexCount,
            (unsigned long)submesh.indexType, (long)submesh.geometryType);
        MDLVertexAttributeData *positions = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributePosition
                                                                             asFormat:MDLVertexFormatFloat3];
        MDLVertexAttributeData *normals = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributeNormal
                                                                           asFormat:MDLVertexFormatFloat3];
        MDLVertexAttributeData *uvs = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributeTextureCoordinate
                                                                      asFormat:MDLVertexFormatFloat2];
        if (positions)
            for (NSUInteger v = 0; v < mesh.vertexCount && v < 8; v++)
                put3([NSString stringWithFormat:@"%@ v%lu p", key, (unsigned long)v],
                     *(vector_float3 *)((uint8_t *)positions.dataStart + v * positions.stride));
        if (normals)
            for (NSUInteger v = 0; v < mesh.vertexCount && v < 4; v++)
                put3([NSString stringWithFormat:@"%@ v%lu n", key, (unsigned long)v],
                     *(vector_float3 *)((uint8_t *)normals.dataStart + v * normals.stride));
        if (uvs)
            for (NSUInteger v = 0; v < mesh.vertexCount && v < 4; v++) {
                vector_float2 uv = *(vector_float2 *)((uint8_t *)uvs.dataStart + v * uvs.stride);
                put(@"%@ v%lu uv %.5f %.5f", key, (unsigned long)v, uv.x, uv.y);
            }
        put(@"%@ submesh material %@ properties %lu", key, submesh.material.name ?: @"-", (unsigned long)submesh.material.count);
        for (MDLMaterialProperty *property in submesh.material) {
            put(@"%@ property %@ semantic %lu type %lu", key, property.name, (unsigned long)property.semantic,
                (unsigned long)property.type);
            if (property.type == MDLMaterialPropertyTypeFloat3)
                put3([NSString stringWithFormat:@"%@ property %@ value", key, property.name], property.float3Value);
            else if (property.type == MDLMaterialPropertyTypeFloat)
                put(@"%@ property %@ value %.5f", key, property.name, property.floatValue);
        }
    }
    put_box([key stringByAppendingString:@" box"], mesh.boundingBox);
}

static NSString *inputDirectory;

static void reportAsset(NSString *key, NSString *extension)
{
    MDLAsset *asset = [[MDLAsset alloc] initWithURL:[NSURL fileURLWithPath:[inputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", key, extension]]]];
    put(@"%@ canImport %d", key, [MDLAsset canImportFileExtension:extension]);
    put(@"%@ objects %lu", key, (unsigned long)asset.count);
    put_box([key stringByAppendingString:@" box"], asset.boundingBox);
    for (MDLObject *object in asset) {
        if ([object isKindOfClass:[MDLMesh class]]) {
            report_image(@"MDLMesh");
            reportMesh((MDLMesh *)object, [key stringByAppendingString:@" mesh"]);
        } else
            put(@"%@ object %@", key, NSStringFromClass([object class]));
    }
}

static void reportTransform(void)
{
    matrix_float4x4 matrix = {{2, 0, 0, 0}, {0, 3, 0, 0}, {0, 0, 4, 1}, {5, 6, 7, 1}};
    MDLTransform *transform = [[MDLTransform alloc] init];
    [transform setMatrix:matrix];
    put3(@"transform translation", [transform translationAtTime:0]);
    put3(@"transform scale", [transform scaleAtTime:0]);
    put3(@"transform rotation", [transform rotationAtTime:0]);
    put3(@"transform shear", [transform shearAtTime:0]);
    put(@"transform keyTimes %lu", (unsigned long)transform.keyTimes.count);
    [transform setTranslation:(vector_float3){1, 2, 3} forTime:0];
    put3(@"transform after setTranslation", [transform translationAtTime:0]);

    MDLAnimatedScalar *scalar = [[MDLAnimatedScalar alloc] init];
    [scalar setFloat:0 atTime:0];
    [scalar setFloat:10 atTime:1];
    for (NSTimeInterval t = -0.5; t <= 1.5; t += 0.25)
        put(@"animated scalar %g %.5f", t, [scalar floatAtTime:t]);
    put(@"animated scalar keyTimes %@", [scalar.keyTimes componentsJoinedByString:@","]);

    MDLAnimatedVector3 *vector = [[MDLAnimatedVector3 alloc] init];
    [vector setFloat3:(vector_float3){0, 0, 0} atTime:0];
    [vector setFloat3:(vector_float3){1, 2, 3} atTime:2];
    put3(@"animated vector at 1", [vector float3AtTime:1]);
    put(@"animated vector animated %d samples %lu", [vector isAnimated], (unsigned long)vector.timeSampleCount);

    MDLTransformStack *stack = [[MDLTransformStack alloc] init];
    MDLTransformTranslateOp *translate = [stack addTranslateOp:@"t" inverse:NO];
    MDLTransformRotateXOp *rotate = [stack addRotateXOp:@"r" inverse:NO];
    [(MDLAnimatedVector3 *)[translate animatedValue] setFloat3:(vector_float3){1, 2, 3} atTime:0];
    [(MDLAnimatedScalar *)[rotate animatedValue] setFloat:(float)M_PI_2 atTime:0];
    put(@"stack count %lu", (unsigned long)stack.count);
    put(@"stack names %@ %@", [translate name], [rotate name]);
    matrix_float4x4 product = [stack float4x4AtTime:0];
    for (int c = 0; c < 4; c++)
        put(@"stack matrix %d %.5f %.5f %.5f %.5f", c, product.columns[c][0], product.columns[c][1], product.columns[c][2],
            product.columns[c][3]);
    put(@"stack value by name %@", [[[stack animatedValueWithName:@"t"] class] description]);
}

static void reportGenerators(void)
{
    // The two SDKs disagree on the plane: the iOS 16.4 header takes inwardNormals: and the macOS one
    // does not, so the plane is the one generator the two processes cannot be asked the same
    // question about. It is named here rather than skipped quietly.
#if MDL_PLANE_TAKES_INWARD_NORMALS
    MDLMesh *plane = [MDLMesh newPlaneWithDimensions:(vector_float2){2, 2} segments:(vector_uint2){2, 3}
                                            geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
    put(@"plane vertices %lu indices %lu", (unsigned long)plane.vertexCount,
        (unsigned long)plane.submeshes.firstObject.indexCount);
    put_box(@"plane", plane.boundingBox);
#else
    MDLMesh *plane = [MDLMesh newPlaneWithDimensions:(vector_float2){2, 2} segments:(vector_uint2){2, 3}
                                            geometryType:MDLGeometryTypeTriangles allocator:nil];
    put(@"plane vertices %lu indices %lu", (unsigned long)plane.vertexCount,
        (unsigned long)plane.submeshes.firstObject.indexCount);
    put_box(@"plane", plane.boundingBox);
#endif
    MDLMesh *box = [MDLMesh newBoxWithDimensions:(vector_float3){2, 2, 2} segments:(vector_uint3){1, 1, 1}
                                      geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
    put(@"box vertices %lu indices %lu", (unsigned long)box.vertexCount, (unsigned long)box.submeshes.firstObject.indexCount);
    put_box(@"box", box.boundingBox);
    MDLMesh *ball = [MDLMesh newEllipsoidWithRadii:(vector_float3){1, 2, 3} radialSegments:8 verticalSegments:6
                                      geometryType:MDLGeometryTypeTriangles inwardNormals:NO hemisphere:NO allocator:nil];
    put(@"ellipsoid vertices %lu indices %lu", (unsigned long)ball.vertexCount,
        (unsigned long)ball.submeshes.firstObject.indexCount);
    put_box(@"ellipsoid", ball.boundingBox);
      // The cylinder at THREE parameter sets, so its topology can be SOLVED rather than fitted to one
      // point. 47 vertices and 162 indices at 8 segments and 2 vertical segments is one observation; the
      // formula has to hold at the other two or it is not the formula.
      {
          const int radial[5] = {8, 8, 8, 12, 5};
          const int vertical[5] = {1, 2, 3, 2, 4};
          for (int c = 0; c < 5; c++) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:radial[c] verticalSegments:vertical[c]
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              put(@"cylinder s%d v%d vertices %lu indices %lu", radial[c], vertical[c],
                  (unsigned long)cyl.vertexCount, (unsigned long)cyl.submeshes.firstObject.indexCount);
          }

          // THE INDEX BUFFER, CLASSIFIED FROM ITS OWN BYTES. Every subtraction failed, so the triangles are
          // counted where they are: a triangle whose three vertices share a y is a CAP one, and one spanning
          // two y values is a WALL one. No arithmetic is assumed.
          //
          // The map is WHOLE-BUFFER, which is why the earlier six attempts failed to read a stride from it:
          //   $ grep -n 'dataOffset|dataStride' over the SDK's ModelIO headers
          //   (nothing)
          //   $ awk over @interface MDLMeshBufferMap
          //   @property (nonatomic, readonly) void *bytes;      <- one member, that is all
          // so the stride comes from the descriptor's layout, the position's offset from the attribute, and
          // the bytes from the buffer - the three typed reads, none of them a guess.
          for (int c = 0; c < 5; c++) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:radial[c] verticalSegments:vertical[c]
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLSubmesh *sm = cyl.submeshes.firstObject;
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              // MDLMeshBuffer is a PROTOCOL and MDLMeshBufferMap carries exactly one member, bytes: the map
              // is the WHOLE buffer, so there is no dataOffset on it to read, and the offset into it comes
              // from the layout and the attribute. Every name below is one the headers declare.
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              // THE STEP, and the bug was here. A vertex is at layout.stride*index BYTES from the start of
              // the buffer, plus the attribute s own offset. Dividing the stride by the format s component
              // count - which has no size property to read - put every read a third of the way into the
              // vertex, so the y printed was a normal or a texture coordinate. It is why one index carried
              // two y values and why the poles read 0.707 and 0.500 instead of plus and minus two.
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              // the y of the vertex an index names, in the units the mesh was built with
              #define posf(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              // The WIDTH comes from indexType and has to be read BEFORE the buffer is indexed. This
              // read the bytes as uint32 first and checked afterwards, so a sixteen-bit mesh indexed twice
              // as far and walked off the end: the host probe died part way through its answers and the
              // whole classification was reading garbage before it died.
              id<MDLMeshBuffer> ibuf = sm.indexBuffer;
              const void *ibytes = [ibuf map].bytes;
              unsigned wide = (sm.indexType == MDLIndexBitDepthUInt32) ? 4 : 2;
              #define CHARON_INDEX(i) ((wide == 4) ? ((const uint32_t *)ibytes)[i] : ((const uint16_t *)ibytes)[i])
              unsigned wall = 0, cap = 0, degenerate = 0;
              for (NSUInteger t = 0; t * 3 + 2 < sm.indexCount; t++) {
                  float y0 = posf(t * 3), y1 = posf(t * 3 + 1),
                        y2 = posf(t * 3 + 2);
                  int distinct = (y0 == y1) + (y1 == y2) + (y0 == y2);
                  if (distinct == 3)
                      degenerate++;
                  else if (distinct == 1)
                      cap++;
                  else
                      wall++;
              }
              put(@"cylinder s%d v%d wall %u cap %u degenerate %u", radial[c], vertical[c], wall, cap, degenerate);
          }

          // THE SANITY LINE, printed BEFORE any class is counted and asserted on both sides. A cylinder of
          // height 4 has its poles at -2 and +2, so the minimum and maximum y over the positions MUST be
          // that. The previous classification divided the stride by the format s component count and read a
          // third of the way into each vertex, so it saw normal and texture coordinates: one index carried two
          // different y values and the poles read 0.707 and 0.500. This line is what would have shown that,
          // and it is here so the next mis-stride is caught by a number rather than by a reader.
          for (int c = 0; c < 5; c++) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:radial[c] verticalSegments:vertical[c]
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              float lo = 1e30f, hi = -1e30f;
              for (unsigned i = 0; i < cyl.vertexCount; i++) {
                  float y = *(const float *)(base + layout.stride * i + pa.offset + sizeof(float));
                  if (y < lo) lo = y;
                  if (y > hi) hi = y;
              }
              put(@"sanity s%d v%d ymin %.4f ymax %.4f", radial[c], vertical[c], (double)lo, (double)hi);
          }

          // THE SWEEP, because five scattered points could not explain a cap sequence of 6, 9 and 8 at one
          // radial. Vertical 1 to 6 at radial 8, and radial 3 to 12 at vertical 2. Nothing is derived from
          // these; they are measurements, and the rule comes after they are recorded.
          for (int v = 1; v <= 6; v++) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:8 verticalSegments:v
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLSubmesh *sm = cyl.submeshes.firstObject;
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              #define posf(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              id<MDLMeshBuffer> ibuf = sm.indexBuffer;
              const void *ibytes = [ibuf map].bytes;
              unsigned wide = (sm.indexType == MDLIndexBitDepthUInt32) ? 4 : 2;
              unsigned wall = 0, cap = 0, deg = 0, pole = 0;
              for (NSUInteger t = 0; t * 3 + 2 < sm.indexCount; t++) {
                  NSUInteger i0 = (wide == 4) ? ((const uint32_t *)ibytes)[t*3] : ((const uint16_t *)ibytes)[t*3];
                  NSUInteger i1 = (wide == 4) ? ((const uint32_t *)ibytes)[t*3+1] : ((const uint16_t *)ibytes)[t*3+1];
                  NSUInteger i2 = (wide == 4) ? ((const uint32_t *)ibytes)[t*3+2] : ((const uint16_t *)ibytes)[t*3+2];
                  float y0 = posf(i0), y1 = posf(i1), y2 = posf(i2);
                  int distinct = (y0==y1)+(y1==y2)+(y0==y2);
                  if (distinct==3) deg++; else if (distinct==1) cap++; else wall++;
              }
              put(@"sweep radial 8 vertical %d vertices %lu indices %lu wall %u cap %u repeated %u atposition %u",
                  v, (unsigned long)cyl.vertexCount, (unsigned long)sm.indexCount, wall, cap, deg, pole);
          }

          // THE RADIAL SWEEP at vertical 2, and the vertical sweep repeated at radial 5, so the two
          // dependences are separated by measurement rather than by a form fitted to one of them.
          for (int r = 3; r <= 12; r++) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:r verticalSegments:2
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLSubmesh *sm = cyl.submeshes.firstObject;
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              #define posf(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              id<MDLMeshBuffer> ibuf = sm.indexBuffer;
              const void *ibytes = [ibuf map].bytes;
              unsigned wide = (sm.indexType == MDLIndexBitDepthUInt32) ? 4 : 2;
              unsigned w = 0, c = 0, dg = 0, po = 0;
              for (NSUInteger t = 0; t * 3 + 2 < sm.indexCount; t++) {
                  NSUInteger ix[3];
                  for (int k = 0; k < 3; k++)
                      ix[k] = (wide == 4) ? ((const uint32_t *)ibytes)[t*3+k] : ((const uint16_t *)ibytes)[t*3+k];
                  float y0 = posf(ix[0]), y1 = posf(ix[1]), y2 = posf(ix[2]);
                  int distinct = (y0==y1)+(y1==y2)+(y0==y2);
                  if (distinct == 1) {
                      float x0 = posx(ix[0]), x1 = posx(ix[1]), x2 = posx(ix[2]);
                      float z0 = posz(ix[0]), z1 = posz(ix[1]), z2 = posz(ix[2]);
                      int samePos = ((x0==x1)&&(y0==y1)&&(z0==z1))+((x1==x2)&&(y1==y2)&&(z1==z2))+((x0==x2)&&(y0==y2)&&(z0==z2));
                      int sameIdx = (ix[0]==ix[1])+(ix[1]==ix[2])+(ix[0]==ix[2]);
                      if (sameIdx) dg++; else if (samePos) po++; else c++;
                  } else if (distinct == 2) w++;
              }
              put(@"radial r%d vertical 2 vertices %lu indices %lu wall %u cap %u repeated %u atposition %u",
                  r, (unsigned long)cyl.vertexCount, (unsigned long)sm.indexCount, w, c, dg, po);
          }
          for (int v = 1; v <= 6; v++) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:5 verticalSegments:v
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLSubmesh *sm = cyl.submeshes.firstObject;
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              #define posf(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              id<MDLMeshBuffer> ibuf = sm.indexBuffer;
              const void *ibytes = [ibuf map].bytes;
              unsigned wide = (sm.indexType == MDLIndexBitDepthUInt32) ? 4 : 2;
              unsigned w = 0, c = 0, dg = 0, po = 0;
              for (NSUInteger t = 0; t * 3 + 2 < sm.indexCount; t++) {
                  NSUInteger ix[3];
                  for (int k = 0; k < 3; k++)
                      ix[k] = (wide == 4) ? ((const uint32_t *)ibytes)[t*3+k] : ((const uint16_t *)ibytes)[t*3+k];
                  float y0 = posf(ix[0]), y1 = posf(ix[1]), y2 = posf(ix[2]);
                  int distinct = (y0==y1)+(y1==y2)+(y0==y2);
                  if (distinct == 1) {
                      float x0 = posx(ix[0]), x1 = posx(ix[1]), x2 = posx(ix[2]);
                      float z0 = posz(ix[0]), z1 = posz(ix[1]), z2 = posz(ix[2]);
                      int samePos = ((x0==x1)&&(y0==y1)&&(z0==z1))+((x1==x2)&&(y1==y2)&&(z1==z2))+((x0==x2)&&(y0==y2)&&(z0==z2));
                      int sameIdx = (ix[0]==ix[1])+(ix[1]==ix[2])+(ix[0]==ix[2]);
                      if (sameIdx) dg++; else if (samePos) po++; else c++;
                  } else if (distinct == 2) w++;
              }
              put(@"second r5 v%d vertices %lu indices %lu wall %u cap %u repeated %u atposition %u",
                  v, (unsigned long)cyl.vertexCount, (unsigned long)sm.indexCount, w, c, dg, po);
          }

          // THE TRIANGULATION, printed as (ring, column) and not as counts. A ring is the y level, read from
          // the position; a column is the angle round the axis, from x and z. Printing the whole list at the
          // smallest sizes is the only way to see a triangulation: every count taken so far summed to the
          // right total while the wall and the caps traded places underneath it.
          // THE VERTICES, printed as (y level, column) and grouped by the y level, so the ring layout is
          // READ rather than inferred from a vertex count. A count of 22 with four columns is five rings plus
          // two centres ONLY IF the rings are those five, and this says which five.
          for (int c = 0; c < 3; c++) {
              static const int rr[3] = {3, 4, 3};
              static const int vv[3] = {2, 3, 1};
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:rr[c] verticalSegments:vv[c]
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              #define vx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define vy(i) (*(const float *)(base + step * (i) + pa.offset + sizeof(float)))
              #define vz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              NSMutableArray *levels = [NSMutableArray array];
              for (unsigned i = 0; i < cyl.vertexCount; i++) {
                  float y = vy(i);
                  BOOL seen = NO;
                  for (NSNumber *lv in levels)
                      if (fabsf([lv floatValue] - y) < 1e-4f) { seen = YES; break; }
                  if (!seen) [levels addObject:@(y)];
              }
              [levels sortUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
                  return [a floatValue] < [b floatValue] ? NSOrderedAscending : NSOrderedDescending; }];
              put(@"verts r%d v%d count %lu levels %lu", rr[c], vv[c],
                  (unsigned long)cyl.vertexCount, (unsigned long)levels.count);
              unsigned li = 0;
              for (NSNumber *lv in levels) {
                  NSMutableString *cols = [NSMutableString string];
                  unsigned n = 0;
                  for (unsigned i = 0; i < cyl.vertexCount; i++)
                      if (fabsf(vy(i) - [lv floatValue]) < 1e-4f) {
                          float a = atan2f(vz(i), vx(i));
                          NSInteger col = llroundf((a + (float)M_PI) / (2.0f * (float)M_PI) * (float)(rr[c] + 1));
                          [cols appendFormat:@"%@%ld", n ? @"," : @"", (long)col];
                          n++;
                      }
                  put(@"  level %u y %.4f count %u cols %@", li++, (double)[lv floatValue], n, cols);
              }
          }


          for (int c = 0; c < 4; c++) {
              static const int rr[4] = {3, 4, 5, 3};
              static const int vv[4] = {1, 1, 1, 2};
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:rr[c] verticalSegments:vv[c]
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLSubmesh *sm = cyl.submeshes.firstObject;
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              #define posx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posy(i) (*(const float *)(base + step * (i) + pa.offset + sizeof(float)))
              #define posz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              id<MDLMeshBuffer> ibuf = sm.indexBuffer;
              const void *ibytes = [ibuf map].bytes;
              unsigned wide = (sm.indexType == MDLIndexBitDepthUInt32) ? 4 : 2;
              for (NSUInteger t = 0; t * 3 + 2 < sm.indexCount; t++) {
                  NSUInteger ix[3];
                  for (int k = 0; k < 3; k++)
                      ix[k] = (wide == 4) ? ((const uint32_t *)ibytes)[t*3+k] : ((const uint16_t *)ibytes)[t*3+k];
                  NSMutableString *s = [NSMutableString string];
                  for (int k = 0; k < 3; k++) {
                      float y = posy(ix[k]);
                      float a = atan2f(posz(ix[k]), posx(ix[k]));
                      NSUInteger ring = llroundf((y + 2.0f) / 4.0f * (float)(vv[c] + 1));
                      NSInteger column = llroundf((a + (float)M_PI) / (2.0f * (float)M_PI) * (float)(rr[c] + 1));
                      [s appendFormat:@" (%lu,%ld)%@", (unsigned long)ring, (long)column,
                          k < 2 ? @"," : @""];
                  }
                  put(@"tri r%d v%d t%lu %@", rr[c], vv[c], (unsigned long)t, s);
              }
          }

          // THE DUMP, so the classes are READ. Every triangle that shares a y is printed with the vertex
          // indices behind it and the ring those indices sit in, so the cap fans and any third class are
          // grouped by what the indices say rather than inferred from a count. A y alone cannot tell a cap
          // from a ring change, and that is what made the last two fits disagree with the index totals:
          // the host s own wall+cap came to 117 against a total of 126 at v=6, so a third class exists and
          // this is what identifies it.
          for (int v = 1; v <= 6; v += 5) {
              MDLMesh *cyl = [MDLMesh newCylinderWithHeight:4 radii:(vector_float2){1, 1}
                              radialSegments:8 verticalSegments:v
                              geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
              MDLSubmesh *sm = cyl.submeshes.firstObject;
              MDLVertexDescriptor *vd = cyl.vertexDescriptor;
              MDLVertexAttribute *pa = [vd attributeNamed:MDLVertexAttributePosition];
              MDLVertexBufferLayout *layout = vd.layouts[pa.bufferIndex];
              id<MDLMeshBuffer> vbuf = cyl.vertexBuffers[pa.bufferIndex];
              const char *base = (const char *)[vbuf map].bytes;
              NSUInteger step = layout.stride;
              #define posf(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posx(i) (*(const float *)(base + step * (i) + pa.offset))
              #define posz(i) (*(const float *)(base + step * (i) + pa.offset + 2 * sizeof(float)))
              id<MDLMeshBuffer> ibuf = sm.indexBuffer;
              const void *ibytes = [ibuf map].bytes;
              unsigned wide = (sm.indexType == MDLIndexBitDepthUInt32) ? 4 : 2;
              // a ring has one vertex per column, and the row is the ring; the vertex layout holds
              // position, normal and texture coordinate, so a vertex is three position floats apart
              // a vertex is THREE position floats apart inside the record, and the record is step bytes: position,
              // normal, texture coordinate. So the ring a vertex sits in is index divided by that count.
              unsigned cols = (unsigned)(step / (3 * (pa.format == MDLVertexFormatFloat3 ? sizeof(float) : sizeof(float))));
              for (NSUInteger t = 0; t * 3 + 2 < sm.indexCount; t++) {
                  NSUInteger ix[3];
                  for (int k = 0; k < 3; k++)
                      ix[k] = (wide == 4) ? ((const uint32_t *)ibytes)[t*3+k] : ((const uint16_t *)ibytes)[t*3+k];
                  float y0 = posf(ix[0]), y1 = posf(ix[1]), y2 = posf(ix[2]);
                  int distinct = (y0==y1)+(y1==y2)+(y0==y2);
                  if (distinct == 1) {
                      NSUInteger col[3], row[3];
                      for (int k = 0; k < 3; k++) { col[k] = ix[k] % cols; row[k] = ix[k] / cols; }
                      put(@"dump v%d t%lu indices %lu %lu %lu cols %u rows %lu %lu %lu y %.3f",
                          v, (unsigned long)t, (unsigned long)ix[0], (unsigned long)ix[1], (unsigned long)ix[2],
                          cols + 1, (unsigned long)row[0], (unsigned long)row[1], (unsigned long)row[2],
                          (double)y0);
                  }
              }
          }
      }
}

static void reportSubmesh(void)
{
    MDLMeshBufferData *indices = [[MDLMeshBufferData alloc] initWithType:MDLMeshBufferTypeIndex data:
                                                    [NSData dataWithBytes:(uint32_t[]){0, 1, 2, 2, 1, 3} length:24]];
    NSMutableData *empty = [NSMutableData dataWithLength:4 * 32];
    MDLMeshBufferData *vertices = [[MDLMeshBufferData alloc] initWithType:MDLMeshBufferTypeVertex data:empty];
    MDLVertexDescriptor *descriptor = [[MDLVertexDescriptor alloc] init];
    [descriptor addOrReplaceAttribute:[[MDLVertexAttribute alloc] initWithName:MDLVertexAttributePosition
                                                                       format:MDLVertexFormatFloat3 offset:0 bufferIndex:0]];
    [descriptor.layouts addObject:[[MDLVertexBufferLayout alloc] initWithStride:32]];
    MDLSubmesh *submesh = [[MDLSubmesh alloc] initWithName:@"s" indexBuffer:indices indexCount:6
                                                   indexType:MDLIndexBitDepthUInt32 geometryType:MDLGeometryTypeTriangles
                                                   material:nil];
    MDLMesh *mesh = [[MDLMesh alloc] initWithVertexBuffers:@[vertices] vertexCount:4 descriptor:descriptor
                                                submeshes:@[submesh]];
    put(@"mesh vertices %lu submeshes %lu", (unsigned long)mesh.vertexCount, (unsigned long)mesh.submeshes.count);
    put_box(@"mesh", mesh.boundingBox);
    id<MDLMeshBuffer> narrow = [submesh indexBufferAsIndexType:MDLIndexBitDepthUInt16];
    put(@"submesh 16 bit buffer %@", narrow ? @"made" : @"none");
    if (narrow) {
        uint8_t *bytes = [narrow map].bytes;
        NSMutableData *out = [NSMutableData data];
        for (NSUInteger k = 0; k < 6; k++) {
            uint16_t value = 0;
            memcpy(&value, bytes + k * 2, 2);
            [out appendBytes:&value length:2];
        }
        put_bytes(@"submesh 16 bit", out);
    }
    put(@"mesh attributes %lu", (unsigned long)mesh.vertexDescriptor.attributes.count);
}

static void reportTexture(void)
{
    NSMutableData *texels = [NSMutableData dataWithLength:8 * 8 * 4];
    uint8_t *bytes = texels.mutableBytes;
    for (NSUInteger k = 0; k < 8 * 8 * 4; k++)
        bytes[k] = (uint8_t)(k * 7 + (k / 32));
    // The iOS header's initialiser has no isCube: and the macOS one has it as its designated one, so
    // each side is asked through the initialiser it declares and what is compared is the texels.
#if MDL_TEXTURE_TAKES_IS_CUBE
    MDLTexture *texture = [[MDLTexture alloc] initWithData:texels topLeftOrigin:NO name:@"t" dimensions:(vector_int2){8, 8}
                                                rowStride:32 channelCount:4 channelEncoding:MDLTextureChannelEncodingUInt8
                                                    isCube:NO];
#else
    MDLTexture *texture = [[MDLTexture alloc] initWithData:texels topLeftOrigin:NO name:@"t" dimensions:(vector_int2){8, 8}
                                                rowStride:32 channelCount:4 channelEncoding:MDLTextureChannelEncodingUInt8];
#endif
    put(@"texture dimensions %ld %ld stride %ld channels %lu mips %lu", (long)texture.dimensions.x, (long)texture.dimensions.y,
        (long)texture.rowStride, (unsigned long)texture.channelCount, (unsigned long)texture.mipLevelCount);
    put_bytes(@"texture bottom left", [texture texelDataWithBottomLeftOrigin]);
    put_bytes(@"texture top left", [texture texelDataWithTopLeftOrigin]);
    put(@"texture alpha %d cube %d", texture.hasAlphaValues, texture.isCube);
}

static void reportObjectAndVoxels(void)
{
    MDLObject *root = [[MDLObject alloc] init], *child = [[MDLObject alloc] init];
    root.name = @"root";
    child.name = @"child";
    [root addChild:child];
    put(@"object children %lu path %@", (unsigned long)root.children.count, child.path);
    put(@"object at path %d", [root objectAtPath:@"/root/child"] == child);
    put_box(@"object", [root boundingBoxAtTime:0]);

    // maxBounds first, as the struct declares it: a box of the unit cube is a maximum of one and a
    // minimum of zero, and written the other way round the framework rightly refuses it.
    MDLAxisAlignedBoundingBox box = {{1, 1, 1}, {0, 0, 0}};
    // The signed shell field of a 4x4x4 division, all of it empty: one byte per voxel, as the header
    // says the data is.
    NSMutableData *empty = [NSMutableData dataWithLength:2 * 2 * 2];
    MDLVoxelArray *host = nil;
    @try {
        host = [[MDLVoxelArray alloc] initWithData:empty boundingBox:box voxelExtent:0.5f];
    } @catch (NSException *exception) {
        put(@"voxels the array this side does not accept: %@: %@", exception.name, exception.reason);
        return;
    }
    [host setVoxelAtIndex:(MDLVoxelIndex){0, 0, 0}];
    [host setVoxelAtIndex:(MDLVoxelIndex){1, 1, 0}];
    put(@"voxels %lu", (unsigned long)host.count);
    MDLVoxelIndexExtent extent = host.voxelIndexExtent;
    put(@"voxel extent %ld %ld %ld to %ld %ld %ld", (long)extent.minimumExtent.x, (long)extent.minimumExtent.y,
        (long)extent.minimumExtent.z, (long)extent.maximumExtent.x, (long)extent.maximumExtent.y,
        (long)extent.maximumExtent.z);
    MDLVoxelIndex at = [host indexOfSpatialLocation:(vector_float3){0.9f, 0.6f, 0.4f}];
    put(@"voxel index %ld %ld %ld", (long)at.x, (long)at.y, (long)at.z);
    put3(@"voxel centre", [host spatialLocationOfIndex:(MDLVoxelIndex){1, 1, 1}]);
    MDLVoxelArray *other = [[MDLVoxelArray alloc] initWithData:[NSMutableData dataWithLength:2 * 2 * 2]
                                                     boundingBox:box voxelExtent:0.5f];
    [other setVoxelAtIndex:(MDLVoxelIndex){1, 1, 1}];
    [host unionWithVoxels:other];
    put(@"voxels after union %lu", (unsigned long)host.count);
    [host differenceWithVoxels:other];
    put(@"voxels after difference %lu", (unsigned long)host.count);
    put_bytes(@"voxel indices", [host voxelIndices]);
}

// The sharing rule of a generator, read off the counts: the vertex count and the index count of the
// same surface with its segments varied say where a vertex is shared and where one is not, and the
// box says the surface itself did not change.
static void reportSharing(void)
{
    static const NSUInteger radial[] = {3, 4, 6, 8, 12};
    static const NSUInteger vertical[] = {1, 2, 3, 6};
    for (size_t r = 0; r < sizeof radial / sizeof *radial; r++)
        for (size_t v = 0; v < sizeof vertical / sizeof *vertical; v++) {
            MDLMesh *ball = [MDLMesh newEllipsoidWithRadii:(vector_float3){1, 1, 1} radialSegments:radial[r]
                                               verticalSegments:vertical[v] geometryType:MDLGeometryTypeTriangles
                                               inwardNormals:NO hemisphere:NO allocator:nil];
            put(@"share ellipsoid r%lu v%lu vertices %lu indices %lu", (unsigned long)radial[r], (unsigned long)vertical[v],
                (unsigned long)ball.vertexCount, (unsigned long)ball.submeshes.firstObject.indexCount);
        }
    for (size_t r = 0; r < sizeof radial / sizeof *radial; r++)
        for (size_t v = 0; v < 2; v++) {
            MDLMesh *tube = [MDLMesh newCylinderWithHeight:2 radii:(vector_float2){1, 1} radialSegments:radial[r]
                                            verticalSegments:vertical[v] + 1 geometryType:MDLGeometryTypeTriangles
                                            inwardNormals:NO allocator:nil];
            put(@"share cylinder r%lu v%lu vertices %lu indices %lu", (unsigned long)radial[r], (unsigned long)(vertical[v] + 1),
                (unsigned long)tube.vertexCount, (unsigned long)tube.submeshes.firstObject.indexCount);
            MDLMesh *box = [MDLMesh newBoxWithDimensions:(vector_float3){2, 2, 2} segments:(vector_uint3){radial[r], vertical[v], 1}
                                             geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:nil];
            put(@"share box r%lu v%lu vertices %lu indices %lu", (unsigned long)radial[r], (unsigned long)vertical[v],
                (unsigned long)box.vertexCount, (unsigned long)box.submeshes.firstObject.indexCount);
        }
}

// The extent of a voxel's division, read off arrays of a known size: the count of the voxels, the
// extent the array reports, and what the box and the voxel size were.
static void reportVoxelRules(void)
{
    for (int along = 1; along <= 4; along++)
        for (int voxel = 1; voxel <= 2; voxel++) {
            MDLAxisAlignedBoundingBox box = {{along * voxel, along * voxel, along * voxel}, {0, 0, 0}};
            NSMutableData *field = [NSMutableData dataWithLength:(NSUInteger)(along * along * along)];
            @try {
                MDLVoxelArray *array = [[MDLVoxelArray alloc] initWithData:field boundingBox:box voxelExtent:(float)voxel];
                MDLVoxelIndexExtent extent = array.voxelIndexExtent;
                put(@"voxrule %ld voxels of %d data %lu extent %ld %ld %ld to %ld %ld %ld", (long)along, voxel,
                    (unsigned long)field.length, (long)extent.minimumExtent.x, (long)extent.minimumExtent.y,
                    (long)extent.minimumExtent.z, (long)extent.maximumExtent.x, (long)extent.maximumExtent.y,
                    (long)extent.maximumExtent.z);
            } @catch (NSException *exception) {
                put(@"voxrule %ld voxels of %d refused %@", (long)along, voxel, exception.reason);
            }
        }
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        NSString *directory = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : NSTemporaryDirectory();
        inputDirectory = directory;
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        writeOBJ([directory stringByAppendingPathComponent:@"cube.obj"]);
        writePLYAscii([directory stringByAppendingPathComponent:@"tri.ply"]);
    // The SAME file with the comment put back inside the face element s data, kept as its own fixture so
    // the divergence stays measured instead of being designed away. The system reads it as a point cloud -
    // 12 indices, geometry 0 - and the port reads the two triangles it plainly contains. Nothing in the port
    // encodes that, because the rule is position-dependent and one of its variants drops a face silently.
    writePLYAsciiWithMidDataComment([directory stringByAppendingPathComponent:@"tri-comment.ply"]);
        writePLYBinary([directory stringByAppendingPathComponent:@"tribin.ply"]);
        writeUSDA([directory stringByAppendingPathComponent:@"plate.usda"]);

        put(@"probe %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] ?: @"host");
        put(@"canImport obj %d ply %d usda %d usd %d", [MDLAsset canImportFileExtension:@"obj"],
            [MDLAsset canImportFileExtension:@"ply"], [MDLAsset canImportFileExtension:@"usda"],
            [MDLAsset canImportFileExtension:@"usd"]);
        guard(@"assets", ^{
            reportAsset(@"cube", @"obj");
            reportAsset(@"tri", @"ply");
            reportAsset(@"tribin", @"ply");
            report_image(@"MDLAsset");
              reportAsset(@"plate", @"usda");
        });
        guard(@"transform", ^{ report_image(@"MDLTransform"); reportTransform(); });
        guard(@"generators", ^{ report_image(@"MDLTransformStack");
              reportGenerators(); });
        guard(@"submesh", ^{ report_image(@"MDLSubmesh");
              reportSubmesh(); });
        guard(@"texture", ^{ report_image(@"MDLTexture"); reportTexture(); });
        guard(@"object", ^{ report_image(@"MDLVoxelArray");
              reportObjectAndVoxels(); });
        guard(@"sharing", ^{ report_image(@"MDLAnimatedScalar");
              reportSharing(); });
        guard(@"voxrule", ^{ report_image(@"MDLVoxelArray");
              reportVoxelRules(); });
    }
    return 0;
}
