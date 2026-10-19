#import "CharonMetal.h"
#import "CharonMetalDebugGroups.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static float halfToFloat(uint16_t h)
{
    uint32_t sign = (h >> 15) & 1, exponent = (h >> 10) & 31, mantissa = h & 1023;
    float value;
    if (exponent == 0)
        value = ldexpf((float)mantissa, -24);
    else if (exponent == 31)
        value = mantissa ? NAN : INFINITY;
    else
        value = ldexpf((float)(mantissa | 1024), (int)exponent - 25);
    return sign ? -value : value;
}

@implementation CharonMetalEncoder {
    CharonMetalDevice *_device;
    CharonMetalPipeline *_pipeline;
    __strong CharonMetalBuffer *_vertexBuffers[31];
    NSUInteger _vertexOffsets[31];
    __strong CharonMetalBuffer *_fragmentBuffers[31];
    NSUInteger _fragmentOffsets[31];
    __strong CharonMetalTexture *_fragmentTextures[16];
    __strong CharonMetalSampler *_fragmentSamplers[16];
    CharonMetalTexture *_target;
    MTLViewport _viewport;
    BOOL _viewportSet;
    MTLCullMode _cull;
    MTLWinding _winding;
    BOOL _ended;
    NSUInteger _instance;
    const CharonPlan *_applied;
    BOOL _uniformsDirty, _attributesDirty, _texturesDirty, _viewportDirty;
    int _cullApplied;
    MTLWinding _windingApplied;
    uint32_t _enabled;
    GLuint _boundTexture[16];
    NSUInteger _epoch;
    __strong CharonMetalTexture *_targets[4];
    NSUInteger _targetCount;
    BOOL _hasDepth, _hasStencil, _depthDirty;
    CharonMetalDepthStencil *_depthStencil;
    uint32_t _frontReference, _backReference;
    __strong CharonMetalHeap *_heaps[8];
    NSUInteger _heapCount;
    NSMutableArray *_groups;
}

@synthesize label;

