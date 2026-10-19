// NOT CharonMetal.h: that header reaches OpenGLES/EAGL.h, which is a DEVICE framework, and this file
// needs nothing from it - the descriptors hold values and name no object of the port's own. A host
// differential that #includes this file (descriptors26.sh) could not compile it otherwise, and a header
// imported for nothing is a header that will be missed when something is added that needs it.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import "CharonMetal26Types.h"
#import "CharonMetalProtocols.h"

// THE PIPELINE DESCRIPTORS OF METAL 4, and they are the same kind of thing as the twenty in
// MTLDescriptors16.m: plain data holders that say what a pipeline is built FROM and ask the device
// nothing. Every one of them arrived with the SDK of iOS 26, so every one of them is in this object
// and no other release's API is: an object holds the API of ONE release, and this file's is 26.0.
//
// EVERY DEFAULT BELOW IS APPLE'S OWN, MEASURED against a fresh object of Apple's class on a machine
// with a Metal device, not read off a header - and the measurement is in
// tests/backports/host/metal-census/descriptors26.sh, which asks both sides and compares. The ones a
// header does not give are exactly the ones worth measuring:
//
//   * a fresh MTL4PipelineDescriptor's `options` is NIL, not an object;
//   * a fresh MTL4RenderPipelineDescriptor's `vertexDescriptor` IS an object, a fresh MTLVertexDescriptor;
//   * the three `null_resettable` static linking descriptors are objects on a fresh descriptor, made by
//     the getter when there is none;
//   * `rasterSampleCount` and `maxVertexAmplificationCount` are 1, and `isRasterizationEnabled` is YES;
//   * the colour attachment's write mask is MTLColorWriteMaskAll (15), its source factors are One and
//     its destination factors Zero, its operations Add, and its pixel format MTLPixelFormatInvalid (0);
//   * a stage's `maxCallStackDepth` is 1, not 0;
//   * the colour attachment array has EIGHT slots: indices 0 to 7 answer a descriptor and index 8
//     fails Apple's own assertion, which is measured out of process because an assertion stops it.
//
// WHAT THESE OBJECTS ARE NOT is stated once, at the end, and it is the same half a caller has to know
// about the 16.0 descriptors: this port vends no object that reads a descriptor made here. The mesh
// pipeline's three MTL4FunctionDescriptor members ARE the pipeline's object, mesh and fragment stages
// rather than values this port can hold, and this port's rendering path is Metal over OpenGL ES 2.0
// (facts/Metal/RenderPath.md), which has no mesh stage and no geometry or tessellation stage either.
// facts/Metal/Descriptors26.md is the whole of it.

// The colour attachment's defaults as one function, because four classes' -reset have to put them
// back and a reset that spelled them out four times would be four places to get wrong.
static void CharonMetal4ResetBlendState(MTL4RenderPipelineColorAttachmentDescriptor *attachment);

@implementation MTL4PipelineOptions {
    MTLShaderValidation _shaderValidation;
    MTL4ShaderReflection _shaderReflection;
}

@synthesize shaderValidation = _shaderValidation;
@synthesize shaderReflection = _shaderReflection;

- (id)copyWithZone:(NSZone *)zone
{
    MTL4PipelineOptions *copy = [[MTL4PipelineOptions alloc] init];
    copy.shaderValidation = _shaderValidation;
    copy.shaderReflection = _shaderReflection;
    return copy;
}


// VALUE EQUALITY, MEMBER BY MEMBER, because Apple's own object has an -isEqual: and an -hash of its own and that
// changes what an application can do with two of them: two descriptors that describe the same thing are the same
// value. Measured against Apple's own object: two fresh ones are equal, their hashes agree, and a copy equals its
// source.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4PipelineOptions class]]) return NO;
    if (self.shaderValidation != ((MTL4PipelineOptions *)object).shaderValidation) return NO;
    if (self.shaderReflection != ((MTL4PipelineOptions *)object).shaderReflection) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)self.shaderValidation;
    hash = hash * 31u + (uint32_t)self.shaderReflection;
    return hash;
}

@end

@implementation MTL4StaticLinkingDescriptor {
    NSArray *_functionDescriptors;
    NSArray *_privateFunctionDescriptors;
    NSDictionary *_groups;
}

@synthesize functionDescriptors = _functionDescriptors;
@synthesize privateFunctionDescriptors = _privateFunctionDescriptors;
@synthesize groups = _groups;

- (id)copyWithZone:(NSZone *)zone
{
    MTL4StaticLinkingDescriptor *copy = [[MTL4StaticLinkingDescriptor alloc] init];
    copy.functionDescriptors = _functionDescriptors;
    copy.privateFunctionDescriptors = _privateFunctionDescriptors;
    copy.groups = _groups;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4StaticLinkingDescriptor class]]) return NO;
    if (self.functionDescriptors != ((MTL4StaticLinkingDescriptor *)object).functionDescriptors && ![self.functionDescriptors isEqual:((MTL4StaticLinkingDescriptor *)object).functionDescriptors]) return NO;
    if (self.privateFunctionDescriptors != ((MTL4StaticLinkingDescriptor *)object).privateFunctionDescriptors && ![self.privateFunctionDescriptors isEqual:((MTL4StaticLinkingDescriptor *)object).privateFunctionDescriptors]) return NO;
    if (self.groups != ((MTL4StaticLinkingDescriptor *)object).groups && ![self.groups isEqual:((MTL4StaticLinkingDescriptor *)object).groups]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.functionDescriptors hash];
    hash = hash * 31u + (uint32_t)[self.privateFunctionDescriptors hash];
    hash = hash * 31u + (uint32_t)[self.groups hash];
    return hash;
}

@end

@implementation MTL4PipelineStageDynamicLinkingDescriptor {
    NSUInteger _maxCallStackDepth;
    NSArray *_binaryLinkedFunctions;
    NSArray *_preloadedLibraries;
}

@synthesize maxCallStackDepth = _maxCallStackDepth;
@synthesize binaryLinkedFunctions = _binaryLinkedFunctions;
@synthesize preloadedLibraries = _preloadedLibraries;

// 1 is Apple's own default, measured: a stage links one frame deep unless the descriptor says more.
- (instancetype)init
{
    if ((self = [super init]))
        _maxCallStackDepth = 1;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4PipelineStageDynamicLinkingDescriptor *copy = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
    copy.maxCallStackDepth = _maxCallStackDepth;
    copy.binaryLinkedFunctions = _binaryLinkedFunctions;
    copy.preloadedLibraries = _preloadedLibraries;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4PipelineStageDynamicLinkingDescriptor class]]) return NO;
    if (self.maxCallStackDepth != ((MTL4PipelineStageDynamicLinkingDescriptor *)object).maxCallStackDepth) return NO;
    if (self.binaryLinkedFunctions != ((MTL4PipelineStageDynamicLinkingDescriptor *)object).binaryLinkedFunctions && ![self.binaryLinkedFunctions isEqual:((MTL4PipelineStageDynamicLinkingDescriptor *)object).binaryLinkedFunctions]) return NO;
    if (self.preloadedLibraries != ((MTL4PipelineStageDynamicLinkingDescriptor *)object).preloadedLibraries && ![self.preloadedLibraries isEqual:((MTL4PipelineStageDynamicLinkingDescriptor *)object).preloadedLibraries]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)self.maxCallStackDepth;
    hash = hash * 31u + (uint32_t)[self.binaryLinkedFunctions hash];
    hash = hash * 31u + (uint32_t)[self.preloadedLibraries hash];
    return hash;
}

@end

// The five stages are the five readonly members the header declares, each an object on a fresh
// descriptor: they are made here rather than on first use because that is what Apple's own object
// answers, and a getter that made one would answer nil first.
@implementation MTL4RenderPipelineDynamicLinkingDescriptor {
    MTL4PipelineStageDynamicLinkingDescriptor *_vertexLinkingDescriptor;
    MTL4PipelineStageDynamicLinkingDescriptor *_fragmentLinkingDescriptor;
    MTL4PipelineStageDynamicLinkingDescriptor *_tileLinkingDescriptor;
    MTL4PipelineStageDynamicLinkingDescriptor *_objectLinkingDescriptor;
    MTL4PipelineStageDynamicLinkingDescriptor *_meshLinkingDescriptor;
}

@synthesize vertexLinkingDescriptor = _vertexLinkingDescriptor;
@synthesize fragmentLinkingDescriptor = _fragmentLinkingDescriptor;
@synthesize tileLinkingDescriptor = _tileLinkingDescriptor;
@synthesize objectLinkingDescriptor = _objectLinkingDescriptor;
@synthesize meshLinkingDescriptor = _meshLinkingDescriptor;

