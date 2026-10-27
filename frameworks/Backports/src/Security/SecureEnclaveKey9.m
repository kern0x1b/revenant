#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <string.h>
#import "../RevenantCFRuntime.h"
#import "RevenantSecAccessControl.h"
#import "RevenantSecureEnclave.h"

extern CFTypeID SecAccessControlGetTypeID(void);
extern const uint8_t *RevenantCKGroupOrder(void);
extern int RevenantCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);
extern void RevenantSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description);

static NSString *const revenant_secure_enclave_private_service = @"org.revenant.secure-enclave.private";
static NSString *const revenant_secure_enclave_public_service = @"org.revenant.secure-enclave.public";

struct RevenantSecureEnclaveState {
    CFDataRef tag;
    CFDataRef point;
    CFDataRef scalar;
    CFOptionFlags flags;
    Boolean isPrivate;
};

static struct RevenantSecureEnclaveState *revenant_secure_enclave_state(CFTypeRef cf)
{
    return (struct RevenantSecureEnclaveState *)((uint8_t *)cf + sizeof(RevenantCFRuntimeBase));
}

static void revenant_secure_enclave_finalize(CFTypeRef cf)
{
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(cf);
    if (state->tag)
        CFRelease(state->tag);
    if (state->point)
        CFRelease(state->point);
    if (state->scalar)
        CFRelease(state->scalar);
    state->tag = NULL;
    state->point = NULL;
    state->scalar = NULL;
}

static CFTypeID revenant_secure_enclave_type(void)
{
    static CFTypeID typeID;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        static const RevenantCFRuntimeClass keyClass = {
            .version = 0,
            .className = "RevenantSecKey",
            .finalize = revenant_secure_enclave_finalize,
        };
        typeID = _CFRuntimeRegisterClass(&keyClass);
    });
    return typeID;
}

static SecKeyRef revenant_secure_enclave_create(BOOL isPrivate, CFDataRef tag, CFDataRef point, CFDataRef scalar, CFOptionFlags flags)
{
    CFTypeRef object = _CFRuntimeCreateInstance(kCFAllocatorDefault, revenant_secure_enclave_type(),
                                                sizeof(struct RevenantSecureEnclaveState), NULL);
    if (!object)
        return NULL;
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(object);
    state->isPrivate = isPrivate;
    state->tag = tag ? (CFDataRef)CFRetain(tag) : NULL;
    state->point = (CFDataRef)CFRetain(point);
    state->scalar = scalar ? (CFDataRef)CFRetain(scalar) : NULL;
    state->flags = flags;
    return (SecKeyRef)object;
}

bool RevenantSecureEnclaveKeyIs(SecKeyRef key)
{
    return key != NULL && CFGetTypeID(key) == revenant_secure_enclave_type();
}

bool RevenantSecureEnclaveKeyIsPrivate(SecKeyRef key)
{
    return RevenantSecureEnclaveKeyIs(key) && revenant_secure_enclave_state(key)->isPrivate;
}

OSStatus RevenantSecureEnclaveKeyPoint(SecKeyRef key, uint8_t point[65])
{
    if (!RevenantSecureEnclaveKeyIs(key))
        return errSecParam;
    CFDataRef stored = revenant_secure_enclave_state(key)->point;
    if (!stored || CFDataGetLength(stored) != 65)
        return errSecInternalError;
    memcpy(point, CFDataGetBytePtr(stored), 65);
    return errSecSuccess;
}

static NSString *revenant_secure_enclave_account(CFDataRef tag)
{
    const uint8_t *bytes = CFDataGetBytePtr(tag);
    CFIndex length = CFDataGetLength(tag);
    NSMutableString *hex = [NSMutableString stringWithCapacity:(NSUInteger)length * 2];
    for (CFIndex index = 0; index < length; index++)
        [hex appendFormat:@"%02x", bytes[index]];
    return hex;
}

static NSData *revenant_secure_enclave_read(NSString *service, NSString *account, OSStatus *status)
{
    NSDictionary *query = @{(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
                            (__bridge NSString *)kSecAttrService: service,
                            (__bridge NSString *)kSecAttrAccount: account,
                            (__bridge NSString *)kSecReturnData: @YES,
                            (__bridge NSString *)kSecMatchLimit: (__bridge NSString *)kSecMatchLimitOne};
    CFTypeRef found = NULL;
    *status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);
    if (*status != errSecSuccess)
        return nil;
    if (!found) {
        *status = errSecInternalError;
        return nil;
    }
    return (__bridge_transfer NSData *)found;
}

