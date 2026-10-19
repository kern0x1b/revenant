#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// GL_HALF_FLOAT and its linear form are named by GL_OES_texture_half_float, not by ES 2.0's own
// headers, so they are here with the values that extension's header gives. Nothing else is defined:
// every other enum this file uses is in ES 2.0's headers.
#ifndef GL_HALF_FLOAT
#define GL_HALF_FLOAT 0x8D61
#endif
#ifndef GL_HALF_FLOAT_LINEAR
#define GL_HALF_FLOAT_LINEAR 0x8D62
#endif

// One entry per pixel format the port can hold: how the driver is told to store it, how many bytes a
// texel is, how many channels it has and how wide one channel is. The last two are not the same thing
// and the readback needs both: a read gives four channels of the channel's own width whatever the
// texture has, so a format of fewer channels is a copy of the leading ones, of a width that is the
// channel's.
typedef struct {
    GLint internal;
    GLenum format;
    GLenum type;
    NSUInteger bytes;      // a whole texel
    NSUInteger channels;   // how many of the four a texel has
    NSUInteger channel;    // how many bytes one of them is
    const char *extension;      // the extension a device must have for this format, NULL when ES 2.0 has it
    const char *linearExtension; // the extension a device must have to filter it, NULL when ES 2.0 can
} CharonFormat;

static BOOL formatFor(MTLPixelFormat pixelFormat, CharonFormat *out)
{
    switch ((NSUInteger)pixelFormat) {
    // The four 8-bit formats the port has always carried.
    case 70: *out = (CharonFormat){GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, 4, 4, 1, NULL, NULL}; return YES;
    case 80: *out = (CharonFormat){GL_RGBA, GL_BGRA_EXT, GL_UNSIGNED_BYTE, 4, 4, 1, NULL, NULL}; return YES;
    case 10: *out = (CharonFormat){GL_RED_EXT, GL_RED_EXT, GL_UNSIGNED_BYTE, 1, 1, 1, "GL_EXT_texture_rg", NULL}; return YES;
    case 30: *out = (CharonFormat){GL_RG_EXT, GL_RG_EXT, GL_UNSIGNED_BYTE, 2, 2, 1, "GL_EXT_texture_rg", NULL}; return YES;
    // The half floats: the SGX 543 of an iPad 2 lists GL_OES_texture_half_float and its linear form
    // (tests/backports/device/gl-extensions.m, 2026-09-24, and facts/SceneKit/SCNView.md), and
    // GL_HALF_FLOAT is what ES 2.0's own header names, so RGBA16Float needs nothing more.
    case 115: *out = (CharonFormat){GL_RGBA, GL_RGBA, GL_HALF_FLOAT, 8, 4, 2, "GL_OES_texture_half_float", "GL_OES_texture_half_float_linear"}; return YES;
    case 25: *out = (CharonFormat){GL_RED_EXT, GL_RED_EXT, GL_HALF_FLOAT, 2, 1, 2, "GL_OES_texture_half_float,GL_EXT_texture_rg", "GL_OES_texture_half_float_linear,GL_EXT_texture_rg"}; return YES;
    case 65: *out = (CharonFormat){GL_RG_EXT, GL_RG_EXT, GL_HALF_FLOAT, 4, 2, 2, "GL_OES_texture_half_float,GL_EXT_texture_rg", "GL_OES_texture_half_float_linear,GL_EXT_texture_rg"}; return YES;
    // The single floats, which need ES 2.0's OES_texture_float: a device without it answers as Metal
    // answers for a pixel format it does not support, which is nil from -newTextureWithDescriptor:.
    case 55: *out = (CharonFormat){GL_RED_EXT, GL_RED_EXT, GL_FLOAT, 4, 1, 4, "GL_OES_texture_float,GL_EXT_texture_rg", "GL_OES_texture_float_linear,GL_EXT_texture_rg"}; return YES;
    case 125: *out = (CharonFormat){GL_RGBA, GL_RGBA, GL_FLOAT, 16, 4, 4, "GL_OES_texture_float", "GL_OES_texture_float_linear"}; return YES;
    default: return NO;
    }
}

