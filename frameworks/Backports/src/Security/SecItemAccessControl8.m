#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <dlfcn.h>
#import "RevenantSecAccessControl.h"
#import "RevenantSecureEnclave.h"

extern CFTypeID SecAccessControlGetTypeID(void);

#if !defined(REVENANT_SECURITY_LIBRARY)
#define REVENANT_SECURITY_LIBRARY "/System/Library/Frameworks/Security.framework/Security"
#endif

static const CFOptionFlags revenant_user_authentication_flags = kSecAccessControlUserPresence | kSecAccessControlBiometryAny
    | kSecAccessControlBiometryCurrentSet | kSecAccessControlDevicePasscode | kSecAccessControlCompanion;

typedef OSStatus (*revenant_item_add_function)(CFDictionaryRef, CFTypeRef *);
typedef OSStatus (*revenant_item_copy_function)(CFDictionaryRef, CFTypeRef *);
typedef OSStatus (*revenant_item_update_function)(CFDictionaryRef, CFDictionaryRef);
typedef OSStatus (*revenant_item_delete_function)(CFDictionaryRef);

static void *revenant_security_library(void)
{
    static void *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        library = dlopen(REVENANT_SECURITY_LIBRARY, RTLD_LAZY);
        if (!library) {
            NSLog(@"Security: the system library cannot be opened: %s", dlerror());
            abort();
        }
    });
    return library;
}

static void *revenant_security_symbol(const char *name)
{
    void *symbol = dlsym(revenant_security_library(), name);
    if (!symbol) {
        NSLog(@"Security: the system library does not export %s", name);
        abort();
    }
    return symbol;
}

static revenant_item_add_function revenant_native_add(void)
{
    static revenant_item_add_function function;
    if (!function)
        function = (revenant_item_add_function)revenant_security_symbol("SecItemAdd");
    return function;
}

static revenant_item_copy_function revenant_native_copy(void)
{
    static revenant_item_copy_function function;
    if (!function)
        function = (revenant_item_copy_function)revenant_security_symbol("SecItemCopyMatching");
    return function;
}

static revenant_item_update_function revenant_native_update(void)
{
    static revenant_item_update_function function;
    if (!function)
        function = (revenant_item_update_function)revenant_security_symbol("SecItemUpdate");
    return function;
}

static revenant_item_delete_function revenant_native_delete(void)
{
    static revenant_item_delete_function function;
    if (!function)
        function = (revenant_item_delete_function)revenant_security_symbol("SecItemDelete");
    return function;
}

static BOOL revenant_system_enforces_access_control(void)
{
#if defined(REVENANT_SECURITY_EMULATE_ACCESS_CONTROL)
    return NO;
#else
    static BOOL enforces;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enforces = dlsym(revenant_security_library(), "SecAccessControlGetTypeID") != NULL;
    });
    return enforces;
#endif
}

static NSString *const revenant_policy_service = @"org.revenant.access-control";
static NSString *const revenant_policy_protection = @"protection";
static NSString *const revenant_policy_flags = @"flags";

static BOOL revenant_is_access_control(CFTypeRef value)
{
    return value != NULL && CFGetTypeID(value) == SecAccessControlGetTypeID();
}

static NSString *revenant_policy_account(NSData *reference)
{
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(reference.bytes, (CC_LONG)reference.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int index = 0; index < CC_SHA256_DIGEST_LENGTH; index++)
        [hex appendFormat:@"%02x", digest[index]];
    return hex;
}

static NSDictionary *revenant_policy_query(NSData *reference)
{
    return @{(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
             (__bridge NSString *)kSecAttrService: revenant_policy_service,
             (__bridge NSString *)kSecAttrAccount: revenant_policy_account(reference)};
}

static void revenant_policy_remove(NSData *reference)
{
    revenant_native_delete()((__bridge CFDictionaryRef)revenant_policy_query(reference));
}

static OSStatus revenant_policy_write(NSData *reference, NSString *protection, CFOptionFlags flags)
{
    NSDictionary *policy = @{revenant_policy_protection: protection, revenant_policy_flags: @(flags)};
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:policy format:NSPropertyListBinaryFormat_v1_0
                                                             options:0 error:NULL];
    if (!data)
        return errSecParam;
    NSDictionary *existing = revenant_policy_query(reference);
    OSStatus status = revenant_native_update()((__bridge CFDictionaryRef)existing,
                                               (__bridge CFDictionaryRef)@{(__bridge NSString *)kSecValueData: data});
    if (status != errSecItemNotFound)
        return status;
    NSMutableDictionary *add = [existing mutableCopy];
    add[(__bridge NSString *)kSecValueData] = data;
    add[(__bridge NSString *)kSecAttrAccessible] = (__bridge NSString *)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    return revenant_native_add()((__bridge CFDictionaryRef)add, NULL);
}

