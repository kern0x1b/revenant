#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Security/Security.h>
#import <dlfcn.h>

typedef OSStatus (*SecItemAddFunction)(CFDictionaryRef, CFTypeRef *);

static NSString *image_of(const char *symbol)
{
    Dl_info where;
    memset(&where, 0, sizeof where);
    dladdr(dlsym(RTLD_DEFAULT, symbol), &where);
    return where.dli_fname ? [[NSString stringWithUTF8String:where.dli_fname] lastPathComponent] : @"none";
}

REVENANT_CASE(backport_impl_shadowed)
{
    BOOL flip = (BOOL)negative;
    const char *names[] = {
        "SecItemAdd", "SecItemCopyMatching", "SecItemUpdate", "SecItemDelete",
        "CFRunLoopObserverCreateWithHandler", "CGColorSpaceCopyPropertyList", "vDSP_biquad", "vDSP_sve_svesq",
    };
    for (size_t index = 0; index < sizeof names / sizeof names[0]; index++)
        printf("shadow fact: %s image %s\n", names[index], [image_of(names[index]) UTF8String]);

    void *security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    SecItemAddFunction systemAdd = (SecItemAddFunction)dlsym(security, "SecItemAdd");
    CFErrorRef error = NULL;
    SecAccessControlRef control = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                  kSecAccessControlUserPresence, &error);
    printf("shadow fact: access control %s\n", control ? "made" : "not made");
    NSData *secret = [@"secret" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *add = [NSMutableDictionary dictionary];
    add[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    add[(__bridge id)kSecAttrService] = @"revenant.backport-impl.probe";
    add[(__bridge id)kSecAttrAccount] = @"access-control";
    add[(__bridge id)kSecValueData] = secret;
    if (control)
        add[(__bridge id)kSecAttrAccessControl] = (__bridge id)control;
    NSDictionary *remove = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecAttrService: @"revenant.backport-impl.probe",
                             (__bridge id)kSecAttrAccount: @"access-control"};
    SecItemDelete((__bridge CFDictionaryRef)remove);
    OSStatus systemStatus = systemAdd ? systemAdd((__bridge CFDictionaryRef)add, NULL) : -1;
    printf("shadow fact: system SecItemAdd with an access control status %d\n", (int)systemStatus);
    SecItemDelete((__bridge CFDictionaryRef)remove);
    NSMutableDictionary *plain = [add mutableCopy];
    [plain removeObjectForKey:(__bridge id)kSecAttrAccessControl];
    OSStatus plainAdd = SecItemAdd((__bridge CFDictionaryRef)plain, NULL);
    NSMutableDictionary *plainQuery = [remove mutableCopy];
    plainQuery[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef plainFound = NULL;
    OSStatus plainCopy = SecItemCopyMatching((__bridge CFDictionaryRef)plainQuery, &plainFound);
    printf("shadow fact: plain keychain item add %d copy %d\n", (int)plainAdd, (int)plainCopy);
    if (plainFound)
        CFRelease(plainFound);
    SecItemDelete((__bridge CFDictionaryRef)remove);
    OSStatus appStatus = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    printf("shadow fact: app SecItemAdd with an access control status %d\n", (int)appStatus);
    NSMutableDictionary *query = [remove mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef found = NULL;
    OSStatus copyStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);
    printf("shadow fact: app SecItemCopyMatching status %d data %s\n", (int)copyStatus,
           found && [(__bridge id)found isKindOfClass:[NSData class]] ? [[[NSString alloc] initWithData:(__bridge NSData *)found encoding:NSUTF8StringEncoding] UTF8String] : "none");
    if (found)
        CFRelease(found);
    OSStatus deleteStatus = SecItemDelete((__bridge CFDictionaryRef)remove);
    printf("shadow fact: app SecItemDelete status %d\n", (int)deleteStatus);
    if (control)
        CFRelease(control);
    revenant_expect_true(@"SecItemAdd does not refuse an item that carries a SecAccessControl as a bad parameter",
                         (appStatus != errSecParam) != flip, [NSString stringWithFormat:@"status %d", (int)appStatus]);
    if (plainAdd == errSecSuccess) {
        revenant_expect_true(@"SecItemAdd stores an item that carries a SecAccessControl",
                             (appStatus == errSecSuccess) != flip, [NSString stringWithFormat:@"status %d", (int)appStatus]);
        revenant_expect_true(@"SecItemCopyMatching returns the item that carried a SecAccessControl",
                             (copyStatus == errSecSuccess) != flip, [NSString stringWithFormat:@"status %d", (int)copyStatus]);
    } else {
        printf("shadow fact: the keychain is not usable here (plain add %d), the stored-item checks are skipped\n", (int)plainAdd);
    }

    __block int observed = 0;
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0,
                                                                       ^(CFRunLoopObserverRef source, CFRunLoopActivity activity) {
        observed++;
    });
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    CFRunLoopRemoveObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    CFRelease(observer);
    revenant_expect_true(@"a run loop observer made with a handler fires",
                         (observed > 0) != flip, [NSString stringWithFormat:@"%d calls", observed]);

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CFPropertyListRef list = CGColorSpaceCopyPropertyList(space);
    printf("shadow fact: CGColorSpaceCopyPropertyList of device RGB %s\n", list ? "returned a list" : "returned NULL");
    if (list)
        CFRelease(list);
    CGColorSpaceRelease(space);
    fflush(stdout);
}
