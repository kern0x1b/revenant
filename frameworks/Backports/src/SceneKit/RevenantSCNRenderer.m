#import "RevenantSCN.h"
#import "RevenantSCNMath.h"
#import "../RevenantSayOnce.h"
#import "../RevenantSRGB.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

typedef NS_ENUM(int, RevenantSCNSlot) {
    RevenantSCNSlotDiffuse,
    RevenantSCNSlotAmbient,
    RevenantSCNSlotSpecular,
    RevenantSCNSlotEmission,
    RevenantSCNSlotMultiply,
    RevenantSCNSlotTransparent,
    RevenantSCNSlotSelfIllumination,
    RevenantSCNSlotMetalness,
    RevenantSCNSlotRoughness,
    RevenantSCNSlotCount
};

static const struct {
    const char *name;
    BOOL sRGB;
} RevenantSCNSlots[RevenantSCNSlotCount] = {
    {"diffuse", YES}, {"ambient", YES}, {"specular", YES}, {"emission", YES}, {"multiply", YES},
    {"transparent", NO}, {"selfIllumination", YES}, {"metalness", NO}, {"roughness", NO},
};

static SCNMaterialProperty *RevenantSCNSlotProperty(SCNMaterial *material, RevenantSCNSlot slot)
{
    switch (slot) {
    case RevenantSCNSlotDiffuse: return material.diffuse;
    case RevenantSCNSlotAmbient: return material.ambient;
    case RevenantSCNSlotSpecular: return material.specular;
    case RevenantSCNSlotEmission: return material.emission;
    case RevenantSCNSlotMultiply: return material.multiply;
    case RevenantSCNSlotTransparent: return material.transparent;
    case RevenantSCNSlotSelfIllumination: return material.selfIllumination;
    case RevenantSCNSlotMetalness: return material.metalness;
    case RevenantSCNSlotRoughness: return material.roughness;
    case RevenantSCNSlotCount: break;
    }
    return nil;
}

static uint16_t RevenantSCNHalf(float value)
{
    if (!(value > 0)) {
        return 0;
    }
    int exponent;
    float mantissa = frexpf(value, &exponent);
    float steps = exponent - 1 >= -14 ? ldexpf(mantissa, 11) : ldexpf(value, 24);
    uint32_t n = (uint32_t)lrintf(steps);
    if (exponent - 1 < -14) {
        return (uint16_t)n;
    }
    uint32_t biased = (uint32_t)(exponent - 1 + 15);
    if (n == 2048) {
        n = 1024;
        biased++;
    }
    return (uint16_t)((biased << 10) | (n - 1024));
}

static const double *RevenantSCNByteBounds(void)
{
    static double bounds[256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bounds[0] = -INFINITY;
        for (int b = 1; b < 256; b++) {
            bounds[b] = revenant_srgb_decode((b - 0.5) / 255.0);
        }
    });
    return bounds;
}

static uint8_t RevenantSCNByteOfLinear(double linear)
{
    const double *bounds = RevenantSCNByteBounds();
    int low = 0, high = 255;
    while (low < high) {
        int mid = (low + high + 1) / 2;
        if (bounds[mid] <= linear) {
            low = mid;
        } else {
            high = mid - 1;
        }
    }
    return (uint8_t)low;
}

static void RevenantSCNUploadLinearLevels(const uint8_t *pixels, size_t width, size_t height)
{
    size_t count = width * height;
    double *level = malloc(count * 4 * sizeof(double));
    uint16_t *halves = malloc(count * 4 * sizeof(uint16_t));
    for (size_t i = 0; i < count; i++) {
        double a = pixels[4 * i + 3] / 255.0;
        for (int k = 0; k < 3; k++) {
            level[4 * i + k] = a > 0 ? revenant_srgb_decode(pixels[4 * i + k] / 255.0 / a) * a : 0;
        }
        level[4 * i + 3] = a;
    }
    for (GLint n = 0;; n++) {
        for (size_t i = 0; i < 4 * width * height; i++) {
            halves[i] = RevenantSCNHalf((float)level[i]);
        }
        glTexImage2D(GL_TEXTURE_2D, n, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_HALF_FLOAT_OES, halves);
        if (width == 1 && height == 1) {
            break;
        }
        size_t half = width > 1 ? width / 2 : 1, rows = height > 1 ? height / 2 : 1;
        size_t sx = width > 1 ? 2 : 1, sy = height > 1 ? 2 : 1;
        for (size_t y = 0; y < rows; y++) {
            for (size_t x = 0; x < half; x++) {
                double sum[4] = {0, 0, 0, 0};
                for (size_t j = 0; j < sy; j++) {
                    for (size_t i = 0; i < sx; i++) {
                        const double *t = level + 4 * ((y * sy + j) * width + x * sx + i);
                        for (int k = 0; k < 4; k++) sum[k] += t[k];
                    }
                }
                double *out = level + 4 * (y * half + x);
                double a = sum[3] / (double)(sx * sy);
                double stored = floor(a * 255 + 0.5) / 255;
                for (int k = 0; k < 3; k++) {
                    double straight = a > 0 ? sum[k] / (double)(sx * sy) / a : 0;
                    out[k] = revenant_srgb_decode(RevenantSCNByteOfLinear(straight) / 255.0) * stored;
                }
                out[3] = stored;
            }
        }
        width = half;
        height = rows;
    }
    free(halves);
    free(level);
}

static BOOL RevenantSCNColorComponents(id contents, float out[4])
{
    CGColorRef color = NULL;
    if ([contents isKindOfClass:[UIColor class]]) {
        color = [(UIColor *)contents CGColor];
    } else if (contents && CFGetTypeID((__bridge CFTypeRef)contents) == CGColorGetTypeID()) {
        color = (__bridge CGColorRef)contents;
    }
    if (color) {
        const CGFloat *c = CGColorGetComponents(color);
        size_t count = CGColorGetNumberOfComponents(color);
        CGColorSpaceModel model = CGColorSpaceGetModel(CGColorGetColorSpace(color));
        if (model == kCGColorSpaceModelMonochrome && count == 2) {
            out[0] = out[1] = out[2] = c[0];
            out[3] = c[1];
            return YES;
        }
        if (model == kCGColorSpaceModelRGB && count == 4) {
            for (int i = 0; i < 4; i++) {
                out[i] = c[i];
            }
            return YES;
        }
        UIColor *converted = [UIColor colorWithCGColor:color];
        CGFloat r, g, b, a;
        if ([converted getRed:&r green:&g blue:&b alpha:&a]) {
            out[0] = r; out[1] = g; out[2] = b; out[3] = a;
            return YES;
        }
        return NO;
    }
    if ([contents isKindOfClass:[NSNumber class]]) {
        float v = [(NSNumber *)contents floatValue];
        out[0] = out[1] = out[2] = v;
        out[3] = 1;
        return YES;
    }
    return NO;
}

static void RevenantSCNSlotDefault(RevenantSCNSlot slot, float out[4])
{
    static SCNMaterial *fresh;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fresh = [SCNMaterial new];
    });
    if (!RevenantSCNColorComponents(RevenantSCNSlotProperty(fresh, slot).contents, out)) {
        out[0] = out[1] = out[2] = 0;
        out[3] = 1;
    }
}

#pragma mark - Images

