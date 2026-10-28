#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <TargetConditionals.h>
#import <dlfcn.h>
#import <stdlib.h>
#import <string.h>
#import "../RevenantCFRuntime.h"
#import "RevenantSecAccessControl.h"
#import "RevenantSecureEnclave.h"

extern CFTypeID SecAccessControlGetTypeID(void);
extern CFTypeID SecKeyGetTypeID(void);
extern const uint8_t *RevenantCKGroupOrder(void);
extern int RevenantCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);
extern int RevenantCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
extern int RevenantCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest, const uint8_t *der, size_t derLength);
extern int RevenantCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength, uint8_t *secret);
extern void RevenantSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description);

static NSString *const revenant_secure_enclave_private_service = @"org.revenant.secure-enclave.private";
static NSString *const revenant_secure_enclave_public_service = @"org.revenant.secure-enclave.public";

struct RevenantSecureEnclaveState {
    CFDataRef tag;
    uint8_t point[65];
    uint8_t scalar[32];
    Boolean hasScalar;
    Boolean isPrivate;
    CFOptionFlags flags;
};

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

static OSStatus revenant_secure_enclave_scalar_of(const struct RevenantSecureEnclaveState *state, uint8_t scalar[32])
{
    if (!state || !state->isPrivate)
        return errSecParam;
    if (state->hasScalar) {
        if (RevenantSecItemFlagsRequireUser(state->flags)) {
            OSStatus status = RevenantSecItemAuthenticate(true, CFSTR("Use the key."));
            if (status != errSecSuccess)
                return status;
        }
        memcpy(scalar, state->scalar, 32);
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

#if TARGET_OS_IPHONE

typedef OSStatus (*RevenantSecKeyInitMethod)(SecKeyRef key, const uint8_t *keyData, CFIndex keyDataLength, uint32_t encoding);
typedef void (*RevenantSecKeyDestroyMethod)(SecKeyRef key);
typedef OSStatus (*RevenantSecKeyRawSignMethod)(SecKeyRef key, SecPadding padding, const uint8_t *dataToSign, size_t dataToSignLength, uint8_t *signature, size_t *signatureLength);
typedef OSStatus (*RevenantSecKeyRawVerifyMethod)(SecKeyRef key, SecPadding padding, const uint8_t *signedData, size_t signedDataLength, const uint8_t *signature, size_t signatureLength);
typedef size_t (*RevenantSecKeyBlockSizeMethod)(SecKeyRef key);
typedef CFDictionaryRef (*RevenantSecKeyCopyDictionaryMethod)(SecKeyRef key);
typedef CFIndex (*RevenantSecKeyGetAlgorithmIDMethod)(SecKeyRef key);
typedef OSStatus (*RevenantSecKeyCopyPublicBytesMethod)(SecKeyRef key, CFDataRef *serialized);

typedef struct {
    uint32_t version;
    const char *name;
    uint32_t extraBytes;
    RevenantSecKeyInitMethod init;
    RevenantSecKeyDestroyMethod destroy;
    RevenantSecKeyRawSignMethod rawSign;
    RevenantSecKeyRawVerifyMethod rawVerify;
    void *encrypt;
    void *decrypt;
    void *compute;
    RevenantSecKeyBlockSizeMethod blockSize;
    RevenantSecKeyCopyDictionaryMethod copyDictionary;
    RevenantSecKeyGetAlgorithmIDMethod getAlgorithmID;
    RevenantSecKeyCopyPublicBytesMethod copyPublic;
} RevenantSecKeyDescriptor;

static const OSStatus revenant_secure_enclave_verify_failed = -67808;
static const CFIndex revenant_secure_enclave_algorithm_ecdsa = 3;
static const uint32_t revenant_secure_enclave_encoding_bytes = 7;

static struct RevenantSecureEnclaveState **revenant_secure_enclave_slot(const void *key)
{
    return (struct RevenantSecureEnclaveState **)((uint8_t *)key + sizeof(RevenantCFRuntimeBase) + sizeof(void *));
}

static struct RevenantSecureEnclaveState *revenant_secure_enclave_state(const void *key)
{
    return *revenant_secure_enclave_slot(key);
}

static OSStatus revenant_secure_enclave_init(SecKeyRef key, const uint8_t *keyData, CFIndex keyDataLength, uint32_t encoding)
{
    if (encoding != revenant_secure_enclave_encoding_bytes || !keyData || keyDataLength != sizeof(struct RevenantSecureEnclaveState))
        return errSecParam;
    struct RevenantSecureEnclaveState *state = calloc(1, sizeof *state);
    if (!state)
        return errSecInternalError;
    memcpy(state, keyData, sizeof *state);
    if (state->tag)
        CFRetain(state->tag);
    *revenant_secure_enclave_slot(key) = state;
    return errSecSuccess;
}

static void revenant_secure_enclave_destroy(SecKeyRef key)
{
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    if (!state)
        return;
    *revenant_secure_enclave_slot(key) = NULL;
    if (state->tag)
        CFRelease(state->tag);
    memset(state, 0, sizeof *state);
    free(state);
}

static OSStatus revenant_secure_enclave_raw_sign(SecKeyRef key, SecPadding padding, const uint8_t *dataToSign, size_t dataToSignLength, uint8_t *signature, size_t *signatureLength)
{
    (void)padding;
    if (!dataToSign || dataToSignLength != 32 || !signatureLength)
        return errSecParam;
    uint8_t scalar[32];
    OSStatus status = revenant_secure_enclave_scalar_of(revenant_secure_enclave_state(key), scalar);
    if (status != errSecSuccess) {
        memset(scalar, 0, sizeof scalar);
        return status;
    }
    uint8_t der[72];
    int written = RevenantCKDigestSignES256(scalar, dataToSign, der, sizeof der);
    memset(scalar, 0, sizeof scalar);
    if (written <= 0)
        return errSecInternalError;
    if (!signature || *signatureLength < (size_t)written)
        return errSecParam;
    memcpy(signature, der, (size_t)written);
    *signatureLength = (size_t)written;
    return errSecSuccess;
}

static OSStatus revenant_secure_enclave_raw_verify(SecKeyRef key, SecPadding padding, const uint8_t *signedData, size_t signedDataLength, const uint8_t *signature, size_t signatureLength)
{
    (void)padding;
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    if (!state || !signedData || signedDataLength != 32 || !signature)
        return errSecParam;
    if (RevenantCKDigestVerifyES256(state->point, sizeof state->point, signedData, signature, signatureLength) == 0)
        return revenant_secure_enclave_verify_failed;
    return errSecSuccess;
}

static size_t revenant_secure_enclave_block_size(SecKeyRef key)
{
    (void)key;
    return 32;
}

static CFDictionaryRef revenant_secure_enclave_copy_dictionary(SecKeyRef key)
{
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    if (!state)
        return NULL;
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[(__bridge NSString *)kSecAttrKeyType] = (__bridge NSString *)kSecAttrKeyTypeECSECPrimeRandom;
    attributes[(__bridge NSString *)kSecAttrKeyClass] = state->isPrivate ? (__bridge NSString *)kSecAttrKeyClassPrivate : (__bridge NSString *)kSecAttrKeyClassPublic;
    attributes[(__bridge NSString *)kSecAttrKeySizeInBits] = @256;
    attributes[(__bridge NSString *)kSecAttrTokenID] = (__bridge NSString *)kSecAttrTokenIDSecureEnclave;
    if (state->tag)
        attributes[(__bridge NSString *)kSecAttrApplicationTag] = (__bridge NSData *)state->tag;
    return (CFDictionaryRef)CFBridgingRetain(attributes);
}

static CFIndex revenant_secure_enclave_algorithm_id(SecKeyRef key)
{
    (void)key;
    return revenant_secure_enclave_algorithm_ecdsa;
}

static OSStatus revenant_secure_enclave_copy_public(SecKeyRef key, CFDataRef *serialized)
{
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    if (!state || !serialized)
        return errSecParam;
    *serialized = CFDataCreate(kCFAllocatorDefault, state->point, sizeof state->point);
    return *serialized ? errSecSuccess : errSecInternalError;
}

static const RevenantSecKeyDescriptor revenant_secure_enclave_private_descriptor = {
    2, "SecureEnclavePrivateKey", 0,
    revenant_secure_enclave_init, revenant_secure_enclave_destroy,
    revenant_secure_enclave_raw_sign, revenant_secure_enclave_raw_verify,
    NULL, NULL, NULL,
    revenant_secure_enclave_block_size,
    revenant_secure_enclave_copy_dictionary,
    revenant_secure_enclave_algorithm_id,
    revenant_secure_enclave_copy_public,
};

static const RevenantSecKeyDescriptor revenant_secure_enclave_public_descriptor = {
    2, "SecureEnclavePublicKey", 0,
    revenant_secure_enclave_init, revenant_secure_enclave_destroy,
    NULL, revenant_secure_enclave_raw_verify,
    NULL, NULL, NULL,
    revenant_secure_enclave_block_size,
    revenant_secure_enclave_copy_dictionary,
    revenant_secure_enclave_algorithm_id,
    revenant_secure_enclave_copy_public,
};

static BOOL revenant_secure_enclave_is_ours(const void *key)
{
    if (!key || CFGetTypeID((CFTypeRef)key) != SecKeyGetTypeID())
        return NO;
    const RevenantSecKeyDescriptor *keyClass = *(const RevenantSecKeyDescriptor *const *)((const uint8_t *)key + sizeof(RevenantCFRuntimeBase));
    return keyClass == &revenant_secure_enclave_private_descriptor || keyClass == &revenant_secure_enclave_public_descriptor;
}

static SecKeyRef revenant_secure_enclave_make(const struct RevenantSecureEnclaveState *init)
{
    static SecKeyRef (*create)(CFAllocatorRef allocator, const RevenantSecKeyDescriptor *keyClass, const uint8_t *keyData, CFIndex keyDataLength, uint32_t encoding);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        create = (SecKeyRef (*)(CFAllocatorRef, const RevenantSecKeyDescriptor *, const uint8_t *, CFIndex, uint32_t))dlsym(RTLD_DEFAULT, "SecKeyCreate");
    });
    if (!create)
        return NULL;
    const RevenantSecKeyDescriptor *keyClass = init->isPrivate ? &revenant_secure_enclave_private_descriptor : &revenant_secure_enclave_public_descriptor;
    return create(kCFAllocatorDefault, keyClass, (const uint8_t *)init, sizeof *init, revenant_secure_enclave_encoding_bytes);
}