static OSStatus revenant_policy_read(NSData *reference, NSDictionary **policy)
{
    *policy = nil;
    NSMutableDictionary *query = [revenant_policy_query(reference) mutableCopy];
    query[(__bridge NSString *)kSecReturnData] = @YES;
    query[(__bridge NSString *)kSecMatchLimit] = (__bridge NSString *)kSecMatchLimitOne;
    CFTypeRef found = NULL;
    OSStatus status = revenant_native_copy()((__bridge CFDictionaryRef)query, &found);
    if (status != errSecSuccess)
        return status;
    if (!found)
        return errSecInternalError;
    NSData *data = (__bridge_transfer NSData *)found;
    NSDictionary *decoded = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable
                                                                      format:NULL error:NULL];
    if (![decoded isKindOfClass:[NSDictionary class]])
        return errSecInternalError;
    *policy = decoded;
    return errSecSuccess;
}

static BOOL revenant_policy_requires_user(NSDictionary *policy)
{
    CFOptionFlags flags = (CFOptionFlags)[policy[revenant_policy_flags] unsignedIntegerValue];
    return (flags & revenant_user_authentication_flags) != 0;
}

static BOOL revenant_query_allows_ui(NSDictionary *query)
{
    if ([query[(__bridge NSString *)kSecUseNoAuthenticationUI] boolValue])
        return NO;
    NSString *ui = query[(__bridge NSString *)kSecUseAuthenticationUI];
    return ![ui isEqualToString:(__bridge NSString *)kSecUseAuthenticationUIFail];
}

static OSStatus revenant_status_for_local_auth_error(NSError *error)
{
    switch (error.code) {
    case LAErrorUserCancel:
    case LAErrorUserFallback:
    case LAErrorSystemCancel:
    case LAErrorAppCancel:
        return errSecUserCanceled;
    case LAErrorNotInteractive:
        return errSecInteractionNotAllowed;
    default:
        return errSecAuthFailed;
    }
}

static OSStatus revenant_authenticate(BOOL allowUI, NSString *reason)
{
    if (!allowUI)
        return errSecInteractionNotAllowed;
    if (reason.length == 0)
        reason = @"Access to a protected item.";
    LAContext *context = [[LAContext alloc] init];
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block OSStatus status = errSecAuthFailed;
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:reason reply:^(BOOL success, NSError *error) {
        status = success ? errSecSuccess : revenant_status_for_local_auth_error(error);
        dispatch_semaphore_signal(finished);
    }];
    if ([NSThread isMainThread]) {
        while (dispatch_semaphore_wait(finished, DISPATCH_TIME_NOW) != 0)
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
    } else {
        dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
    }
    return status;
}

OSStatus RevenantSecItemAuthenticate(bool allowUI, CFStringRef reason)
{
    return revenant_authenticate(allowUI, (__bridge NSString *)reason);
}

bool RevenantSecItemFlagsRequireUser(CFOptionFlags flags)
{
    return (flags & revenant_user_authentication_flags) != 0;
}

bool RevenantSecItemSystemEnforcesAccessControl(void)
{
    return revenant_system_enforces_access_control();
}

static BOOL revenant_is_key_query(NSDictionary *source)
{
    return [source[(__bridge NSString *)kSecClass] isEqual:(__bridge NSString *)kSecClassKey];
}

