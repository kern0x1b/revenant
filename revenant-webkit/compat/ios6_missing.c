extern int fprintf(void *stream, const char *format, ...);
extern void *__stderrp;

static void report(const char *name)
{
    static const char *seen[512];
    static unsigned count;
    for (unsigned i = 0; i < count; i++)
        if (seen[i] == name)
            return;
    if (count < 512)
        seen[count++] = name;
    fprintf(__stderrp, "[ios6] unavailable: %s\n", name);
}

long CCCryptorGCMOneshotDecrypt() { report("CCCryptorGCMOneshotDecrypt"); return -1; }
long CCDeriveKey() { report("CCDeriveKey"); return -1; }
long CCKDFParametersCreateHkdf() { report("CCKDFParametersCreateHkdf"); return -1; }
long CCKDFParametersDestroy() { report("CCKDFParametersDestroy"); return 0; }
long CCRSACryptorGetPublicKeyFromPrivateKey() { report("CCRSACryptorGetPublicKeyFromPrivateKey"); return 0; }
long CCRSAGetCRTComponents() { report("CCRSAGetCRTComponents"); return -1; }
long CCRSAGetCRTComponentsSizes() { report("CCRSAGetCRTComponentsSizes"); return -1; }
long CGContextDrawPDFPageWithAnnotations() { report("CGContextDrawPDFPageWithAnnotations"); return 0; }
long CGImageApplyHDRGainMap() { report("CGImageApplyHDRGainMap"); return 0; }
long CGImageCreateFromIOSurface() { report("CGImageCreateFromIOSurface"); return 0; }
long CGImageCreatePixelBufferAttributesForHDRTarget() { report("CGImageCreatePixelBufferAttributesForHDRTarget"); return 0; }
long CGImageGetHDRGainMapHeadroom() { report("CGImageGetHDRGainMapHeadroom"); return 0; }
long CGImageMetadataCreateFromXMPData() { report("CGImageMetadataCreateFromXMPData"); return 0; }
long CGImageMetadataCreateXMPData() { report("CGImageMetadataCreateXMPData"); return 0; }
long CGImageSourceSetAllowableTypes() { report("CGImageSourceSetAllowableTypes"); return 0; }
long CGStyleCreateColorMatrix() { report("CGStyleCreateColorMatrix"); return 0; }
long CGStyleCreateGaussianBlur() { report("CGStyleCreateGaussianBlur"); return 0; }
long FPFontCopyPostScriptName() { report("FPFontCopyPostScriptName"); return 0; }
long FPFontCopySFNTData() { report("FPFontCopySFNTData"); return 0; }
long FPFontCreateFontsFromData() { report("FPFontCreateFontsFromData"); return 0; }
long FPFontCreateMemorySafeFontsFromData() { report("FPFontCreateMemorySafeFontsFromData"); return 0; }
long SecCertificateGetSignatureHashAlgorithm() { report("SecCertificateGetSignatureHashAlgorithm"); return 0; }
long SecTrustDeserialize() { report("SecTrustDeserialize"); return 0; }
long SecTrustSerialize() { report("SecTrustSerialize"); return 0; }
long SecTrustSetClientAuditToken() { report("SecTrustSetClientAuditToken"); return 0; }
long UTTypeCopyAllTagsWithClass() { report("UTTypeCopyAllTagsWithClass"); return 0; }
long UTTypeIsDeclared() { report("UTTypeIsDeclared"); return 0; }
long UTTypeIsDynamic() { report("UTTypeIsDynamic"); return 0; }
long _AXSEnhanceTextLegibilityEnabled() { report("_AXSEnhanceTextLegibilityEnabled"); return 0; }
long _CFCachedURLResponseGetMemMappedData() { report("_CFCachedURLResponseGetMemMappedData"); return 0; }
long _CFCachedURLResponseSetBecameFileBackedCallBackBlock() { report("_CFCachedURLResponseSetBecameFileBackedCallBackBlock"); return 0; }
long _CFRunLoopSetPerCalloutAutoreleasepoolEnabled() { report("_CFRunLoopSetPerCalloutAutoreleasepoolEnabled"); return 0; }
long _CFURLStorageSessionDisableCache() { report("_CFURLStorageSessionDisableCache"); return 0; }
long _os_feature_enabled_impl() { report("_os_feature_enabled_impl"); return 0; }
long _os_log_create() { report("_os_log_create"); return 0; }
long _os_log_default() { report("_os_log_default"); return 0; }
long _os_log_internal() { report("_os_log_internal"); return 0; }
long abort_with_reason() { report("abort_with_reason"); return 0; }
long cache_simulate_memory_warning_event() { report("cache_simulate_memory_warning_event"); return 0; }
long compression_stream_destroy() { report("compression_stream_destroy"); return -1; }
long compression_stream_process() { report("compression_stream_process"); return -1; }
long dispatch_block_create_with_qos_class() { report("dispatch_block_create_with_qos_class"); return 0; }
long dispatch_queue_attr_make_with_qos_class() { report("dispatch_queue_attr_make_with_qos_class"); return 0; }
long dyld_shared_cache_file_path() { report("dyld_shared_cache_file_path"); return 0; }
long mach_memory_entry_ownership() { report("mach_memory_entry_ownership"); return 0; }
long nw_array_get_count() { report("nw_array_get_count"); return 0; }
long nw_array_get_object_at_index() { report("nw_array_get_object_at_index"); return 0; }
long nw_context_create() { report("nw_context_create"); return 0; }
long nw_context_set_privacy_level() { report("nw_context_set_privacy_level"); return 0; }
long nw_endpoint_create_host() { report("nw_endpoint_create_host"); return 0; }
long nw_endpoint_get_address() { report("nw_endpoint_get_address"); return 0; }
long nw_endpoint_get_known_tracker_name() { report("nw_endpoint_get_known_tracker_name"); return 0; }
long nw_parameters_create() { report("nw_parameters_create"); return 0; }
long nw_parameters_set_context() { report("nw_parameters_set_context"); return 0; }
long nw_parameters_set_source_application() { report("nw_parameters_set_source_application"); return 0; }
long nw_path_copy_effective_remote_endpoint() { report("nw_path_copy_effective_remote_endpoint"); return 0; }
long nw_path_create_evaluator_for_endpoint() { report("nw_path_create_evaluator_for_endpoint"); return 0; }
long nw_path_evaluator_copy_path() { report("nw_path_evaluator_copy_path"); return 0; }
long nw_resolver_cancel() { report("nw_resolver_cancel"); return 0; }
long nw_resolver_create_with_path() { report("nw_resolver_create_with_path"); return 0; }
long nw_resolver_set_update_handler() { report("nw_resolver_set_update_handler"); return 0; }
long object_isClass() { report("object_isClass"); return 0; }
long os_fault_with_payload() { report("os_fault_with_payload"); return 0; }
long os_log_with_args() { report("os_log_with_args"); return 0; }
long pthread_attr_set_qos_class_np() { report("pthread_attr_set_qos_class_np"); return 0; }
long pthread_get_qos_class_np() { report("pthread_get_qos_class_np"); return 0; }
long pthread_set_qos_class_self_np() { report("pthread_set_qos_class_self_np"); return 0; }
long sqlite3_errstr() { report("sqlite3_errstr"); return 0; }
void vDSP_vaddi(const int *a, long strideA, const int *b, long strideB, int *result, long strideResult, unsigned long count)
{
    for (unsigned long i = 0; i < count; ++i)
        result[i * (unsigned long)strideResult] = a[i * (unsigned long)strideA] + b[i * (unsigned long)strideB];
}
long vImageConvert_AnyToAny() { report("vImageConvert_AnyToAny"); return -21773; }
void *vImageConverter_CreateWithCGImageFormat(void *srcFormat, void *destFormat, void *backgroundColor, unsigned flags, long *error)
{
    (void)srcFormat; (void)destFormat; (void)backgroundColor; (void)flags;
    report("vImageConverter_CreateWithCGImageFormat");
    if (error)
        *error = -21771;
    return 0;
}
long vImageCopyBuffer() { report("vImageCopyBuffer"); return -21773; }