static NSString *RevenantSCNImagePath(id contents, NSURL *sceneURL)
{
    if ([contents isKindOfClass:[NSURL class]]) {
        return [(NSURL *)contents path];
    }
    if (![contents isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *name = contents;
    if ([name isAbsolutePath] && [[NSFileManager defaultManager] fileExistsAtPath:name]) {
        return name;
    }
    NSString *file = [name lastPathComponent];
    NSString *beside = sceneURL ? [[[sceneURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:file] path] : nil;
    if (beside && [[NSFileManager defaultManager] fileExistsAtPath:beside]) {
        return beside;
    }
    return [[NSBundle mainBundle] pathForResource:[file stringByDeletingPathExtension] ofType:[file pathExtension]];
}

static CGImageRef RevenantSCNCreateImage(id contents, NSString *path)
{
    if ([contents isKindOfClass:[UIImage class]]) {
        return CGImageRetain([(UIImage *)contents CGImage]);
    }
    if (contents && CFGetTypeID((__bridge CFTypeRef)contents) == CGImageGetTypeID()) {
        return CGImageRetain((__bridge CGImageRef)contents);
    }
    if (path == nil) {
        return NULL;
    }
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    return image ? CGImageRetain(image.CGImage) : NULL;
}

@interface RevenantSCNTexture : NSObject
@property (nonatomic) GLuint name;
@property (nonatomic) BOOL hasAlpha;
@property (nonatomic) NSUInteger lastFrame;
@end

@implementation RevenantSCNTexture
@synthesize name = _name;
@synthesize hasAlpha = _hasAlpha;
@synthesize lastFrame = _lastFrame;
@end

#pragma mark - Geometry

@interface RevenantSCNDraw : NSObject
@property (nonatomic) GLenum mode;
@property (nonatomic) GLuint indexBuffer;
@property (nonatomic) GLenum indexType;
@property (nonatomic) GLsizei count;
@end

@implementation RevenantSCNDraw
@synthesize mode = _mode;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexType = _indexType;
@synthesize count = _count;
@end

typedef struct {
    GLuint buffer;
    GLint size;
    GLenum type;
    GLboolean normalized;
    GLsizei stride;
    GLintptr offset;
    BOOL present;
} RevenantSCNAttribute;

enum { RevenantSCNAttributePosition, RevenantSCNAttributeNormal, RevenantSCNAttributeColor, RevenantSCNAttributeUV0, RevenantSCNAttributeUV1, RevenantSCNAttributeCount };

@interface RevenantSCNMesh : NSObject
{
@public
    RevenantSCNAttribute _attributes[RevenantSCNAttributeCount];
}
@property (nonatomic, strong) NSArray<RevenantSCNDraw *> *draws;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *buffers;
@property (nonatomic) NSUInteger lastFrame;
@end

@implementation RevenantSCNMesh
@synthesize draws = _draws;
@synthesize buffers = _buffers;
@synthesize lastFrame = _lastFrame;
@end

static BOOL RevenantSCNAttributeFor(SCNGeometrySource *source, RevenantSCNAttribute *out, NSMutableArray<NSNumber *> *buffers)
{
    NSData *data = source.data;
    if (data.length == 0 || source.componentsPerVector < 1 || source.componentsPerVector > 4) {
        return NO;
    }
    GLenum type;
    if (source.floatComponents) {
        if (source.bytesPerComponent != 4) {
            return NO;
        }
        type = GL_FLOAT;
    } else if (source.bytesPerComponent == 1) {
        type = GL_UNSIGNED_BYTE;
    } else if (source.bytesPerComponent == 2) {
        type = GL_SHORT;
    } else {
        return NO;
    }
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)data.length, data.bytes, GL_STATIC_DRAW);
    [buffers addObject:@(buffer)];
    out->buffer = buffer;
    out->size = (GLint)source.componentsPerVector;
    out->type = type;
    out->normalized = type != GL_FLOAT;
    out->stride = (GLsizei)(source.dataStride ?: source.componentsPerVector * source.bytesPerComponent);
    out->offset = source.dataOffset;
    out->present = YES;
    return YES;
}

static uint32_t RevenantSCNIndex(const uint8_t *bytes, NSInteger bytesPerIndex, NSUInteger i)
{
    switch (bytesPerIndex) {
    case 1: return bytes[i];
    case 2: { uint16_t v; memcpy(&v, bytes + i * 2, 2); return v; }
    default: { uint32_t v; memcpy(&v, bytes + i * 4, 4); return v; }
    }
}

static RevenantSCNDraw *RevenantSCNDrawFor(SCNGeometryElement *element, NSMutableArray<NSNumber *> *buffers)
{
    NSData *data = element.data;
    const uint8_t *bytes = data.bytes;
    NSInteger width = element.bytesPerIndex;
    NSInteger primitives = element.primitiveCount;
    if (data.length == 0 || primitives <= 0 || (width != 1 && width != 2 && width != 4)) {
        return nil;
    }
    NSUInteger available = data.length / (NSUInteger)width;
    NSMutableData *indices = [NSMutableData data];
    GLenum mode;
    switch (element.primitiveType) {
    case SCNGeometryPrimitiveTypeTriangles:
        mode = GL_TRIANGLES;
        for (NSUInteger i = 0; i < (NSUInteger)primitives * 3 && i < available; i++) {
            uint32_t v = RevenantSCNIndex(bytes, width, i);
            [indices appendBytes:&v length:4];
        }
        break;
    case SCNGeometryPrimitiveTypeTriangleStrip:
        mode = GL_TRIANGLE_STRIP;
        for (NSUInteger i = 0; i < (NSUInteger)primitives + 2 && i < available; i++) {
            uint32_t v = RevenantSCNIndex(bytes, width, i);
            [indices appendBytes:&v length:4];
        }
        break;
    case SCNGeometryPrimitiveTypeLine:
        mode = GL_LINES;
        for (NSUInteger i = 0; i < (NSUInteger)primitives * 2 && i < available; i++) {
            uint32_t v = RevenantSCNIndex(bytes, width, i);
            [indices appendBytes:&v length:4];
        }
        break;
    case SCNGeometryPrimitiveTypePoint:
        mode = GL_POINTS;
        for (NSUInteger i = 0; i < (NSUInteger)primitives && i < available; i++) {
            uint32_t v = RevenantSCNIndex(bytes, width, i);
            [indices appendBytes:&v length:4];
        }
        break;
    case SCNGeometryPrimitiveTypePolygon: {
        mode = GL_TRIANGLES;
        if ((NSUInteger)primitives > available) {
            return nil;
        }
        NSUInteger cursor = (NSUInteger)primitives;
        for (NSInteger p = 0; p < primitives; p++) {
            uint32_t count = RevenantSCNIndex(bytes, width, (NSUInteger)p);
            if (cursor + count > available) {
                return nil;
            }
            uint32_t first = RevenantSCNIndex(bytes, width, cursor);
            for (uint32_t k = 1; k + 1 < count; k++) {
                uint32_t b = RevenantSCNIndex(bytes, width, cursor + k), c = RevenantSCNIndex(bytes, width, cursor + k + 1);
                [indices appendBytes:&first length:4];
                [indices appendBytes:&b length:4];
                [indices appendBytes:&c length:4];
            }
            cursor += count;
        }
        break;
    }
    default:
        return nil;
    }
    NSUInteger count = indices.length / 4;
    if (count == 0) {
        return nil;
    }
    const uint32_t *wide = indices.bytes;
    uint32_t largest = 0;
    for (NSUInteger i = 0; i < count; i++) {
        largest = wide[i] > largest ? wide[i] : largest;
    }
    RevenantSCNDraw *draw = [RevenantSCNDraw new];
    draw.mode = mode;
    draw.count = (GLsizei)count;
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, buffer);
    if (largest <= 0xffff) {
        NSMutableData *narrow = [NSMutableData dataWithLength:count * 2];
        uint16_t *out = narrow.mutableBytes;
        for (NSUInteger i = 0; i < count; i++) {
            out[i] = (uint16_t)wide[i];
        }
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)narrow.length, narrow.bytes, GL_STATIC_DRAW);
        draw.indexType = GL_UNSIGNED_SHORT;
    } else {
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)indices.length, indices.bytes, GL_STATIC_DRAW);
        draw.indexType = GL_UNSIGNED_INT;
    }
    [buffers addObject:@(buffer)];
    draw.indexBuffer = buffer;
    return draw;
}

#pragma mark - Programs

typedef NS_ENUM(int, RevenantSCNModel) {
    RevenantSCNModelConstant,
    RevenantSCNModelLambert,
    RevenantSCNModelBlinn,
    RevenantSCNModelPhong,
    RevenantSCNModelPhysicallyBased,
};

static RevenantSCNModel RevenantSCNModelFor(SCNMaterial *material)
{
    NSString *name = material.lightingModelName;
    if ([name isEqualToString:SCNLightingModelConstant]) return RevenantSCNModelConstant;
    if ([name isEqualToString:SCNLightingModelLambert]) return RevenantSCNModelLambert;
    if ([name isEqualToString:SCNLightingModelPhong]) return RevenantSCNModelPhong;
    if ([name isEqualToString:SCNLightingModelPhysicallyBased]) return RevenantSCNModelPhysicallyBased;
    return RevenantSCNModelBlinn;
}

enum { RevenantSCNLightDirectional, RevenantSCNLightOmni, RevenantSCNLightSpot };
enum { RevenantSCNMaxLights = 8 };

typedef struct {
    int type;
    float color[3];
    float position[3];
    float direction[3];
    float attenuation[3];
    float spot[2];
} RevenantSCNLightState;