static NSMutableDictionary *revenant_lookup_query(NSDictionary *query, BOOL all)
{
    NSSet *skipped = [NSSet setWithObjects:(__bridge NSString *)kSecReturnData, (__bridge NSString *)kSecReturnAttributes,
                                           (__bridge NSString *)kSecReturnRef, (__bridge NSString *)kSecReturnPersistentRef,
                                           (__bridge NSString *)kSecMatchLimit, (__bridge NSString *)kSecUseNoAuthenticationUI,
                                           (__bridge NSString *)kSecUseOperationPrompt, (__bridge NSString *)kSecUseAuthenticationUI,
                                           (__bridge NSString *)kSecUseAuthenticationContext,
                                           (__bridge NSString *)kSecAttrAccessControl, nil];
    NSMutableDictionary *lookup = [NSMutableDictionary dictionary];
    for (NSString *key in query) {
        if (![skipped containsObject:key])
            lookup[key] = query[key];
    }
    lookup[(__bridge NSString *)kSecReturnPersistentRef] = @YES;
    NSString *limit = all ? (__bridge NSString *)kSecMatchLimitAll : query[(__bridge NSString *)kSecMatchLimit];
    lookup[(__bridge NSString *)kSecMatchLimit] = limit ?: (__bridge NSString *)kSecMatchLimitOne;
    return lookup;
}

static OSStatus revenant_references(NSDictionary *query, BOOL all, NSArray **references)
{
    *references = @[];
    id reference = query[(__bridge NSString *)kSecValuePersistentRef];
    if (reference) {
        *references = @[reference];
        return errSecSuccess;
    }
    CFTypeRef found = NULL;
    OSStatus status = revenant_native_copy()((__bridge CFDictionaryRef)revenant_lookup_query(query, all), &found);
    if (status == errSecItemNotFound)
        return errSecSuccess;
    if (status != errSecSuccess)
        return status;
    if (!found)
        return errSecSuccess;
    id value = (__bridge_transfer id)found;
    *references = [value isKindOfClass:[NSArray class]] ? value : @[value];
    return errSecSuccess;
}

static OSStatus revenant_gate(NSDictionary *query, NSArray *references)
{
    BOOL needsUser = NO;
    for (NSData *reference in references) {
        NSDictionary *policy = nil;
        OSStatus status = revenant_policy_read(reference, &policy);
        if (status == errSecItemNotFound)
            continue;
        if (status != errSecSuccess)
            return status;
        if (revenant_policy_requires_user(policy)) {
            needsUser = YES;
            break;
        }
    }
    if (!needsUser)
        return errSecSuccess;
    NSString *reason = query[(__bridge NSString *)kSecUseOperationPrompt];
    return revenant_authenticate(revenant_query_allows_ui(query), reason);
}

static NSMutableDictionary *revenant_native_attributes(NSDictionary *attributes, CFTypeRef accessControl, NSString **protectionOut)
{
    NSMutableDictionary *native = [attributes mutableCopy];
    [native removeObjectForKey:(__bridge NSString *)kSecAttrAccessControl];
    if (!accessControl)
        return native;
    NSString *protection = (__bridge NSString *)RevenantAccessControlProtection((SecAccessControlRef)accessControl);
    native[(__bridge NSString *)kSecAttrAccessible] = protection;
    if (protectionOut)
        *protectionOut = protection;
    return native;
}

OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result)
{
    NSDictionary *source = (__bridge NSDictionary *)attributes;
    CFTypeRef accessControl = attributes ? CFDictionaryGetValue(attributes, kSecAttrAccessControl) : NULL;
    if (revenant_system_enforces_access_control() || !accessControl)
        return revenant_native_add()(attributes, result);
    if (!revenant_is_access_control(accessControl))
        return errSecParam;
    NSString *protection = nil;
    NSMutableDictionary *native = revenant_native_attributes(source, accessControl, &protection);
    CFOptionFlags flags = RevenantAccessControlFlags((SecAccessControlRef)accessControl);
    BOOL wantsReference = [source[(__bridge NSString *)kSecReturnPersistentRef] boolValue];
    NSMutableDictionary *callerReturns = [NSMutableDictionary dictionary];
    for (NSString *key in @[(__bridge NSString *)kSecReturnData, (__bridge NSString *)kSecReturnAttributes, (__bridge NSString *)kSecReturnRef]) {
        if (source[key])
            callerReturns[key] = source[key];
    }
    [native removeObjectsForKeys:@[(__bridge NSString *)kSecReturnData, (__bridge NSString *)kSecReturnAttributes,
                                   (__bridge NSString *)kSecReturnRef, (__bridge NSString *)kSecReturnPersistentRef]];
    native[(__bridge NSString *)kSecReturnPersistentRef] = @YES;
    CFTypeRef added = NULL;
    OSStatus status = revenant_native_add()((__bridge CFDictionaryRef)native, &added);
    if (status != errSecSuccess)
        return status;
    if (!added)
        return errSecInternalError;
    NSData *reference = (__bridge_transfer NSData *)added;
    status = revenant_policy_write(reference, protection, flags);
    if (status != errSecSuccess) {
        NSDictionary *remove = @{(__bridge NSString *)kSecValuePersistentRef: reference};
        revenant_native_delete()((__bridge CFDictionaryRef)remove);
        return status;
    }
    if (!result)
        return errSecSuccess;
    if (callerReturns.count > 0) {
        NSMutableDictionary *lookup = [callerReturns mutableCopy];
        lookup[(__bridge NSString *)kSecValuePersistentRef] = reference;
        return SecItemCopyMatching((__bridge CFDictionaryRef)lookup, result);
    }
    *result = wantsReference ? (__bridge_retained CFTypeRef)reference : NULL;
    return errSecSuccess;
}

OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
{
    if (revenant_system_enforces_access_control() || !query)
        return revenant_native_copy()(query, result);
    NSDictionary *source = (__bridge NSDictionary *)query;
    if (revenant_is_key_query(source)) {
        OSStatus handled = RevenantSecureEnclaveKeyLookup(query, result);
        if (handled != errSecItemNotFound)
            return handled;
    }
    NSArray *references = nil;
    OSStatus status = revenant_references(source, NO, &references);
    if (status == errSecSuccess)
        status = revenant_gate(source, references);
    if (status != errSecSuccess)
        return status;
    return revenant_native_copy()(query, result);
}

OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate)
{
    if (revenant_system_enforces_access_control() || !query || !attributesToUpdate)
        return revenant_native_update()(query, attributesToUpdate);
    CFTypeRef accessControl = CFDictionaryGetValue(attributesToUpdate, kSecAttrAccessControl);
    if (accessControl && !revenant_is_access_control(accessControl))
        return errSecParam;
    NSDictionary *source = (__bridge NSDictionary *)query;
    NSArray *references = nil;
    OSStatus status = revenant_references(source, YES, &references);
    if (status == errSecSuccess)
        status = revenant_gate(source, references);
    if (status != errSecSuccess)
        return status;
    if (!accessControl)
        return revenant_native_update()(query, attributesToUpdate);
    NSString *protection = nil;
    NSMutableDictionary *native = revenant_native_attributes((__bridge NSDictionary *)attributesToUpdate, accessControl, &protection);
    status = revenant_native_update()(query, (__bridge CFDictionaryRef)native);
    if (status != errSecSuccess)
        return status;
    CFOptionFlags flags = RevenantAccessControlFlags((SecAccessControlRef)accessControl);
    for (NSData *reference in references) {
        status = revenant_policy_write(reference, protection, flags);
        if (status != errSecSuccess)
            return status;
    }
    return errSecSuccess;
}

OSStatus SecItemDelete(CFDictionaryRef query)
{
    if (revenant_system_enforces_access_control() || !query)
        return revenant_native_delete()(query);
    NSDictionary *source = (__bridge NSDictionary *)query;
    if (revenant_is_key_query(source)) {
        OSStatus handled = RevenantSecureEnclaveKeyDelete(query);
        if (handled != errSecItemNotFound)
            return handled;
    }
    NSArray *references = nil;
    OSStatus status = revenant_references(source, YES, &references);
    if (status != errSecSuccess)
        return status;
    status = revenant_native_delete()(query);
    if (status != errSecSuccess)
        return status;
    for (NSData *reference in references)
        revenant_policy_remove(reference);
    return errSecSuccess;
}