#else

static struct RevenantSecureEnclaveState *revenant_secure_enclave_state(const void *key)
{
    return (struct RevenantSecureEnclaveState *)((uint8_t *)key + sizeof(RevenantCFRuntimeBase));
}

static void revenant_secure_enclave_finalize(CFTypeRef cf)
{
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(cf);
    if (state->tag)
        CFRelease(state->tag);
    memset(state, 0, sizeof *state);
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

static BOOL revenant_secure_enclave_is_ours(const void *key)
{
    return key != NULL && CFGetTypeID((CFTypeRef)key) == revenant_secure_enclave_type();
}

static SecKeyRef revenant_secure_enclave_make(const struct RevenantSecureEnclaveState *init)
{
    CFTypeRef object = _CFRuntimeCreateInstance(kCFAllocatorDefault, revenant_secure_enclave_type(),
                                                sizeof(struct RevenantSecureEnclaveState), NULL);
    if (!object)
        return NULL;
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(object);
    memcpy(state, init, sizeof *state);
    if (state->tag)
        CFRetain(state->tag);
    return (SecKeyRef)object;
}

#endif

bool RevenantSecureEnclaveKeyIs(SecKeyRef key)
{
    return revenant_secure_enclave_is_ours(key);
}

bool RevenantSecureEnclaveKeyIsPrivate(SecKeyRef key)
{
    return revenant_secure_enclave_is_ours(key) && revenant_secure_enclave_state(key)->isPrivate;
}

OSStatus RevenantSecureEnclaveKeyPoint(SecKeyRef key, uint8_t point[65])
{
    if (!revenant_secure_enclave_is_ours(key))
        return errSecParam;
    memcpy(point, revenant_secure_enclave_state(key)->point, 65);
    return errSecSuccess;
}

OSStatus RevenantSecureEnclaveKeyScalar(SecKeyRef key, uint8_t scalar[32])
{
    if (!RevenantSecureEnclaveKeyIsPrivate(key))
        return errSecParam;
    return revenant_secure_enclave_scalar_of(revenant_secure_enclave_state(key), scalar);
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
    struct RevenantSecureEnclaveState init;
    memset(&init, 0, sizeof init);
    memcpy(init.point, point, sizeof point);
    init.isPrivate = YES;
    init.flags = flags;
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
        NSData *pointData = [NSData dataWithBytes:point length:sizeof point];
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
        init.tag = (__bridge CFDataRef)tag;
    } else {
        memcpy(init.scalar, scalar, sizeof scalar);
        init.hasScalar = YES;
        memset(scalar, 0, sizeof scalar);
    }
    SecKeyRef key = revenant_secure_enclave_make(&init);
    memset(init.scalar, 0, sizeof init.scalar);
    if (!key)
        RevenantSecKeyFail(error, errSecInternalError, @"the release could not make the emulated key object");
    return key;
}

SecKeyRef RevenantSecureEnclaveKeyCopyPublic(SecKeyRef key)
{
    if (!revenant_secure_enclave_is_ours(key))
        return NULL;
    struct RevenantSecureEnclaveState *state = revenant_secure_enclave_state(key);
    struct RevenantSecureEnclaveState init;
    memset(&init, 0, sizeof init);
    init.tag = state->tag;
    memcpy(init.point, state->point, sizeof init.point);
    return revenant_secure_enclave_make(&init);
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
    if (point.length != 65)
        return errSecInternalError;
    BOOL wantsPublic = [source[(__bridge NSString *)kSecAttrKeyClass] isEqual:(__bridge NSString *)kSecAttrKeyClassPublic];
    struct RevenantSecureEnclaveState init;
    memset(&init, 0, sizeof init);
    init.tag = (__bridge CFDataRef)tag;
    memcpy(init.point, point.bytes, sizeof init.point);
    init.isPrivate = !wantsPublic;
    SecKeyRef key = revenant_secure_enclave_make(&init);
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
