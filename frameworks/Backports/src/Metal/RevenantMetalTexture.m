#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#ifndef GL_HALF_FLOAT
#define GL_HALF_FLOAT 0x8D61
#endif
#ifndef GL_HALF_FLOAT_LINEAR
#define GL_HALF_FLOAT_LINEAR 0x8D62
#endif

typedef struct {
    GLint internal;
    GLenum format;
    GLenum type;
    NSUInteger bytes;
    NSUInteger channels;
    NSUInteger channel;
    const char *extension;
    const char *linearExtension;
} RevenantFormat;

// The CoreVideo format of an IOSurface whose pixels are this Metal format. Only the formats the OpenGL ES form above
// reads directly from a surface are listed.
static BOOL surfaceFormatFor(MTLPixelFormat pixelFormat, OSType *out)
{
    switch ((NSUInteger)pixelFormat) {
    case 70: *out = kCVPixelFormatType_32RGBA; return YES;
    case 80: *out = kCVPixelFormatType_32BGRA; return YES;
    default: return NO;
    }
}

static BOOL formatFor(MTLPixelFormat pixelFormat, RevenantFormat *out)
{
    switch ((NSUInteger)pixelFormat) {
    case 70: *out = (RevenantFormat){GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, 4, 4, 1, NULL, NULL}; return YES;
    case 80: *out = (RevenantFormat){GL_RGBA, GL_BGRA_EXT, GL_UNSIGNED_BYTE, 4, 4, 1, NULL, NULL}; return YES;
    case 10: *out = (RevenantFormat){GL_RED_EXT, GL_RED_EXT, GL_UNSIGNED_BYTE, 1, 1, 1, "GL_EXT_texture_rg", NULL}; return YES;
    case 30: *out = (RevenantFormat){GL_RG_EXT, GL_RG_EXT, GL_UNSIGNED_BYTE, 2, 2, 1, "GL_EXT_texture_rg", NULL}; return YES;
    case 115: *out = (RevenantFormat){GL_RGBA, GL_RGBA, GL_HALF_FLOAT, 8, 4, 2, "GL_OES_texture_half_float", "GL_OES_texture_half_float_linear"}; return YES;
    case 25: *out = (RevenantFormat){GL_RED_EXT, GL_RED_EXT, GL_HALF_FLOAT, 2, 1, 2, "GL_OES_texture_half_float,GL_EXT_texture_rg", "GL_OES_texture_half_float_linear,GL_EXT_texture_rg"}; return YES;
    case 65: *out = (RevenantFormat){GL_RG_EXT, GL_RG_EXT, GL_HALF_FLOAT, 4, 2, 2, "GL_OES_texture_half_float,GL_EXT_texture_rg", "GL_OES_texture_half_float_linear,GL_EXT_texture_rg"}; return YES;
    case 55: *out = (RevenantFormat){GL_RED_EXT, GL_RED_EXT, GL_FLOAT, 4, 1, 4, "GL_OES_texture_float,GL_EXT_texture_rg", "GL_OES_texture_float_linear,GL_EXT_texture_rg"}; return YES;
    case 125: *out = (RevenantFormat){GL_RGBA, GL_RGBA, GL_FLOAT, 16, 4, 4, "GL_OES_texture_float", "GL_OES_texture_float_linear"}; return YES;
    default: return NO;
    }
}

static BOOL RevenantMetalDeviceHasExtension(const char *required)
{
    static char *extensions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        const GLubyte *string = glGetString(GL_EXTENSIONS);
        extensions = string ? strdup((const char *)string) : NULL;
        [device relinquish];
    });
    if (!extensions)
        return NO;
    if (!required || !*required)
        return YES;
    for (const char *want = required; *want;) {
        const char *comma = strchr(want, ',');
        size_t length = comma ? (size_t)(comma - want) : strlen(want);
        if (length) {
            BOOL found = NO;
            for (const char *at = extensions; at;) {
                const char *space = strchr(at, ' ');
                size_t here = space ? (size_t)(space - at) : strlen(at);
                if (here == length && memcmp(at, want, length) == 0) {
                    found = YES;
                    break;
                }
                at = space ? space + 1 : NULL;
            }
            if (!found)
                return NO;
        }
        if (!comma)
            break;
        want = comma + 1;
    }
    return YES;
}

