#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <string.h>

static const OSStatus revenant_shared_web_missing_entitlement = -34018;
static const uint32_t revenant_signature_superblob_magic = 0xfade0cc0;
static const uint32_t revenant_signature_entitlements_magic = 0xfade7171;
static const uint32_t revenant_signature_entitlements_slot = 5;
static const uint32_t revenant_signature_superblob_header = 12;
static const uint32_t revenant_signature_index_size = 8;
static const uint32_t revenant_signature_blob_header = 8;
static const NSUInteger revenant_shared_web_default_port = 443;
static const NSTimeInterval revenant_association_timeout = 15;
static NSString *const revenant_shared_password_key = @"spwd";
static NSString *const revenant_shared_web_access_group = @"com.apple.cfnetwork";

struct revenant_signature_layout {
    uint64_t text;
    uint64_t linkedit;
    uint64_t linkeditOffset;
};

static void revenant_reply(void (^block)(void))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

static BOOL revenant_fqdn_is_usable(CFStringRef fqdn)
{
    return fqdn && CFGetTypeID(fqdn) == CFStringGetTypeID() && CFStringGetLength(fqdn) > 0;
}

static CFErrorRef revenant_shared_web_credential_error(OSStatus status)
{
    return (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
}

static void revenant_deliver(void (^handler)(CFArrayRef, CFErrorRef), CFArrayRef credentials, OSStatus status)
{
    CFErrorRef error = status == errSecSuccess ? NULL : revenant_shared_web_credential_error(status);
    handler(credentials, error);
    if (error)
        CFRelease(error);
}

static uint32_t revenant_read_big_endian(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | bytes[3];
}

static NSDictionary *revenant_entitlements_from_signature(const uint8_t *blob, uint32_t size)
{
    const uint8_t *end = blob + size;
    if (size < revenant_signature_superblob_header || revenant_read_big_endian(blob) != revenant_signature_superblob_magic)
        return nil;
    uint32_t count = revenant_read_big_endian(blob + 8);
    for (uint32_t index = 0; index < count; index++) {
        const uint8_t *entry = blob + revenant_signature_superblob_header + index * revenant_signature_index_size;
        if (entry + revenant_signature_index_size > end)
            return nil;
        if (revenant_read_big_endian(entry) != revenant_signature_entitlements_slot)
            continue;
        const uint8_t *data = blob + revenant_read_big_endian(entry + 4);
        if (data + revenant_signature_blob_header > end || revenant_read_big_endian(data) != revenant_signature_entitlements_magic)
            return nil;
        uint32_t length = revenant_read_big_endian(data + 4);
        if (length < revenant_signature_blob_header || length > end - data)
            return nil;
        NSData *xml = [NSData dataWithBytes:data + revenant_signature_blob_header length:length - revenant_signature_blob_header];
        id plist = [NSPropertyListSerialization propertyListWithData:xml options:NSPropertyListImmutable format:NULL error:NULL];
        return [plist isKindOfClass:[NSDictionary class]] ? plist : nil;
    }
    return nil;
}

static void revenant_note_segment(const char *name, uint64_t address, uint64_t fileoff, struct revenant_signature_layout *layout)
{
    if (strncmp(name, "__TEXT", 16) == 0)
        layout->text = address;
    if (strncmp(name, "__LINKEDIT", 16) == 0) {
        layout->linkedit = address;
        layout->linkeditOffset = fileoff;
    }
}

static NSDictionary *revenant_entitlements(void)
{
    const struct mach_header *header = _dyld_get_image_header(0);
    if (!header || (header->magic != MH_MAGIC && header->magic != MH_MAGIC_64))
        return nil;
    const uint8_t *cursor = (const uint8_t *)header + (header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    struct revenant_signature_layout layout = {0, 0, 0};
    const struct linkedit_data_command *signature = NULL;
    for (uint32_t index = 0; index < header->ncmds; index++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmd == LC_SEGMENT) {
            const struct segment_command *segment = (const struct segment_command *)command;
            revenant_note_segment(segment->segname, segment->vmaddr, segment->fileoff, &layout);
        } else if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            revenant_note_segment(segment->segname, segment->vmaddr, segment->fileoff, &layout);
        } else if (command->cmd == LC_CODE_SIGNATURE) {
            signature = (const struct linkedit_data_command *)command;
        }
        cursor += command->cmdsize;
    }
    if (!signature || !layout.text || !layout.linkedit || signature->dataoff < layout.linkeditOffset)
        return nil;
    uintptr_t slide = (uintptr_t)header - (uintptr_t)layout.text;
    uintptr_t blob = (uintptr_t)(layout.linkedit + (signature->dataoff - layout.linkeditOffset)) + slide;
    return revenant_entitlements_from_signature((const uint8_t *)blob, signature->datasize);
}

static NSString *revenant_application_identifier(NSDictionary *entitlements)
{
    id identifier = entitlements[@"application-identifier"];
    return [identifier isKindOfClass:[NSString class]] ? identifier : nil;
}

static BOOL revenant_domain_is_associated(NSDictionary *entitlements, NSString *fqdn)
{
    id domains = entitlements[@"com.apple.developer.associated-domains"];
    return [domains isKindOfClass:[NSArray class]] && [domains containsObject:[@"webcredentials:" stringByAppendingString:fqdn]];
}