- (instancetype)init
{
    if ((self = [super init])) {
        _vertexLinkingDescriptor = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
        _fragmentLinkingDescriptor = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
        _tileLinkingDescriptor = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
        _objectLinkingDescriptor = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
        _meshLinkingDescriptor = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // The five members are readonly, so the copy takes the IVARS rather than the properties: they are
    // this class's own, and a copy that went through a setter that does not exist would be a setter
    // invented for the copy's sake.
    MTL4RenderPipelineDynamicLinkingDescriptor *copy = [[MTL4RenderPipelineDynamicLinkingDescriptor alloc] init];
    copy->_vertexLinkingDescriptor = [_vertexLinkingDescriptor copy];
    copy->_fragmentLinkingDescriptor = [_fragmentLinkingDescriptor copy];
    copy->_tileLinkingDescriptor = [_tileLinkingDescriptor copy];
    copy->_objectLinkingDescriptor = [_objectLinkingDescriptor copy];
    copy->_meshLinkingDescriptor = [_meshLinkingDescriptor copy];
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4RenderPipelineDynamicLinkingDescriptor class]]) return NO;
    if (self.vertexLinkingDescriptor != ((MTL4RenderPipelineDynamicLinkingDescriptor *)object).vertexLinkingDescriptor && ![self.vertexLinkingDescriptor isEqual:((MTL4RenderPipelineDynamicLinkingDescriptor *)object).vertexLinkingDescriptor]) return NO;
    if (self.fragmentLinkingDescriptor != ((MTL4RenderPipelineDynamicLinkingDescriptor *)object).fragmentLinkingDescriptor && ![self.fragmentLinkingDescriptor isEqual:((MTL4RenderPipelineDynamicLinkingDescriptor *)object).fragmentLinkingDescriptor]) return NO;
    if (self.tileLinkingDescriptor != ((MTL4RenderPipelineDynamicLinkingDescriptor *)object).tileLinkingDescriptor && ![self.tileLinkingDescriptor isEqual:((MTL4RenderPipelineDynamicLinkingDescriptor *)object).tileLinkingDescriptor]) return NO;
    if (self.objectLinkingDescriptor != ((MTL4RenderPipelineDynamicLinkingDescriptor *)object).objectLinkingDescriptor && ![self.objectLinkingDescriptor isEqual:((MTL4RenderPipelineDynamicLinkingDescriptor *)object).objectLinkingDescriptor]) return NO;
    if (self.meshLinkingDescriptor != ((MTL4RenderPipelineDynamicLinkingDescriptor *)object).meshLinkingDescriptor && ![self.meshLinkingDescriptor isEqual:((MTL4RenderPipelineDynamicLinkingDescriptor *)object).meshLinkingDescriptor]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.vertexLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.fragmentLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.tileLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.objectLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.meshLinkingDescriptor hash];
    return hash;
}

@end

@implementation MTL4RenderPipelineBinaryFunctionsDescriptor {
    NSArray *_vertexAdditionalBinaryFunctions;
    NSArray *_fragmentAdditionalBinaryFunctions;
    NSArray *_tileAdditionalBinaryFunctions;
    NSArray *_objectAdditionalBinaryFunctions;
    NSArray *_meshAdditionalBinaryFunctions;
}

@synthesize vertexAdditionalBinaryFunctions = _vertexAdditionalBinaryFunctions;
@synthesize fragmentAdditionalBinaryFunctions = _fragmentAdditionalBinaryFunctions;
@synthesize tileAdditionalBinaryFunctions = _tileAdditionalBinaryFunctions;
@synthesize objectAdditionalBinaryFunctions = _objectAdditionalBinaryFunctions;
@synthesize meshAdditionalBinaryFunctions = _meshAdditionalBinaryFunctions;

- (void)reset
{
    _vertexAdditionalBinaryFunctions = nil;
    _fragmentAdditionalBinaryFunctions = nil;
    _tileAdditionalBinaryFunctions = nil;
    _objectAdditionalBinaryFunctions = nil;
    _meshAdditionalBinaryFunctions = nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4RenderPipelineBinaryFunctionsDescriptor *copy = [[MTL4RenderPipelineBinaryFunctionsDescriptor alloc] init];
    copy.vertexAdditionalBinaryFunctions = _vertexAdditionalBinaryFunctions;
    copy.fragmentAdditionalBinaryFunctions = _fragmentAdditionalBinaryFunctions;
    copy.tileAdditionalBinaryFunctions = _tileAdditionalBinaryFunctions;
    copy.objectAdditionalBinaryFunctions = _objectAdditionalBinaryFunctions;
    copy.meshAdditionalBinaryFunctions = _meshAdditionalBinaryFunctions;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4RenderPipelineBinaryFunctionsDescriptor class]]) return NO;
    if (self.vertexAdditionalBinaryFunctions != ((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).vertexAdditionalBinaryFunctions && ![self.vertexAdditionalBinaryFunctions isEqual:((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).vertexAdditionalBinaryFunctions]) return NO;
    if (self.fragmentAdditionalBinaryFunctions != ((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).fragmentAdditionalBinaryFunctions && ![self.fragmentAdditionalBinaryFunctions isEqual:((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).fragmentAdditionalBinaryFunctions]) return NO;
    if (self.tileAdditionalBinaryFunctions != ((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).tileAdditionalBinaryFunctions && ![self.tileAdditionalBinaryFunctions isEqual:((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).tileAdditionalBinaryFunctions]) return NO;
    if (self.objectAdditionalBinaryFunctions != ((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).objectAdditionalBinaryFunctions && ![self.objectAdditionalBinaryFunctions isEqual:((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).objectAdditionalBinaryFunctions]) return NO;
    if (self.meshAdditionalBinaryFunctions != ((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).meshAdditionalBinaryFunctions && ![self.meshAdditionalBinaryFunctions isEqual:((MTL4RenderPipelineBinaryFunctionsDescriptor *)object).meshAdditionalBinaryFunctions]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.vertexAdditionalBinaryFunctions hash];
    hash = hash * 31u + (uint32_t)[self.fragmentAdditionalBinaryFunctions hash];
    hash = hash * 31u + (uint32_t)[self.tileAdditionalBinaryFunctions hash];
    hash = hash * 31u + (uint32_t)[self.objectAdditionalBinaryFunctions hash];
    hash = hash * 31u + (uint32_t)[self.meshAdditionalBinaryFunctions hash];
    return hash;
}

@end

@implementation MTL4RenderPipelineColorAttachmentDescriptor {
    MTLPixelFormat _pixelFormat;
    MTL4BlendState _blendingState;
    MTLBlendFactor _sourceRGBBlendFactor;
    MTLBlendFactor _destinationRGBBlendFactor;
    MTLBlendOperation _rgbBlendOperation;
    MTLBlendFactor _sourceAlphaBlendFactor;
    MTLBlendFactor _destinationAlphaBlendFactor;
    MTLBlendOperation _alphaBlendOperation;
    MTLColorWriteMask _writeMask;
}

@synthesize pixelFormat = _pixelFormat;
@synthesize blendingState = _blendingState;
@synthesize sourceRGBBlendFactor = _sourceRGBBlendFactor;
@synthesize destinationRGBBlendFactor = _destinationRGBBlendFactor;
@synthesize rgbBlendOperation = _rgbBlendOperation;
@synthesize sourceAlphaBlendFactor = _sourceAlphaBlendFactor;
@synthesize destinationAlphaBlendFactor = _destinationAlphaBlendFactor;
@synthesize alphaBlendOperation = _alphaBlendOperation;
@synthesize writeMask = _writeMask;

// The header's own defaults, member by member (MTL4RenderPipeline.h:52 onwards): the format is
// MTLPixelFormatInvalid, the blend state is MTL4BlendStateDisabled, the source factors are One, the
// destination factors Zero, both operations Add and the write mask MTLColorWriteMaskAll. Measured
// against Apple's own fresh object, and the numbers are 0/0/1/0/0/1/0/0/15.
- (instancetype)init
{
    if ((self = [super init])) {
        _pixelFormat = MTLPixelFormatInvalid;
        _blendingState = MTL4BlendStateDisabled;
        _sourceRGBBlendFactor = MTLBlendFactorOne;
        _destinationRGBBlendFactor = MTLBlendFactorZero;
        _rgbBlendOperation = MTLBlendOperationAdd;
        _sourceAlphaBlendFactor = MTLBlendFactorOne;
        _destinationAlphaBlendFactor = MTLBlendFactorZero;
        _alphaBlendOperation = MTLBlendOperationAdd;
        _writeMask = MTLColorWriteMaskAll;
    }
    return self;
}

- (void)reset
{
    CharonMetal4ResetBlendState(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4RenderPipelineColorAttachmentDescriptor *copy = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
    copy.pixelFormat = _pixelFormat;
    copy.blendingState = _blendingState;
    copy.sourceRGBBlendFactor = _sourceRGBBlendFactor;
    copy.destinationRGBBlendFactor = _destinationRGBBlendFactor;
    copy.rgbBlendOperation = _rgbBlendOperation;
    copy.sourceAlphaBlendFactor = _sourceAlphaBlendFactor;
    copy.destinationAlphaBlendFactor = _destinationAlphaBlendFactor;
    copy.alphaBlendOperation = _alphaBlendOperation;
    copy.writeMask = _writeMask;
    return copy;
}


// VALUE EQUALITY, MEMBER BY MEMBER, and the ninth member is the one a differential can watch: measured against
// Apple's own object, two fresh attachments are equal, one whose write mask is MTLColorWriteMaskRed against one
// whose is MTLColorWriteMaskAll is not, and Red against Red is.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4RenderPipelineColorAttachmentDescriptor class]]) return NO;
    if (self.pixelFormat != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).pixelFormat) return NO;
    if (self.blendingState != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).blendingState) return NO;
    if (self.sourceRGBBlendFactor != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).sourceRGBBlendFactor) return NO;
    if (self.destinationRGBBlendFactor != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).destinationRGBBlendFactor) return NO;
    if (self.rgbBlendOperation != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).rgbBlendOperation) return NO;
    if (self.sourceAlphaBlendFactor != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).sourceAlphaBlendFactor) return NO;
    if (self.destinationAlphaBlendFactor != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).destinationAlphaBlendFactor) return NO;
    if (self.alphaBlendOperation != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).alphaBlendOperation) return NO;
    if (self.writeMask != ((MTL4RenderPipelineColorAttachmentDescriptor *)object).writeMask) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)self.pixelFormat;
    hash = hash * 31u + (uint32_t)self.blendingState;
    hash = hash * 31u + (uint32_t)self.sourceRGBBlendFactor;
    hash = hash * 31u + (uint32_t)self.destinationRGBBlendFactor;
    hash = hash * 31u + (uint32_t)self.rgbBlendOperation;
    hash = hash * 31u + (uint32_t)self.sourceAlphaBlendFactor;
    hash = hash * 31u + (uint32_t)self.destinationAlphaBlendFactor;
    hash = hash * 31u + (uint32_t)self.alphaBlendOperation;
    hash = hash * 31u + (uint32_t)self.writeMask;
    return hash;
}