static NSUInteger levelExtent(NSUInteger extent, NSUInteger level)
{
    NSUInteger size = extent >> level;
    return size ? size : 1;
}

NSUInteger RevenantMetalBindEpoch;

@implementation RevenantMetalTexture {
    GLuint _name;
    GLuint _framebuffer;
    CVOpenGLESTextureRef _surfaceTexture;
    BOOL _screen;
    MTLPixelFormat _pixelFormat;
    NSUInteger _width;
    NSUInteger _height;
    NSUInteger _levels;
    MTLTextureUsage _usage;
    __unsafe_unretained RevenantMetalSampler *_appliedSampler;
    int _kind;
    GLuint _renderbuffer;
    GLuint _checkedDepth, _checkedStencil;
    int _appliedCompare;
    __strong RevenantMetalHeap *_revenantHeap;
    NSUInteger _revenantHeapOffset;
    NSUInteger _attachedLevel;
}

@synthesize label;

static int depthKind(MTLPixelFormat pixelFormat)
{
    switch ((NSUInteger)pixelFormat) {
    case 250: case 252: return 1;
    case 253: return 3;
    case 255: case 260: return 2;
    default: return 0;
    }
}

- (instancetype)initWithDepthDescriptor:(MTLTextureDescriptor *)descriptor kind:(int)kind
{
    if (descriptor.textureType != MTLTextureType2D || descriptor.sampleCount != 1 || descriptor.width == 0 || descriptor.height == 0)
        return nil;
    if ((self = [super init])) {
        _pixelFormat = descriptor.pixelFormat;
        _width = descriptor.width;
        _height = descriptor.height;
        _levels = 1;
        _usage = descriptor.usage;
        _kind = kind;
        _attachedLevel = NSNotFound;
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        if (kind == 3) {
            glGenRenderbuffers(1, &_renderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, (GLsizei)_width, (GLsizei)_height);
        } else {
            RevenantMetalBindEpoch++;
            glGenTextures(1, &_name);
            glBindTexture(GL_TEXTURE_2D, _name);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            if (kind == 2)
                glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_STENCIL_OES, (GLsizei)_width, (GLsizei)_height, 0, GL_DEPTH_STENCIL_OES, GL_UNSIGNED_INT_24_8_OES, NULL);
            else
                glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, (GLsizei)_width, (GLsizei)_height, 0, GL_DEPTH_COMPONENT, (NSUInteger)descriptor.pixelFormat == 250 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT, NULL);
        }
        [device relinquish];
    }
    return self;
}

- (int)appliedCompare
{
    return _appliedCompare;
}

- (void)setAppliedCompare:(int)value
{
    _appliedCompare = value;
}

- (GLuint)checkedDepth
{
    return _checkedDepth;
}

- (void)setCheckedDepth:(GLuint)value
{
    _checkedDepth = value;
}

- (GLuint)checkedStencil
{
    return _checkedStencil;
}

- (void)setCheckedStencil:(GLuint)value
{
    _checkedStencil = value;
}

- (int)attachmentKind
{
    return _kind;
}

- (GLuint)renderbuffer
{
    return _renderbuffer;
}