@interface RevenantSCNShaderProgram : NSObject
{
@public
    GLuint _program;
    GLint _modelViewProjection, _model, _normalMatrix, _cameraPosition, _coatView, _ambientLight, _opacity, _transparency;
    GLint _slotValue[RevenantSCNSlotCount], _slotSampler[RevenantSCNSlotCount], _slotTransform[RevenantSCNSlotCount];
    GLint _lightColor[RevenantSCNMaxLights], _lightPosition[RevenantSCNMaxLights], _lightDirection[RevenantSCNMaxLights];
    GLint _lightAttenuation[RevenantSCNMaxLights], _lightSpot[RevenantSCNMaxLights];
    GLint _shininess, _implicitLight;
}
@end

@implementation RevenantSCNShaderProgram
@end

static GLuint RevenantSCNCompile(GLenum kind, NSString *source)
{
    GLuint shader = glCreateShader(kind);
    const char *text = source.UTF8String;
    glShaderSource(shader, 1, &text, NULL);
    glCompileShader(shader);
    GLint ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[2048];
        glGetShaderInfoLog(shader, sizeof(log), NULL, log);
        NSLog(@"SceneKit: a generated shader does not compile: %s\n%@", log, source);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

SCNMatrix4 RevenantSCNProjectionMatrix(SCNNode *pointOfView, int width, int height)
{
    SCNCamera *camera = pointOfView.camera;
    float aspect = (float)width / (float)height;
    float zNear = camera ? camera.zNear : 1, zFar = camera ? camera.zFar : 100;
    SCNMatrix4 projection;
    memset(&projection, 0, sizeof(projection));
    if (camera.usesOrthographicProjection) {
        float scale = camera.orthographicScale;
        projection.m11 = 1 / (scale * aspect);
        projection.m22 = 1 / scale;
        projection.m33 = -2 / (zFar - zNear);
        projection.m43 = -(zFar + zNear) / (zFar - zNear);
        projection.m44 = 1;
    } else {
        float fov = camera ? camera.fieldOfView : 60;
        float f = 1 / tanf(fov * (float)M_PI / 360);
        projection.m11 = f / aspect;
        projection.m22 = f;
        projection.m33 = (zFar + zNear) / (zNear - zFar);
        projection.m34 = -1;
        projection.m43 = 2 * zFar * zNear / (zNear - zFar);
    }
    return projection;
}

@implementation RevenantSCNRenderEngine
{
    EAGLContext *_context;
    NSMapTable<SCNGeometry *, RevenantSCNMesh *> *_meshes;
    NSMapTable<id, RevenantSCNTexture *> *_textures[2];
    int _linearTextures;
    NSMutableDictionary<NSString *, RevenantSCNShaderProgram *> *_programs;
    NSMutableDictionary<NSString *, id> *_resolvedPaths;
    NSMutableSet<NSString *> *_failedPrograms;
    NSUInteger _frame;
    NSURL *_sceneURL;
    NSHashTable<SCNScene *> *_surveyed;
}
@synthesize lastRenderPointOfView = _lastRenderPointOfView, lastRenderWidth = _lastRenderWidth, lastRenderHeight = _lastRenderHeight;
@synthesize jitterX = _jitterX, jitterY = _jitterY;
@synthesize autoenablesDefaultLighting = _autoenablesDefaultLighting;

- (instancetype)initWithContext:(EAGLContext *)context
{
    if ((self = [super init])) {
        _context = context;
        _meshes = [NSMapTable strongToStrongObjectsMapTable];
        _textures[0] = [NSMapTable strongToStrongObjectsMapTable];
        _textures[1] = [NSMapTable strongToStrongObjectsMapTable];
        _linearTextures = -1;
        _programs = [NSMutableDictionary dictionary];
        _resolvedPaths = [NSMutableDictionary dictionary];
        _failedPrograms = [NSMutableSet set];
        _surveyed = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (void)dealloc
{
    EAGLContext *previous = [EAGLContext currentContext];
    if ([EAGLContext setCurrentContext:_context]) {
        for (RevenantSCNMesh *mesh in [_meshes objectEnumerator]) {
            [self deleteMesh:mesh];
        }
        for (int sRGB = 0; sRGB < 2; sRGB++) {
            for (RevenantSCNTexture *texture in [_textures[sRGB] objectEnumerator]) {
                GLuint name = texture.name;
                glDeleteTextures(1, &name);
            }
        }
        for (RevenantSCNShaderProgram *program in _programs.allValues) {
            glDeleteProgram(program->_program);
        }
    }
    [EAGLContext setCurrentContext:previous];
}

- (void)deleteMesh:(RevenantSCNMesh *)mesh
{
    for (NSNumber *number in mesh.buffers) {
        GLuint buffer = number.unsignedIntValue;
        glDeleteBuffers(1, &buffer);
    }
    mesh.buffers = nil;
}

+ (SCNNode *)defaultPointOfViewInScene:(SCNScene *)scene
{
    NSMutableArray<SCNNode *> *queue = [NSMutableArray arrayWithObject:scene.rootNode];
    while (queue.count) {
        SCNNode *node = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (node.camera) {
            return node;
        }
        [queue addObjectsFromArray:node.childNodes];
    }
    return nil;
}

#pragma mark Resources

- (RevenantSCNMesh *)meshFor:(SCNGeometry *)geometry
{
    RevenantSCNMesh *mesh = [_meshes objectForKey:geometry];
    if (mesh) {
        mesh.lastFrame = _frame;
        return mesh;
    }
    mesh = [RevenantSCNMesh new];
    mesh.buffers = [NSMutableArray array];
    SCNGeometrySource *position = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticVertex].firstObject;
    if (position == nil || !RevenantSCNAttributeFor(position, &mesh->_attributes[RevenantSCNAttributePosition], mesh.buffers)) {
        NSLog(@"SceneKit: geometry %@ has no vertex source this renderer can read", geometry.name);
        mesh.draws = @[];
    } else {
        SCNGeometrySource *normal = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticNormal].firstObject;
        SCNGeometrySource *color = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticColor].firstObject;
        NSArray<SCNGeometrySource *> *texcoords = [geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticTexcoord];
        NSMutableArray *sources = [NSMutableArray array];
        if (normal) [sources addObject:@[normal, @(RevenantSCNAttributeNormal)]];
        if (color) [sources addObject:@[color, @(RevenantSCNAttributeColor)]];
        for (NSUInteger channel = 0; channel < texcoords.count && channel < 2; channel++) {
            [sources addObject:@[texcoords[channel], @(RevenantSCNAttributeUV0 + channel)]];
        }
        for (NSArray *pair in sources) {
            SCNGeometrySource *source = pair[0];
            if (!RevenantSCNAttributeFor(source, &mesh->_attributes[[pair[1] intValue]], mesh.buffers)) {
                NSLog(@"SceneKit: geometry %@ has a %@ source this renderer cannot read (%ld components of %ld bytes, float %d)",
                      geometry.name, source.semantic, (long)source.componentsPerVector, (long)source.bytesPerComponent, source.floatComponents);
            }
        }
        NSMutableArray<RevenantSCNDraw *> *draws = [NSMutableArray array];
        for (SCNGeometryElement *element in geometry.geometryElements) {
            RevenantSCNDraw *draw = RevenantSCNDrawFor(element, mesh.buffers);
            if (draw == nil) {
                NSLog(@"SceneKit: geometry %@ has an element this renderer cannot draw (type %ld, %ld primitives, %ld bytes per index, %lu bytes)",
                      geometry.name, (long)element.primitiveType, (long)element.primitiveCount, (long)element.bytesPerIndex, (unsigned long)element.data.length);
            }
            [draws addObject:draw ?: (id)[NSNull null]];
        }
        mesh.draws = (NSArray *)draws;
    }
    mesh.lastFrame = _frame;
    [_meshes setObject:mesh forKey:geometry];
    return mesh;
}

- (NSString *)pathForContents:(id)contents
{
    if (![contents isKindOfClass:[NSString class]] && ![contents isKindOfClass:[NSURL class]]) {
        return nil;
    }
    NSString *memo = [NSString stringWithFormat:@"%@\n%@", _sceneURL.path ?: @"", contents];
    id path = _resolvedPaths[memo];
    if (path == nil) {
        path = RevenantSCNImagePath(contents, _sceneURL) ?: (id)[NSNull null];
        _resolvedPaths[memo] = path;
    }
    return path == [NSNull null] ? nil : path;
}