// What this device's driver offers, read once. A format whose extensions are not all in this string is
// one the GPU cannot hold, and the answer for it is the same as for a format ES 2.0 has no form of: no
// texture, and one line in the log saying which extension is missing. The names are compared whole, so
// a name that is the prefix of another one does not count as present.
static BOOL CharonMetalDeviceHasExtension(const char *required)
{
    static char *extensions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CharonMetalDevice *device = [CharonMetalDevice shared];
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

NSUInteger CharonMetalBindEpoch;

@implementation CharonMetalTexture {
    GLuint _name;
    GLuint _framebuffer;
    BOOL _screen;
    MTLPixelFormat _pixelFormat;
    NSUInteger _width;
    NSUInteger _height;
    NSUInteger _levels;
    MTLTextureUsage _usage;
    __unsafe_unretained CharonMetalSampler *_appliedSampler;
    int _kind;
    GLuint _renderbuffer;
    GLuint _checkedDepth, _checkedStencil;
    int _appliedCompare;
    __strong CharonMetalHeap *_charonHeap;
    NSUInteger _charonHeapOffset;
    // The level the one framebuffer of this texture has attached, NSNotFound when it has none. The
    // attachment is a property of the framebuffer, not of the call, so it is remembered: a read of a
    // level below the first changes it, and the next caller has to be able to see that.
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
        CharonMetalDevice *device = [CharonMetalDevice shared];
        [device acquire];
        if (kind == 3) {
            glGenRenderbuffers(1, &_renderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, (GLsizei)_width, (GLsizei)_height);
        } else {
            CharonMetalBindEpoch++;
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
    CharonFormat format;
    if (descriptor.textureType != MTLTextureType2D || !formatFor(descriptor.pixelFormat, &format) || descriptor.sampleCount != 1 || descriptor.width == 0 || descriptor.height == 0) {
        NSLog(@"Metal: texture of type %d, pixel format %d, %d samples has no OpenGL ES 2.0 form", (int)descriptor.textureType, (int)descriptor.pixelFormat, (int)descriptor.sampleCount);
        return nil;
    }
    if (!CharonMetalDeviceHasExtension(format.extension)) {
        // What Metal answers for a pixel format this device does not support: no texture. The line says
        // which extension is missing, because "unsupported" on its own would not tell a caller why.
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
        CharonMetalDevice *device = [CharonMetalDevice shared];
        [device acquire];
        CharonMetalBindEpoch++;
        glGenTextures(1, &_name);
        glBindTexture(GL_TEXTURE_2D, _name);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        // Every level of the chain is allocated here, so a level below is a texture the driver can
        // sample, blit to and read back, not a name it refuses.
        for (NSUInteger level = 0; level < _levels; level++)
            glTexImage2D(GL_TEXTURE_2D, (GLint)level, format.internal,
                         (GLsizei)levelExtent(_width, level), (GLsizei)levelExtent(_height, level), 0,
                         format.format, format.type, NULL);
        [device relinquish];
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
    if (!_screen && (_name || _renderbuffer)) {
        CharonMetalDevice *device = [CharonMetalDevice shared];
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

- (CharonMetalSampler *)appliedSampler
{
    return _appliedSampler;
}

- (void)setAppliedSampler:(CharonMetalSampler *)sampler
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
    return [CharonMetalDevice shared];
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
    [self charonWriteRegion:region level:level bytes:pointer bytesPerRow:bytesPerRow];
}

- (void)getBytes:(void *)pointer bytesPerRow:(NSUInteger)bytesPerRow fromRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level
{
    [self charonReadRegion:region level:level bytesPerRow:bytesPerRow into:pointer];
}

// What a texture of this shape takes out of a heap: every level of its chain at its own size, in the
// texture's own channel count, which is the same arithmetic the driver's own allocation does.
- (NSUInteger)charonStorageSize
{
    CharonFormat format;
    if (!formatFor(_pixelFormat, &format))
        return 0;
    NSUInteger levels = _levels ? _levels : 1;
    NSUInteger total = 0;
    for (NSUInteger level = 0; level < levels; level++)
        total += levelExtent(_width, level) * levelExtent(_height, level) * format.bytes;
    return total;
}

- (void)charonSetHeap:(CharonMetalHeap *)heap offset:(NSUInteger)offset
{
    _charonHeap = heap;
    _charonHeapOffset = offset;
}

// MTLResource's own properties, answered as the SDK declares them.
- (id<MTLHeap>)heap
{
    return _charonHeap;
}

- (NSUInteger)heapOffset
{
    return _charonHeapOffset;
}

- (BOOL)charonIsColour
{
    CharonFormat format;
    return !_kind && !_screen && formatFor(_pixelFormat, &format);
}

// Whether this device can filter this texture, which is a different question from whether it can
// hold it: ES 2.0 can filter the 8-bit formats with nothing, a half float only with
// GL_OES_texture_half_float_linear and a float only with GL_OES_texture_float_linear. Metal answers a
// draw that filters a format which is not filterable with a validation error, and so does this.
- (BOOL)charonCanFilter
{
    CharonFormat format;
    if (!formatFor(_pixelFormat, &format))
        return NO;
    return CharonMetalDeviceHasExtension(format.linearExtension);
}

- (NSUInteger)charonChannels
{
    CharonFormat format;
    if (!formatFor(_pixelFormat, &format))
        return 0;
    return format.bytes;
}

// The one framebuffer of this texture, with the level asked for attached to it. Both the creation and
// the re-attachment attach the level that was asked for: a framebuffer created for a read of the third
// level has the third level attached, or that read would return the first level's pixels.
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

// The texture's framebuffer is one object with one attachment, and a read of a level below the first
// leaves it attached to that level. Whatever was attached before the read is attached again here, and
// the binding the caller had is restored, so that a render into the texture afterwards finds the level
// it would have found had nothing read in between.
- (void)charonRestoreAttachment:(NSUInteger)level previous:(GLint)previous
{
    if (!_screen && _attachedLevel != level) {
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _name, (GLint)level);
        _attachedLevel = level;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)previous);
}

// ES 2.0 reads a colour attachment as RGBA/UNSIGNED_BYTE whatever the texture's own format is, so a
// read of a texture with fewer or swapped channels is repacked here into the bytes Metal says the
// texture holds. That is the same pixels in the same order the texture would report, not an
// approximation of them.
- (BOOL)charonReadRegion:(MTLRegion)region level:(NSUInteger)level bytesPerRow:(NSUInteger)bytesPerRow into:(void *)pointer
{
    CharonFormat format;
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
        CharonMetalDevice *device = [CharonMetalDevice shared];
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
        [self charonRestoreAttachment:attached previous:previous];
        [device relinquish];
        return YES;
    }
    // A read gives four channels of the channel's own width whatever the texture has, so a texture
    // with fewer channels is the leading ones copied out of that row: two 16-bit channels are the
    // first four bytes of each eight, and one 32-bit channel is the first four bytes of each sixteen.
    NSUInteger texel = format.channel * channels;
    uint8_t *scratch = calloc(1, width * 4 * format.channel);
    if (!scratch)
        return NO;
    CharonMetalDevice *device = [CharonMetalDevice shared];
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
    [self charonRestoreAttachment:attached previous:previous];
    [device relinquish];
    free(scratch);
    return YES;
}

- (BOOL)charonWriteRegion:(MTLRegion)region level:(NSUInteger)level bytes:(const void *)pointer bytesPerRow:(NSUInteger)bytesPerRow
{
    CharonFormat format;
    if (_screen || _kind || !formatFor(_pixelFormat, &format) || level >= _levels)
        return NO;
    if (!CharonMetalDeviceHasExtension(format.extension))
        return NO;
    if (!bytesPerRow)
        bytesPerRow = region.size.width * format.bytes;
    if (bytesPerRow < region.size.width * format.bytes)
        return NO;
    CharonMetalDevice *device = [CharonMetalDevice shared];
    [device acquire];
    CharonMetalBindEpoch++;
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

// A mip chain is only complete once its minification filter reads beyond level 0, which is what
// glGenerateMipmap wants, so the filter is one that reads the chain for the call.
//
// The filter is read back afterwards and put back as it was, not set to a constant: the filter of
// this texture at this moment is whatever the last draw through it left there, which is the filter
// of that draw's sampler, not the one the texture was created with. And because the call changes the
// texture's own filter, the sampler it last had applied is forgotten, so that the next draw through
// this texture re-applies its own sampler instead of finding the cache still holding the previous one
// and leaving the texture filtering the way this call left it.
- (BOOL)charonGenerateMipmaps
{
    CharonFormat format;
    if (![self charonIsColour] || _levels < 2 || !formatFor(_pixelFormat, &format))
        return NO;
    CharonMetalDevice *device = [CharonMetalDevice shared];
    [device acquire];
    CharonMetalBindEpoch++;
    glBindTexture(GL_TEXTURE_2D, _name);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    // ES 2.0 reports through the one error flag rather than through a return value, so the flag is
    // read once before the call and once after: an error left by anything else cannot be mistaken for
    // this call's, and this call's own error is not cleared for whoever reads it next.
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

@implementation CharonMetalSampler {
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
    return [CharonMetalDevice shared];
}


// MTLSamplerState's gpuResourceID, which a review of my own work measured and I had put on the
// WRONG CLASS: the criterion in tests/backports/host/protocol-conformance.sh reads the protocol's members
// from the AST rather than from warnings, and it is what found this - -Wprotocol does not see property
// accessors, and -Wobjc-protocol-property-synthesis cannot tell a hand-written getter from a missing
// one, so both were clean while the getter sat on the texture. MTLTexture.h:424 describes it as a
// handle to a resource fit for an argument buffer, and this device is the
// port's own over OpenGL ES 2.0, so the answer is a typed zero rather than a selector that raises.
- (MTLResourceID)gpuResourceID
{
    // MTLResourceID is a STRUCT, so "(MTLResourceID)0" is arithmetic on a type that has none and the
    // compiler says so. A zero-initialised struct is the same value and is legal: every field is the
    // struct's own zero, which is what "no handle" means for a struct handle.
    MTLResourceID empty = {0};
    return empty;
}

@end