- (instancetype)initWithDescriptor:(MTLRenderPassDescriptor *)descriptor
{
    MTLRenderPassColorAttachmentDescriptor *color = descriptor.colorAttachments[0];
    CharonMetalTexture *texture = (CharonMetalTexture *)color.texture;
    if (![texture isKindOfClass:[CharonMetalTexture class]])
        return nil;
    if ((self = [super init])) {
        _device = [CharonMetalDevice shared];
        [_device acquire];
        _groups = [NSMutableArray array];
        _target = texture;
        _winding = MTLWindingClockwise;
        _cullApplied = -1;
        _viewportDirty = _viewportSet;
        for (int i = 0; i < 4; i++) {
            CharonMetalTexture *t = (CharonMetalTexture *)descriptor.colorAttachments[i].texture;
            if (![t isKindOfClass:[CharonMetalTexture class]])
                break;
            _targets[_targetCount++] = t;
        }
        CharonMetalTexture *depth = (CharonMetalTexture *)descriptor.depthAttachment.texture;
        CharonMetalTexture *stencil = (CharonMetalTexture *)descriptor.stencilAttachment.texture;
        if (![depth isKindOfClass:[CharonMetalTexture class]] || !(depth.attachmentKind == 1 || depth.attachmentKind == 2))
            depth = nil;
        if (![stencil isKindOfClass:[CharonMetalTexture class]] || !(stencil.attachmentKind == 2 || stencil.attachmentKind == 3))
            stencil = nil;
        _hasDepth = depth != nil;
        _hasStencil = stencil != nil;
        _depthDirty = YES;
        glDisable(GL_SCISSOR_TEST);
        glDisable(GL_POLYGON_OFFSET_FILL);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        for (NSUInteger i = 0; i < _targetCount; i++) {
            CharonMetalTexture *t = _targets[i];
            glBindFramebuffer(GL_FRAMEBUFFER, [t renderTarget]);
            if (depth)
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth.name, 0);
            else
                glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0);
            if (stencil && stencil.attachmentKind == 2)
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_TEXTURE_2D, stencil.name, 0);
            else if (stencil)
                glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, stencil.renderbuffer);
            else
                glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, 0);
            if ((depth || stencil) && (t.checkedDepth != (depth ? depth.name : 0) || t.checkedStencil != (stencil ? (stencil.attachmentKind == 3 ? stencil.renderbuffer : stencil.name) : 0))) {
                t.checkedDepth = depth ? depth.name : 0;
                t.checkedStencil = stencil ? (stencil.attachmentKind == 3 ? stencil.renderbuffer : stencil.name) : 0;
                GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
                if (status != GL_FRAMEBUFFER_COMPLETE)
                    NSLog(@"Metal: the colour, depth and stencil attachments make a framebuffer OpenGL ES 2.0 calls incomplete (0x%x); a stencil that is not packed with depth may be the cause", status);
            }
            glViewport(0, 0, (GLsizei)t.width, (GLsizei)t.height);
            GLbitfield clear = 0;
            MTLRenderPassColorAttachmentDescriptor *c = descriptor.colorAttachments[i];
            if (c.loadAction == MTLLoadActionClear) {
                MTLClearColor cc = c.clearColor;
                glClearColor(cc.red, cc.green, cc.blue, cc.alpha);
                clear |= GL_COLOR_BUFFER_BIT;
            }
            if (i == 0 && depth && descriptor.depthAttachment.loadAction == MTLLoadActionClear) {
                glDepthMask(GL_TRUE);
                glClearDepthf((GLfloat)descriptor.depthAttachment.clearDepth);
                clear |= GL_DEPTH_BUFFER_BIT;
            }
            if (i == 0 && stencil && descriptor.stencilAttachment.loadAction == MTLLoadActionClear) {
                glStencilMask(0xFFFFFFFF);
                glClearStencil((GLint)descriptor.stencilAttachment.clearStencil);
                clear |= GL_STENCIL_BUFFER_BIT;
            }
            if (clear)
                glClear(clear);
        }
        glBindFramebuffer(GL_FRAMEBUFFER, [texture renderTarget]);
    }
    return self;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (void)setRenderPipelineState:(id<MTLRenderPipelineState>)pipelineState
{
    _pipeline = (CharonMetalPipeline *)pipelineState;
    _uniformsDirty = _attributesDirty = _texturesDirty = YES;
}

- (void)setViewport:(MTLViewport)viewport
{
    _viewport = viewport;
    _viewportSet = YES;
    _viewportDirty = YES;
}

- (void)setCullMode:(MTLCullMode)cullMode
{
    _cull = cullMode;
}

- (void)setFrontFacingWinding:(MTLWinding)frontFacingWinding
{
    _winding = frontFacingWinding;
}

- (void)setBlendColorRed:(float)red green:(float)green blue:(float)blue alpha:(float)alpha
{
    glBlendColor(red, green, blue, alpha);
}

- (void)setDepthStencilState:(id<MTLDepthStencilState>)depthStencilState
{
    _depthStencil = (CharonMetalDepthStencil *)depthStencilState;
    _depthDirty = YES;
}

- (void)setStencilReferenceValue:(uint32_t)referenceValue
{
    _frontReference = _backReference = referenceValue;
    _depthDirty = YES;
}

- (void)setStencilFrontReferenceValue:(uint32_t)frontReferenceValue backReferenceValue:(uint32_t)backReferenceValue
{
    _frontReference = frontReferenceValue;
    _backReference = backReferenceValue;
    _depthDirty = YES;
}

- (void)setDepthBias:(float)depthBias slopeScale:(float)slopeScale clamp:(float)clamp
{
    if (depthBias == 0 && slopeScale == 0) {
        glDisable(GL_POLYGON_OFFSET_FILL);
    } else {
        glEnable(GL_POLYGON_OFFSET_FILL);
        glPolygonOffset(slopeScale, depthBias);
    }
}

- (void)setTriangleFillMode:(MTLTriangleFillMode)fillMode
{
    if (fillMode != MTLTriangleFillModeFill)
        NSLog(@"Metal: a triangle fill mode of lines has no form in OpenGL ES 2.0");
}

- (void)setScissorRect:(MTLScissorRect)rect
{
    glEnable(GL_SCISSOR_TEST);
    glScissor((GLint)rect.x, _target.screen ? (GLint)(_target.height - rect.y - rect.height) : (GLint)rect.y, (GLsizei)rect.width, (GLsizei)rect.height);
}

