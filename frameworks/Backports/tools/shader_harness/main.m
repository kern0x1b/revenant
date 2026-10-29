#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef REVENANT_ANGLE_LIB
#define REVENANT_ANGLE_LIB "."
#endif

#define W 64
#define H 64
#define TEX 8
#define TOLERANCE 2
#define VERTICES 6

static const float QUAD_XY[VERTICES][2] = {{-1, -1}, {1, -1}, {-1, 1}, {1, -1}, {1, 1}, {-1, 1}};
static const float QUAD_UV[VERTICES][2] = {{0, 1}, {1, 1}, {0, 0}, {1, 1}, {1, 0}, {0, 0}};

typedef unsigned int GLenum, GLuint, GLbitfield;
typedef int GLint, GLsizei;
typedef unsigned char GLboolean;
typedef void *EGLDisplay, *EGLConfig, *EGLContext, *EGLSurface;
typedef int EGLint;
typedef unsigned int EGLenum, EGLBoolean;

enum {
    EGL_NONE = 0x3038, EGL_SURFACE_TYPE = 0x3033, EGL_PBUFFER_BIT = 0x0001, EGL_RENDERABLE_TYPE = 0x3040,
    EGL_OPENGL_ES2_BIT = 0x0004, EGL_RED_SIZE = 0x3024, EGL_GREEN_SIZE = 0x3023, EGL_BLUE_SIZE = 0x3022,
    EGL_ALPHA_SIZE = 0x3021, EGL_WIDTH = 0x3057, EGL_HEIGHT = 0x3056, EGL_CONTEXT_CLIENT_VERSION = 0x3098,
    EGL_PLATFORM_ANGLE_ANGLE = 0x3202, EGL_PLATFORM_ANGLE_TYPE_ANGLE = 0x3203,
    EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE = 0x3489, EGL_VENDOR = 0x3053,
};

enum {
    GL_NO_ERROR = 0, GL_FLOAT = 0x1406, GL_UNSIGNED_BYTE = 0x1401, GL_RGBA = 0x1908, GL_TRIANGLES = 0x0004,
    GL_COLOR_BUFFER_BIT = 0x4000, GL_TEXTURE_2D = 0x0DE1, GL_TEXTURE0 = 0x84C0, GL_LINEAR = 0x2601,
    GL_TEXTURE_MAG_FILTER = 0x2800, GL_TEXTURE_MIN_FILTER = 0x2801, GL_TEXTURE_WRAP_S = 0x2802,
    GL_TEXTURE_WRAP_T = 0x2803, GL_CLAMP_TO_EDGE = 0x812F, GL_FRAGMENT_SHADER = 0x8B30,
    GL_VERTEX_SHADER = 0x8B31, GL_COMPILE_STATUS = 0x8B81, GL_LINK_STATUS = 0x8B82, GL_INFO_LOG_LENGTH = 0x8B84,
};

typedef struct {
    void *(*eglGetPlatformDisplayEXT)(EGLenum, void *, const EGLint *);
    EGLBoolean (*eglInitialize)(EGLDisplay, EGLint *, EGLint *);
    const char *(*eglQueryString)(EGLDisplay, EGLint);
    EGLBoolean (*eglChooseConfig)(EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *);
    EGLSurface (*eglCreatePbufferSurface)(EGLDisplay, EGLConfig, const EGLint *);
    EGLContext (*eglCreateContext)(EGLDisplay, EGLConfig, EGLContext, const EGLint *);
    EGLBoolean (*eglMakeCurrent)(EGLDisplay, EGLSurface, EGLSurface, EGLContext);
    void (*glViewport)(GLint, GLint, GLsizei, GLsizei);
    void (*glClearColor)(float, float, float, float);
    void (*glClear)(GLbitfield);
    GLuint (*glCreateShader)(GLenum);
    void (*glShaderSource)(GLuint, GLsizei, const char *const *, const GLint *);
    void (*glCompileShader)(GLuint);
    void (*glGetShaderiv)(GLuint, GLenum, GLint *);
    void (*glGetShaderInfoLog)(GLuint, GLsizei, GLsizei *, char *);
    void (*glDeleteShader)(GLuint);
    GLuint (*glCreateProgram)(void);
    void (*glAttachShader)(GLuint, GLuint);
    void (*glLinkProgram)(GLuint);
    void (*glGetProgramiv)(GLuint, GLenum, GLint *);
    void (*glGetProgramInfoLog)(GLuint, GLsizei, GLsizei *, char *);
    void (*glDeleteProgram)(GLuint);
    void (*glUseProgram)(GLuint);
    GLint (*glGetAttribLocation)(GLuint, const char *);
    GLint (*glGetUniformLocation)(GLuint, const char *);
    void (*glUniform1f)(GLint, float);
    void (*glUniform2f)(GLint, float, float);
    void (*glUniform3fv)(GLint, GLsizei, const float *);
    void (*glUniform4fv)(GLint, GLsizei, const float *);
    void (*glUniform1i)(GLint, GLint);
    void (*glVertexAttribPointer)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void *);
    void (*glEnableVertexAttribArray)(GLuint);
    void (*glDisableVertexAttribArray)(GLuint);
    void (*glActiveTexture)(GLenum);
    void (*glBindTexture)(GLenum, GLuint);
    void (*glGenTextures)(GLsizei, GLuint *);
    void (*glTexImage2D)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
    void (*glTexParameteri)(GLenum, GLenum, GLint);
    void (*glDrawArrays)(GLenum, GLint, GLsizei);
    void (*glReadPixels)(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *);
    GLenum (*glGetError)(void);
} API;