@end

// The defaults, in one place, because four -reset methods have to put them back: a reset that spelled
// them out four times would be four places to get wrong and one place to measure.
static void CharonMetal4ResetBlendState(MTL4RenderPipelineColorAttachmentDescriptor *attachment)
{
    attachment.pixelFormat = MTLPixelFormatInvalid;
    attachment.blendingState = MTL4BlendStateDisabled;
    attachment.sourceRGBBlendFactor = MTLBlendFactorOne;
    attachment.destinationRGBBlendFactor = MTLBlendFactorZero;
    attachment.rgbBlendOperation = MTLBlendOperationAdd;
    attachment.sourceAlphaBlendFactor = MTLBlendFactorOne;
    attachment.destinationAlphaBlendFactor = MTLBlendFactorZero;
    attachment.alphaBlendOperation = MTLBlendOperationAdd;
    attachment.writeMask = MTLColorWriteMaskAll;
}

// EIGHT SLOTS, measured: Apple's own array answers indices 0 to 7 with a descriptor and fails its own
// assertion at 8. The header declares two members and no bound, so the number is Apple's and not the
// header's - and it is measured out of process, one index per invocation, because the assertion STOPS
// the process and a case that asked 0 to 8 in one run would die at 8 having compared nothing after it.
// An enumeration, not a static const: an ivar array's bound has to be a compile-time constant,
// and a static const NSUInteger is folded to one as an extension (-Wgnu-folding-constant).
enum { CharonMetal4ColorAttachmentSlots = 8 };

// The TILE pipeline's array has eight slots as well - measured against Apple's own array the same way,
// indices 0 to 7 answer a descriptor and index 8 fails the framework's own assertion - and the array
// itself is the 11.0 class in MTLTileRenderPipelineAttachments11.m. The number is written out here
// because a compile-time constant has to be in the file that uses it, and it is the same measurement
// rather than a second guess.
enum { CharonMetal4TileColorAttachmentSlots = 8 };

@implementation MTL4RenderPipelineColorAttachmentDescriptorArray {
    MTL4RenderPipelineColorAttachmentDescriptor *_slots[CharonMetal4ColorAttachmentSlots];
}

- (MTL4RenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= CharonMetal4ColorAttachmentSlots) {
        // What Apple does, in the shape this port can: refuse the index and say which one, rather than
        // read past the array. facts/Metal/Descriptors16.md records the out-of-process measurement of
        // Apple's own assertion for the 14.0 family; this is the same rule for the 26.0 one.
        [NSException raise:NSRangeException
                    format:@"colorAttachments[%lu]: this array has %lu slots",
                           (unsigned long)attachmentIndex, (unsigned long)CharonMetal4ColorAttachmentSlots];
        return nil;
    }
    if (!_slots[attachmentIndex])
        _slots[attachmentIndex] = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
    return _slots[attachmentIndex];
}

- (void)setObject:(MTL4RenderPipelineColorAttachmentDescriptor *)attachment
    atIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= CharonMetal4ColorAttachmentSlots) {
        [NSException raise:NSRangeException
                    format:@"setObject:atIndexedSubscript:%lu: this array has %lu slots",
                           (unsigned long)attachmentIndex, (unsigned long)CharonMetal4ColorAttachmentSlots];
        return;
    }
    // The header says this setter has copy semantics, and that a caller can set the color attachment at a
    // valid index set to nil, which restores that attachment's default state. So a nil resets the slot to the defaults rather than
    // leaving the old descriptor there - measured against Apple's own array by the differential.
    if (attachment)
        _slots[attachmentIndex] = [attachment copy];
    else {
        _slots[attachmentIndex] = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
        CharonMetal4ResetBlendState(_slots[attachmentIndex]);
    }
}

- (void)reset
{
    for (NSUInteger index = 0; index < CharonMetal4ColorAttachmentSlots; index++)
        [self setObject:nil atIndexedSubscript:index];
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4RenderPipelineColorAttachmentDescriptorArray *copy = [[MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init];
    for (NSUInteger index = 0; index < CharonMetal4ColorAttachmentSlots; index++)
        if (_slots[index])
            [copy setObject:_slots[index] atIndexedSubscript:index];
    return copy;
}

// VALUE EQUALITY, SLOT BY SLOT, over the eight slots there are. Two fresh arrays are equal because
// both make a descriptor at an index on first read and those descriptors are equal; an array whose slot
// 2 holds a different descriptor is not equal to one whose does. This is the member the three pipeline
// descriptors' own equality asks, so a pipeline whose colour attachments differ is not equal to one
// whose do not.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4RenderPipelineColorAttachmentDescriptorArray class]]) return NO;
    for (NSUInteger index = 0; index < CharonMetal4ColorAttachmentSlots; index++) {
        id mine = _slots[index];
        id theirs = ((MTL4RenderPipelineColorAttachmentDescriptorArray *)object)->_slots[index];
        if (mine != theirs && ![mine isEqual:theirs]) return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    for (NSUInteger index = 0; index < CharonMetal4ColorAttachmentSlots; index++)
        hash = hash * 31u + (uint32_t)[_slots[index] hash];
    return hash;
}

@end

// THE BASE OF THREE, and its two members are the header's: a label and a set of options. A fresh
// options is NIL - measured, and not the null_resettable an implementer would guess - so the port
// keeps nil until a caller sets one.
@implementation MTL4PipelineDescriptor {
    NSString *_label;
    MTL4PipelineOptions *_options;
}

@synthesize label = _label;
@synthesize options = _options;

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

- (void)setOptions:(MTL4PipelineOptions *)options
{
    _options = options;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4PipelineDescriptor *copy = [[MTL4PipelineDescriptor alloc] init];
    copy.label = _label;
    copy.options = _options;
    return copy;
}


// VALUE EQUALITY, MEMBER BY MEMBER, and the LABEL is one of the two. Measured against Apple's own object: two
// fresh descriptors whose labels are both nil are equal, nil against "x" are not, "x" against "x" are, and
// "x" against "y" are not.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4PipelineDescriptor class]]) return NO;
    if (self.label != ((MTL4PipelineDescriptor *)object).label && ![self.label isEqual:((MTL4PipelineDescriptor *)object).label]) return NO;
    if (self.options != ((MTL4PipelineDescriptor *)object).options && ![self.options isEqual:((MTL4PipelineDescriptor *)object).options]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.label hash];
    hash = hash * 31u + (uint32_t)[self.options hash];
    return hash;
}

@end

// THE THREE STATIC LINKING DESCRIPTORS of the render pipeline are `null_resettable`, which is the
// header saying the getter may hand back a fresh one: that is what Apple's own fresh descriptor
// answers, so the getter makes one when there is none and the setter copies what it is given.
static MTL4StaticLinkingDescriptor *CharonMetal4NullResettable(MTL4StaticLinkingDescriptor *stored)
{
    if (!stored)
        stored = [[MTL4StaticLinkingDescriptor alloc] init];
    return stored;
}

@implementation MTL4RenderPipelineDescriptor {
    MTL4FunctionDescriptor *_vertexFunctionDescriptor;
    MTL4FunctionDescriptor *_fragmentFunctionDescriptor;
    MTLVertexDescriptor *_vertexDescriptor;
    NSUInteger _rasterSampleCount;
    MTL4AlphaToCoverageState _alphaToCoverageState;
    MTL4AlphaToOneState _alphaToOneState;
    BOOL _rasterizationEnabled;
    NSUInteger _maxVertexAmplificationCount;
    MTL4RenderPipelineColorAttachmentDescriptorArray *_colorAttachments;
    MTLPrimitiveTopologyClass _inputPrimitiveTopology;
    MTL4StaticLinkingDescriptor *_vertexStaticLinkingDescriptor;
    MTL4StaticLinkingDescriptor *_fragmentStaticLinkingDescriptor;
    BOOL _supportVertexBinaryLinking;
    BOOL _supportFragmentBinaryLinking;
    MTL4LogicalToPhysicalColorAttachmentMappingState _colorAttachmentMappingState;
    MTL4IndirectCommandBufferSupportState _supportIndirectCommandBuffers;
}

@synthesize vertexFunctionDescriptor = _vertexFunctionDescriptor;
@synthesize fragmentFunctionDescriptor = _fragmentFunctionDescriptor;
@synthesize vertexDescriptor = _vertexDescriptor;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize alphaToCoverageState = _alphaToCoverageState;
@synthesize alphaToOneState = _alphaToOneState;
@synthesize rasterizationEnabled = _rasterizationEnabled;
@synthesize maxVertexAmplificationCount = _maxVertexAmplificationCount;
@synthesize colorAttachments = _colorAttachments;
@synthesize inputPrimitiveTopology = _inputPrimitiveTopology;
@synthesize supportVertexBinaryLinking = _supportVertexBinaryLinking;
@synthesize supportFragmentBinaryLinking = _supportFragmentBinaryLinking;
@synthesize colorAttachmentMappingState = _colorAttachmentMappingState;
@synthesize supportIndirectCommandBuffers = _supportIndirectCommandBuffers;