- (instancetype)initWithDescriptor:(MTLTextureDescriptor *)descriptor
{
    int depth = depthKind(descriptor.pixelFormat);
    if (depth)
        return [self initWithDepthDescriptor:descriptor kind:depth];
    RevenantFormat format;
    if (descriptor.textureType != MTLTextureType2D || !formatFor(descriptor.pixelFormat, &format) || descriptor.sampleCount != 1 || descriptor.width == 0 || descriptor.height == 0) {
        NSLog(@"Metal: texture of type %d, pixel format %d, %d samples has no OpenGL ES 2.0 form", (int)descriptor.textureType, (int)descriptor.pixelFormat, (int)descriptor.sampleCount);
        return nil;
    }
    if (!RevenantMetalDeviceHasExtension(format.extension)) {
        NSLog(@"Metal: pixel format %d needs %s, which this device's OpenGL ES 2.0 driver does not list", (int)descriptor.pixelFormat, format.extension);
        return nil;
    }
    if ((self = [super init])) {
        _pixelFormat = descriptor.pixelFormat;
        _width = descriptor.width;
        _height = descriptor.height;
        _levels = descriptor.mipmapLevelCount ? descriptor.mipmapLevelCount : 1;
        _usage = descriptor.usage;
        _attachedLevel = NSNotFound;
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        RevenantMetalBindEpoch++;
        glGenTextures(1, &_name);
        glBindTexture(GL_TEXTURE_2D, _name);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        for (NSUInteger level = 0; level < _levels; level++)
            glTexImage2D(GL_TEXTURE_2D, (GLint)level, format.internal,
                         (GLsizei)levelExtent(_width, level), (GLsizei)levelExtent(_height, level), 0,
                         format.format, format.type, NULL);
        [device relinquish];
    }
    return self;
}

// The texture is the OpenGL ES texture CoreVideo maps onto the surface's memory, so a write to either side is seen by
// the other without a copy. CoreVideo owns its name, so dealloc releases the mapping rather than deleting the name.
- (instancetype)initWithDescriptor:(MTLTextureDescriptor *)descriptor iosurface:(IOSurfaceRef)iosurface plane:(NSUInteger)plane
{
    RevenantFormat format;
    OSType surfaceFormat;
    if (descriptor.textureType != MTLTextureType2D || descriptor.sampleCount != 1 || descriptor.mipmapLevelCount > 1 || plane != 0 || !formatFor(descriptor.pixelFormat, &format) || !surfaceFormatFor(descriptor.pixelFormat, &surfaceFormat)) {
        NSLog(@"Metal: pixel format %d, %d samples, plane %lu has no IOSurface texture form on this backport", (int)descriptor.pixelFormat, (int)descriptor.sampleCount, (unsigned long)plane);
        return nil;
    }
    if (IOSurfaceGetWidth(iosurface) != descriptor.width || IOSurfaceGetHeight(iosurface) != descriptor.height || IOSurfaceGetPixelFormat(iosurface) != surfaceFormat) {
        NSLog(@"Metal: the IOSurface is %lux%lu in format %u, which does not match the texture descriptor", (unsigned long)IOSurfaceGetWidth(iosurface), (unsigned long)IOSurfaceGetHeight(iosurface), (unsigned)IOSurfaceGetPixelFormat(iosurface));
        return nil;
    }
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    CVOpenGLESTextureCacheRef cache = [device textureCache];
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = cache ? CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, iosurface, NULL, &pixelBuffer) : kCVReturnError;
    CVOpenGLESTextureRef texture = NULL;
    if (status == kCVReturnSuccess)
        status = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, pixelBuffer, NULL, GL_TEXTURE_2D, format.internal, (GLsizei)descriptor.width, (GLsizei)descriptor.height, format.format, format.type, 0, &texture);
    if (pixelBuffer)
        CVPixelBufferRelease(pixelBuffer);
    [device relinquish];
    if (status != kCVReturnSuccess) {
        NSLog(@"Metal: the IOSurface cannot be bound as an OpenGL ES texture: CoreVideo returned %d", (int)status);
        return nil;
    }
    if ((self = [super init])) {
        _surfaceTexture = texture;
        _name = CVOpenGLESTextureGetName(texture);
        _pixelFormat = descriptor.pixelFormat;
        _width = descriptor.width;
        _height = descriptor.height;
        _levels = 1;
        _usage = descriptor.usage;
        _attachedLevel = NSNotFound;
        RevenantMetalBindEpoch++;
    } else {
        CFRelease(texture);
    }
    return self;
}