static API api;
static GLuint glTexture;

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;
static id<MTLLibrary> library;
static id<MTLSamplerState> sampler;
static id<MTLTexture> input;
static id<MTLTexture> target;

static void die(const char *message)
{
    fprintf(stderr, "metal_shader_harness: %s\n", message);
    exit(2);
}

static void load(void *library, void **slot, const char *name)
{
    *slot = dlsym(library, name);
    if (!*slot) {
        fprintf(stderr, "metal_shader_harness: missing %s\n", name);
        exit(2);
    }
}

#define LOAD(library, field) load(library, (void **)&api.field, #field)

static void startANGLE(NSString *dir)
{
    char path[4096];
    snprintf(path, sizeof path, "%s/libGLESv2.dylib", dir.UTF8String);
    void *gles = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    snprintf(path, sizeof path, "%s/libEGL.dylib", dir.UTF8String);
    void *egl = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if (!gles || !egl) {
        fprintf(stderr, "metal_shader_harness: dlopen: %s\n", dlerror());
        exit(2);
    }
    LOAD(egl, eglGetPlatformDisplayEXT);
    LOAD(egl, eglInitialize);
    LOAD(egl, eglQueryString);
    LOAD(egl, eglChooseConfig);
    LOAD(egl, eglCreatePbufferSurface);
    LOAD(egl, eglCreateContext);
    LOAD(egl, eglMakeCurrent);
    LOAD(gles, glViewport);
    LOAD(gles, glClearColor);
    LOAD(gles, glClear);
    LOAD(gles, glCreateShader);
    LOAD(gles, glShaderSource);
    LOAD(gles, glCompileShader);
    LOAD(gles, glGetShaderiv);
    LOAD(gles, glGetShaderInfoLog);
    LOAD(gles, glDeleteShader);
    LOAD(gles, glCreateProgram);
    LOAD(gles, glAttachShader);
    LOAD(gles, glLinkProgram);
    LOAD(gles, glGetProgramiv);
    LOAD(gles, glGetProgramInfoLog);
    LOAD(gles, glDeleteProgram);
    LOAD(gles, glUseProgram);
    LOAD(gles, glGetAttribLocation);
    LOAD(gles, glGetUniformLocation);
    LOAD(gles, glUniform1f);
    LOAD(gles, glUniform2f);
    LOAD(gles, glUniform3fv);
    LOAD(gles, glUniform4fv);
    LOAD(gles, glUniform1i);
    LOAD(gles, glVertexAttribPointer);
    LOAD(gles, glEnableVertexAttribArray);
    LOAD(gles, glDisableVertexAttribArray);
    LOAD(gles, glActiveTexture);
    LOAD(gles, glBindTexture);
    LOAD(gles, glGenTextures);
    LOAD(gles, glTexImage2D);
    LOAD(gles, glTexParameteri);
    LOAD(gles, glDrawArrays);
    LOAD(gles, glReadPixels);
    LOAD(gles, glGetError);
}

static NSData *testTexels(void)
{
    NSMutableData *texels = [NSMutableData dataWithLength:TEX * TEX * 4];
    unsigned char *p = texels.mutableBytes;
    for (int y = 0; y < TEX; y++) {
        for (int x = 0; x < TEX; x++) {
            unsigned char *px = p + (y * TEX + x) * 4;
            px[0] = (unsigned char)(x * 255 / (TEX - 1));
            px[1] = (unsigned char)(y * 255 / (TEX - 1));
            px[2] = ((x + y) & 1) ? 255 : 0;
            px[3] = 255;
        }
    }
    return texels;
}

