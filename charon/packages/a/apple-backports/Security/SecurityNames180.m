#import <Foundation/Foundation.h>
#import <Security/Security.h>

// kSecImportToMemoryOnly, iOS 18.0 (SecImportExport.h). Its value is the host's own, "memory", read by dlsym and
// compared by tests/backports/host/commoncrypto/differential-constants.c. No function in the port's sources reads it
// (facts/Security/SecImportToMemoryOnly.md): the name is carried, and the option has no effect here.
const CFStringRef kSecImportToMemoryOnly = CFSTR("memory");