- (BOOL)materialBlends:(SCNMaterial *)material
{
    if (RevenantSCNModelFor(material) != RevenantSCNModelPhysicallyBased && material.transparency < 1) {
        return YES;
    }
    const RevenantSCNSlot alphaSlots[] = {RevenantSCNSlotDiffuse, RevenantSCNSlotTransparent};
    for (int i = 0; i < 2; i++) {
        RevenantSCNSlot slot = alphaSlots[i];
        id contents = RevenantSCNSlotProperty(material, slot).contents;
        BOOL hasAlpha = NO;
        float colour[4];
        if ([self textureFor:contents sRGB:RevenantSCNSlots[slot].sRGB hasAlpha:&hasAlpha] ? hasAlpha : (RevenantSCNColorComponents(contents, colour) && colour[3] < 1)) {
            return YES;
        }
    }
    return NO;
}

- (GLuint)textureFor:(id)contents sRGB:(BOOL)sRGB hasAlpha:(BOOL *)hasAlpha
{
    *hasAlpha = NO;
    if (contents == nil || RevenantSCNColorComponents(contents, (float[4]){0})) {
        return 0;
    }
    NSString *path = [self pathForContents:contents];
    id key = path ?: contents;
    RevenantSCNTexture *texture = [_textures[sRGB] objectForKey:key];
    if (texture) {
        texture.lastFrame = _frame;
        *hasAlpha = texture.hasAlpha;
        return texture.name;
    }
    texture = [RevenantSCNTexture new];
    texture.lastFrame = _frame;
    [_textures[sRGB] setObject:texture forKey:key];
    CGImageRef image = RevenantSCNCreateImage(contents, path);
    if (image == NULL) {
        NSLog(@"SceneKit: no image for material contents %@", contents);
        return 0;
    }
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image);
    texture.hasAlpha = alpha != kCGImageAlphaNone && alpha != kCGImageAlphaNoneSkipFirst && alpha != kCGImageAlphaNoneSkipLast;
    *hasAlpha = texture.hasAlpha;
    size_t width = 1, height = 1;
    while (width < CGImageGetWidth(image)) width <<= 1;
    while (height < CGImageGetHeight(image)) height <<= 1;
    NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    CGContextSetBlendMode(bitmap, kCGBlendModeCopy);
    CGContextSetInterpolationQuality(bitmap, kCGInterpolationHigh);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image);
    CGContextRelease(bitmap);
    CGImageRelease(image);
    GLuint name;
    glGenTextures(1, &name);
    glBindTexture(GL_TEXTURE_2D, name);
    if (sRGB && [self linearTextures]) {
        RevenantSCNUploadLinearLevels(pixels.bytes, width, height);
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels.bytes);
        glGenerateMipmap(GL_TEXTURE_2D);
    }
    texture.name = name;
    return name;
}

- (BOOL)linearTextures
{
    if (_linearTextures < 0) {
        NSString *extensions = [NSString stringWithUTF8String:(const char *)glGetString(GL_EXTENSIONS) ?: ""];
        NSArray<NSString *> *names = [extensions componentsSeparatedByString:@" "];
        _linearTextures = [names containsObject:@"GL_OES_texture_half_float"] && [names containsObject:@"GL_OES_texture_half_float_linear"];
        if (!_linearTextures) {
            revenant_say_once_for(@"linear textures", @"SceneKit: this GPU filters no half-float texture: images in colour slots are mipmapped and filtered in their sRGB encoding, not in linear light as SceneKit does");
        }
    }
    return _linearTextures;
}

- (void)purgeUnused
{
    for (int sRGB = 0; sRGB < 2; sRGB++) {
        for (id key in [[_textures[sRGB] keyEnumerator] allObjects]) {
            RevenantSCNTexture *texture = [_textures[sRGB] objectForKey:key];
            if (texture && _frame - texture.lastFrame > 120) {
                GLuint name = texture.name;
                glDeleteTextures(1, &name);
                [_textures[sRGB] removeObjectForKey:key];
            }
        }
    }
    for (id key in [[_meshes keyEnumerator] allObjects]) {
        RevenantSCNMesh *mesh = [_meshes objectForKey:key];
        if (mesh && _frame - mesh.lastFrame > 120) {
            [self deleteMesh:mesh];
            [_meshes removeObjectForKey:key];
        }
    }
}

#pragma mark Shaders