// Measured against Apple's own fresh object: a vertex descriptor IS there (a fresh MTLVertexDescriptor),
// the sample count and the amplification count are 1, rasterization is on, and everything else is its
// own zero or NO.
- (instancetype)init
{
    if ((self = [super init])) {
        _vertexDescriptor = [[MTLVertexDescriptor alloc] init];
        _rasterSampleCount = 1;
        _alphaToCoverageState = MTL4AlphaToCoverageStateDisabled;
        _alphaToOneState = MTL4AlphaToOneStateDisabled;
        _rasterizationEnabled = YES;
        _maxVertexAmplificationCount = 1;
        _colorAttachments = [[MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init];
        _inputPrimitiveTopology = MTLPrimitiveTopologyClassUnspecified;
        _supportVertexBinaryLinking = NO;
        _supportFragmentBinaryLinking = NO;
        _colorAttachmentMappingState = MTL4LogicalToPhysicalColorAttachmentMappingStateIdentity;
        _supportIndirectCommandBuffers = MTL4IndirectCommandBufferSupportStateDisabled;
    }
    return self;
}

- (MTL4StaticLinkingDescriptor *)vertexStaticLinkingDescriptor
{
    _vertexStaticLinkingDescriptor = CharonMetal4NullResettable(_vertexStaticLinkingDescriptor);
    return _vertexStaticLinkingDescriptor;
}

- (void)setVertexStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _vertexStaticLinkingDescriptor = [descriptor copy];
}

- (MTL4StaticLinkingDescriptor *)fragmentStaticLinkingDescriptor
{
    _fragmentStaticLinkingDescriptor = CharonMetal4NullResettable(_fragmentStaticLinkingDescriptor);
    return _fragmentStaticLinkingDescriptor;
}

- (void)setFragmentStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _fragmentStaticLinkingDescriptor = [descriptor copy];
}

- (void)reset
{
    _vertexFunctionDescriptor = nil;
    _fragmentFunctionDescriptor = nil;
    _vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    _rasterSampleCount = 1;
    _alphaToCoverageState = MTL4AlphaToCoverageStateDisabled;
    _alphaToOneState = MTL4AlphaToOneStateDisabled;
    _rasterizationEnabled = YES;
    _maxVertexAmplificationCount = 1;
    [_colorAttachments reset];
    _inputPrimitiveTopology = MTLPrimitiveTopologyClassUnspecified;
    _vertexStaticLinkingDescriptor = nil;
    _fragmentStaticLinkingDescriptor = nil;
    _supportVertexBinaryLinking = NO;
    _supportFragmentBinaryLinking = NO;
    _colorAttachmentMappingState = MTL4LogicalToPhysicalColorAttachmentMappingStateIdentity;
    _supportIndirectCommandBuffers = MTL4IndirectCommandBufferSupportStateDisabled;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4RenderPipelineDescriptor *copy = [[MTL4RenderPipelineDescriptor alloc] init];
    copy.vertexFunctionDescriptor = _vertexFunctionDescriptor;
    copy.fragmentFunctionDescriptor = _fragmentFunctionDescriptor;
    copy.vertexDescriptor = _vertexDescriptor;
    copy.rasterSampleCount = _rasterSampleCount;
    copy.alphaToCoverageState = _alphaToCoverageState;
    copy.alphaToOneState = _alphaToOneState;
    copy.rasterizationEnabled = _rasterizationEnabled;
    copy.maxVertexAmplificationCount = _maxVertexAmplificationCount;
    for (NSUInteger index = 0; index < CharonMetal4ColorAttachmentSlots; index++)
        [copy.colorAttachments setObject:[_colorAttachments objectAtIndexedSubscript:index]
                      atIndexedSubscript:index];
    copy.inputPrimitiveTopology = _inputPrimitiveTopology;
    copy.vertexStaticLinkingDescriptor = _vertexStaticLinkingDescriptor;
    copy.fragmentStaticLinkingDescriptor = _fragmentStaticLinkingDescriptor;
    copy.supportVertexBinaryLinking = _supportVertexBinaryLinking;
    copy.supportFragmentBinaryLinking = _supportFragmentBinaryLinking;
    copy.colorAttachmentMappingState = _colorAttachmentMappingState;
    copy.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
    // label and options are the BASE's members and its ivars are private to it, so a subclass's
    // copy reads them through the base's own getters and writes them through its setters. That is the
    // public interface the header declares, and it is the only way a subclass can carry them without a
    // seam of this package's own - which would be a method Apple's class does not have and would need
    // a registry row of its own.
    copy.label = self.label;
    copy.options = self.options;
    return copy;
}


// VALUE EQUALITY, MEMBER BY MEMBER, THE COLOUR ATTACHMENTS INCLUDED: two render descriptors are equal only when
// their attachment ARRAYS are equal too, and an array is equal only when its slots are - which is why the array's
// own equality is below and this one asks it. The base's label and options are the last two members.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4RenderPipelineDescriptor class]]) return NO;
    if (self.vertexFunctionDescriptor != ((MTL4RenderPipelineDescriptor *)object).vertexFunctionDescriptor && ![self.vertexFunctionDescriptor isEqual:((MTL4RenderPipelineDescriptor *)object).vertexFunctionDescriptor]) return NO;
    if (self.fragmentFunctionDescriptor != ((MTL4RenderPipelineDescriptor *)object).fragmentFunctionDescriptor && ![self.fragmentFunctionDescriptor isEqual:((MTL4RenderPipelineDescriptor *)object).fragmentFunctionDescriptor]) return NO;
    if (self.vertexDescriptor != ((MTL4RenderPipelineDescriptor *)object).vertexDescriptor && ![self.vertexDescriptor isEqual:((MTL4RenderPipelineDescriptor *)object).vertexDescriptor]) return NO;
    if (self.rasterSampleCount != ((MTL4RenderPipelineDescriptor *)object).rasterSampleCount) return NO;
    if (self.alphaToCoverageState != ((MTL4RenderPipelineDescriptor *)object).alphaToCoverageState) return NO;
    if (self.alphaToOneState != ((MTL4RenderPipelineDescriptor *)object).alphaToOneState) return NO;
    if (self.rasterizationEnabled != ((MTL4RenderPipelineDescriptor *)object).rasterizationEnabled) return NO;
    if (self.maxVertexAmplificationCount != ((MTL4RenderPipelineDescriptor *)object).maxVertexAmplificationCount) return NO;
    if (self.colorAttachments != ((MTL4RenderPipelineDescriptor *)object).colorAttachments && ![self.colorAttachments isEqual:((MTL4RenderPipelineDescriptor *)object).colorAttachments]) return NO;
    if (self.inputPrimitiveTopology != ((MTL4RenderPipelineDescriptor *)object).inputPrimitiveTopology) return NO;
    if (self.vertexStaticLinkingDescriptor != ((MTL4RenderPipelineDescriptor *)object).vertexStaticLinkingDescriptor && ![self.vertexStaticLinkingDescriptor isEqual:((MTL4RenderPipelineDescriptor *)object).vertexStaticLinkingDescriptor]) return NO;
    if (self.fragmentStaticLinkingDescriptor != ((MTL4RenderPipelineDescriptor *)object).fragmentStaticLinkingDescriptor && ![self.fragmentStaticLinkingDescriptor isEqual:((MTL4RenderPipelineDescriptor *)object).fragmentStaticLinkingDescriptor]) return NO;
    if (self.supportVertexBinaryLinking != ((MTL4RenderPipelineDescriptor *)object).supportVertexBinaryLinking) return NO;
    if (self.supportFragmentBinaryLinking != ((MTL4RenderPipelineDescriptor *)object).supportFragmentBinaryLinking) return NO;
    if (self.colorAttachmentMappingState != ((MTL4RenderPipelineDescriptor *)object).colorAttachmentMappingState) return NO;
    if (self.supportIndirectCommandBuffers != ((MTL4RenderPipelineDescriptor *)object).supportIndirectCommandBuffers) return NO;
    if (self.label != ((MTL4RenderPipelineDescriptor *)object).label && ![self.label isEqual:((MTL4RenderPipelineDescriptor *)object).label]) return NO;
    if (self.options != ((MTL4RenderPipelineDescriptor *)object).options && ![self.options isEqual:((MTL4RenderPipelineDescriptor *)object).options]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.vertexFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.fragmentFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.vertexDescriptor hash];
    hash = hash * 31u + (uint32_t)self.rasterSampleCount;
    hash = hash * 31u + (uint32_t)self.alphaToCoverageState;
    hash = hash * 31u + (uint32_t)self.alphaToOneState;
    hash = hash * 31u + (uint32_t)self.rasterizationEnabled;
    hash = hash * 31u + (uint32_t)self.maxVertexAmplificationCount;
    hash = hash * 31u + (uint32_t)self.inputPrimitiveTopology;
    hash = hash * 31u + (uint32_t)[self.vertexStaticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.fragmentStaticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)self.supportVertexBinaryLinking;
    hash = hash * 31u + (uint32_t)self.supportFragmentBinaryLinking;
    hash = hash * 31u + (uint32_t)self.colorAttachmentMappingState;
    hash = hash * 31u + (uint32_t)self.supportIndirectCommandBuffers;
    hash = hash * 31u + (uint32_t)[self.label hash];
    hash = hash * 31u + (uint32_t)[self.options hash];
    return hash;
}

@end

