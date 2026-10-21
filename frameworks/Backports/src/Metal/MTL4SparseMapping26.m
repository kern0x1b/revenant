#import <Foundation/Foundation.h>

NSString *RevenantMetal4SparseBufferUpdateRefusal(BOOL bufferIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode)
{
    if (!bufferIsPlacementSparse)
        return @"Buffer is not a Placement Sparse Buffer";
    if (heapPresent && !heapIsPlacement)
        return @"Heap is not a Placement";
    if (!heapPresent && mappingMode)
        return @"Mapping mode must be unmap for nil heap";
    return nil;
}

NSString *RevenantMetal4SparseBufferCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse)
{
    if (!sourceIsPlacementSparse)
        return @"Source Buffer is not a Placement Sparse Buffer";
    if (!destinationIsPlacementSparse)
        return @"Destination Buffer is not a Placement Sparse Buffer";
    return nil;
}

NSString *RevenantMetal4SparseTextureUpdateRefusal(BOOL textureIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode)
{
    if (!textureIsPlacementSparse)
        return @"Texture is not a Placement Sparse Texture";
    if (heapPresent && !heapIsPlacement)
        return @"Heap is not a Placement";
    if (!heapPresent && mappingMode)
        return @"Mapping mode must be unmap for nil heap";
    return nil;
}

NSString *RevenantMetal4SparseTextureCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse)
{
    if (!sourceIsPlacementSparse)
        return @"Source Texture is not a Placement Sparse Texture";
    if (!destinationIsPlacementSparse)
        return @"Destination Texture is not a Placement Sparse Texture";
    return nil;
}