// The heaps -useHeap: and -useHeaps:count: name, and the check a bind makes against them. Metal leaves
// undefined what happens when a resource that did not come from one of them is bound, so the port says
// which resource it was rather than passing it by: an application that lists heaps and then binds
// something else has a bug the log names, and one that lists no heap is not checked at all.
- (void)charonUseHeaps:(id<MTLHeap> const *)heaps count:(NSUInteger)count
{
    _heapCount = 0;
    for (NSUInteger index = 0; index < count && index < 8; index++)
        _heaps[_heapCount++] = heaps[index];
}

- (void)charonCheckHeapOf:(id)resource what:(const char *)what
{
    if (!_heapCount || !resource)
        return;
    id<MTLHeap> heap = [(id<MTLResource>)resource heap];
    if (heap) {
        for (NSUInteger index = 0; index < _heapCount; index++)
            if (_heaps[index] == heap)
                return;
    }
    NSLog(@"Metal: %s of a resource that did not come from one of the %lu heaps this encoder was given; the heaps were %@",
          what, (unsigned long)_heapCount, [self charonHeapNames]);
}

- (NSString *)charonHeapNames
{
    NSMutableArray *names = [NSMutableArray array];
    for (NSUInteger index = 0; index < _heapCount; index++)
        [names addObject:_heaps[index].label ? _heaps[index].label
                                            : [NSString stringWithFormat:@"heap %lu", (unsigned long)index]];
    return [names componentsJoinedByString:@", "];
}

- (void)setVertexBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index
{
    [self charonCheckHeapOf:buffer what:"a vertex buffer"];
    if (index < 31) {
        _vertexBuffers[index] = (CharonMetalBuffer *)buffer;
        _vertexOffsets[index] = offset;
        _uniformsDirty = _attributesDirty = YES;
    }
}

- (void)setVertexBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index
{
    [self setVertexBuffer:(id<MTLBuffer>)[[CharonMetalBuffer alloc] initWithLength:length bytes:bytes] offset:0 atIndex:index];
}

- (void)setFragmentBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index
{
    [self charonCheckHeapOf:buffer what:"a fragment buffer"];
    if (index < 31) {
        _fragmentBuffers[index] = (CharonMetalBuffer *)buffer;
        _fragmentOffsets[index] = offset;
        _uniformsDirty = YES;
    }
}

- (void)setFragmentBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index
{
    [self setFragmentBuffer:(id<MTLBuffer>)[[CharonMetalBuffer alloc] initWithLength:length bytes:bytes] offset:0 atIndex:index];
}

- (void)setFragmentTexture:(id<MTLTexture>)texture atIndex:(NSUInteger)index
{
    [self charonCheckHeapOf:texture what:"a fragment texture"];
    if (index < 16)
    {
        _fragmentTextures[index] = (CharonMetalTexture *)texture;
        _texturesDirty = YES;
    }
}

- (void)setFragmentSamplerState:(id<MTLSamplerState>)sampler atIndex:(NSUInteger)index
{
    if (index < 16)
    {
        _fragmentSamplers[index] = (CharonMetalSampler *)sampler;
        _texturesDirty = YES;
    }
}