- (instancetype)initScreenWithFramebuffer:(GLuint)framebuffer width:(NSUInteger)width height:(NSUInteger)height pixelFormat:(MTLPixelFormat)format
{
    if ((self = [super init])) {
        _screen = YES;
        _framebuffer = framebuffer;
        _width = width;
        _height = height;
        _levels = 1;
        _pixelFormat = format;
        _attachedLevel = NSNotFound;
        _usage = MTLTextureUsageRenderTarget;
    }
    return self;
}

- (void)dealloc
{
    if (_surfaceTexture) {
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        if (_framebuffer)
            glDeleteFramebuffers(1, &_framebuffer);
        CFRelease(_surfaceTexture);
        [device relinquish];
    } else if (!_screen && (_name || _renderbuffer)) {
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        if (_framebuffer)
            glDeleteFramebuffers(1, &_framebuffer);
        if (_name)
            glDeleteTextures(1, &_name);
        if (_renderbuffer)
            glDeleteRenderbuffers(1, &_renderbuffer);
        [device relinquish];
    }
}

- (RevenantMetalSampler *)appliedSampler
{
    return _appliedSampler;
}

- (void)setAppliedSampler:(RevenantMetalSampler *)sampler
{
    _appliedSampler = sampler;
}

- (GLuint)name
{
    return _name;
}

- (GLuint)framebuffer
{
    return _framebuffer;
}

- (BOOL)screen
{
    return _screen;
}

- (GLuint)renderTarget
{
    return [self framebufferAtLevel:0];
}

- (MTLPixelFormat)pixelFormat
{
    return _pixelFormat;
}

- (NSUInteger)width
{
    return _width;
}

- (NSUInteger)height
{
    return _height;
}

- (NSUInteger)depth
{
    return 1;
}

- (NSUInteger)mipmapLevelCount
{
    return _levels;
}

- (NSUInteger)sampleCount
{
    return 1;
}

- (NSUInteger)arrayLength
{
    return 1;
}

- (MTLTextureType)textureType
{
    return MTLTextureType2D;
}

- (MTLTextureUsage)usage
{
    return _usage;
}

- (BOOL)isFramebufferOnly
{
    return _screen;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (MTLResourceOptions)resourceOptions
{
    return MTLResourceStorageModeShared;
}

- (MTLStorageMode)storageMode
{
    return MTLStorageModeShared;
}

- (void)replaceRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level withBytes:(const void *)pointer bytesPerRow:(NSUInteger)bytesPerRow
{
    [self revenantWriteRegion:region level:level bytes:pointer bytesPerRow:bytesPerRow];
}

- (void)getBytes:(void *)pointer bytesPerRow:(NSUInteger)bytesPerRow fromRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level
{
    [self revenantReadRegion:region level:level bytesPerRow:bytesPerRow into:pointer];
}

- (NSUInteger)revenantStorageSize
{
    RevenantFormat format;
    if (!formatFor(_pixelFormat, &format))
        return 0;
    NSUInteger levels = _levels ? _levels : 1;
    NSUInteger total = 0;
    for (NSUInteger level = 0; level < levels; level++)
        total += levelExtent(_width, level) * levelExtent(_height, level) * format.bytes;
    return total;
}

- (void)revenantSetHeap:(RevenantMetalHeap *)heap offset:(NSUInteger)offset
{
    _revenantHeap = heap;
    _revenantHeapOffset = offset;
}

- (id<MTLHeap>)heap
{
    return _revenantHeap;
}

- (NSUInteger)heapOffset
{
    return _revenantHeapOffset;
}

- (BOOL)revenantIsColour
{
    RevenantFormat format;
    return !_kind && !_screen && formatFor(_pixelFormat, &format);
}

- (BOOL)revenantCanFilter
{
    RevenantFormat format;
    if (!formatFor(_pixelFormat, &format))
        return NO;
    return RevenantMetalDeviceHasExtension(format.linearExtension);
}

- (NSUInteger)revenantChannels
{
    RevenantFormat format;
    if (!formatFor(_pixelFormat, &format))
        return 0;
    return format.bytes;
}

- (GLuint)framebufferAtLevel:(NSUInteger)level
{
    if (_screen)
        return _framebuffer;
    if (!_framebuffer) {
        glGenFramebuffers(1, &_framebuffer);
        _attachedLevel = NSNotFound;
    }
    if (_attachedLevel != level) {
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _name, (GLint)level);
        _attachedLevel = level;
    }
    return _framebuffer;
}