- (RevenantSCNShaderProgram *)programForModel:(RevenantSCNModel)model textured:(unsigned)textured bordered:(unsigned)bordered lockedAmbient:(BOOL)lockedAmbient lights:(const RevenantSCNLightState *)lights count:(int)count mesh:(RevenantSCNMesh *)mesh
{
    BOOL hasNormal = mesh->_attributes[RevenantSCNAttributeNormal].present;
    BOOL hasColor = mesh->_attributes[RevenantSCNAttributeColor].present;
    BOOL hasUV0 = mesh->_attributes[RevenantSCNAttributeUV0].present, hasUV1 = mesh->_attributes[RevenantSCNAttributeUV1].present;
    NSMutableString *key = [NSMutableString stringWithFormat:@"m%d t%x b%x a%d n%d c%d u%d%d l", model, textured, bordered, lockedAmbient, hasNormal, hasColor, hasUV0, hasUV1];
    for (int i = 0; i < count; i++) {
        [key appendFormat:@"%d", lights[i].type];
    }
    RevenantSCNShaderProgram *program = _programs[key];
    if (program) {
        return program;
    }
    if ([_failedPrograms containsObject:key]) {
        return nil;
    }

    NSMutableString *vertex = [NSMutableString string];
    [vertex appendString:@"attribute highp vec3 a_position;\nattribute highp vec3 a_normal;\nattribute mediump vec4 a_color;\n"
                          "attribute highp vec2 a_uv0;\nattribute highp vec2 a_uv1;\n"
                          "uniform highp mat4 u_modelViewProjection;\nuniform highp mat4 u_model;\nuniform highp mat3 u_normalMatrix;\n"
                          "varying highp vec3 v_position;\nvarying highp vec3 v_normal;\nvarying mediump vec4 v_color;\n"
                          "varying highp vec2 v_uv0;\nvarying highp vec2 v_uv1;\n"
                          "void main() {\n"
                          "  gl_Position = u_modelViewProjection * vec4(a_position, 1.0);\n"
                          "  v_position = (u_model * vec4(a_position, 1.0)).xyz;\n"];
    [vertex appendString:hasNormal ? @"  v_normal = u_normalMatrix * a_normal;\n" : @"  v_normal = vec3(0.0);\n"];
    [vertex appendString:hasColor ? @"  v_color = a_color;\n" : @"  v_color = vec4(1.0);\n"];
    [vertex appendString:hasUV0 ? @"  v_uv0 = a_uv0;\n" : @"  v_uv0 = vec2(0.0);\n"];
    [vertex appendString:hasUV1 ? @"  v_uv1 = a_uv1;\n" : @"  v_uv1 = v_uv0;\n"];
    [vertex appendString:@"}\n"];

    NSMutableString *fragment = [NSMutableString string];
    [fragment appendString:@"precision highp float;\nprecision highp sampler2D;\n"
                            "varying highp vec3 v_position;\nvarying highp vec3 v_normal;\nvarying mediump vec4 v_color;\n"
                            "varying highp vec2 v_uv0;\nvarying highp vec2 v_uv1;\n"
                            "uniform vec3 u_cameraPosition;\nuniform vec4 u_coatView;\nuniform vec3 u_ambientLight;\nuniform float u_opacity;\nuniform float u_transparency;\n"
                            "uniform float u_shininess;\nuniform float u_implicitLight;\n"
                            "vec3 revenantLinear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }\n"
                            "vec3 revenantEncode(vec3 l) { l = clamp(l, 0.0, 1.0); return mix(l * 12.92, 1.055 * pow(l, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), l)); }\n"];
    for (int slot = 0; slot < RevenantSCNSlotCount; slot++) {
        const char *name = RevenantSCNSlots[slot].name;
        if (textured & (1u << slot)) {
            [fragment appendFormat:@"uniform sampler2D u_%s_sampler;\nuniform vec4 u_%s_value;\nuniform mat3 u_%s_transform;\n", name, name, name];
            [fragment appendFormat:@"vec4 revenant_%s(vec2 uv0, vec2 uv1, float channel) {\n"
                                    "  vec2 uv = (u_%s_transform * vec3(channel > 0.5 ? uv1 : uv0, 1.0)).xy;\n", name, name];
            if (bordered & (1u << (2 * slot))) {
                [fragment appendString:@"  if (uv.x < 0.0 || uv.x > 1.0) return vec4(0.0);\n"];
            }
            if (bordered & (1u << (2 * slot + 1))) {
                [fragment appendString:@"  if (uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);\n"];
            }
            [fragment appendFormat:@"  vec4 t = texture2D(u_%s_sampler, uv);\n"
                                    "  vec3 c = t.a > 0.0 ? t.rgb / t.a : vec3(0.0);\n", name];
            [fragment appendString:RevenantSCNSlots[slot].sRGB && ![self linearTextures] ? @"  c = revenantLinear(c);\n" : @""];
            [fragment appendFormat:@"  return vec4(c, t.a) * u_%s_value;\n}\n", name];
        } else {
            [fragment appendFormat:@"uniform vec4 u_%s_value;\n", name];
        }
    }
    for (int i = 0; i < count; i++) {
        [fragment appendFormat:@"uniform vec3 u_light%d_color;\nuniform vec3 u_light%d_position;\nuniform vec3 u_light%d_direction;\n"
                                "uniform vec3 u_light%d_attenuation;\nuniform vec2 u_light%d_spot;\n", i, i, i, i, i];
    }
    [fragment appendString:@"void main() {\n"];
    for (int slot = 0; slot < RevenantSCNSlotCount; slot++) {
        const char *name = RevenantSCNSlots[slot].name;
        if (textured & (1u << slot)) {
            [fragment appendFormat:@"  vec4 %s = revenant_%s(v_uv0, v_uv1, u_%s_transform[2][2]);\n", name, name, name];
        } else {
            [fragment appendFormat:@"  vec4 %s = u_%s_value;\n", name, name];
        }
    }
    if (lockedAmbient) {
        [fragment appendString:@"  ambient = diffuse;\n"];
    }
    [fragment appendString:@"  diffuse *= v_color;\n"
                            "  vec3 N = length(v_normal) > 0.0 ? normalize(v_normal) : vec3(0.0);\n"
                            "  vec3 V = normalize(u_cameraPosition - v_position);\n"
                            "  vec3 color = vec3(0.0);\n"];
    if (model == RevenantSCNModelPhysicallyBased) {
        [fragment appendString:@"  float metal = clamp(metalness.r, 0.0, 1.0);\n"
                                "  float alpha = roughness.r * roughness.r;\n"
                                "  float a2 = alpha * alpha;\n"
                                "  vec3 albedo = diffuse.rgb;\n"
                                "  vec3 diffuseColor = albedo * (1.0 - metal);\n"
                                "  vec3 f0 = mix(vec3(0.04), albedo, metal);\n"
                                "  float NdotV = max(dot(N, V), 0.0001);\n"
                                "  float coatNdotV = max(dot(N, normalize(u_coatView.xyz - u_coatView.w * v_position)), 0.0001);\n"
                                "  float grazing = clamp(1.0 - coatNdotV, 0.0, 1.0);\n"
                                "  float grazing2 = grazing * grazing;\n"
                                "  float roughSquared = clamp(roughness.r, 0.0, 1.0) * clamp(roughness.r, 0.0, 1.0);\n"
                                "  vec3 coat = (1.0 - roughSquared) * max(1.0 - 1.140 * grazing2 * grazing2 * grazing, 0.0) +\n"
                                "              roughSquared * (0.709 + 0.124 * grazing2 + 0.367 * diffuseColor);\n"
                                "  color += albedo * u_ambientLight + diffuseColor * selfIllumination.rgb * coat;\n"];
    } else {
        [fragment appendString:@"  vec3 lightDiffuse = vec3(0.0);\n  vec3 lightSpecular = vec3(0.0);\n"];
    }
    for (int i = 0; i < count; i++) {
        int type = lights[i].type;
        [fragment appendString:@"  {\n"];
        if (type == RevenantSCNLightDirectional) {
            [fragment appendFormat:@"    vec3 L = -u_light%d_direction;\n    vec3 radiance = u_light%d_color;\n", i, i];
        } else {
            [fragment appendFormat:@"    vec3 toLight = u_light%d_position - v_position;\n    float d = length(toLight);\n    vec3 L = toLight / d;\n", i];
            if (model == RevenantSCNModelPhysicallyBased) {
                [fragment appendFormat:@"    vec3 radiance = u_light%d_color / (d * d);\n"
                                        "    if (u_light%d_attenuation.y > 0.0) {\n"
                                        "      float w = clamp(1.0 - pow(d / u_light%d_attenuation.y, 4.0), 0.0, 1.0);\n"
                                        "      radiance *= w * w;\n"
                                        "    }\n", i, i, i];
            } else {
                [fragment appendFormat:@"    vec3 radiance = u_light%d_color;\n"
                                        "    if (u_light%d_attenuation.y > u_light%d_attenuation.x) {\n"
                                        "      radiance *= pow(clamp((u_light%d_attenuation.y - d) / (u_light%d_attenuation.y - u_light%d_attenuation.x), 0.0, 1.0), u_light%d_attenuation.z);\n"
                                        "    }\n", i, i, i, i, i, i, i];
            }
            if (type == RevenantSCNLightSpot) {
                [fragment appendFormat:@"    radiance *= clamp((dot(-L, u_light%d_direction) - u_light%d_spot.x) / max(u_light%d_spot.y - u_light%d_spot.x, 0.0001), 0.0, 1.0);\n", i, i, i, i];
            }
        }
        [fragment appendString:@"    float NdotL = max(dot(N, L), 0.0);\n"];
        if (model == RevenantSCNModelPhysicallyBased) {
            [fragment appendString:@"    if (NdotL > 0.0) {\n"
                                    "      vec3 H = normalize(L + V);\n"
                                    "      float NdotH = max(dot(N, H), 0.0);\n"
                                    "      float VdotH = max(dot(V, H), 0.0);\n"
                                    "      float dd = NdotH * NdotH * (a2 - 1.0) + 1.0;\n"
                                    "      float D = a2 / (dd * dd);\n"
                                    "      float visibility = 0.5 / (NdotL * sqrt(NdotV * NdotV * (1.0 - a2) + a2) + NdotV * sqrt(NdotL * NdotL * (1.0 - a2) + a2));\n"
                                    "      vec3 F = f0 + (1.0 - f0) * pow(1.0 - VdotH, 5.0);\n"
                                    "      color += radiance * NdotL * (diffuseColor + D * visibility * F);\n"
                                    "    }\n"];
        } else if (model != RevenantSCNModelConstant) {
            [fragment appendString:@"    lightDiffuse += radiance * NdotL;\n"];
            if (model == RevenantSCNModelBlinn) {
                [fragment appendString:@"    if (NdotL > 0.0) lightSpecular += radiance * NdotL * pow(max(dot(N, normalize(L + V)), 0.0), 128.0 * u_shininess);\n"];
            } else if (model == RevenantSCNModelPhong) {
                [fragment appendString:@"    if (NdotL > 0.0) lightSpecular += radiance * NdotL * pow(max(dot(reflect(-L, N), V), 0.0), 128.0 * u_shininess);\n"];
            }
        }
        [fragment appendString:@"  }\n"];
    }
    if (model == RevenantSCNModelConstant) {
        [fragment appendString:@"  color = diffuse.rgb;\n"];
    } else if (model != RevenantSCNModelPhysicallyBased) {
        [fragment appendString:@"  lightDiffuse += mix(selfIllumination.rgb, vec3(1.0), u_implicitLight);\n"
                                "  color = ambient.rgb * u_ambientLight + diffuse.rgb * lightDiffuse + specular.rgb * lightSpecular;\n"];
    }
    [fragment appendString:@"  color += emission.rgb;\n"
                            "  color *= multiply.rgb;\n"
                            "  float outAlpha = u_opacity;\n"];
    if (model == RevenantSCNModelPhysicallyBased) {
        [fragment appendString:@"  outAlpha *= transparent.a * diffuse.a;\n"];
    } else {
        [fragment appendString:@"  outAlpha *= u_transparency * transparent.a * diffuse.a * diffuse.a;\n"];
    }
    [fragment appendString:@"  gl_FragColor = vec4(revenantEncode(color * outAlpha), outAlpha);\n}\n"];

    GLuint vs = RevenantSCNCompile(GL_VERTEX_SHADER, vertex), fs = RevenantSCNCompile(GL_FRAGMENT_SHADER, fragment);
    if (vs == 0 || fs == 0) {
        glDeleteShader(vs);
        glDeleteShader(fs);
        [_failedPrograms addObject:key];
        return nil;
    }
    GLuint handle = glCreateProgram();
    glAttachShader(handle, vs);
    glAttachShader(handle, fs);
    glBindAttribLocation(handle, RevenantSCNAttributePosition, "a_position");
    glBindAttribLocation(handle, RevenantSCNAttributeNormal, "a_normal");
    glBindAttribLocation(handle, RevenantSCNAttributeColor, "a_color");
    glBindAttribLocation(handle, RevenantSCNAttributeUV0, "a_uv0");
    glBindAttribLocation(handle, RevenantSCNAttributeUV1, "a_uv1");
    glLinkProgram(handle);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint linked = 0;
    glGetProgramiv(handle, GL_LINK_STATUS, &linked);
    if (!linked) {
        char log[2048];
        glGetProgramInfoLog(handle, sizeof(log), NULL, log);
        NSLog(@"SceneKit: a generated program does not link: %s", log);
        glDeleteProgram(handle);
        [_failedPrograms addObject:key];
        return nil;
    }
    program = [RevenantSCNShaderProgram new];
    program->_program = handle;
    program->_modelViewProjection = glGetUniformLocation(handle, "u_modelViewProjection");
    program->_model = glGetUniformLocation(handle, "u_model");
    program->_normalMatrix = glGetUniformLocation(handle, "u_normalMatrix");
    program->_cameraPosition = glGetUniformLocation(handle, "u_cameraPosition");
    program->_coatView = glGetUniformLocation(handle, "u_coatView");
    program->_ambientLight = glGetUniformLocation(handle, "u_ambientLight");
    program->_opacity = glGetUniformLocation(handle, "u_opacity");
    program->_transparency = glGetUniformLocation(handle, "u_transparency");
    program->_shininess = glGetUniformLocation(handle, "u_shininess");
    program->_implicitLight = glGetUniformLocation(handle, "u_implicitLight");
    for (int slot = 0; slot < RevenantSCNSlotCount; slot++) {
        const char *name = RevenantSCNSlots[slot].name;
        program->_slotValue[slot] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_%s_value", name].UTF8String);
        program->_slotSampler[slot] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_%s_sampler", name].UTF8String);
        program->_slotTransform[slot] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_%s_transform", name].UTF8String);
    }
    for (int i = 0; i < count; i++) {
        program->_lightColor[i] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_light%d_color", i].UTF8String);
        program->_lightPosition[i] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_light%d_position", i].UTF8String);
        program->_lightDirection[i] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_light%d_direction", i].UTF8String);
        program->_lightAttenuation[i] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_light%d_attenuation", i].UTF8String);
        program->_lightSpot[i] = glGetUniformLocation(handle, [NSString stringWithFormat:@"u_light%d_spot", i].UTF8String);
    }
    _programs[key] = program;
    return program;
}