@implementation MTL4ComputePipelineDescriptor {
    MTL4FunctionDescriptor *_computeFunctionDescriptor;
    BOOL _threadGroupSizeIsMultipleOfThreadExecutionWidth;
    NSUInteger _maxTotalThreadsPerThreadgroup;
    MTLSize _requiredThreadsPerThreadgroup;
    BOOL _supportBinaryLinking;
    MTL4StaticLinkingDescriptor *_staticLinkingDescriptor;
    MTL4IndirectCommandBufferSupportState _supportIndirectCommandBuffers;
}

@synthesize computeFunctionDescriptor = _computeFunctionDescriptor;
@synthesize threadGroupSizeIsMultipleOfThreadExecutionWidth = _threadGroupSizeIsMultipleOfThreadExecutionWidth;
@synthesize maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
@synthesize requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;
@synthesize supportBinaryLinking = _supportBinaryLinking;
@synthesize supportIndirectCommandBuffers = _supportIndirectCommandBuffers;

- (MTL4StaticLinkingDescriptor *)staticLinkingDescriptor
{
    _staticLinkingDescriptor = CharonMetal4NullResettable(_staticLinkingDescriptor);
    return _staticLinkingDescriptor;
}

- (void)setStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _staticLinkingDescriptor = [descriptor copy];
}

// Every measured default here is a zero, a NO or nil - including the required threadgroup size, which
// is 0 x 0 x 0 and not 1 x 1 x 1. The static linking descriptor is an object, as the null_resettable
// getter says it is.
- (instancetype)init
{
    if ((self = [super init])) {
        _threadGroupSizeIsMultipleOfThreadExecutionWidth = NO;
        _requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);
        _supportBinaryLinking = NO;
        _staticLinkingDescriptor = [[MTL4StaticLinkingDescriptor alloc] init];
        _supportIndirectCommandBuffers = MTL4IndirectCommandBufferSupportStateDisabled;
    }
    return self;
}

- (void)reset
{
    _computeFunctionDescriptor = nil;
    _threadGroupSizeIsMultipleOfThreadExecutionWidth = NO;
    _maxTotalThreadsPerThreadgroup = 0;
    _requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);
    _supportBinaryLinking = NO;
    _staticLinkingDescriptor = [[MTL4StaticLinkingDescriptor alloc] init];
    _supportIndirectCommandBuffers = MTL4IndirectCommandBufferSupportStateDisabled;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4ComputePipelineDescriptor *copy = [[MTL4ComputePipelineDescriptor alloc] init];
    copy.computeFunctionDescriptor = _computeFunctionDescriptor;
    copy.threadGroupSizeIsMultipleOfThreadExecutionWidth = _threadGroupSizeIsMultipleOfThreadExecutionWidth;
    copy.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
    copy.requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;
    copy.supportBinaryLinking = _supportBinaryLinking;
    copy.staticLinkingDescriptor = _staticLinkingDescriptor;
    copy.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
    // label and options are the BASE's members and its ivars are private to it, so a subclass's
    // copy reads them through the base's own getters and writes them through its setters. That is the
    // public interface the header declares, and it is the only way a subclass can carry them without a
    // seam of this package's own - which would be a method Apple's class does not have and would need
    // a registry row of its own.
    copy.label = self.label;
    copy.options = self.options;
    return copy;
}


// VALUE EQUALITY MEMBER BY MEMBER, AND THE THREADGROUP SIZE IS THREE MEMBERS: measured, two fresh descriptors are
// equal and one whose required size is 1x2x3 against one whose is 0x0x0 is not, so MTLSize is compared by its three
// components rather than as one number - which a memcmp of the struct would have got wrong on padding.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4ComputePipelineDescriptor class]]) return NO;
    if (self.computeFunctionDescriptor != ((MTL4ComputePipelineDescriptor *)object).computeFunctionDescriptor && ![self.computeFunctionDescriptor isEqual:((MTL4ComputePipelineDescriptor *)object).computeFunctionDescriptor]) return NO;
    if (self.threadGroupSizeIsMultipleOfThreadExecutionWidth != ((MTL4ComputePipelineDescriptor *)object).threadGroupSizeIsMultipleOfThreadExecutionWidth) return NO;
    if (self.maxTotalThreadsPerThreadgroup != ((MTL4ComputePipelineDescriptor *)object).maxTotalThreadsPerThreadgroup) return NO;
    if (self.requiredThreadsPerThreadgroup.width != ((MTL4ComputePipelineDescriptor *)object).requiredThreadsPerThreadgroup.width) return NO;
    if (self.requiredThreadsPerThreadgroup.height != ((MTL4ComputePipelineDescriptor *)object).requiredThreadsPerThreadgroup.height) return NO;
    if (self.requiredThreadsPerThreadgroup.depth != ((MTL4ComputePipelineDescriptor *)object).requiredThreadsPerThreadgroup.depth) return NO;
    if (self.supportBinaryLinking != ((MTL4ComputePipelineDescriptor *)object).supportBinaryLinking) return NO;
    if (self.staticLinkingDescriptor != ((MTL4ComputePipelineDescriptor *)object).staticLinkingDescriptor && ![self.staticLinkingDescriptor isEqual:((MTL4ComputePipelineDescriptor *)object).staticLinkingDescriptor]) return NO;
    if (self.supportIndirectCommandBuffers != ((MTL4ComputePipelineDescriptor *)object).supportIndirectCommandBuffers) return NO;
    if (self.label != ((MTL4ComputePipelineDescriptor *)object).label && ![self.label isEqual:((MTL4ComputePipelineDescriptor *)object).label]) return NO;
    if (self.options != ((MTL4ComputePipelineDescriptor *)object).options && ![self.options isEqual:((MTL4ComputePipelineDescriptor *)object).options]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.computeFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)self.threadGroupSizeIsMultipleOfThreadExecutionWidth;
    hash = hash * 31u + (uint32_t)self.maxTotalThreadsPerThreadgroup;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerThreadgroup.width;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerThreadgroup.height;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerThreadgroup.depth;
    hash = hash * 31u + (uint32_t)self.supportBinaryLinking;
    hash = hash * 31u + (uint32_t)[self.staticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)self.supportIndirectCommandBuffers;
    hash = hash * 31u + (uint32_t)[self.label hash];
    hash = hash * 31u + (uint32_t)[self.options hash];
    return hash;
}

@end

// ONE MEMBER OF THIS CLASS IS NOT IN ITS EQUALITY, and the reason is a measurement: the colour
// attachments. Apple's own MTLTileRenderPipelineColorAttachmentDescriptorArray carries NO -isEqual: of
// its own - measured, its own method list has neither isEqual: nor hash - so two fresh arrays are two
// objects that are not equal, and yet two fresh MTL4TileRenderPipelineDescriptors on Apple's side ARE
// equal, also measured. An equality that compared the attachments could not answer that. The render and
// mesh descriptors beside it DO compare theirs, because their array is MTL4RenderPipelineColorAttachment
// DescriptorArray and that one carries an -isEqual: of its own, measured.
@implementation MTL4TileRenderPipelineDescriptor {
    MTL4FunctionDescriptor *_tileFunctionDescriptor;
    NSUInteger _rasterSampleCount;
    MTLTileRenderPipelineColorAttachmentDescriptorArray *_colorAttachments;
    BOOL _threadgroupSizeMatchesTileSize;
    NSUInteger _maxTotalThreadsPerThreadgroup;
    MTLSize _requiredThreadsPerThreadgroup;
    MTL4StaticLinkingDescriptor *_staticLinkingDescriptor;
    BOOL _supportBinaryLinking;
}

@synthesize tileFunctionDescriptor = _tileFunctionDescriptor;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize colorAttachments = _colorAttachments;
@synthesize threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
@synthesize maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
@synthesize requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;
@synthesize supportBinaryLinking = _supportBinaryLinking;

- (MTL4StaticLinkingDescriptor *)staticLinkingDescriptor
{
    _staticLinkingDescriptor = CharonMetal4NullResettable(_staticLinkingDescriptor);
    return _staticLinkingDescriptor;
}

- (void)setStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _staticLinkingDescriptor = [descriptor copy];
}

// The colour attachments are an object on a fresh descriptor - measured - so they are made here rather
// than left to an auto-synthesised getter that would answer nil. The array itself is the 11.0 class in
// MTLTileRenderPipelineAttachments11.m; this object only names it, so it carries no 11.0 symbol.
- (instancetype)init
{
    if ((self = [super init])) {
        _colorAttachments = [[MTLTileRenderPipelineColorAttachmentDescriptorArray alloc] init];
        _rasterSampleCount = 1;
        _threadgroupSizeMatchesTileSize = NO;
        _requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);
        _staticLinkingDescriptor = [[MTL4StaticLinkingDescriptor alloc] init];
        _supportBinaryLinking = NO;
    }
    return self;
}