- (void)revenantRestoreAttachment:(NSUInteger)level previous:(GLint)previous
{
    if (!_screen && _attachedLevel != level) {
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _name, (GLint)level);
        _attachedLevel = level;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)previous);
}

- (BOOL)revenantReadRegion:(MTLRegion)region level:(NSUInteger)level bytesPerRow:(NSUInteger)bytesPerRow into:(void *)pointer
{
    RevenantFormat format;
    if (_kind || !formatFor(_pixelFormat, &format) || level >= _levels)
        return NO;
    if (!bytesPerRow)
        bytesPerRow = region.size.width * format.bytes;
    if (bytesPerRow < region.size.width * format.bytes)
        return NO;
    NSUInteger channels = format.channels;
    NSUInteger width = region.size.width;
    if (!channels)
        return NO;
    if (channels == 4) {
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        GLint previous;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previous);
        NSUInteger attached = _attachedLevel;
        glBindFramebuffer(GL_FRAMEBUFFER, [self framebufferAtLevel:level]);
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        for (NSUInteger row = 0; row < region.size.height; row++)
            glReadPixels((GLint)region.origin.x, (GLint)(region.origin.y + row), (GLsizei)width, 1,
                         format.format == GL_BGRA_EXT ? GL_BGRA_EXT : GL_RGBA, GL_UNSIGNED_BYTE,
                         (uint8_t *)pointer + row * bytesPerRow);
        [self revenantRestoreAttachment:attached previous:previous];
        [device relinquish];
        return YES;
    }
    NSUInteger texel = format.channel * channels;
    uint8_t *scratch = calloc(1, width * 4 * format.channel);
    if (!scratch)
        return NO;
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    GLint previous;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previous);
    NSUInteger attached = _attachedLevel;
    glBindFramebuffer(GL_FRAMEBUFFER, [self framebufferAtLevel:level]);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    for (NSUInteger row = 0; row < region.size.height; row++) {
        glReadPixels((GLint)region.origin.x, (GLint)(region.origin.y + row), (GLsizei)width, 1, GL_RGBA, GL_UNSIGNED_BYTE, scratch);
        const uint8_t *source = scratch + row * width * 4 * format.channel;
        uint8_t *target = (uint8_t *)pointer + row * bytesPerRow;
        memcpy(target, source, width * texel);
    }
    [self revenantRestoreAttachment:attached previous:previous];
    [device relinquish];
    free(scratch);
    return YES;
}

- (BOOL)revenantWriteRegion:(MTLRegion)region level:(NSUInteger)level bytes:(const void *)pointer bytesPerRow:(NSUInteger)bytesPerRow
{
    RevenantFormat format;
    if (_screen || _kind || !formatFor(_pixelFormat, &format) || level >= _levels)
        return NO;
    if (!RevenantMetalDeviceHasExtension(format.extension))
        return NO;
    if (!bytesPerRow)
        bytesPerRow = region.size.width * format.bytes;
    if (bytesPerRow < region.size.width * format.bytes)
        return NO;
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    RevenantMetalBindEpoch++;
    glBindTexture(GL_TEXTURE_2D, _name);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (bytesPerRow == region.size.width * format.bytes) {
        glTexSubImage2D(GL_TEXTURE_2D, (GLint)level, (GLint)region.origin.x, (GLint)region.origin.y,
                        (GLsizei)region.size.width, (GLsizei)region.size.height, format.format, format.type, pointer);
    } else {
        for (NSUInteger row = 0; row < region.size.height; row++)
            glTexSubImage2D(GL_TEXTURE_2D, (GLint)level, (GLint)region.origin.x, (GLint)(region.origin.y + row),
                            (GLsizei)region.size.width, 1, format.format, format.type,
                            (const uint8_t *)pointer + row * bytesPerRow);
    }
    [device relinquish];
    return YES;
}