#pragma mark What is not drawn

static BOOL RevenantSCNPropertyShows(SCNMaterialProperty *property, BOOL alphaMatters)
{
    id contents = property.contents;
    if (contents == nil || property.intensity == 0) {
        return NO;
    }
    float c[4];
    if (!RevenantSCNColorComponents(contents, c)) {
        return YES;
    }
    return alphaMatters ? c[3] > 0 : (c[0] > 0 || c[1] > 0 || c[2] > 0);
}

static BOOL RevenantSCNPropertyIsImage(SCNMaterialProperty *property)
{
    float c[4];
    return property.contents != nil && !RevenantSCNColorComponents(property.contents, c);
}

- (void)surveyScene:(SCNScene *)scene
{
    if ([_surveyed containsObject:scene]) {
        return;
    }
    [_surveyed addObject:scene];
    NSString *title = [scene revenantSourceURL].lastPathComponent ?: [NSString stringWithFormat:@"%p", scene];
    void (^say)(NSString *, NSString *) = ^(NSString *what, NSString *text) {
        revenant_say_once_for([NSString stringWithFormat:@"scenekit %p %@", scene, what], [NSString stringWithFormat:@"SceneKit: %@: %@", title, text]);
    };
    if (RevenantSCNPropertyShows(scene.background, YES)) {
        say(@"background", @"the scene's background is not drawn");
    }
    if (RevenantSCNPropertyShows(scene.lightingEnvironment, YES)) {
        say(@"environment", @"the scene's lighting environment is not drawn");
    }
    NSMutableArray<SCNNode *> *queue = [NSMutableArray arrayWithObject:scene.rootNode];
    NSUInteger particleSystems = 0;
    NSMutableArray<NSString *> *emitters = [NSMutableArray array];
    while (queue.count) {
        SCNNode *node = queue.lastObject;
        [queue removeLastObject];
        [queue addObjectsFromArray:node.childNodes];
        NSString *name = node.name ?: @"(unnamed)";
        if (node.particleSystems.count) {
            particleSystems += node.particleSystems.count;
            [emitters addObject:name];
        }
        SCNLight *light = node.light;
        if (light) {
            NSString *type = light.type;
            if (![@[SCNLightTypeAmbient, SCNLightTypeDirectional, SCNLightTypeOmni, SCNLightTypeSpot] containsObject:type]) {
                say([@"light type " stringByAppendingString:name],
                    [NSString stringWithFormat:@"node %@ has a light of type %@; it is not drawn, and a node lit only by lights like it is drawn unlit", name, type]);
            }
            if (light.castsShadow) {
                say([@"shadow " stringByAppendingString:name], [NSString stringWithFormat:@"node %@: the light's shadow is not drawn", name]);
            }
            if (light.temperature != 6500) {
                say([@"temperature " stringByAppendingString:name], [NSString stringWithFormat:@"node %@: the light's temperature %g is not applied", name, light.temperature]);
            }
        }
        SCNGeometry *geometry = node.geometry;
        if (geometry.subdivisionLevel > 0) {
            say([NSString stringWithFormat:@"subdivision %@", name],
                [NSString stringWithFormat:@"node %@ asks for subdivision level %lu; it is drawn unsubdivided", name, (unsigned long)geometry.subdivisionLevel]);
        }
        for (SCNMaterial *material in geometry.materials) {
            NSString *where = [NSString stringWithFormat:@"node %@, material %@", name, material.name ?: @"(unnamed)"];
            NSString *model = material.lightingModelName;
            if (![@[SCNLightingModelConstant, SCNLightingModelLambert, SCNLightingModelBlinn, SCNLightingModelPhong, SCNLightingModelPhysicallyBased] containsObject:model]) {
                say([@"model " stringByAppendingString:where], [NSString stringWithFormat:@"%@: the lighting model %@ is drawn as Blinn", where, model]);
            }
            if (material.blendMode != SCNBlendModeAlpha) {
                say([@"blend " stringByAppendingString:where], [NSString stringWithFormat:@"%@: the blend mode %ld is drawn as alpha", where, (long)material.blendMode]);
            }
            if (RevenantSCNPropertyShows(material.clearCoat, NO)) {
                say([@"clearCoat " stringByAppendingString:where], [where stringByAppendingString:@": the clear coat is not drawn"]);
            }
            if (RevenantSCNPropertyIsImage(material.normal)) {
                say([@"normal " stringByAppendingString:where], [where stringByAppendingString:@": the normal map is not drawn"]);
            }
            if (RevenantSCNPropertyIsImage(material.ambientOcclusion)) {
                say([@"occlusion " stringByAppendingString:where], [where stringByAppendingString:@": the ambient occlusion map is not drawn"]);
            }
            if (RevenantSCNPropertyShows(material.reflective, NO)) {
                say([@"reflective " stringByAppendingString:where], [where stringByAppendingString:@": the reflective slot is not drawn"]);
            }
            if (RevenantSCNPropertyIsImage(material.displacement)) {
                say([@"displacement " stringByAppendingString:where], [where stringByAppendingString:@": the displacement map is not drawn"]);
            }
        }
    }
    if (particleSystems) {
        say(@"particles", [NSString stringWithFormat:@"%lu particle systems on %@ are not drawn", (unsigned long)particleSystems,
                                                    [emitters componentsJoinedByString:@", "]]);
    }
}

#pragma mark Drawing

typedef struct {
    __unsafe_unretained SCNNode *node;
    __unsafe_unretained SCNGeometry *geometry;
    SCNMatrix4 world;
    float opacity;
    float depth;
    BOOL transparent;
} RevenantSCNItem;