static void uploadUniforms(const CharonUniformPlan *plans, unsigned count, CharonMetalBuffer *__strong *buffers, const NSUInteger *offsets, NSUInteger instance)
{
    for (unsigned k = 0; k < count; k++) {
        const CharonUniformPlan *u = &plans[k];
        CharonMetalBuffer *buffer = u->buffer < 31 ? buffers[u->buffer] : nil;
        if (!buffer)
            continue;
        const uint8_t *p = (const uint8_t *)buffer.bytes + offsets[u->buffer] + u->offset + u->instanceStride * instance;
        int n = u->components;
        if (u->scalar == CharonScalarFloat || u->scalar == CharonScalarHalf) {
            GLfloat converted[4];
            const GLfloat *f = (const GLfloat *)p;
            if (u->scalar == CharonScalarHalf) {
                for (int i = 0; i < n; i++)
                    converted[i] = halfToFloat(((const uint16_t *)p)[i]);
                f = converted;
            }
            switch (n) {
            case 1: glUniform1fv(u->location, 1, f); break;
            case 2: glUniform2fv(u->location, 1, f); break;
            case 3: glUniform3fv(u->location, 1, f); break;
            default: glUniform4fv(u->location, 1, f); break;
            }
        } else {
            GLint v[4] = {0, 0, 0, 0};
            for (int i = 0; i < n; i++)
                v[i] = u->scalar == CharonScalarI32 ? ((const int32_t *)p)[i] : u->scalar == CharonScalarI16 ? ((const int16_t *)p)[i] : ((const int8_t *)p)[i];
            switch (n) {
            case 1: glUniform1iv(u->location, 1, v); break;
            case 2: glUniform2iv(u->location, 1, v); break;
            case 3: glUniform3iv(u->location, 1, v); break;
            default: glUniform4iv(u->location, 1, v); break;
            }
        }
    }
}

static GLfloat *ramp;
static NSUInteger rampCount;

static const GLfloat *rampOf(NSUInteger count)
{
    if (count > rampCount) {
        NSUInteger size = rampCount ? rampCount : 1024;
        while (size < count)
            size *= 2;
        GLfloat *grown = realloc(ramp, size * sizeof(GLfloat));
        for (NSUInteger i = rampCount; i < size; i++)
            grown[i] = (GLfloat)i;
        ramp = grown;
        rampCount = size;
    }
    return ramp;
}

- (void)setAttribute:(GLint)location enabled:(BOOL)enabled
{
    uint32_t bit = 1u << (location & 31);
    if (enabled && !(_enabled & bit)) {
        glEnableVertexAttribArray(location);
        _enabled |= bit;
    } else if (!enabled && (_enabled & bit)) {
        glDisableVertexAttribArray(location);
        _enabled &= ~bit;
    }
}

- (void)applyDepth
{
    const CharonDepthStencil *state = _depthStencil.state;
    if (_hasDepth) {
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(state ? state->depthFunction : GL_ALWAYS);
        glDepthMask(state ? state->depthWrite : GL_FALSE);
    } else {
        glDisable(GL_DEPTH_TEST);
    }
    if (_hasStencil && state && state->stencilEnabled) {
        glEnable(GL_STENCIL_TEST);
        glStencilFuncSeparate(GL_FRONT, state->front.function, (GLint)_frontReference, state->front.readMask);
        glStencilFuncSeparate(GL_BACK, state->back.function, (GLint)_backReference, state->back.readMask);
        glStencilOpSeparate(GL_FRONT, state->front.failure, state->front.depthFailure, state->front.pass);
        glStencilOpSeparate(GL_BACK, state->back.failure, state->back.depthFailure, state->back.pass);
        glStencilMaskSeparate(GL_FRONT, state->front.writeMask);
        glStencilMaskSeparate(GL_BACK, state->back.writeMask);
    } else {
        glDisable(GL_STENCIL_TEST);
    }
    _depthDirty = NO;
}

