#import <Foundation/Foundation.h>

// The sparse mapping calls of MTL4CommandQueue, and the refusals Apple makes when one of their
// requirements is not met. Metal's own answers are measured on the macOS 26 host (facts/Metal/SparseMapping26.md):
// a buffer that is not placement sparse, a heap that is not a placement heap, and a nil heap with a mapping
// mode that is not unmap all stop the process with an assertion, and the assertion's text is the reason
// below. Every refusal here is returned as text, and the method that asked raises it as an
// NSInternalInconsistencyException, which terminates an uncaught process the way Metal's assertion does.
//
// The functions take what the call knows, as plain flags, so that the decision is one piece of arithmetic
// that tests/backports/host/mtl4-sparse-mapping/run.sh can compile and check against Apple beside it.
// The port's buffers and textures are never placement sparse (the port makes none), so every call that
// reaches these refusals is refused: a sparse mapping has no backing on this device, and an answer that
// let it through would be a mapping nothing performs.

// The reason Metal's buffer update gives for a call its buffer and heap do not satisfy, or nil when the
// requirements hold. Order is Metal's: the buffer first, then the heap, then the nil-heap rule.
NSString *CharonMetal4SparseBufferUpdateRefusal(BOOL bufferIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode)
{
    if (!bufferIsPlacementSparse)
        return @"Buffer is not a Placement Sparse Buffer";
    if (heapPresent && !heapIsPlacement)
        return @"Heap is not a Placement";
    if (!heapPresent && mappingMode)
        return @"Mapping mode must be unmap for nil heap";
    return nil;
}

// The reason Metal's buffer copy gives: the source is named before the destination, as Metal checks them.
NSString *CharonMetal4SparseBufferCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse)
{
    if (!sourceIsPlacementSparse)
        return @"Source Buffer is not a Placement Sparse Buffer";
    if (!destinationIsPlacementSparse)
        return @"Destination Buffer is not a Placement Sparse Buffer";
    return nil;
}

// THE TEXTURE FORMS ARE NOT MEASURED AS REFUSALS. Metal returned normally for a texture update or copy
// whose texture was not placement sparse, and for a sparse texture with a non-placement heap, so no refusal
// text exists to copy (facts/Metal/SparseMapping26.md, "What Metal accepts"). Metal's documentation makes
// the placement-sparse texture and the placement heap the caller's responsibility. The port cannot map a
// tile of a texture at all, so it cannot accept the call as a mapping; it refuses it on that requirement,
// and the facts say that this is the port's own answer and not one Metal gives.
NSString *CharonMetal4SparseTextureUpdateRefusal(BOOL textureIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode)
{
    if (!textureIsPlacementSparse)
        return @"Texture is not a Placement Sparse Texture";
    if (heapPresent && !heapIsPlacement)
        return @"Heap is not a Placement";
    if (!heapPresent && mappingMode)
        return @"Mapping mode must be unmap for nil heap";
    return nil;
}

NSString *CharonMetal4SparseTextureCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse)
{
    if (!sourceIsPlacementSparse)
        return @"Source Texture is not a Placement Sparse Texture";
    if (!destinationIsPlacementSparse)
        return @"Destination Texture is not a Placement Sparse Texture";
    return nil;
}