static void startContext(void)
{
    EGLint platform[] = {EGL_PLATFORM_ANGLE_TYPE_ANGLE, EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE, EGL_NONE};
    EGLDisplay display = api.eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE, NULL, platform);
    EGLint major = 0, minor = 0;
    if (!display || !api.eglInitialize(display, &major, &minor))
        die("eglInitialize failed");
    fprintf(stderr, "ANGLE EGL %d.%d, vendor %s\n", major, minor, api.eglQueryString(display, EGL_VENDOR));
    EGLint configAttributes[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                                 EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE};
    EGLConfig config = NULL;
    EGLint count = 0;
    if (!api.eglChooseConfig(display, configAttributes, &config, 1, &count) || count < 1)
        die("no EGL config");
    EGLint surfaceAttributes[] = {EGL_WIDTH, W, EGL_HEIGHT, H, EGL_NONE};
    EGLSurface surface = api.eglCreatePbufferSurface(display, config, surfaceAttributes);
    EGLint contextAttributes[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    EGLContext context = api.eglCreateContext(display, config, NULL, contextAttributes);
    if (!surface || !context || !api.eglMakeCurrent(display, surface, surface, context))
        die("no GLES2 context");
    api.glGenTextures(1, &glTexture);
    api.glBindTexture(GL_TEXTURE_2D, glTexture);
    api.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    api.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    api.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    api.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    api.glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, TEX, TEX, 0, GL_RGBA, GL_UNSIGNED_BYTE, testTexels().bytes);
}

static void startMetal(NSString *metallib)
{
    device = MTLCreateSystemDefaultDevice();
    if (!device)
        die("no Metal device");
    queue = [device newCommandQueue];
    NSError *error = nil;
    library = [device newLibraryWithURL:[NSURL fileURLWithPath:metallib] error:&error];
    if (!library) {
        fprintf(stderr, "metal_shader_harness: %s: %s\n", metallib.UTF8String, error.localizedDescription.UTF8String);
        exit(2);
    }
    MTLSamplerDescriptor *sd = [MTLSamplerDescriptor new];
    sd.minFilter = MTLSamplerMinMagFilterLinear;
    sd.magFilter = MTLSamplerMinMagFilterLinear;
    sd.sAddressMode = MTLSamplerAddressModeClampToEdge;
    sd.tAddressMode = MTLSamplerAddressModeClampToEdge;
    sd.normalizedCoordinates = YES;
    sampler = [device newSamplerStateWithDescriptor:sd];

    MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                  width:TEX height:TEX mipmapped:NO];
    input = [device newTextureWithDescriptor:td];
    [input replaceRegion:MTLRegionMake2D(0, 0, TEX, TEX) mipmapLevel:0 withBytes:testTexels().bytes bytesPerRow:TEX * 4];

    MTLTextureDescriptor *rd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                  width:W height:H mipmapped:NO];
    rd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    rd.storageMode = MTLStorageModeShared;
    target = [device newTextureWithDescriptor:rd];
}

static NSString *infoLog(GLuint object, BOOL program)
{
    GLint length = 0;
    if (program)
        api.glGetProgramiv(object, GL_INFO_LOG_LENGTH, &length);
    else
        api.glGetShaderiv(object, GL_INFO_LOG_LENGTH, &length);
    char *log = calloc(length + 1, 1);
    if (program)
        api.glGetProgramInfoLog(object, length + 1, NULL, log);
    else
        api.glGetShaderInfoLog(object, length + 1, NULL, log);
    NSString *text = [NSString stringWithUTF8String:log] ?: @"(no log)";
    free(log);
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static GLuint compileShader(GLenum type, NSString *source, NSString **log)
{
    GLuint shader = api.glCreateShader(type);
    const char *text = source.UTF8String;
    api.glShaderSource(shader, 1, &text, NULL);
    api.glCompileShader(shader);
    GLint ok = 0;
    api.glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        *log = infoLog(shader, NO);
        api.glDeleteShader(shader);
        return 0;
    }
    return shader;
}

static float uniformValue(NSInteger k)
{
    return 0.25f * (float)(k + 1);
}

static BOOL isFloatScalar(NSString *scalar)
{
    return [scalar isEqualToString:@"float"];
}

static BOOL isIntScalar(NSString *scalar)
{
    return [scalar hasPrefix:@"i"] || [scalar hasPrefix:@"u"] || [scalar hasPrefix:@"b"];
}