- (BOOL)prepareForVertexCount:(NSUInteger)count
{
    if (!_pipeline)
        return NO;
    const CharonPlan *plan = _pipeline.plan;
    if (plan != _applied) {
        glUseProgram(plan->program);
        if (plan->blending) {
            glEnable(GL_BLEND);
            glBlendFuncSeparate(plan->sourceRGB, plan->destinationRGB, plan->sourceAlpha, plan->destinationAlpha);
            glBlendEquationSeparate(plan->equationRGB, plan->equationAlpha);
        } else {
            glDisable(GL_BLEND);
        }
        glColorMask(plan->mask[0], plan->mask[1], plan->mask[2], plan->mask[3]);
        if (plan->flip >= 0)
            glUniform1f(plan->flip, _target.screen ? 1.0f : -1.0f);
        if (plan->instance >= 0)
            glUniform1f(plan->instance, (GLfloat)_instance);
        if (plan->target >= 0)
            glUniform2f(plan->target, (GLfloat)_target.width, (GLfloat)_target.height);
        _applied = plan;
        _uniformsDirty = _attributesDirty = _texturesDirty = YES;
        _cullApplied = -1;
    }
    if (_viewportDirty) {
        GLint y = _target.screen ? (GLint)(_target.height - _viewport.originY - _viewport.height) : (GLint)_viewport.originY;
        glViewport((GLint)_viewport.originX, y, (GLsizei)_viewport.width, (GLsizei)_viewport.height);
        _viewportDirty = NO;
    }
    if (_cullApplied != (int)_cull || _windingApplied != _winding) {
        BOOL flipped = !_target.screen;
        glFrontFace((_winding == MTLWindingClockwise) != flipped ? GL_CW : GL_CCW);
        if (_cull == MTLCullModeNone) {
            glDisable(GL_CULL_FACE);
        } else {
            glEnable(GL_CULL_FACE);
            glCullFace(_cull == MTLCullModeFront ? GL_FRONT : GL_BACK);
        }
        _cullApplied = (int)_cull;
        _windingApplied = _winding;
    }
    if (_depthDirty)
        [self applyDepth];
    if (plan->vertexId >= 0) {
        [self setAttribute:plan->vertexId enabled:YES];
        glVertexAttribPointer(plan->vertexId, 1, GL_FLOAT, GL_FALSE, 0, rampOf(count));
    }
    if (_attributesDirty) {
        for (unsigned k = 0; k < plan->attributeCount; k++) {
            const CharonAttributePlan *a = &plan->attributes[k];
            CharonMetalBuffer *buffer = a->buffer < 31 ? _vertexBuffers[a->buffer] : nil;
            if (!buffer) {
                [self setAttribute:a->location enabled:NO];
                continue;
            }
            [self setAttribute:a->location enabled:YES];
            glVertexAttribPointer(a->location, a->components, a->type, GL_FALSE, (GLsizei)a->stride, (const uint8_t *)buffer.bytes + _vertexOffsets[a->buffer] + a->offset);
        }
        for (unsigned k = 0; k < plan->inputCount; k++) {
            const CharonInputPlan *in = &plan->inputs[k];
            CharonMetalBuffer *buffer = in->buffer < 31 ? _vertexBuffers[in->buffer] : nil;
            if (!buffer) {
                [self setAttribute:in->location enabled:NO];
                continue;
            }
            const uint8_t *base = (const uint8_t *)buffer.bytes + _vertexOffsets[in->buffer] + in->offset;
            if (in->step == MTLVertexStepFunctionPerVertex) {
                [self setAttribute:in->location enabled:YES];
                glVertexAttribPointer(in->location, in->decoded.size, in->decoded.type, in->decoded.normalized, (GLsizei)in->stride, base);
            } else {
                NSUInteger element = in->step == MTLVertexStepFunctionConstant ? 0 : _instance / in->stepRate;
                GLfloat v[4];
                CharonMetalDecodeVertex(in->format, base + element * in->stride, v);
                [self setAttribute:in->location enabled:NO];
                glVertexAttrib4f(in->location, v[0], v[1], v[2], v[3]);
            }
        }
        _attributesDirty = NO;
    }
    if (_uniformsDirty) {
        uploadUniforms(plan->vertexUniforms, plan->vertexUniformCount, _vertexBuffers, _vertexOffsets, _instance);
        uploadUniforms(plan->fragmentUniforms, plan->fragmentUniformCount, _fragmentBuffers, _fragmentOffsets, _instance);
        _uniformsDirty = NO;
    }
    if (_epoch != CharonMetalBindEpoch) {
        memset(_boundTexture, 0, sizeof _boundTexture);
        _epoch = CharonMetalBindEpoch;
        _texturesDirty = YES;
    }
    if (_texturesDirty) {
        for (unsigned k = 0; k < plan->textureCount; k++) {
            unsigned unit = plan->textures[k].unit;
            CharonMetalTexture *texture = unit < 8 ? _fragmentTextures[unit] : nil;
            if (!texture)
                continue;
            glActiveTexture(GL_TEXTURE0 + unit);
            if (_boundTexture[unit] != texture.name) {
                glBindTexture(GL_TEXTURE_2D, texture.name);
                _boundTexture[unit] = texture.name;
            }
            CharonMetalSampler *sampler = _fragmentSamplers[unit];
            int compare = plan->textures[k].compare ? 1 : 0;
            if (sampler && (texture.appliedSampler != sampler || texture.appliedCompare != compare)) {
                BOOL depth = texture.attachmentKind != 0;
                // A format this device cannot filter, asked to be filtered, is what Metal answers with
                // a validation error: the draw is refused rather than filtered in the encoding, and the
                // log says which texture and which format, once per texture so a loop cannot flood it.
                if (!depth && sampler.minFilter == GL_LINEAR && ![texture charonCanFilter]) {
                    // Keyed by the TEXTURE and not by its name: two textures may carry one name, and a
                    // set keyed by the name would let the second one's refusal go unlogged forever.
                    // One line per texture, which is the most that can be said about a draw.
                    static NSMutableSet *refused;
                    static dispatch_once_t once;
                    dispatch_once(&once, ^{ refused = [NSMutableSet set]; });
                    if (![refused containsObject:(id)texture]) {
                        [refused addObject:(id)texture];
                        NSLog(@"Metal: a fragment texture of pixel format %d is filtered by a linear sampler and this device's driver cannot filter that format; the draw is drawn nearest instead, which is what a device without the format's linear filtering has",
                              (int)texture.pixelFormat);
                    }
                }
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, depth ? GL_NEAREST : sampler.minFilter);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, depth ? GL_NEAREST : sampler.magFilter);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, sampler.wrapS);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, sampler.wrapT);
                if (depth) {
                    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE_EXT, compare ? GL_COMPARE_REF_TO_TEXTURE_EXT : GL_NONE);
                    if (compare)
                        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_FUNC_EXT, sampler.compareFunction);
                }
                texture.appliedSampler = sampler;
                texture.appliedCompare = compare;
            }
            glUniform1i(plan->textures[k].location, (GLint)unit);
        }
        for (unsigned k = 0; k < plan->fetchCount; k++) {
            CharonMetalTexture *attachment = plan->fetches[k].attachment < _targetCount ? _targets[plan->fetches[k].attachment] : nil;
            if (!attachment)
                continue;
            unsigned unit = plan->fetches[k].unit;
            glActiveTexture(GL_TEXTURE0 + unit);
            glBindTexture(GL_TEXTURE_2D, attachment.name);
            _boundTexture[unit] = attachment.name;
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            attachment.appliedSampler = nil;
            glUniform1i(plan->fetches[k].location, (GLint)unit);
        }
        for (unsigned k = 0; k < plan->sizeCount; k++) {
            unsigned unit = plan->sizes[k].unit;
            if (unit < 16 && _fragmentTextures[unit])
                glUniform2f(plan->sizes[k].location, (GLfloat)_fragmentTextures[unit].width, (GLfloat)_fragmentTextures[unit].height);
        }
        _texturesDirty = NO;
    }
    return YES;
}