static void RevenantSCNCollect(SCNNode *node, SCNMatrix4 parent, float opacity, NSMutableData *items, NSMutableArray<SCNNode *> *lights)
{
    if (node.hidden) {
        return;
    }
    SCNMatrix4 world = RevenantSCNMatrixMultiply([node revenantPresentedTransform], parent);
    opacity *= [node revenantPresentedOpacity];
    if (node.light) {
        [lights addObject:node];
    }
    if (node.geometry) {
        RevenantSCNItem item = {node, node.geometry, world, opacity, 0, NO};
        [items appendBytes:&item length:sizeof(item)];
    }
    for (SCNNode *child in node.childNodes) {
        RevenantSCNCollect(child, world, opacity, items, lights);
    }
}

static void RevenantSCNLightColor(SCNLight *light, float scale, float out[3])
{
    float c[4] = {1, 1, 1, 1};
    RevenantSCNColorComponents(light.color, c);
    for (int i = 0; i < 3; i++) {
        out[i] = (float)revenant_srgb_decode(c[i]) * scale;
    }
}

- (BOOL)prepareObject:(id)object shouldAbortBlock:(BOOL (^)(void))block
{
    if (block && block()) {
        return NO;
    }
    if ([object isKindOfClass:[SCNScene class]]) {
        return [self prepareObject:((SCNScene *)object).rootNode shouldAbortBlock:block];
    }
    if ([object isKindOfClass:[SCNNode class]]) {
        SCNNode *node = object;
        if (node.geometry && ![self prepareObject:node.geometry shouldAbortBlock:block]) {
            return NO;
        }
        for (SCNNode *child in node.childNodes) {
            if (![self prepareObject:child shouldAbortBlock:block]) {
                return NO;
            }
        }
        return YES;
    }
    if ([object isKindOfClass:[SCNGeometry class]]) {
        return [self meshFor:object] != nil;
    }
    if ([object isKindOfClass:[SCNMaterial class]]) {
        SCNMaterial *material = object;
        for (int slot = 0; slot < RevenantSCNSlotCount; slot++) {
            BOOL hasAlpha = NO;
            [self textureFor:RevenantSCNSlotProperty(material, (RevenantSCNSlot)slot).contents sRGB:RevenantSCNSlots[slot].sRGB hasAlpha:&hasAlpha];
        }
        return YES;
    }
    if ([object isKindOfClass:[SCNMaterialProperty class]]) {
        BOOL hasAlpha = NO;
        [self textureFor:((SCNMaterialProperty *)object).contents sRGB:NO hasAlpha:&hasAlpha];
        return YES;
    }
    return NO;
}

