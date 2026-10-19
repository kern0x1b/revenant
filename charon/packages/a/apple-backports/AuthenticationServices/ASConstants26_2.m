// The AuthenticationServices string constants of iOS 26.2. Every value here was read out of a real
// AuthenticationServices.framework: the host's own AuthenticationServices.framework, read with dlsym: the symbol's own pointer, then the __CFConstantString's char* and its length, with the bytes at that address agreeing with the length (6 of 6, 12 of 12, 10 of 10)
// One release's API per object file, which is what the band machinery needs.
#import <Foundation/Foundation.h>

NSString *const ASGeneratedPasswordKindAlphanumeric = @"ALPHANUMERIC";
NSString *const ASGeneratedPasswordKindPassphrase = @"PASSPHRASE";
NSString *const ASGeneratedPasswordKindStrong = @"STRONG";