static GLenum primitive(MTLPrimitiveType type)
{
    switch (type) {
    case MTLPrimitiveTypePoint: return GL_POINTS;
    case MTLPrimitiveTypeLine: return GL_LINES;
    case MTLPrimitiveTypeLineStrip: return GL_LINE_STRIP;
    case MTLPrimitiveTypeTriangleStrip: return GL_TRIANGLE_STRIP;
    default: return GL_TRIANGLES;
    }
}

- (void)issue:(GLenum)mode first:(GLint)first count:(GLsizei)count indices:(const void *)indices type:(GLenum)type
{
    const CharonPlan *plan = _pipeline.plan;
    if (plan->outputCount == 1 && plan->outputIndex[0] == 0) {
        if (indices)
            glDrawElements(mode, count, type, indices);
        else
            glDrawArrays(mode, first, count);
        return;
    }
    for (unsigned n = plan->outputCount; n-- > 0;) {
        unsigned k = plan->outputIndex[n];
        if (k >= _targetCount)
            continue;
        const CharonBlend *b = &plan->blends[k];
        glBindFramebuffer(GL_FRAMEBUFFER, [_targets[k] renderTarget]);
        if (b->blending) {
            glEnable(GL_BLEND);
            glBlendFuncSeparate(b->sourceRGB, b->destinationRGB, b->sourceAlpha, b->destinationAlpha);
            glBlendEquationSeparate(b->equationRGB, b->equationAlpha);
        } else {
            glDisable(GL_BLEND);
        }
        glColorMask(b->mask[0], b->mask[1], b->mask[2], b->mask[3]);
        if (plan->output >= 0)
            glUniform1i(plan->output, (GLint)k);
        if (n != 0) {
            glDepthMask(GL_FALSE);
            glStencilMask(0);
        } else {
            [self applyDepth];
        }
        if (indices)
            glDrawElements(mode, count, type, indices);
        else
            glDrawArrays(mode, first, count);
    }
    _depthDirty = YES;
    _applied = NULL;
}