static NSInteger intValue(NSDictionary *d, NSString *key)
{
    return [d[key] integerValue];
}

static BOOL hasIntUniform(NSDictionary *shader)
{
    for (NSDictionary *u in shader[@"reflection"][@"uniforms"])
        if (!isFloatScalar(u[@"scalar"]))
            return YES;
    return NO;
}

static BOOL uniformSupported(NSDictionary *u)
{
    NSInteger comps = intValue(u, @"components");
    if (isFloatScalar(u[@"scalar"]))
        return comps >= 1 && comps <= 4;
    return isIntScalar(u[@"scalar"]) && comps == 1;
}

static NSDictionary<NSNumber *, NSMutableData *> *vertexBuffers(NSArray *attributes, NSString **detail)
{
    NSMutableDictionary *buffers = [NSMutableDictionary dictionary];
    for (NSDictionary *a in attributes) {
        NSInteger buffer = intValue(a, @"buffer"), stride = intValue(a, @"stride"), offset = intValue(a, @"offset");
        NSInteger comps = intValue(a, @"components");
        if (stride <= 0 || offset + comps * 4 > stride || comps < 1 || comps > 4) {
            *detail = [NSString stringWithFormat:@"attribute %@ does not fit its stride", a[@"name"]];
            return nil;
        }
        NSMutableData *data = buffers[@(buffer)];
        if (!data) {
            data = [NSMutableData dataWithLength:stride * VERTICES];
            buffers[@(buffer)] = data;
        }
        NSString *name = [a[@"name"] lowercaseString];
        unsigned char *base = data.mutableBytes;
        for (int v = 0; v < VERTICES; v++) {
            float value[4] = {0.5f, 0.5f, 0.5f, 1.0f};
            if ([name containsString:@"pos"]) {
                value[0] = QUAD_XY[v][0];
                value[1] = QUAD_XY[v][1];
                value[2] = 0;
                value[3] = 1;
            } else if ([name containsString:@"tex"] || [name containsString:@"uv"]) {
                value[0] = QUAD_UV[v][0];
                value[1] = QUAD_UV[v][1];
                value[2] = 0;
                value[3] = 1;
            }
            memcpy(base + v * stride + offset, value, comps * 4);
        }
    }
    return buffers;
}

static NSInteger metalComponents(MTLDataType type)
{
    switch (type) {
    case MTLDataTypeFloat: return 1;
    case MTLDataTypeFloat2: return 2;
    case MTLDataTypeFloat3: return 3;
    case MTLDataTypeFloat4: return 4;
    default: return 0;
    }
}

static NSString *checkVertexInputs(NSArray *arguments, NSArray *attributes, NSString **state)
{
    NSMutableDictionary *byIndex = [NSMutableDictionary dictionary];
    for (MTLArgument *argument in arguments)
        if (argument.type == MTLArgumentTypeBuffer)
            byIndex[@(argument.index)] = argument;
    for (NSDictionary *a in attributes) {
        NSInteger buffer = intValue(a, @"buffer"), stride = intValue(a, @"stride");
        MTLArgument *argument = byIndex[@(buffer)];
        if (!argument) {
            *state = @"SKIP";
            return [NSString stringWithFormat:@"attribute %@ has no Metal buffer %ld", a[@"name"], (long)buffer];
        }
        if (argument.bufferDataSize != (NSUInteger)stride) {
            *state = @"FAIL";
            return [NSString stringWithFormat:@"layout: buffer %ld is %lu bytes per vertex in Metal and stride %ld in air2es",
                    (long)buffer, (unsigned long)argument.bufferDataSize, (long)stride];
        }
        NSString *name = [(NSString *)a[@"name"] substringFromIndex:2];
        if (!argument.bufferStructType) {
            if (![argument.name isEqualToString:name]) {
                *state = @"FAIL";
                return [NSString stringWithFormat:@"layout: buffer %ld is named %@ in Metal and %@ in air2es",
                        (long)buffer, argument.name, name];
            }
            if (metalComponents(argument.bufferDataType) != intValue(a, @"components")) {
                *state = @"FAIL";
                return [NSString stringWithFormat:@"layout: %@ has %ld components in air2es and %ld in Metal", name,
                        (long)intValue(a, @"components"), (long)metalComponents(argument.bufferDataType)];
            }
            continue;
        }
        MTLStructMember *member = nil;
        for (MTLStructMember *m in argument.bufferStructType.members)
            if ([m.name isEqualToString:name])
                member = m;
        if (!member) {
            *state = @"FAIL";
            return [NSString stringWithFormat:@"layout: Metal's struct has no field %@", name];
        }
        if (member.offset != (NSUInteger)intValue(a, @"offset")) {
            *state = @"FAIL";
            return [NSString stringWithFormat:@"layout: %@ is at %lu in Metal and %ld in air2es", name,
                    (unsigned long)member.offset, (long)intValue(a, @"offset")];
        }
        if (metalComponents(member.dataType) != intValue(a, @"components")) {
            *state = @"FAIL";
            return [NSString stringWithFormat:@"layout: %@ has %ld components in air2es and %ld in Metal", name,
                    (long)intValue(a, @"components"), (long)metalComponents(member.dataType)];
        }
    }
    return nil;
}

