#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dispatch/dispatch.h>
#import "../RevenantCFRuntime.h"
#import "RevenantSecAccessControl.h"

const CFStringRef kSecAttrAccessControl = CFSTR("accc");
const CFStringRef kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly = CFSTR("aku");
const CFStringRef kSecUseOperationPrompt = CFSTR("u_OpPrompt");
const CFStringRef kSecUseNoAuthenticationUI = CFSTR("u_NoAuthUI");
const CFStringRef kSecSharedPassword = CFSTR("spwd");

struct RevenantAccessControlState {
    CFStringRef protection;
    CFOptionFlags flags;
};

static const CFOptionFlags revenantAccessControlUnnamedPresenceBit = 1u << 2;

static struct RevenantAccessControlState *revenant_access_control_state(CFTypeRef cf)
{
    return (struct RevenantAccessControlState *)((uint8_t *)cf + sizeof(RevenantCFRuntimeBase));
}

static void revenant_access_control_finalize(CFTypeRef cf)
{
    struct RevenantAccessControlState *state = revenant_access_control_state(cf);
    if (state->protection)
        CFRelease(state->protection);
    state->protection = NULL;
}

static Boolean revenant_access_control_equal(CFTypeRef first, CFTypeRef second)
{
    struct RevenantAccessControlState *a = revenant_access_control_state(first);
    struct RevenantAccessControlState *b = revenant_access_control_state(second);
    return a->flags == b->flags && CFEqual(a->protection, b->protection);
}

static CFHashCode revenant_access_control_hash(CFTypeRef cf)
{
    struct RevenantAccessControlState *state = revenant_access_control_state(cf);
    return CFHash(state->protection) * 31 + (CFHashCode)state->flags;
}

static CFStringRef revenant_access_control_debug_description(CFTypeRef cf)
{
    struct RevenantAccessControlState *state = revenant_access_control_state(cf);
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<SecAccessControl %p: protection %@, flags 0x%lx>"),
                                    cf, state->protection, (unsigned long)state->flags);
}

static CFTypeID revenant_access_control_type(void)
{
    static CFTypeID typeID;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        static const RevenantCFRuntimeClass accessControlClass = {
            .version = 0,
            .className = "SecAccessControl",
            .finalize = revenant_access_control_finalize,
            .equal = revenant_access_control_equal,
            .hash = revenant_access_control_hash,
            .copyDebugDesc = revenant_access_control_debug_description,
        };
        typeID = _CFRuntimeRegisterClass(&accessControlClass);
    });
    return typeID;
}

static BOOL revenant_access_control_protection_is_valid(CFTypeRef protection)
{
    if (!protection || CFGetTypeID(protection) != CFStringGetTypeID())
        return NO;
    const CFStringRef accepted[] = {
        kSecAttrAccessibleWhenUnlocked,
        kSecAttrAccessibleAfterFirstUnlock,
        kSecAttrAccessibleAlways,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrAccessibleAlwaysThisDeviceOnly,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    };
    for (size_t index = 0; index < sizeof accepted / sizeof accepted[0]; index++) {
        if (CFEqual(protection, accepted[index]))
            return YES;
    }
    return NO;
}

static BOOL revenant_access_control_flags_are_valid(CFOptionFlags flags)
{
    const CFOptionFlags presenceExclusive = kSecAccessControlBiometryAny | kSecAccessControlBiometryCurrentSet
        | kSecAccessControlDevicePasscode | kSecAccessControlCompanion | kSecAccessControlOr | kSecAccessControlAnd
        | revenantAccessControlUnnamedPresenceBit;
    if ((flags & kSecAccessControlOr) && (flags & kSecAccessControlAnd))
        return NO;
    if ((flags & kSecAccessControlBiometryAny) && (flags & kSecAccessControlBiometryCurrentSet))
        return NO;
    if ((flags & kSecAccessControlUserPresence) && (flags & presenceExclusive))
        return NO;
    return YES;
}

SecAccessControlRef SecAccessControlCreateWithFlags(CFAllocatorRef allocator, CFTypeRef protection, SecAccessControlCreateFlags flags, CFErrorRef *error)
{
    if (!revenant_access_control_protection_is_valid(protection) || !revenant_access_control_flags_are_valid(flags)) {
        if (error)
            *error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:NSOSStatusErrorDomain code:errSecParam userInfo:nil]);
        return NULL;
    }
    CFTypeRef object = _CFRuntimeCreateInstance(allocator, revenant_access_control_type(), sizeof(struct RevenantAccessControlState), NULL);
    if (!object)
        return NULL;
    struct RevenantAccessControlState *state = revenant_access_control_state(object);
    state->protection = (CFStringRef)CFRetain(protection);
    state->flags = flags;
    return (SecAccessControlRef)object;
}

CFTypeID SecAccessControlGetTypeID(void)
{
    return revenant_access_control_type();
}

CFTypeRef RevenantAccessControlProtection(SecAccessControlRef accessControl)
{
    if (!accessControl || CFGetTypeID(accessControl) != revenant_access_control_type())
        return NULL;
    return revenant_access_control_state(accessControl)->protection;
}

CFOptionFlags RevenantAccessControlFlags(SecAccessControlRef accessControl)
{
    if (!accessControl || CFGetTypeID(accessControl) != revenant_access_control_type())
        return 0;
    return revenant_access_control_state(accessControl)->flags;
}