static OSStatus revenant_secure_enclave_store(NSString *service, NSString *account, NSData *data, CFStringRef accessible, CFTypeRef accessControl)
{
    CFMutableDictionaryRef add = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(add, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(add, kSecAttrService, (__bridge CFStringRef)service);
    CFDictionarySetValue(add, kSecAttrAccount, (__bridge CFStringRef)account);
    CFDictionarySetValue(add, kSecValueData, (__bridge CFDataRef)data);
    CFDictionarySetValue(add, kSecAttrAccessible, accessible);
    if (accessControl)
        CFDictionarySetValue(add, kSecAttrAccessControl, accessControl);
    OSStatus status = SecItemAdd(add, NULL);
    CFRelease(add);
    return status;
}

static OSStatus revenant_secure_enclave_remove(NSString *service, NSString *account)
{
    NSDictionary *query = @{(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
                            (__bridge NSString *)kSecAttrService: service,
                            (__bridge NSString *)kSecAttrAccount: account};
    return SecItemDelete((__bridge CFDictionaryRef)query);
}

static BOOL revenant_secure_enclave_random_scalar(uint8_t scalar[32])
{
    const uint8_t *order = RevenantCKGroupOrder();
    for (int attempt = 0; attempt < 16; attempt++) {
        if (SecRandomCopyBytes(kSecRandomDefault, 32, scalar) != errSecSuccess)
            return NO;
        uint8_t any = 0;
        for (int index = 0; index < 32; index++)
            any |= scalar[index];
        if (any != 0 && memcmp(scalar, order, 32) < 0)
            return YES;
    }
    return NO;
}

SecKeyRef RevenantSecureEnclaveKeyCreateRandom(CFDictionaryRef parameters, CFErrorRef *error)
{
    NSDictionary *source = (__bridge NSDictionary *)parameters;
    if (![source[(__bridge NSString *)kSecAttrKeyType] isEqual:(__bridge NSString *)kSecAttrKeyTypeECSECPrimeRandom]) {
        RevenantSecKeyFail(error, errSecParam, @"the Secure Enclave emulation makes P-256 keys only");
        return NULL;
    }
    NSNumber *bits = source[(__bridge NSString *)kSecAttrKeySizeInBits];
    if (bits && [bits integerValue] != 256) {
        RevenantSecKeyFail(error, errSecParam, @"the Secure Enclave emulation makes 256 bit keys only");
        return NULL;
    }
    NSDictionary *privateAttributes = source[(__bridge NSString *)kSecPrivateKeyAttrs];
    BOOL permanent = [privateAttributes[(__bridge NSString *)kSecAttrIsPermanent] boolValue];
    NSData *tag = privateAttributes[(__bridge NSString *)kSecAttrApplicationTag];
    if (permanent && ![tag isKindOfClass:[NSData class]]) {
        RevenantSecKeyFail(error, errSecParam, @"a permanent Secure Enclave key needs an application tag");
        return NULL;
    }
    CFTypeRef accessControl = (__bridge CFTypeRef)privateAttributes[(__bridge NSString *)kSecAttrAccessControl];
    if (accessControl && CFGetTypeID(accessControl) != SecAccessControlGetTypeID()) {
        RevenantSecKeyFail(error, errSecParam, @"the access control is not a SecAccessControl");
        return NULL;
    }
    CFOptionFlags flags = accessControl ? RevenantAccessControlFlags((SecAccessControlRef)accessControl) : 0;
    CFStringRef accessible = accessControl ? (CFStringRef)RevenantAccessControlProtection((SecAccessControlRef)accessControl)
                                           : kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    uint8_t scalar[32];
    uint8_t point[65];
    if (!revenant_secure_enclave_random_scalar(scalar) || RevenantCKPublicKeyES256(scalar, point) != 65) {
        memset(scalar, 0, sizeof scalar);
        RevenantSecKeyFail(error, errSecInternalError, @"micro-ecc made no P-256 key pair");
        return NULL;
    }
    NSData *pointData = [NSData dataWithBytes:point length:sizeof point];
    SecKeyRef key = NULL;
    if (permanent) {
        NSString *account = revenant_secure_enclave_account((__bridge CFDataRef)tag);
        OSStatus status = errSecSuccess;
        revenant_secure_enclave_read(revenant_secure_enclave_public_service, account, &status);
        if (status == errSecSuccess) {
            memset(scalar, 0, sizeof scalar);
            RevenantSecKeyFail(error, errSecDuplicateItem, @"a Secure Enclave key with this tag exists");
            return NULL;
        }
        NSData *scalarData = [NSData dataWithBytes:scalar length:sizeof scalar];
        status = revenant_secure_enclave_store(revenant_secure_enclave_private_service, account, scalarData, accessible, accessControl);
        if (status == errSecSuccess) {
            status = revenant_secure_enclave_store(revenant_secure_enclave_public_service, account, pointData,
                                                   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, NULL);
            if (status != errSecSuccess)
                revenant_secure_enclave_remove(revenant_secure_enclave_private_service, account);
        }
        memset(scalar, 0, sizeof scalar);
        if (status != errSecSuccess) {
            RevenantSecKeyFail(error, status, @"the keychain refused the emulated Secure Enclave key");
            return NULL;
        }
        key = revenant_secure_enclave_create(YES, (__bridge CFDataRef)tag, (__bridge CFDataRef)pointData, NULL, flags);
    } else {
        NSData *scalarData = [NSData dataWithBytes:scalar length:sizeof scalar];
        memset(scalar, 0, sizeof scalar);
        key = revenant_secure_enclave_create(YES, NULL, (__bridge CFDataRef)pointData, (__bridge CFDataRef)scalarData, flags);
    }
    if (!key)
        RevenantSecKeyFail(error, errSecInternalError, @"the release could not make the emulated key object");
    return key;
}

SecKeyRef RevenantSecureEnclaveKeyCopyPublic(SecKeyRef key)
{
    if (!RevenantSecureEnclaveKeyIs(key))
        return NULL;
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    return revenant_secure_enclave_create(NO, state->tag, state->point, NULL, 0);
}

OSStatus RevenantSecureEnclaveKeyScalar(SecKeyRef key, uint8_t scalar[32])
{
    if (!RevenantSecureEnclaveKeyIsPrivate(key))
        return errSecParam;
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    if (state->scalar) {
        if (RevenantSecItemFlagsRequireUser(state->flags)) {
            OSStatus status = RevenantSecItemAuthenticate(true, CFSTR("Use the key."));
            if (status != errSecSuccess)
                return status;
        }
        if (CFDataGetLength(state->scalar) != 32)
            return errSecInternalError;
        memcpy(scalar, CFDataGetBytePtr(state->scalar), 32);
        return errSecSuccess;
    }
    if (!state->tag)
        return errSecInternalError;
    OSStatus status = errSecSuccess;
    NSData *data = revenant_secure_enclave_read(revenant_secure_enclave_private_service,
                                                revenant_secure_enclave_account(state->tag), &status);
    if (!data)
        return status;
    if (data.length != 32)
        return errSecInternalError;
    memcpy(scalar, data.bytes, 32);
    return errSecSuccess;
}

static BOOL revenant_secure_enclave_is_query(NSDictionary *source, NSData **tag)
{
    if (![source[(__bridge NSString *)kSecClass] isEqual:(__bridge NSString *)kSecClassKey])
        return NO;
    id keyType = source[(__bridge NSString *)kSecAttrKeyType];
    if (keyType && ![keyType isEqual:(__bridge NSString *)kSecAttrKeyTypeECSECPrimeRandom])
        return NO;
    NSData *value = source[(__bridge NSString *)kSecAttrApplicationTag];
    if (![value isKindOfClass:[NSData class]])
        return NO;
    *tag = value;
    return YES;
}

OSStatus RevenantSecureEnclaveKeyLookup(CFDictionaryRef query, CFTypeRef *result)
{
    NSDictionary *source = (__bridge NSDictionary *)query;
    NSData *tag = nil;
    if (!revenant_secure_enclave_is_query(source, &tag))
        return errSecItemNotFound;
    OSStatus status = errSecSuccess;
    NSString *account = revenant_secure_enclave_account((__bridge CFDataRef)tag);
    NSData *point = revenant_secure_enclave_read(revenant_secure_enclave_public_service, account, &status);
    if (!point)
        return status == errSecSuccess ? errSecItemNotFound : status;
    if (!result)
        return errSecSuccess;
    if ([source[(__bridge NSString *)kSecReturnData] boolValue] || [source[(__bridge NSString *)kSecReturnAttributes] boolValue]
        || [source[(__bridge NSString *)kSecReturnPersistentRef] boolValue])
        return errSecUnimplemented;
    BOOL wantsPublic = [source[(__bridge NSString *)kSecAttrKeyClass] isEqual:(__bridge NSString *)kSecAttrKeyClassPublic];
    SecKeyRef key = revenant_secure_enclave_create(!wantsPublic, (__bridge CFDataRef)tag, (__bridge CFDataRef)point, NULL, 0);
    if (!key)
        return errSecInternalError;
    *result = key;
    return errSecSuccess;
}

OSStatus RevenantSecureEnclaveKeyDelete(CFDictionaryRef query)
{
    NSDictionary *source = (__bridge NSDictionary *)query;
    NSData *tag = nil;
    if (!revenant_secure_enclave_is_query(source, &tag))
        return errSecItemNotFound;
    NSString *account = revenant_secure_enclave_account((__bridge CFDataRef)tag);
    OSStatus privateStatus = revenant_secure_enclave_remove(revenant_secure_enclave_private_service, account);
    OSStatus publicStatus = revenant_secure_enclave_remove(revenant_secure_enclave_public_service, account);
    if (privateStatus == errSecSuccess || publicStatus == errSecSuccess)
        return errSecSuccess;
    return errSecItemNotFound;
}
