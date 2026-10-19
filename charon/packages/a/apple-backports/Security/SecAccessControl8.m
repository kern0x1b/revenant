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

@interface CharonSecAccessControl : NSObject
@end

@implementation CharonSecAccessControl
@end

CFTypeID SecAccessControlGetTypeID(void)
{
    return (CFTypeID)[CharonSecAccessControl class];
}