static NSString *placeUniform(NSDictionary *u, int ints, NSMutableData *blob, MTLArgument *argument, NSString **state)
{
    NSInteger offset = intValue(u, @"offset");
    NSInteger comps = intValue(u, @"components");
    NSInteger size = isFloatScalar(u[@"scalar"]) ? comps * 4 : 4;
    if (offset + size > (NSInteger)blob.length) {
        *state = @"FAIL";
        return [NSString stringWithFormat:@"layout: %@ at %ld is past Metal's %lu-byte buffer", u[@"name"],
                (long)offset, (unsigned long)blob.length];
    }
    for (MTLStructMember *member in argument.bufferStructType.members) {
        if ([member.name isEqualToString:u[@"name"]] && member.offset != (NSUInteger)offset) {
            *state = @"FAIL";
            return [NSString stringWithFormat:@"layout: %@ is at %ld in air2es and %lu in Metal", u[@"name"],
                    (long)offset, (unsigned long)member.offset];
        }
    }
    unsigned char *bytes = blob.mutableBytes;
    if (isFloatScalar(u[@"scalar"])) {
        float values[4];
        for (NSInteger k = 0; k < comps; k++)
            values[k] = uniformValue(k);
        memcpy(bytes + offset, values, comps * 4);
    } else {
        int32_t value = ints;
        memcpy(bytes + offset, &value, 4);
    }
    return nil;
}

static NSString *uniformBlobs(NSArray *arguments, NSDictionary *shader, int ints, NSMutableDictionary *blobs,
                              NSString **state)
{
    NSMutableDictionary *byIndex = [NSMutableDictionary dictionary];
    for (MTLArgument *argument in arguments)
        if (argument.type == MTLArgumentTypeBuffer)
            byIndex[@(argument.index)] = argument;
    for (NSDictionary *u in shader[@"reflection"][@"uniforms"]) {
        if (!uniformSupported(u)) {
            *state = @"SKIP";
            return [NSString stringWithFormat:@"uniform %@ is not a float vector or an int", u[@"name"]];
        }
        MTLArgument *argument = byIndex[@(intValue(u, @"buffer"))];
        if (!argument) {
            *state = @"SKIP";
            return [NSString stringWithFormat:@"uniform %@ has no Metal buffer %ld", u[@"name"],
                    (long)intValue(u, @"buffer")];
        }
        NSMutableData *blob = blobs[@(argument.index)];
        if (!blob) {
            NSUInteger size = argument.bufferDataSize > 16 ? argument.bufferDataSize : 16;
            blob = [NSMutableData dataWithLength:size];
            blobs[@(argument.index)] = blob;
        }
        NSString *detail = placeUniform(u, ints, blob, argument, state);
        if (detail)
            return detail;
    }
    return nil;
}