static BOOL revenant_app_is_listed(NSString *fqdn, NSString *identifier)
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/apple-app-site-association", fqdn]];
    if (!url)
        return NO;
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:revenant_association_timeout];
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    NSData *body = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (!body || error || response.statusCode != 200)
        return NO;
    id document = [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL];
    NSDictionary *webcredentials = [document isKindOfClass:[NSDictionary class]] ? [document objectForKey:@"webcredentials"] : nil;
    NSArray *apps = [webcredentials isKindOfClass:[NSDictionary class]] ? [webcredentials objectForKey:@"apps"] : nil;
    return [apps isKindOfClass:[NSArray class]] && [apps containsObject:identifier];
}

static CFArrayRef revenant_copy_shared_credentials(NSString *fqdn, NSString *account, OSStatus *status)
{
    NSMutableDictionary *query = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecAttrServer: fqdn,
        (__bridge id)kSecAttrAccessGroup: revenant_shared_web_access_group,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecReturnData: @YES,
    } mutableCopy];
    if (account)
        query[(__bridge id)kSecAttrAccount] = account;
    CFTypeRef found = NULL;
    *status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);
    if (*status != errSecSuccess && *status != errSecItemNotFound) {
        if (found)
            CFRelease(found);
        return NULL;
    }
    NSArray *items = (__bridge_transfer NSArray *)found;
    NSMutableArray *credentials = [NSMutableArray array];
    for (NSDictionary *item in items) {
        NSString *password = [[NSString alloc] initWithData:item[(__bridge id)kSecValueData] encoding:NSUTF8StringEncoding];
        if (!password)
            continue;
        NSMutableDictionary *credential = [NSMutableDictionary dictionary];
        credential[(__bridge id)kSecAttrServer] = item[(__bridge id)kSecAttrServer] ?: fqdn;
        credential[(__bridge id)kSecAttrAccount] = item[(__bridge id)kSecAttrAccount] ?: @"";
        credential[revenant_shared_password_key] = password;
        NSNumber *port = item[(__bridge id)kSecAttrPort];
        if (port && port.unsignedIntegerValue != revenant_shared_web_default_port)
            credential[(__bridge id)kSecAttrPort] = port;
        [credentials addObject:credential];
    }
    if (credentials.count == 0)
        *status = errSecItemNotFound;
    return (CFArrayRef)CFBridgingRetain(credentials);
}

void SecAddSharedWebCredential(CFStringRef fqdn, CFStringRef username, CFStringRef password, void (^completionHandler)(CFErrorRef error))
{
    void (^handler)(CFErrorRef) = [completionHandler copy];
    if (!handler)
        return;
    OSStatus status = revenant_fqdn_is_usable(fqdn) ? errSecUnimplemented : errSecParam;
    revenant_reply(^{
        CFErrorRef error = revenant_shared_web_credential_error(status);
        handler(error);
        CFRelease(error);
    });
}

void SecRequestSharedWebCredential(CFStringRef fqdn, CFStringRef account, void (^completionHandler)(CFArrayRef credentials, CFErrorRef error))
{
    void (^handler)(CFArrayRef, CFErrorRef) = [completionHandler copy];
    if (!handler)
        return;
    if (!revenant_fqdn_is_usable(fqdn)) {
        revenant_reply(^{
            revenant_deliver(handler, NULL, errSecParam);
        });
        return;
    }
    NSString *host = (__bridge NSString *)fqdn;
    NSString *user = (__bridge NSString *)account;
    revenant_reply(^{
        NSDictionary *entitlements = revenant_entitlements();
        if (!revenant_domain_is_associated(entitlements, host)) {
            revenant_deliver(handler, NULL, revenant_shared_web_missing_entitlement);
            return;
        }
        NSString *identifier = revenant_application_identifier(entitlements);
        if (!identifier || !revenant_app_is_listed(host, identifier)) {
            revenant_deliver(handler, NULL, errSecAuthFailed);
            return;
        }
        OSStatus status = errSecSuccess;
        CFArrayRef credentials = revenant_copy_shared_credentials(host, user, &status);
        revenant_deliver(handler, credentials, status);
        if (credentials)
            CFRelease(credentials);
    });
}

CFStringRef SecCreateSharedWebCredentialPassword(void)
{
    static const char digits[] = "23456789";
    static const char upper[] = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    static const char lower[] = "abcdefghkmnopqrstuvwxyz";
    char all[sizeof(digits) + sizeof(upper) + sizeof(lower)];
    size_t total = 0;
    for (const char *set = digits; *set; set++)
        all[total++] = *set;
    for (const char *set = upper; *set; set++)
        all[total++] = *set;
    for (const char *set = lower; *set; set++)
        all[total++] = *set;
    char password[16];
    for (;;) {
        BOOL hasDigit = NO, hasUpper = NO, hasLower = NO;
        size_t at = 0;
        for (int i = 0; i < 12; i++) {
            if (i && i % 3 == 0)
                password[at++] = '-';
            char c = all[arc4random_uniform((uint32_t)total)];
            hasDigit = hasDigit || (c >= '2' && c <= '9');
            hasUpper = hasUpper || (c >= 'A' && c <= 'Z');
            hasLower = hasLower || (c >= 'a' && c <= 'z');
            password[at++] = c;
        }
        password[at] = 0;
        if (hasDigit && hasUpper && hasLower)
            break;
    }
    return CFStringCreateWithCString(kCFAllocatorDefault, password, kCFStringEncodingASCII);
}
