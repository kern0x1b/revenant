#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>

// The 10.0.1 half of the texture loader's constants.
//
// An object carries the API of ONE release, decided by the cache ladder, and release-split measured
// which on the gate's own object: these eight are exported from 10.0.1, while MTKTextureLoader, the
// error domain and key, MTKTextureLoaderOptionSRGB, OptionAllocateMipmaps, OptionTextureUsage and
// OptionTextureCPUCacheMode are exported from 9.0. One object for all of them mixed releases, which is
// what the 6.1.3 gate's release-split rule stopped on.
//
// The values are each constant's own name, which is what a caller passing the name it read out of
// the header needs - and MTKTextureLoader.h:47 and its siblings state what each one does. These are
// DATA, and the loader in MTKTextureLoader9.m reads them across this object boundary: a 9.0 band that
// links neither never sees them, and a 10.0.1 band sees exactly the ones that release introduced.

NSString *const MTKTextureLoaderOptionGenerateMipmaps = @"MTKTextureLoaderOptionGenerateMipmaps";
NSString *const MTKTextureLoaderOptionTextureStorageMode = @"MTKTextureLoaderOptionTextureStorageMode";
NSString *const MTKTextureLoaderOptionCubeLayout = @"MTKTextureLoaderOptionCubeLayout";
NSString *const MTKTextureLoaderOptionOrigin = @"MTKTextureLoaderOptionOrigin";
NSString *const MTKTextureLoaderCubeLayoutVertical = @"MTKTextureLoaderCubeLayoutVertical";
NSString *const MTKTextureLoaderOriginTopLeft = @"MTKTextureLoaderOriginTopLeft";
NSString *const MTKTextureLoaderOriginBottomLeft = @"MTKTextureLoaderOriginBottomLeft";
NSString *const MTKTextureLoaderOriginFlippedVertically = @"MTKTextureLoaderOriginFlippedVertically";