- (BOOL)revenantGenerateMipmaps
{
    RevenantFormat format;
    if (![self revenantIsColour] || _levels < 2 || !formatFor(_pixelFormat, &format))
        return NO;
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    RevenantMetalBindEpoch++;
    glBindTexture(GL_TEXTURE_2D, _name);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    GLint minFilter = GL_LINEAR;
    glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, &minFilter);
    glGetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, (GLint)minFilter);
    GLenum failure = glGetError();
    _appliedSampler = nil;
    [device relinquish];
    return failure == GL_NO_ERROR;
}

@end

@implementation RevenantMetalSampler {
    GLint _minFilter, _magFilter, _wrapS, _wrapT;
    GLenum _compareFunction;
}

@synthesize label;

static BOOL wrapFor(MTLSamplerAddressMode mode, GLint *out)
{
    switch (mode) {
    case MTLSamplerAddressModeClampToEdge: *out = GL_CLAMP_TO_EDGE; return YES;
    case MTLSamplerAddressModeRepeat: *out = GL_REPEAT; return YES;
    case MTLSamplerAddressModeMirrorRepeat: *out = GL_MIRRORED_REPEAT; return YES;
    default: return NO;
    }
}

- (instancetype)initWithDescriptor:(MTLSamplerDescriptor *)descriptor
{
    if ((self = [super init])) {
        if (!wrapFor(descriptor.sAddressMode, &_wrapS) || !wrapFor(descriptor.tAddressMode, &_wrapT)) {
            NSLog(@"Metal: sampler address mode %d/%d has no OpenGL ES 2.0 form", (int)descriptor.sAddressMode, (int)descriptor.tAddressMode);
            return nil;
        }
        if (!descriptor.normalizedCoordinates) {
            NSLog(@"Metal: sampler with pixel coordinates has no OpenGL ES 2.0 form");
            return nil;
        }
        switch (descriptor.compareFunction) {
        case MTLCompareFunctionLess: _compareFunction = GL_LESS; break;
        case MTLCompareFunctionEqual: _compareFunction = GL_EQUAL; break;
        case MTLCompareFunctionLessEqual: _compareFunction = GL_LEQUAL; break;
        case MTLCompareFunctionGreater: _compareFunction = GL_GREATER; break;
        case MTLCompareFunctionNotEqual: _compareFunction = GL_NOTEQUAL; break;
        case MTLCompareFunctionGreaterEqual: _compareFunction = GL_GEQUAL; break;
        case MTLCompareFunctionAlways: _compareFunction = GL_ALWAYS; break;
        default: _compareFunction = GL_NEVER; break;
        }
        _minFilter = descriptor.minFilter == MTLSamplerMinMagFilterNearest ? GL_NEAREST : GL_LINEAR;
        _magFilter = descriptor.magFilter == MTLSamplerMinMagFilterNearest ? GL_NEAREST : GL_LINEAR;
    }
    return self;
}

- (GLenum)compareFunction
{
    return _compareFunction;
}

- (GLint)minFilter
{
    return _minFilter;
}

- (GLint)magFilter
{
    return _magFilter;
}

- (GLint)wrapS
{
    return _wrapS;
}

- (GLint)wrapT
{
    return _wrapT;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}


- (MTLResourceID)gpuResourceID
{
    MTLResourceID empty = {0};
    return empty;
}

@end