typedef const void *CFTypeRef;
typedef const void *CFStringRef;
typedef const void *CFDictionaryRef;
typedef const void *CFNumberRef;
typedef const void *CFBooleanRef;
typedef unsigned long CFTypeID;
typedef long CFIndex;

extern void CFRelease(CFTypeRef object);
extern CFTypeID CFGetTypeID(CFTypeRef object);
extern CFTypeID CFNumberGetTypeID(void);
extern CFTypeID CFBooleanGetTypeID(void);
extern unsigned char CFBooleanGetValue(CFBooleanRef object);
extern unsigned char CFNumberGetValue(CFNumberRef number, CFIndex type, void *valuePtr);

extern void *dlopen(const char *path, int mode);
extern void *dlsym(void *handle, const char *symbol);
#define RTLD_LAZY 1
#define RTLD_DEFAULT ((void *)-2)

static CFTypeRef MGCopyAnswer(CFStringRef question, CFDictionaryRef options)
{
    static CFTypeRef (*copyAnswer)(CFStringRef, CFDictionaryRef);
    static int resolved;
    if (!resolved) {
        resolved = 1;
        copyAnswer = (CFTypeRef (*)(CFStringRef, CFDictionaryRef))dlsym(RTLD_DEFAULT, "MGCopyAnswer");
        if (!copyAnswer) {
            void *handle = dlopen("/System/Library/PrivateFrameworks/MobileGestalt.framework/MobileGestalt", RTLD_LAZY);
            if (handle)
                copyAnswer = (CFTypeRef (*)(CFStringRef, CFDictionaryRef))dlsym(handle, "MGCopyAnswer");
        }
        report(copyAnswer ? "MGCopyAnswer resolved" : "MGCopyAnswer UNRESOLVED");
    }
    if (!copyAnswer)
        return 0;
    return copyAnswer(question, options);
}

