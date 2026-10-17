#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef kSecAttrAccessControl = CFSTR("accc");
const CFStringRef kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly = CFSTR("akpu");
const CFStringRef kSecUseOperationPrompt = CFSTR("u_OpPrompt");
const CFStringRef kSecUseNoAuthenticationUI = CFSTR("u_NoAuthUI");
const CFStringRef kSecSharedPassword = CFSTR("spwd");

SecAccessControlRef SecAccessControlCreateWithFlags(CFAllocatorRef allocator, CFTypeRef protection, SecAccessControlCreateFlags flags, CFErrorRef *error)
{
    if (error) {
        NSDictionary *info = @{NSLocalizedDescriptionKey: @"Function or operation not implemented."};
        *error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:NSOSStatusErrorDomain code:errSecUnimplemented userInfo:info]);
    }
    return NULL;
}

// SecAccessControlGetTypeID, SecAccessControl.h:41-47,
// __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0). It joins this file because it arrived in the
// same release as everything above it, and an object carries the API of exactly one release.
//
// WHAT 6.1.3 ANSWERS: it has no SecAccessControl AT ALL. The type arrived with its only two entry
// points in the same release - SecAccessControlCreateWithFlags (SecAccessControl.h:119-122,
// API_AVAILABLE(macos(10.10), ios(8.0))) and this one - and neither is in the armv7 cache of 6.1.3 or
// of 4.3 (first rung 8.0 for both, read with tools/cache-index/first-rung.lua --rungs). The attributes
// that would carry it are absent from the same caches: the literal "accc" (kSecAttrAccessControl)
// first appears at 8.0, and "akpu" (kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) with it.
//
// So on 6.1.3 there is no SecAccessControlRef for a type ID to identify: no creator, no instance, and
// no keychain call that would take one.
//
// WHAT THE PORT ANSWERS, and why it is a real type ID rather than a number it made up: this library
// DECLARES the type - the constants above, and SecAccessControlCreateWithFlags beside them - so the
// type exists in the process, and its CFTypeID is the runtime's own for the port's private class, which
// is the mechanism every toll-free bridged type uses and therefore a value no other type can have.
// Returning some other type's ID would be worse than returning nothing: a caller writing
// CFGetTypeID(x) == SecAccessControlGetTypeID() would be told a CFString or an NSArray was an access
// control.
//
// THE EFFECT, which is the whole row: 6.1.3 CANNOT produce an instance, so a caller holding this
// CFTypeID can never match an object against it. SecAccessControlCreateWithFlags above answers NULL
// with errSecUnimplemented on this release, so the type is declared and identifiable but unreachable -
// which is why this row is registered `inert` with that effect stated, and not `implemented`, which
// would claim an object a caller could hold.
//
// MEASURED ON THE HOST for the contrast, because the difference IS the row: there
// SecAccessControlCreateWithFlags returns an object for kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
// with kSecAccessControlDevicePasscode, and its type ID is not CFStringGetTypeID(). On 6.1.3 no call in
// this family returns an object at all, so the two answers are not comparable and the port does not
// pretend they are.
@interface CharonSecAccessControl : NSObject
@end

@implementation CharonSecAccessControl
@end

CFTypeID SecAccessControlGetTypeID(void)
{
    return (CFTypeID)[CharonSecAccessControl class];
}
