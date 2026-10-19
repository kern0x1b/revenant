#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

// THE ERROR DOMAIN OF THE IO FACILITY, which arrived with iOS 16: MTLIOErrorDomain. The SDK declares it as an
// NSErrorDomain and never spells the string. Its value is Apple's own, "MTLIOError" (not "MTLIOErrorDomain"),
// read from Apple's Metal by dlsym in tests/backports/host/error-domains/run.sh.
//
// The IO classes this constant belongs to are not in this port (registry/Metal/absent_Metal.json), so no error
// reaches a caller with this domain. The constant is carried so that a comparison against it is well formed.
NSErrorDomain const MTLIOErrorDomain = @"MTLIOError";