- (void)reset
{
    _tileFunctionDescriptor = nil;
    // The 16.4 header types this setter's attachment as nonnull while its own comment says a nil at a
    // legal index is safe and resets the slot; a nil VARIABLE is what says that without contradicting
    // the annotation, and a nil literal is what -Wnonnull is about.
    MTLTileRenderPipelineColorAttachmentDescriptor *noAttachment = nil;
    [_colorAttachments setObject:noAttachment atIndexedSubscript:0];
    _rasterSampleCount = 1;
    _threadgroupSizeMatchesTileSize = NO;
    _maxTotalThreadsPerThreadgroup = 0;
    _requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);
    _staticLinkingDescriptor = [[MTL4StaticLinkingDescriptor alloc] init];
    _supportBinaryLinking = NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4TileRenderPipelineDescriptor *copy = [[MTL4TileRenderPipelineDescriptor alloc] init];
    copy.tileFunctionDescriptor = _tileFunctionDescriptor;
    for (NSUInteger index = 0; index < CharonMetal4TileColorAttachmentSlots; index++)
        [copy.colorAttachments setObject:[_colorAttachments objectAtIndexedSubscript:index]
                      atIndexedSubscript:index];
    copy.rasterSampleCount = _rasterSampleCount;
    copy.threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
    copy.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
    copy.requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;
    copy.staticLinkingDescriptor = _staticLinkingDescriptor;
    copy.supportBinaryLinking = _supportBinaryLinking;
    // label and options are the BASE's members and its ivars are private to it, so a subclass's
    // copy reads them through the base's own getters and writes them through its setters. That is the
    // public interface the header declares, and it is the only way a subclass can carry them without a
    // seam of this package's own - which would be a method Apple's class does not have and would need
    // a registry row of its own.
    copy.label = self.label;
    copy.options = self.options;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4TileRenderPipelineDescriptor class]]) return NO;
    if (self.tileFunctionDescriptor != ((MTL4TileRenderPipelineDescriptor *)object).tileFunctionDescriptor && ![self.tileFunctionDescriptor isEqual:((MTL4TileRenderPipelineDescriptor *)object).tileFunctionDescriptor]) return NO;
    if (self.rasterSampleCount != ((MTL4TileRenderPipelineDescriptor *)object).rasterSampleCount) return NO;
    if (self.threadgroupSizeMatchesTileSize != ((MTL4TileRenderPipelineDescriptor *)object).threadgroupSizeMatchesTileSize) return NO;
    if (self.maxTotalThreadsPerThreadgroup != ((MTL4TileRenderPipelineDescriptor *)object).maxTotalThreadsPerThreadgroup) return NO;
    if (self.requiredThreadsPerThreadgroup.width != ((MTL4TileRenderPipelineDescriptor *)object).requiredThreadsPerThreadgroup.width) return NO;
    if (self.requiredThreadsPerThreadgroup.height != ((MTL4TileRenderPipelineDescriptor *)object).requiredThreadsPerThreadgroup.height) return NO;
    if (self.requiredThreadsPerThreadgroup.depth != ((MTL4TileRenderPipelineDescriptor *)object).requiredThreadsPerThreadgroup.depth) return NO;
    if (self.staticLinkingDescriptor != ((MTL4TileRenderPipelineDescriptor *)object).staticLinkingDescriptor && ![self.staticLinkingDescriptor isEqual:((MTL4TileRenderPipelineDescriptor *)object).staticLinkingDescriptor]) return NO;
    if (self.supportBinaryLinking != ((MTL4TileRenderPipelineDescriptor *)object).supportBinaryLinking) return NO;
    if (self.label != ((MTL4TileRenderPipelineDescriptor *)object).label && ![self.label isEqual:((MTL4TileRenderPipelineDescriptor *)object).label]) return NO;
    if (self.options != ((MTL4TileRenderPipelineDescriptor *)object).options && ![self.options isEqual:((MTL4TileRenderPipelineDescriptor *)object).options]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.tileFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)self.rasterSampleCount;
    hash = hash * 31u + (uint32_t)self.threadgroupSizeMatchesTileSize;
    hash = hash * 31u + (uint32_t)self.maxTotalThreadsPerThreadgroup;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerThreadgroup.width;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerThreadgroup.height;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerThreadgroup.depth;
    hash = hash * 31u + (uint32_t)[self.staticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)self.supportBinaryLinking;
    hash = hash * 31u + (uint32_t)[self.label hash];
    hash = hash * 31u + (uint32_t)[self.options hash];
    return hash;
}

@end

@implementation MTL4MeshRenderPipelineDescriptor {
    MTL4FunctionDescriptor *_objectFunctionDescriptor;
    MTL4FunctionDescriptor *_meshFunctionDescriptor;
    MTL4FunctionDescriptor *_fragmentFunctionDescriptor;
    NSUInteger _maxTotalThreadsPerObjectThreadgroup;
    NSUInteger _maxTotalThreadsPerMeshThreadgroup;
    MTLSize _requiredThreadsPerObjectThreadgroup;
    MTLSize _requiredThreadsPerMeshThreadgroup;
    BOOL _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    BOOL _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    NSUInteger _payloadMemoryLength;
    NSUInteger _maxTotalThreadgroupsPerMeshGrid;
    NSUInteger _rasterSampleCount;
    MTL4AlphaToCoverageState _alphaToCoverageState;
    MTL4AlphaToOneState _alphaToOneState;
    BOOL _rasterizationEnabled;
    NSUInteger _maxVertexAmplificationCount;
    MTL4RenderPipelineColorAttachmentDescriptorArray *_colorAttachments;
    MTL4StaticLinkingDescriptor *_objectStaticLinkingDescriptor;
    MTL4StaticLinkingDescriptor *_meshStaticLinkingDescriptor;
    MTL4StaticLinkingDescriptor *_fragmentStaticLinkingDescriptor;
    BOOL _supportObjectBinaryLinking;
    BOOL _supportMeshBinaryLinking;
    BOOL _supportFragmentBinaryLinking;
    MTL4LogicalToPhysicalColorAttachmentMappingState _colorAttachmentMappingState;
    MTL4IndirectCommandBufferSupportState _supportIndirectCommandBuffers;
}

@synthesize objectFunctionDescriptor = _objectFunctionDescriptor;
@synthesize meshFunctionDescriptor = _meshFunctionDescriptor;
@synthesize fragmentFunctionDescriptor = _fragmentFunctionDescriptor;
@synthesize maxTotalThreadsPerObjectThreadgroup = _maxTotalThreadsPerObjectThreadgroup;
@synthesize maxTotalThreadsPerMeshThreadgroup = _maxTotalThreadsPerMeshThreadgroup;
@synthesize requiredThreadsPerObjectThreadgroup = _requiredThreadsPerObjectThreadgroup;
@synthesize requiredThreadsPerMeshThreadgroup = _requiredThreadsPerMeshThreadgroup;
@synthesize objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@synthesize meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@synthesize payloadMemoryLength = _payloadMemoryLength;
@synthesize maxTotalThreadgroupsPerMeshGrid = _maxTotalThreadgroupsPerMeshGrid;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize alphaToCoverageState = _alphaToCoverageState;
@synthesize alphaToOneState = _alphaToOneState;
@synthesize rasterizationEnabled = _rasterizationEnabled;
@synthesize maxVertexAmplificationCount = _maxVertexAmplificationCount;
@synthesize colorAttachments = _colorAttachments;
@synthesize supportObjectBinaryLinking = _supportObjectBinaryLinking;
@synthesize supportMeshBinaryLinking = _supportMeshBinaryLinking;
@synthesize supportFragmentBinaryLinking = _supportFragmentBinaryLinking;
@synthesize colorAttachmentMappingState = _colorAttachmentMappingState;
@synthesize supportIndirectCommandBuffers = _supportIndirectCommandBuffers;

- (MTL4StaticLinkingDescriptor *)objectStaticLinkingDescriptor
{
    _objectStaticLinkingDescriptor = CharonMetal4NullResettable(_objectStaticLinkingDescriptor);
    return _objectStaticLinkingDescriptor;
}

- (void)setObjectStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _objectStaticLinkingDescriptor = [descriptor copy];
}

- (MTL4StaticLinkingDescriptor *)meshStaticLinkingDescriptor
{
    _meshStaticLinkingDescriptor = CharonMetal4NullResettable(_meshStaticLinkingDescriptor);
    return _meshStaticLinkingDescriptor;
}

- (void)setMeshStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _meshStaticLinkingDescriptor = [descriptor copy];
}

- (MTL4StaticLinkingDescriptor *)fragmentStaticLinkingDescriptor
{
    _fragmentStaticLinkingDescriptor = CharonMetal4NullResettable(_fragmentStaticLinkingDescriptor);
    return _fragmentStaticLinkingDescriptor;
}

- (void)setFragmentStaticLinkingDescriptor:(MTL4StaticLinkingDescriptor *)descriptor
{
    _fragmentStaticLinkingDescriptor = [descriptor copy];
}

