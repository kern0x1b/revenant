#import <MetalKit/MetalKit.h>

// The 17.0 half of the texture loader's option keys, and it is one key.
//
// MTKTextureLoaderOptionLoadAsArray arrived with the SDK of iOS 17.0, and an object carries the API
// of ONE release, so it cannot share an object with the 9.0 keys in MTKTextureLoader9.m or with the
// 10.0.1 keys in MTKTextureLoader10.m. The value is that constant's own name, which is what the
// sibling keys are and what a caller needs: the option is an NSNumber with a boolean value, so the
// key only has to be the same NSString the header names. It was read out of Apple's own framework
// rather than assumed - tests/backports/host/metal-census/loaderoptions.sh prints the value of every
// key MetalKit exports, this one included, and the file it writes is named there.

NSString *const MTKTextureLoaderOptionLoadAsArray = @"MTKTextureLoaderOptionLoadAsArray";