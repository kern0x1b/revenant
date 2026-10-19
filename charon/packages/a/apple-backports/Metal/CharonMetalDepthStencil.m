#import "CharonMetal.h"


static GLenum compareFunction(MTLCompareFunction f)
{
    switch (f) {
    case MTLCompareFunctionNever: return GL_NEVER;
    case MTLCompareFunctionLess: return GL_LESS;
    case MTLCompareFunctionEqual: return GL_EQUAL;
    case MTLCompareFunctionLessEqual: return GL_LEQUAL;
    case MTLCompareFunctionGreater: return GL_GREATER;
    case MTLCompareFunctionNotEqual: return GL_NOTEQUAL;
    case MTLCompareFunctionGreaterEqual: return GL_GEQUAL;
    default: return GL_ALWAYS;
    }
}

static GLenum stencilOperation(MTLStencilOperation o)
{
    switch (o) {
    case MTLStencilOperationZero: return GL_ZERO;
    case MTLStencilOperationReplace: return GL_REPLACE;
    case MTLStencilOperationIncrementClamp: return GL_INCR;
    case MTLStencilOperationDecrementClamp: return GL_DECR;
    case MTLStencilOperationInvert: return GL_INVERT;
    case MTLStencilOperationIncrementWrap: return GL_INCR_WRAP;
    case MTLStencilOperationDecrementWrap: return GL_DECR_WRAP;
    default: return GL_KEEP;
    }
}

static CharonStencil stencilOf(MTLStencilDescriptor *d)
{
    return (CharonStencil){compareFunction(d.stencilCompareFunction), stencilOperation(d.stencilFailureOperation), stencilOperation(d.depthFailureOperation),
                           stencilOperation(d.depthStencilPassOperation), d.readMask, d.writeMask};
}

static BOOL active(MTLStencilDescriptor *d)
{
    return d.stencilCompareFunction != MTLCompareFunctionAlways || d.stencilFailureOperation != MTLStencilOperationKeep || d.depthFailureOperation != MTLStencilOperationKeep ||
           d.depthStencilPassOperation != MTLStencilOperationKeep;
}

@implementation CharonMetalDepthStencil {
    CharonDepthStencil _state;
}

@synthesize label;

- (instancetype)initWithDescriptor:(MTLDepthStencilDescriptor *)descriptor
{
    if ((self = [super init])) {
        _state.depthFunction = compareFunction(descriptor.depthCompareFunction);
        _state.depthWrite = descriptor.depthWriteEnabled;
        _state.front = stencilOf(descriptor.frontFaceStencil);
        _state.back = stencilOf(descriptor.backFaceStencil);
        _state.stencilEnabled = active(descriptor.frontFaceStencil) || active(descriptor.backFaceStencil);
    }
    return self;
}

- (const CharonDepthStencil *)state
{
    return &_state;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

@end