- (void)drawPrimitives:(MTLPrimitiveType)primitiveType vertexStart:(NSUInteger)vertexStart vertexCount:(NSUInteger)vertexCount
{
    if (![self prepareForVertexCount:vertexStart + vertexCount])
        return;
    [self issue:primitive(primitiveType) first:(GLint)vertexStart count:(GLsizei)vertexCount indices:NULL type:0];
}

- (void)drawPrimitives:(MTLPrimitiveType)primitiveType vertexStart:(NSUInteger)vertexStart vertexCount:(NSUInteger)vertexCount instanceCount:(NSUInteger)instanceCount
{
    for (_instance = 0; _instance < instanceCount; _instance++) {
        if (_applied && _applied->instance >= 0)
            glUniform1f(_applied->instance, (GLfloat)_instance);
        _uniformsDirty = _attributesDirty = YES;
        [self drawPrimitives:primitiveType vertexStart:vertexStart vertexCount:vertexCount];
    }
    _instance = 0;
    _uniformsDirty = _attributesDirty = YES;
}

- (void)drawIndexedPrimitives:(MTLPrimitiveType)primitiveType indexCount:(NSUInteger)indexCount indexType:(MTLIndexType)indexType indexBuffer:(id<MTLBuffer>)indexBuffer indexBufferOffset:(NSUInteger)indexBufferOffset instanceCount:(NSUInteger)instanceCount
{
    for (_instance = 0; _instance < instanceCount; _instance++) {
        if (_applied && _applied->instance >= 0)
            glUniform1f(_applied->instance, (GLfloat)_instance);
        _uniformsDirty = _attributesDirty = YES;
        [self drawIndexedPrimitives:primitiveType indexCount:indexCount indexType:indexType indexBuffer:indexBuffer indexBufferOffset:indexBufferOffset];
    }
    _instance = 0;
    _uniformsDirty = _attributesDirty = YES;
}

- (void)drawIndexedPrimitives:(MTLPrimitiveType)primitiveType indexCount:(NSUInteger)indexCount indexType:(MTLIndexType)indexType indexBuffer:(id<MTLBuffer>)indexBuffer indexBufferOffset:(NSUInteger)indexBufferOffset
{
    CharonMetalBuffer *buffer = (CharonMetalBuffer *)indexBuffer;
    const uint8_t *indices = (const uint8_t *)buffer.bytes + indexBufferOffset;
    NSUInteger maximum = 0;
    for (NSUInteger i = 0; _pipeline.plan->vertexId >= 0 && i < indexCount; i++) {
        NSUInteger v = indexType == MTLIndexTypeUInt16 ? ((const uint16_t *)indices)[i] : ((const uint32_t *)indices)[i];
        if (v > maximum)
            maximum = v;
    }
    if (![self prepareForVertexCount:maximum + 1])
        return;
    [self issue:primitive(primitiveType) first:0 count:(GLsizei)indexCount indices:indices type:indexType == MTLIndexTypeUInt16 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT];
}

- (void)pushDebugGroup:(NSString *)string
{
    CharonMetalPushDebugGroup(_groups, string);
}

- (void)popDebugGroup
{
    CharonMetalPopDebugGroup(_groups, self);
}

- (void)insertDebugSignpost:(NSString *)string
{
}

- (void)endEncoding
{
    if (_ended)
        return;
    _ended = YES;
    [_device relinquish];
}

- (void)dealloc
{
    [self endEncoding];
}

@end