- (void)renderScene:(SCNScene *)scene pointOfView:(SCNNode *)pointOfView width:(int)width height:(int)height
{
    _frame++;
    _sceneURL = [scene revenantSourceURL];
    glViewport(0, 0, width, height);
    if (scene == nil || width <= 0 || height <= 0) {
        return;
    }
    [self surveyScene:scene];
    NSMutableData *itemData = [NSMutableData data];
    NSMutableArray<SCNNode *> *lightNodes = [NSMutableArray array];
    RevenantSCNCollect(scene.rootNode, SCNMatrix4Identity, 1, itemData, lightNodes);

    SCNMatrix4 cameraWorld = pointOfView ? [pointOfView revenantPresentedWorldTransform] : SCNMatrix4Identity;
    SCNMatrix4 view = RevenantSCNMatrixInvert(cameraWorld);
    SCNCamera *camera = pointOfView.camera;
    SCNMatrix4 projection = RevenantSCNProjectionMatrix(pointOfView, width, height);
    if (self.jitterX != 0 || self.jitterY != 0) {
        SCNMatrix4 shift = SCNMatrix4Identity;
        shift.m41 = 2 * self.jitterX / width;
        shift.m42 = 2 * self.jitterY / height;
        projection = RevenantSCNMatrixMultiply(projection, shift);
    }
    self.lastRenderPointOfView = pointOfView;
    self.lastRenderWidth = width;
    self.lastRenderHeight = height;
    SCNMatrix4 viewProjection = RevenantSCNMatrixMultiply(view, projection);
    float cameraPosition[3] = {cameraWorld.m41, cameraWorld.m42, cameraWorld.m43};
    float coatView[4] = {cameraWorld.m41, cameraWorld.m42, cameraWorld.m43, 1};
    if (camera.usesOrthographicProjection) {
        float axisLength = sqrtf(cameraWorld.m31 * cameraWorld.m31 + cameraWorld.m32 * cameraWorld.m32 + cameraWorld.m33 * cameraWorld.m33);
        coatView[0] = cameraWorld.m31 / axisLength, coatView[1] = cameraWorld.m32 / axisLength, coatView[2] = cameraWorld.m33 / axisLength, coatView[3] = 0;
    }

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);

    RevenantSCNItem *items = itemData.mutableBytes;
    NSUInteger itemCount = itemData.length / sizeof(RevenantSCNItem);
    for (NSUInteger i = 0; i < itemCount; i++) {
        SCNMatrix4 clip = RevenantSCNMatrixMultiply(items[i].world, viewProjection);
        items[i].depth = clip.m44 != 0 ? clip.m43 / clip.m44 : clip.m43;
        items[i].transparent = items[i].opacity < 1;
        for (SCNMaterial *material in items[i].geometry.materials) {
            items[i].transparent = items[i].transparent || [self materialBlends:material];
        }
    }
    NSMutableArray<NSValue *> *order = [NSMutableArray array];
    for (NSUInteger i = 0; i < itemCount; i++) {
        [order addObject:@(i)];
    }
    [order sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        RevenantSCNItem *x = &items[a.unsignedIntegerValue], *y = &items[b.unsignedIntegerValue];
        if (x->node.renderingOrder != y->node.renderingOrder) {
            return x->node.renderingOrder < y->node.renderingOrder ? NSOrderedAscending : NSOrderedDescending;
        }
        if (x->transparent != y->transparent) {
            return x->transparent ? NSOrderedDescending : NSOrderedAscending;
        }
        if (x->transparent && x->depth != y->depth) {
            return x->depth > y->depth ? NSOrderedAscending : NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    for (NSNumber *index in order) {
        RevenantSCNItem *item = &items[((NSNumber *)index).unsignedIntegerValue];
        [self drawItem:item viewProjection:viewProjection cameraPosition:cameraPosition coatView:coatView lights:lightNodes];
    }
    glDisable(GL_BLEND);
    glDepthMask(GL_TRUE);
    if (_frame % 60 == 0) {
        [self purgeUnused];
    }
}

- (void)drawItem:(RevenantSCNItem *)item viewProjection:(SCNMatrix4)viewProjection cameraPosition:(const float *)cameraPosition coatView:(const float *)coatView lights:(NSArray<SCNNode *> *)lightNodes
{
    SCNGeometry *geometry = item->geometry;
    RevenantSCNMesh *mesh = [self meshFor:geometry];
    if (mesh.draws.count == 0) {
        return;
    }
    NSArray<SCNMaterial *> *materials = geometry.materials;
    SCNMatrix4 world = item->world;
    SCNMatrix4 modelViewProjection = RevenantSCNMatrixMultiply(world, viewProjection);
    SCNMatrix4 inverse = RevenantSCNMatrixInvert(world);
    float normalMatrix[9] = {inverse.m11, inverse.m21, inverse.m31, inverse.m12, inverse.m22, inverse.m32, inverse.m13, inverse.m23, inverse.m33};

    NSUInteger nodeCategory = item->node.categoryBitMask;
    for (NSUInteger e = 0; e < mesh.draws.count; e++) {
        RevenantSCNDraw *draw = (id)mesh.draws[e];
        if ((id)draw == [NSNull null]) {
            continue;
        }
        SCNMaterial *material = materials.count ? materials[e % materials.count] : nil;
        if (material == nil) {
            material = [SCNMaterial material];
        }
        RevenantSCNModel model = RevenantSCNModelFor(material);
        BOOL physical = model == RevenantSCNModelPhysicallyBased;

        float ambient[3] = {0, 0, 0};
        RevenantSCNLightState lights[RevenantSCNMaxLights];
        int lightCount = 0;
        for (SCNNode *lightNode in lightNodes) {
            SCNLight *light = lightNode.light;
            if ((light.categoryBitMask & nodeCategory) == 0) {
                continue;
            }
            NSString *type = light.type;
            if ([type isEqualToString:SCNLightTypeAmbient]) {
                float c[3];
                RevenantSCNLightColor(light, (float)light.intensity / 1000, c);
                for (int k = 0; k < 3; k++) ambient[k] += c[k];
                continue;
            }
            int kind;
            if ([type isEqualToString:SCNLightTypeDirectional]) {
                kind = RevenantSCNLightDirectional;
            } else if ([type isEqualToString:SCNLightTypeSpot]) {
                kind = RevenantSCNLightSpot;
            } else if ([type isEqualToString:SCNLightTypeOmni]) {
                kind = RevenantSCNLightOmni;
            } else {
                continue;
            }
            if (lightCount == RevenantSCNMaxLights) {
                revenant_say_once_for([NSString stringWithFormat:@"scenekit lights %p", item->node],
                                    [NSString stringWithFormat:@"SceneKit: node %@ is reached by more than %d lights; %@ and the rest are not drawn", item->node.name, RevenantSCNMaxLights, lightNode.name]);
                continue;
            }
            RevenantSCNLightState *state = &lights[lightCount++];
            state->type = kind;
            float scale = (physical && kind != RevenantSCNLightDirectional) ? (float)light.intensity / (float)M_PI : (float)light.intensity / 1000;
            RevenantSCNLightColor(light, scale, state->color);
            SCNMatrix4 lw = [lightNode revenantPresentedWorldTransform];
            state->position[0] = lw.m41; state->position[1] = lw.m42; state->position[2] = lw.m43;
            float dx = -lw.m31, dy = -lw.m32, dz = -lw.m33, length = sqrtf(dx * dx + dy * dy + dz * dz);
            if (length == 0) length = 1;
            state->direction[0] = dx / length; state->direction[1] = dy / length; state->direction[2] = dz / length;
            state->attenuation[0] = light.attenuationStartDistance;
            state->attenuation[1] = light.attenuationEndDistance;
            state->attenuation[2] = light.attenuationFalloffExponent;
            state->spot[0] = cosf((float)light.spotOuterAngle * (float)M_PI / 360);
            state->spot[1] = cosf((float)light.spotInnerAngle * (float)M_PI / 360);
        }

        unsigned textured = 0, bordered = 0;
        GLuint textures[RevenantSCNSlotCount] = {0};
        for (int slot = 0; slot < RevenantSCNSlotCount; slot++) {
            SCNMaterialProperty *property = RevenantSCNSlotProperty(material, (RevenantSCNSlot)slot);
            BOOL hasAlpha = NO;
            textures[slot] = [self textureFor:property.contents sRGB:RevenantSCNSlots[slot].sRGB hasAlpha:&hasAlpha];
            if (textures[slot]) {
                textured |= 1u << slot;
                bordered |= (property.wrapS == SCNWrapModeClampToBorder ? 1u : 0u) << (2 * slot);
                bordered |= (property.wrapT == SCNWrapModeClampToBorder ? 1u : 0u) << (2 * slot + 1);
            }
        }
        BOOL lockedAmbient = !physical && material.locksAmbientWithDiffuse;
        RevenantSCNShaderProgram *program = [self programForModel:model textured:textured bordered:bordered lockedAmbient:lockedAmbient lights:lights count:lightCount mesh:mesh];
        if (program == nil) {
            continue;
        }
        glUseProgram(program->_program);
        glUniformMatrix4fv(program->_modelViewProjection, 1, GL_FALSE, &modelViewProjection.m11);
        glUniformMatrix4fv(program->_model, 1, GL_FALSE, &world.m11);
        glUniformMatrix3fv(program->_normalMatrix, 1, GL_FALSE, normalMatrix);
        glUniform3fv(program->_cameraPosition, 1, cameraPosition);
        glUniform4fv(program->_coatView, 1, coatView);
        glUniform3fv(program->_ambientLight, 1, ambient);
        glUniform1f(program->_opacity, item->opacity);
        glUniform1f(program->_transparency, (float)material.transparency);
        glUniform1f(program->_shininess, (float)material.shininess);
        glUniform1f(program->_implicitLight, (lightCount == 0 && self.autoenablesDefaultLighting) ? 1 : 0);
        GLint unit = 0;
        for (int slot = 0; slot < RevenantSCNSlotCount; slot++) {
            SCNMaterialProperty *property = RevenantSCNSlotProperty(material, (RevenantSCNSlot)slot);
            float value[4];
            float intensity = (float)property.intensity;
            if (textures[slot]) {
                value[0] = value[1] = value[2] = intensity;
                value[3] = 1;
                glActiveTexture(GL_TEXTURE0 + unit);
                glBindTexture(GL_TEXTURE_2D, textures[slot]);
                [self applySampling:property];
                glUniform1i(program->_slotSampler[slot], unit++);
                SCNMatrix4 t = [property revenantPresentedContentsTransform];
                float uv[9] = {t.m11, t.m12, 0, t.m21, t.m22, 0, t.m41, t.m42, property.mappingChannel > 0 ? 1 : 0};
                glUniformMatrix3fv(program->_slotTransform[slot], 1, GL_FALSE, uv);
            } else {
                BOOL encoded = RevenantSCNSlots[slot].sRGB || property.revenantHoldsDefault;
                if (!RevenantSCNColorComponents(property.contents, value)) {
                    RevenantSCNSlotDefault((RevenantSCNSlot)slot, value);
                    encoded = YES;
                }
                if (encoded) {
                    for (int k = 0; k < 3; k++) value[k] = (float)revenant_srgb_decode(value[k]);
                }
                for (int k = 0; k < 3; k++) value[k] *= intensity;
            }
            glUniform4fv(program->_slotValue[slot], 1, value);
        }
        for (int i = 0; i < lightCount; i++) {
            glUniform3fv(program->_lightColor[i], 1, lights[i].color);
            glUniform3fv(program->_lightPosition[i], 1, lights[i].position);
            glUniform3fv(program->_lightDirection[i], 1, lights[i].direction);
            glUniform3fv(program->_lightAttenuation[i], 1, lights[i].attenuation);
            glUniform2fv(program->_lightSpot[i], 1, lights[i].spot);
        }

        for (int a = 0; a < RevenantSCNAttributeCount; a++) {
            RevenantSCNAttribute *attribute = &mesh->_attributes[a];
            if (attribute->present) {
                glBindBuffer(GL_ARRAY_BUFFER, attribute->buffer);
                glVertexAttribPointer((GLuint)a, attribute->size, attribute->type, attribute->normalized, attribute->stride, (const GLvoid *)attribute->offset);
                glEnableVertexAttribArray((GLuint)a);
            } else {
                glDisableVertexAttribArray((GLuint)a);
            }
        }

        if (item->transparent || [self materialBlends:material]) {
            glEnable(GL_BLEND);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        } else {
            glDisable(GL_BLEND);
        }
        glDepthMask(material.writesToDepthBuffer ? GL_TRUE : GL_FALSE);
        if (material.readsFromDepthBuffer) {
            glEnable(GL_DEPTH_TEST);
        } else {
            glDisable(GL_DEPTH_TEST);
        }
        if (material.doubleSided) {
            glDisable(GL_CULL_FACE);
        } else {
            glEnable(GL_CULL_FACE);
            glCullFace(material.cullMode == SCNCullModeFront ? GL_FRONT : GL_BACK);
        }
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, draw.indexBuffer);
        glDrawElements(draw.mode, draw.count, draw.indexType, NULL);
    }
}

- (void)applySampling:(SCNMaterialProperty *)property
{
    GLenum wrap[2];
    SCNWrapMode modes[2] = {property.wrapS, property.wrapT};
    for (int i = 0; i < 2; i++) {
        wrap[i] = modes[i] == SCNWrapModeRepeat ? GL_REPEAT : modes[i] == SCNWrapModeMirror ? GL_MIRRORED_REPEAT : GL_CLAMP_TO_EDGE;
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, (GLint)wrap[0]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, (GLint)wrap[1]);
    GLint magnify = property.magnificationFilter == SCNFilterModeNearest ? GL_NEAREST : GL_LINEAR;
    GLint minify;
    BOOL nearest = property.minificationFilter == SCNFilterModeNearest;
    switch (property.mipFilter) {
    case SCNFilterModeNearest: minify = nearest ? GL_NEAREST_MIPMAP_NEAREST : GL_LINEAR_MIPMAP_NEAREST; break;
    case SCNFilterModeLinear: minify = nearest ? GL_NEAREST_MIPMAP_LINEAR : GL_LINEAR_MIPMAP_LINEAR; break;
    default: minify = nearest ? GL_NEAREST : GL_LINEAR; break;
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magnify);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minify);
}

@end