// Measured against Apple's own fresh object: the three stage descriptors are nil, both required
// threadgroup sizes are 0 x 0 x 0, every count is 0 except the sample count and the amplification
// count, which are 1, rasterization is on and every flag is NO or its own zero.
- (instancetype)init
{
    if ((self = [super init])) {
        _requiredThreadsPerObjectThreadgroup = MTLSizeMake(0, 0, 0);
        _requiredThreadsPerMeshThreadgroup = MTLSizeMake(0, 0, 0);
        _rasterSampleCount = 1;
        _alphaToCoverageState = MTL4AlphaToCoverageStateDisabled;
        _alphaToOneState = MTL4AlphaToOneStateDisabled;
        _rasterizationEnabled = YES;
        _maxVertexAmplificationCount = 1;
        _colorAttachments = [[MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init];
        _colorAttachmentMappingState = MTL4LogicalToPhysicalColorAttachmentMappingStateIdentity;
        _supportIndirectCommandBuffers = MTL4IndirectCommandBufferSupportStateDisabled;
    }
    return self;
}

- (void)reset
{
    _objectFunctionDescriptor = nil;
    _meshFunctionDescriptor = nil;
    _fragmentFunctionDescriptor = nil;
    _maxTotalThreadsPerObjectThreadgroup = 0;
    _maxTotalThreadsPerMeshThreadgroup = 0;
    _requiredThreadsPerObjectThreadgroup = MTLSizeMake(0, 0, 0);
    _requiredThreadsPerMeshThreadgroup = MTLSizeMake(0, 0, 0);
    _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = NO;
    _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = NO;
    _payloadMemoryLength = 0;
    _maxTotalThreadgroupsPerMeshGrid = 0;
    _rasterSampleCount = 1;
    _alphaToCoverageState = MTL4AlphaToCoverageStateDisabled;
    _alphaToOneState = MTL4AlphaToOneStateDisabled;
    _rasterizationEnabled = YES;
    _maxVertexAmplificationCount = 1;
    [_colorAttachments reset];
    _objectStaticLinkingDescriptor = nil;
    _meshStaticLinkingDescriptor = nil;
    _fragmentStaticLinkingDescriptor = nil;
    _supportObjectBinaryLinking = NO;
    _supportMeshBinaryLinking = NO;
    _supportFragmentBinaryLinking = NO;
    _colorAttachmentMappingState = MTL4LogicalToPhysicalColorAttachmentMappingStateIdentity;
    _supportIndirectCommandBuffers = MTL4IndirectCommandBufferSupportStateDisabled;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4MeshRenderPipelineDescriptor *copy = [[MTL4MeshRenderPipelineDescriptor alloc] init];
    copy.objectFunctionDescriptor = _objectFunctionDescriptor;
    copy.meshFunctionDescriptor = _meshFunctionDescriptor;
    copy.fragmentFunctionDescriptor = _fragmentFunctionDescriptor;
    copy.maxTotalThreadsPerObjectThreadgroup = _maxTotalThreadsPerObjectThreadgroup;
    copy.maxTotalThreadsPerMeshThreadgroup = _maxTotalThreadsPerMeshThreadgroup;
    copy.requiredThreadsPerObjectThreadgroup = _requiredThreadsPerObjectThreadgroup;
    copy.requiredThreadsPerMeshThreadgroup = _requiredThreadsPerMeshThreadgroup;
    copy.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    copy.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    copy.payloadMemoryLength = _payloadMemoryLength;
    copy.maxTotalThreadgroupsPerMeshGrid = _maxTotalThreadgroupsPerMeshGrid;
    copy.rasterSampleCount = _rasterSampleCount;
    copy.alphaToCoverageState = _alphaToCoverageState;
    copy.alphaToOneState = _alphaToOneState;
    copy.rasterizationEnabled = _rasterizationEnabled;
    copy.maxVertexAmplificationCount = _maxVertexAmplificationCount;
    for (NSUInteger index = 0; index < CharonMetal4ColorAttachmentSlots; index++)
        [copy.colorAttachments setObject:[_colorAttachments objectAtIndexedSubscript:index]
                      atIndexedSubscript:index];
    copy.objectStaticLinkingDescriptor = _objectStaticLinkingDescriptor;
    copy.meshStaticLinkingDescriptor = _meshStaticLinkingDescriptor;
    copy.fragmentStaticLinkingDescriptor = _fragmentStaticLinkingDescriptor;
    copy.supportObjectBinaryLinking = _supportObjectBinaryLinking;
    copy.supportMeshBinaryLinking = _supportMeshBinaryLinking;
    copy.supportFragmentBinaryLinking = _supportFragmentBinaryLinking;
    copy.colorAttachmentMappingState = _colorAttachmentMappingState;
    copy.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
    // label and options are the BASE's members and its ivars are private to it, so a subclass's
    // copy reads them through the base's own getters and writes them through its setters. That is the
    // public interface the header declares, and it is the only way a subclass can carry them without a
    // seam of this package's own - which would be a method Apple's class does not have and would need
    // a registry row of its own.
    copy.label = self.label;
    copy.options = self.options;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4MeshRenderPipelineDescriptor class]]) return NO;
    if (self.objectFunctionDescriptor != ((MTL4MeshRenderPipelineDescriptor *)object).objectFunctionDescriptor && ![self.objectFunctionDescriptor isEqual:((MTL4MeshRenderPipelineDescriptor *)object).objectFunctionDescriptor]) return NO;
    if (self.meshFunctionDescriptor != ((MTL4MeshRenderPipelineDescriptor *)object).meshFunctionDescriptor && ![self.meshFunctionDescriptor isEqual:((MTL4MeshRenderPipelineDescriptor *)object).meshFunctionDescriptor]) return NO;
    if (self.fragmentFunctionDescriptor != ((MTL4MeshRenderPipelineDescriptor *)object).fragmentFunctionDescriptor && ![self.fragmentFunctionDescriptor isEqual:((MTL4MeshRenderPipelineDescriptor *)object).fragmentFunctionDescriptor]) return NO;
    if (self.maxTotalThreadsPerObjectThreadgroup != ((MTL4MeshRenderPipelineDescriptor *)object).maxTotalThreadsPerObjectThreadgroup) return NO;
    if (self.maxTotalThreadsPerMeshThreadgroup != ((MTL4MeshRenderPipelineDescriptor *)object).maxTotalThreadsPerMeshThreadgroup) return NO;
    if (self.requiredThreadsPerObjectThreadgroup.width != ((MTL4MeshRenderPipelineDescriptor *)object).requiredThreadsPerObjectThreadgroup.width) return NO;
    if (self.requiredThreadsPerObjectThreadgroup.height != ((MTL4MeshRenderPipelineDescriptor *)object).requiredThreadsPerObjectThreadgroup.height) return NO;
    if (self.requiredThreadsPerObjectThreadgroup.depth != ((MTL4MeshRenderPipelineDescriptor *)object).requiredThreadsPerObjectThreadgroup.depth) return NO;
    if (self.requiredThreadsPerMeshThreadgroup.width != ((MTL4MeshRenderPipelineDescriptor *)object).requiredThreadsPerMeshThreadgroup.width) return NO;
    if (self.requiredThreadsPerMeshThreadgroup.height != ((MTL4MeshRenderPipelineDescriptor *)object).requiredThreadsPerMeshThreadgroup.height) return NO;
    if (self.requiredThreadsPerMeshThreadgroup.depth != ((MTL4MeshRenderPipelineDescriptor *)object).requiredThreadsPerMeshThreadgroup.depth) return NO;
    if (self.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth != ((MTL4MeshRenderPipelineDescriptor *)object).objectThreadgroupSizeIsMultipleOfThreadExecutionWidth) return NO;
    if (self.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth != ((MTL4MeshRenderPipelineDescriptor *)object).meshThreadgroupSizeIsMultipleOfThreadExecutionWidth) return NO;
    if (self.payloadMemoryLength != ((MTL4MeshRenderPipelineDescriptor *)object).payloadMemoryLength) return NO;
    if (self.maxTotalThreadgroupsPerMeshGrid != ((MTL4MeshRenderPipelineDescriptor *)object).maxTotalThreadgroupsPerMeshGrid) return NO;
    if (self.rasterSampleCount != ((MTL4MeshRenderPipelineDescriptor *)object).rasterSampleCount) return NO;
    if (self.alphaToCoverageState != ((MTL4MeshRenderPipelineDescriptor *)object).alphaToCoverageState) return NO;
    if (self.alphaToOneState != ((MTL4MeshRenderPipelineDescriptor *)object).alphaToOneState) return NO;
    if (self.rasterizationEnabled != ((MTL4MeshRenderPipelineDescriptor *)object).rasterizationEnabled) return NO;
    if (self.maxVertexAmplificationCount != ((MTL4MeshRenderPipelineDescriptor *)object).maxVertexAmplificationCount) return NO;
    if (self.colorAttachments != ((MTL4MeshRenderPipelineDescriptor *)object).colorAttachments && ![self.colorAttachments isEqual:((MTL4MeshRenderPipelineDescriptor *)object).colorAttachments]) return NO;
    if (self.objectStaticLinkingDescriptor != ((MTL4MeshRenderPipelineDescriptor *)object).objectStaticLinkingDescriptor && ![self.objectStaticLinkingDescriptor isEqual:((MTL4MeshRenderPipelineDescriptor *)object).objectStaticLinkingDescriptor]) return NO;
    if (self.meshStaticLinkingDescriptor != ((MTL4MeshRenderPipelineDescriptor *)object).meshStaticLinkingDescriptor && ![self.meshStaticLinkingDescriptor isEqual:((MTL4MeshRenderPipelineDescriptor *)object).meshStaticLinkingDescriptor]) return NO;
    if (self.fragmentStaticLinkingDescriptor != ((MTL4MeshRenderPipelineDescriptor *)object).fragmentStaticLinkingDescriptor && ![self.fragmentStaticLinkingDescriptor isEqual:((MTL4MeshRenderPipelineDescriptor *)object).fragmentStaticLinkingDescriptor]) return NO;
    if (self.supportObjectBinaryLinking != ((MTL4MeshRenderPipelineDescriptor *)object).supportObjectBinaryLinking) return NO;
    if (self.supportMeshBinaryLinking != ((MTL4MeshRenderPipelineDescriptor *)object).supportMeshBinaryLinking) return NO;
    if (self.supportFragmentBinaryLinking != ((MTL4MeshRenderPipelineDescriptor *)object).supportFragmentBinaryLinking) return NO;
    if (self.colorAttachmentMappingState != ((MTL4MeshRenderPipelineDescriptor *)object).colorAttachmentMappingState) return NO;
    if (self.supportIndirectCommandBuffers != ((MTL4MeshRenderPipelineDescriptor *)object).supportIndirectCommandBuffers) return NO;
    if (self.label != ((MTL4MeshRenderPipelineDescriptor *)object).label && ![self.label isEqual:((MTL4MeshRenderPipelineDescriptor *)object).label]) return NO;
    if (self.options != ((MTL4MeshRenderPipelineDescriptor *)object).options && ![self.options isEqual:((MTL4MeshRenderPipelineDescriptor *)object).options]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.objectFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.meshFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.fragmentFunctionDescriptor hash];
    hash = hash * 31u + (uint32_t)self.maxTotalThreadsPerObjectThreadgroup;
    hash = hash * 31u + (uint32_t)self.maxTotalThreadsPerMeshThreadgroup;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerObjectThreadgroup.width;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerObjectThreadgroup.height;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerObjectThreadgroup.depth;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerMeshThreadgroup.width;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerMeshThreadgroup.height;
    hash = hash * 31u + (uint32_t)self.requiredThreadsPerMeshThreadgroup.depth;
    hash = hash * 31u + (uint32_t)self.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    hash = hash * 31u + (uint32_t)self.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    hash = hash * 31u + (uint32_t)self.payloadMemoryLength;
    hash = hash * 31u + (uint32_t)self.maxTotalThreadgroupsPerMeshGrid;
    hash = hash * 31u + (uint32_t)self.rasterSampleCount;
    hash = hash * 31u + (uint32_t)self.alphaToCoverageState;
    hash = hash * 31u + (uint32_t)self.alphaToOneState;
    hash = hash * 31u + (uint32_t)self.rasterizationEnabled;
    hash = hash * 31u + (uint32_t)self.maxVertexAmplificationCount;
    hash = hash * 31u + (uint32_t)[self.objectStaticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.meshStaticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.fragmentStaticLinkingDescriptor hash];
    hash = hash * 31u + (uint32_t)self.supportObjectBinaryLinking;
    hash = hash * 31u + (uint32_t)self.supportMeshBinaryLinking;
    hash = hash * 31u + (uint32_t)self.supportFragmentBinaryLinking;
    hash = hash * 31u + (uint32_t)self.colorAttachmentMappingState;
    hash = hash * 31u + (uint32_t)self.supportIndirectCommandBuffers;
    hash = hash * 31u + (uint32_t)[self.label hash];
    hash = hash * 31u + (uint32_t)[self.options hash];
    return hash;
}