static NSString *metalRun(NSDictionary *vs, NSDictionary *fs, int ints, NSMutableData *pixels, NSString **state)
{
    id<MTLFunction> vfn = [library newFunctionWithName:vs[@"name"]];
    id<MTLFunction> ffn = [library newFunctionWithName:fs[@"name"]];
    if (!vfn || !ffn) {
        *state = @"ERROR";
        return @"Metal has no such function";
    }
    NSDictionary *vr = vs[@"reflection"];
    if (vfn.stageInputAttributes.count) {
        *state = @"SKIP";
        return @"a stage_in vertex input is not handled";
    }
    NSString *detail = nil;
    NSDictionary *buffers = vertexBuffers(vr[@"attributes"], &detail);
    if (!buffers) {
        *state = @"ERROR";
        return detail;
    }

    MTLRenderPipelineDescriptor *pd = [MTLRenderPipelineDescriptor new];
    pd.vertexFunction = vfn;
    pd.fragmentFunction = ffn;
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    MTLRenderPipelineReflection *reflection = nil;
    NSError *error = nil;
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:pd
                                                                              options:MTLPipelineOptionArgumentInfo | MTLPipelineOptionBufferTypeInfo
                                                                           reflection:&reflection
                                                                                error:&error];
    if (!pipeline) {
        *state = @"ERROR";
        return [NSString stringWithFormat:@"Metal pipeline: %@", error.localizedDescription];
    }

    detail = checkVertexInputs(reflection.vertexArguments, vr[@"attributes"], state);
    if (detail)
        return detail;
    NSMutableDictionary *vertexBlobs = [NSMutableDictionary dictionary];
    NSMutableDictionary *fragmentBlobs = [NSMutableDictionary dictionary];
    detail = uniformBlobs(reflection.vertexArguments, vs, ints, vertexBlobs, state);
    if (detail)
        return detail;
    detail = uniformBlobs(reflection.fragmentArguments, fs, ints, fragmentBlobs, state);
    if (detail)
        return detail;
    for (NSNumber *b in buffers.allKeys)
        if (vertexBlobs[b]) {
            *state = @"SKIP";
            return [NSString stringWithFormat:@"vertex buffer %@ is also a uniform buffer", b];
        }


    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLCommandBuffer> commands = [queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    for (NSNumber *b in buffers) {
        NSData *data = buffers[b];
        [encoder setVertexBytes:data.bytes length:data.length atIndex:b.integerValue];
    }
    for (NSNumber *b in vertexBlobs) {
        NSData *blob = vertexBlobs[b];
        [encoder setVertexBytes:blob.bytes length:blob.length atIndex:b.integerValue];
    }
    for (NSNumber *b in fragmentBlobs) {
        NSData *blob = fragmentBlobs[b];
        [encoder setFragmentBytes:blob.bytes length:blob.length atIndex:b.integerValue];
    }
    for (MTLArgument *argument in reflection.fragmentArguments) {
        if (argument.type == MTLArgumentTypeTexture)
            [encoder setFragmentTexture:input atIndex:argument.index];
        else if (argument.type == MTLArgumentTypeSampler)
            [encoder setFragmentSamplerState:sampler atIndex:argument.index];
    }
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:VERTICES];
    [encoder endEncoding];
    [commands commit];
    [commands waitUntilCompleted];
    if (commands.error) {
        *state = @"ERROR";
        return [NSString stringWithFormat:@"Metal command buffer: %@", commands.error.localizedDescription];
    }
    [target getBytes:pixels.mutableBytes bytesPerRow:W * 4 fromRegion:MTLRegionMake2D(0, 0, W, H) mipmapLevel:0];
    return nil;
}

