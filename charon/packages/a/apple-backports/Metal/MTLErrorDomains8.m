#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

// THE ERROR DOMAINS THAT ARRIVED WITH iOS 8: MTLCommandBufferErrorDomain and MTLLibraryErrorDomain. The SDK
// declares each one as an NSErrorDomain and never spells the string, so the values below are Apple's own, read
// from Apple's Metal by dlsym in tests/backports/host/error-domains/run.sh and compared byte for byte.
//
// A caller compares an NSError's domain with these strings. No error this port raises carries either domain, so the
// constants answer what Apple's do and nothing in the port depends on them (facts/Metal/ErrorDomains.md).
NSErrorDomain const MTLCommandBufferErrorDomain = @"MTLCommandBufferErrorDomain";
NSErrorDomain const MTLLibraryErrorDomain = @"MTLLibraryErrorDomain";