@end

// THE FUNCTION DESCRIPTORS: the base, which MTL4FunctionDescriptor.h declares and ends - no members
// of its own - and the three that extend it. The base carries nothing but its existence, which is what
// Apple's own header says it is: a name a pipeline descriptor's function members are spelled in.
//
// The three subclasses hold VALUES, and each one is what its own header says it is: a specialisation
// names the function it specialises and the constant values it specialises it with; a stitched
// function names a stitching graph and the functions it stitches; a library function names a library
// and a name inside it. This port carries the values; what a pipeline would be built from them is the
// half that is not there, and it is at the end of this file.
@implementation MTL4FunctionDescriptor
// NSCOPYING, AND IT IS THE ONE -Wprotocol WAS HIDING. The 26.2 header declares this class as
// NSObject <NSCopying> and gives it no members of its own, and the file-level
// `#pragma clang diagnostic ignored "-Wprotocol"` made the missing -copyWithZone: a silence instead of
// a warning. THE PRAGMA IS GONE: every class in this file implements the protocol its own declaration
// names, and this file builds with no diagnostic silenced.
//
// The copy is a fresh instance of THIS class. The three subclasses add members and override
// -copyWithZone: to carry them, so a copy of one of those never reaches this.
- (id)copyWithZone:(NSZone *)zone
{
    return [[MTL4FunctionDescriptor alloc] init];
}

// AND VALUE EQUALITY, which this class has on Apple's side with no member of its own to compare:
// measured, two fresh ones are equal, their hashes agree, and a copy equals its source. There is
// nothing else to compare here; each subclass's equality below adds that subclass's own members to it,
// which is what makes a specialised function different from a plain one.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4FunctionDescriptor class]]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    return (NSUInteger)object_getClass(self);
}

@end

@implementation MTL4SpecializedFunctionDescriptor {
    MTL4FunctionDescriptor *_functionDescriptor;
    NSString *_specializedName;
    MTLFunctionConstantValues *_constantValues;
}

@synthesize functionDescriptor = _functionDescriptor;
@synthesize specializedName = _specializedName;
@synthesize constantValues = _constantValues;

- (void)setFunctionDescriptor:(MTL4FunctionDescriptor *)functionDescriptor
{
    _functionDescriptor = [functionDescriptor copy];
}

// `atomic` is what the 26.2 header declares for this property, and a writable atomic property cannot
// pair a synthesised getter with a hand-written setter: the getter would read without the lock the
// setter took. So BOTH are written here, and the getter reads under the lock, which is what atomic
// means - not a copied setter on a synthesised getter.
- (NSString *)specializedName
{
    @synchronized(self) { return _specializedName; }
}

- (void)setSpecializedName:(NSString *)specializedName
{
    NSString *copied = [specializedName copy];
    @synchronized(self) { _specializedName = copied; }
}

- (void)setConstantValues:(MTLFunctionConstantValues *)constantValues
{
    _constantValues = [constantValues copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4SpecializedFunctionDescriptor *copy = [[MTL4SpecializedFunctionDescriptor alloc] init];
    copy.functionDescriptor = _functionDescriptor;
    copy.specializedName = _specializedName;
    copy.constantValues = _constantValues;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4SpecializedFunctionDescriptor class]]) return NO;
    if (self.functionDescriptor != ((MTL4SpecializedFunctionDescriptor *)object).functionDescriptor && ![self.functionDescriptor isEqual:((MTL4SpecializedFunctionDescriptor *)object).functionDescriptor]) return NO;
    if (self.specializedName != ((MTL4SpecializedFunctionDescriptor *)object).specializedName && ![self.specializedName isEqual:((MTL4SpecializedFunctionDescriptor *)object).specializedName]) return NO;
    if (self.constantValues != ((MTL4SpecializedFunctionDescriptor *)object).constantValues && ![self.constantValues isEqual:((MTL4SpecializedFunctionDescriptor *)object).constantValues]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.functionDescriptor hash];
    hash = hash * 31u + (uint32_t)[self.specializedName hash];
    hash = hash * 31u + (uint32_t)[self.constantValues hash];
    return hash;
}

@end

@implementation MTL4StitchedFunctionDescriptor {
    MTLFunctionStitchingGraph *_functionGraph;
    NSArray *_functionDescriptors;
}

@synthesize functionGraph = _functionGraph;
@synthesize functionDescriptors = _functionDescriptors;

- (void)setFunctionGraph:(MTLFunctionStitchingGraph *)functionGraph
{
    _functionGraph = [functionGraph copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4StitchedFunctionDescriptor *copy = [[MTL4StitchedFunctionDescriptor alloc] init];
    copy.functionGraph = _functionGraph;
    copy.functionDescriptors = _functionDescriptors;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4StitchedFunctionDescriptor class]]) return NO;
    if (self.functionGraph != ((MTL4StitchedFunctionDescriptor *)object).functionGraph && ![self.functionGraph isEqual:((MTL4StitchedFunctionDescriptor *)object).functionGraph]) return NO;
    if (self.functionDescriptors != ((MTL4StitchedFunctionDescriptor *)object).functionDescriptors && ![self.functionDescriptors isEqual:((MTL4StitchedFunctionDescriptor *)object).functionDescriptors]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.functionGraph hash];
    hash = hash * 31u + (uint32_t)[self.functionDescriptors hash];
    return hash;
}

@end

@implementation MTL4LibraryFunctionDescriptor {
    NSString *_name;
    id<MTLLibrary> _library;
}

@synthesize name = _name;
@synthesize library = _library;

// `atomic` again, and the same reason: both halves are written, and the getter reads under the lock.
- (NSString *)name
{
    @synchronized(self) { return _name; }
}

- (void)setName:(NSString *)name
{
    NSString *copied = [name copy];
    @synchronized(self) { _name = copied; }
}

- (void)setLibrary:(id<MTLLibrary>)library
{
    _library = library;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4LibraryFunctionDescriptor *copy = [[MTL4LibraryFunctionDescriptor alloc] init];
    copy.name = _name;
    copy.library = _library;
    return copy;
}


- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4LibraryFunctionDescriptor class]]) return NO;
    if (self.name != ((MTL4LibraryFunctionDescriptor *)object).name && ![self.name isEqual:((MTL4LibraryFunctionDescriptor *)object).name]) return NO;
    if (self.library != ((MTL4LibraryFunctionDescriptor *)object).library && ![self.library isEqual:((MTL4LibraryFunctionDescriptor *)object).library]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.name hash];
    hash = hash * 31u + (uint32_t)[self.library hash];
    return hash;
}

@end

// WHAT NONE OF THIS IS, and it is the half a caller has to know: nothing in this port reads a
// descriptor made here. There is no MTL4CommandQueue, no MTL4CommandBuffer and no pipeline state this
// port builds from any of these, so an application that fills one gets an object it can read, copy and
// reset - and no object to hand it to. That is the same line facts/Metal/Descriptors16.md draws for
// the 16.0 family and it is what each row's `effect` says, because `implemented` owes a reader the
// measured behaviour INCLUDING the part that is not there. The mesh descriptor is the sharpest case:
// its three MTL4FunctionDescriptor members ARE the pipeline's object, mesh and fragment stages rather
// than values this port can hold, and facts/Metal/RenderPath.md is where the rendering path says it has
// no mesh stage.