static NSString *glesRun(NSDictionary *vs, NSDictionary *fs, int ints, NSMutableData *pixels, NSString **state)
{
    NSString *log = nil;
    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vs[@"glsl"], &log);
    if (!vertexShader) {
        *state = @"ERROR";
        return [@"GLES vertex shader: " stringByAppendingString:log];
    }
    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fs[@"glsl"], &log);
    if (!fragmentShader) {
        api.glDeleteShader(vertexShader);
        *state = @"ERROR";
        return [@"GLES fragment shader: " stringByAppendingString:log];
    }
    GLuint program = api.glCreateProgram();
    api.glAttachShader(program, vertexShader);
    api.glAttachShader(program, fragmentShader);
    api.glLinkProgram(program);
    GLint linked = 0;
    api.glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        log = infoLog(program, YES);
        api.glDeleteProgram(program);
        api.glDeleteShader(vertexShader);
        api.glDeleteShader(fragmentShader);
        *state = @"ERROR";
        return [@"GLES link: " stringByAppendingString:log];
    }
    api.glUseProgram(program);

    NSString *detail = nil;
    NSDictionary *buffers = nil;
    NSMutableArray *enabled = [NSMutableArray array];
    NSArray *attributes = vs[@"reflection"][@"attributes"];
    buffers = vertexBuffers(attributes, &detail);
    if (!buffers) {
        *state = @"ERROR";
        return detail;
    }
    for (NSDictionary *a in attributes) {
        GLint location = api.glGetAttribLocation(program, [a[@"name"] UTF8String]);
        if (location < 0)
            continue;
        NSData *data = buffers[@(intValue(a, @"buffer"))];
        api.glVertexAttribPointer((GLuint)location, (GLint)intValue(a, @"components"), GL_FLOAT, 0,
                                  (GLsizei)intValue(a, @"stride"),
                                  (const char *)data.bytes + intValue(a, @"offset"));
        api.glEnableVertexAttribArray((GLuint)location);
        [enabled addObject:@(location)];
    }
    NSMutableData *vertexIds = [NSMutableData dataWithLength:VERTICES * sizeof(float)];
    for (int v = 0; v < VERTICES; v++)
        ((float *)vertexIds.mutableBytes)[v] = (float)v;
    GLint vertexIdLocation = api.glGetAttribLocation(program, "a_vertex_id");
    if (vertexIdLocation >= 0) {
        api.glVertexAttribPointer((GLuint)vertexIdLocation, 1, GL_FLOAT, 0, sizeof(float), vertexIds.bytes);
        api.glEnableVertexAttribArray((GLuint)vertexIdLocation);
        [enabled addObject:@(vertexIdLocation)];
    }

    for (NSDictionary *shader in @[vs, fs]) {
        for (NSDictionary *u in shader[@"reflection"][@"uniforms"]) {
            GLint location = api.glGetUniformLocation(program, [u[@"name"] UTF8String]);
            if (location < 0)
                continue;
            NSInteger comps = intValue(u, @"components");
            if (!isFloatScalar(u[@"scalar"])) {
                api.glUniform1i(location, ints);
                continue;
            }
            float values[4];
            for (NSInteger k = 0; k < comps; k++)
                values[k] = uniformValue(k);
            switch (comps) {
            case 1: api.glUniform1f(location, values[0]); break;
            case 2: api.glUniform2f(location, values[0], values[1]); break;
            case 3: api.glUniform3fv(location, 1, values); break;
            default: api.glUniform4fv(location, 1, values); break;
            }
        }
    }
    GLint flip = api.glGetUniformLocation(program, "revenant_flip");
    if (flip >= 0)
        api.glUniform1f(flip, 1.0f);
    for (NSDictionary *size in fs[@"reflection"][@"sizes"]) {
        GLint location = api.glGetUniformLocation(program, [size[@"name"] UTF8String]);
        if (location >= 0)
            api.glUniform2f(location, TEX, TEX);
    }
    for (NSDictionary *t in fs[@"reflection"][@"textures"]) {
        GLint unit = (GLint)intValue(t, @"index");
        api.glActiveTexture(GL_TEXTURE0 + unit);
        api.glBindTexture(GL_TEXTURE_2D, glTexture);
        GLint location = api.glGetUniformLocation(program, [t[@"name"] UTF8String]);
        if (location >= 0)
            api.glUniform1i(location, unit);
    }

    api.glViewport(0, 0, W, H);
    api.glClearColor(0, 0, 0, 0);
    api.glClear(GL_COLOR_BUFFER_BIT);
    api.glDrawArrays(GL_TRIANGLES, 0, VERTICES);
    GLenum error = api.glGetError();

    unsigned char *rows = malloc(W * H * 4);
    api.glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, rows);
    unsigned char *out = pixels.mutableBytes;
    for (int r = 0; r < H; r++)
        memcpy(out + r * W * 4, rows + (H - 1 - r) * W * 4, W * 4);
    free(rows);

    for (NSNumber *location in enabled)
        api.glDisableVertexAttribArray((GLuint)location.integerValue);
    api.glUseProgram(0);
    api.glDeleteProgram(program);
    api.glDeleteShader(vertexShader);
    api.glDeleteShader(fragmentShader);
    if (error != GL_NO_ERROR) {
        *state = @"ERROR";
        return [NSString stringWithFormat:@"GLES draw: error 0x%x", error];
    }
    return nil;
}

static NSString *compare(NSData *metal, NSData *gles, NSString **state)
{
    const unsigned char *m = metal.bytes, *g = gles.bytes;
    int maxDiff = 0, over = 0, nonzero = 0;
    for (NSUInteger i = 0; i < metal.length; i++) {
        int d = abs((int)m[i] - (int)g[i]);
        if (d > maxDiff)
            maxDiff = d;
        if (d > TOLERANCE)
            over++;
        if (m[i])
            nonzero++;
    }
    if (nonzero == 0) {
        *state = @"SKIP";
        return @"Metal output is blank, so the case proves nothing";
    }
    if (maxDiff <= TOLERANCE) {
        *state = @"PASS";
        return [NSString stringWithFormat:@"max channel diff %d/255 over %d non-zero Metal channels", maxDiff, nonzero];
    }
    *state = @"FAIL";
    return [NSString stringWithFormat:@"max channel diff %d/255, %d of %lu channels over the tolerance of %d", maxDiff,
            over, (unsigned long)metal.length, TOLERANCE];
}