int MGGetBoolAnswer(CFStringRef question)
{
    CFTypeRef answer = MGCopyAnswer(question, 0);
    if (!answer)
        return 0;
    int result = CFGetTypeID(answer) == CFBooleanGetTypeID() && CFBooleanGetValue(answer);
    CFRelease(answer);
    return result;
}

int MGGetSInt32Answer(CFStringRef question, int defaultValue)
{
    CFTypeRef answer = MGCopyAnswer(question, 0);
    if (!answer)
        return defaultValue;
    int result = defaultValue;
    if (CFGetTypeID(answer) == CFNumberGetTypeID())
        CFNumberGetValue(answer, 3, &result);
    CFRelease(answer);
    return result;
}

float MGGetFloat32Answer(CFStringRef question, float defaultValue)
{
    CFTypeRef answer = MGCopyAnswer(question, 0);
    if (!answer)
        return defaultValue;
    float result = defaultValue;
    if (CFGetTypeID(answer) == CFNumberGetTypeID())
        CFNumberGetValue(answer, 5, &result);
    CFRelease(answer);
    return result;
}

const void *CFAutorelease(const void *object)
{
    extern void *objc_msgSend(void *, void *, ...);
    extern void *sel_registerName(const char *);
    if (object)
        objc_msgSend((void *)object, sel_registerName("autorelease"));
    return object;
}

void *os_retain(void *object) { return object; }
void os_release(void *object) { (void)object; }

int timingsafe_bcmp(const void *a, const void *b, unsigned long length)
{
    const unsigned char *left = a, *right = b;
    unsigned char difference = 0;
    for (unsigned long i = 0; i < length; i++)
        difference |= left[i] ^ right[i];
    return difference != 0;
}

extern int mkstemps(char *templateName, int suffixLength);
extern int fcntl(int fd, int cmd, ...);
int mkostemps(char *templateName, int suffixLength, int flags)
{
    int fd = mkstemps(templateName, suffixLength);
    if (fd >= 0 && flags)
        fcntl(fd, 2 /* F_SETFD */, 1 /* FD_CLOEXEC */);
    return fd;
}

int _dyld_get_shared_cache_uuid(unsigned char uuid[16])
{
    for (int i = 0; i < 16; i++)
        uuid[i] = 0;
    return 0;
}