static NSInteger rank(NSString *state)
{
    if ([state isEqualToString:@"ERROR"]) return 3;
    if ([state isEqualToString:@"FAIL"]) return 2;
    if ([state isEqualToString:@"SKIP"]) return 1;
    return 0;
}

static NSArray<NSString *> *varyingsOf(NSString *glsl)
{
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *line in [glsl componentsSeparatedByString:@"\n"]) {
        NSString *t = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (![t hasPrefix:@"varying "])
            continue;
        NSString *plain = [t stringByReplacingOccurrencesOfString:@";" withString:@""];
        NSArray *words = [[plain componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
            filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
        [out addObject:[NSString stringWithFormat:@"%@ %@", words[1], words[2]]];
    }
    return out;
}

static BOOL covers(NSArray *outputs, NSArray *inputs)
{
    for (NSString *input in inputs)
        if (![outputs containsObject:input])
            return NO;
    return YES;
}

static NSDictionary *readJSON(NSString *path)
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        fprintf(stderr, "metal_shader_harness: cannot read %s\n", path.UTF8String);
        exit(2);
    }
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "usage: metal_shader_harness <metallib> <es2 folder> [<ANGLE libraries folder>]\n");
            return 2;
        }
        NSString *metallib = [NSString stringWithUTF8String:argv[1]];
        NSString *folder = [NSString stringWithUTF8String:argv[2]];
        NSString *angle = argc > 3 ? [NSString stringWithUTF8String:argv[3]] : [NSString stringWithUTF8String:REVENANT_ANGLE_LIB];

        startMetal(metallib);
        startANGLE(angle);
        startContext();

        NSMutableArray *vertexFns = [NSMutableArray array], *fragmentFns = [NSMutableArray array];
        for (NSDictionary *entry in readJSON([folder stringByAppendingPathComponent:@"library.json"])[@"functions"]) {
            NSString *name = entry[@"name"];
            NSString *glsl = [NSString stringWithContentsOfFile:[folder stringByAppendingPathComponent:entry[@"source"]]
                                                       encoding:NSUTF8StringEncoding error:NULL];
            NSDictionary *shader = @{@"name": name, @"glsl": glsl ?: @"",
                                     @"reflection": readJSON([folder stringByAppendingPathComponent:entry[@"reflection"]]),
                                     @"varyings": varyingsOf(glsl ?: @"")};
            if (![library.functionNames containsObject:name]) {
                printf("SKIP  %s: not in the metallib\n", name.UTF8String);
                continue;
            }
            if ([entry[@"stage"] isEqualToString:@"vertex"])
                [vertexFns addObject:shader];
            else
                [fragmentFns addObject:shader];
        }

        NSMutableDictionary *worst = [NSMutableDictionary dictionary];
        int failures = 0, runs = 0;
        for (NSDictionary *vs in vertexFns) {
            for (NSDictionary *fs in fragmentFns) {
                if (!covers(vs[@"varyings"], fs[@"varyings"]))
                    continue;
                int variants = hasIntUniform(vs) || hasIntUniform(fs) ? 2 : 1;
                for (int ints = 0; ints < variants; ints++) {
                    NSMutableData *metalPixels = [NSMutableData dataWithLength:W * H * 4];
                    NSMutableData *glesPixels = [NSMutableData dataWithLength:W * H * 4];
                    NSString *state = @"PASS";
                    NSString *detail = metalRun(vs, fs, ints, metalPixels, &state);
                    if (!detail) {
                        detail = glesRun(vs, fs, ints, glesPixels, &state);
                        if (!detail)
                            detail = compare(metalPixels, glesPixels, &state);
                    }
                    runs++;
                    if (rank(state) >= 2)
                        failures++;
                    printf("%-5s %s + %s [ints=%d] %s\n", state.UTF8String, [vs[@"name"] UTF8String],
                           [fs[@"name"] UTF8String], ints, detail.UTF8String);
                    for (NSDictionary *shader in @[vs, fs]) {
                        NSString *known = worst[shader[@"name"]];
                        if (!known || rank(state) > rank(known))
                            worst[shader[@"name"]] = state;
                    }
                }
            }
        }
        for (NSDictionary *shader in [vertexFns arrayByAddingObjectsFromArray:fragmentFns]) {
            NSString *verdict = worst[shader[@"name"]] ?: @"NOT RUN";
            printf("SHADER %s: %s\n", [shader[@"name"] UTF8String], verdict.UTF8String);
        }
        printf("%d runs, %d failing\n", runs, failures);
        return failures ? 1 : 0;
    }
}
