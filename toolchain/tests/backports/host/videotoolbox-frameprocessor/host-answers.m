#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <VideoToolbox/VideoToolbox.h>

extern NSErrorDomain const VTFrameProcessorErrorDomain;

static BOOL implements_init(Class cls)
{
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index++) {
        const char *name = sel_getName(method_getName(methods[index]));
        if (name[0] == 'i' && name[1] == 'n' && name[2] == 'i' && name[3] == 't' && name[4] == 0)
            found = YES;
    }
    free(methods);
    return found;
}

static BOOL send_id_catching(id target, SEL selector, id *answer)
{
    @try {
        *answer = ((id (*)(id, SEL))objc_msgSend)(target, selector);
        return NO;
    } @catch (NSException *exception) {
        *answer = nil;
        return YES;
    }
}

static id send_id(id target, SEL selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static BOOL send_bool(id target, SEL selector)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(target, selector);
}

static const char *const CLASSES[] = {
    "VTFrameProcessor", "VTFrameProcessorFrame", "VTFrameProcessorOpticalFlow",
    "VTFrameRateConversionConfiguration", "VTFrameRateConversionParameters",
    "VTLowLatencyFrameInterpolationConfiguration", "VTLowLatencyFrameInterpolationParameters",
    "VTLowLatencySuperResolutionScalerConfiguration", "VTLowLatencySuperResolutionScalerParameters",
    "VTMotionBlurConfiguration", "VTMotionBlurParameters",
    "VTOpticalFlowConfiguration", "VTOpticalFlowParameters",
    "VTSuperResolutionScalerConfiguration", "VTSuperResolutionScalerParameters",
    "VTTemporalNoiseFilterConfiguration", "VTTemporalNoiseFilterParameters",
};

static const struct { const char *name; NSInteger code; } CODES[] = {
    {"VTFrameProcessorUnknownError", -19730}, {"VTFrameProcessorUnsupportedResolution", -19731},
    {"VTFrameProcessorSessionNotStarted", -19732}, {"VTFrameProcessorSessionAlreadyActive", -19733},
    {"VTFrameProcessorFatalError", -19734}, {"VTFrameProcessorSessionLevelError", -19735},
    {"VTFrameProcessorInitializationFailed", -19736}, {"VTFrameProcessorUnsupportedInput", -19737},
    {"VTFrameProcessorMemoryAllocationFailure", -19738}, {"VTFrameProcessorRevisionNotSupported", -19739},
    {"VTFrameProcessorProcessingError", -19740}, {"VTFrameProcessorInvalidParameterError", -19741},
    {"VTFrameProcessorInvalidFrameTiming", -19742}, {"VTFrameProcessorAssetDownloadFailed", -19743},
};

int main(void)
{
    void *library = dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", RTLD_LAZY);
    printf("CONTROL\tframework=%s\tdomain-symbol=%s\n",
           library ? "opened" : "DID NOT OPEN",
           library && dlsym(library, "VTFrameProcessorErrorDomain") ? "present" : "ABSENT");

    printf("DOMAIN\t%s\t%s\n", [VTFrameProcessorErrorDomain UTF8String],
           class_getName([VTFrameProcessorErrorDomain class]));

    NSError *built = [NSError errorWithDomain:VTFrameProcessorErrorDomain
                                         code:VTFrameProcessorSessionNotStarted
                                     userInfo:@{NSLocalizedDescriptionKey: @"the host's own"}];
    printf("BUILDERROR\t%s\t%ld\n", [built.domain UTF8String], (long)built.code);

    for (unsigned index = 0; index < sizeof(CODES) / sizeof(CODES[0]); index++)
        printf("ERRORCODE\t%s\t%ld\n", CODES[index].name, (long)CODES[index].code);

    for (unsigned index = 0; index < sizeof(CLASSES) / sizeof(CLASSES[0]); index++) {
        NSString *name = [NSString stringWithUTF8String:CLASSES[index]];
        Class cls = NSClassFromString(name);
        if (!cls) { printf("ABSENT\t%s\n", CLASSES[index]); continue; }
        id made = nil, again = nil;
        BOOL newRaises = send_id_catching(cls, @selector(new), &made);
        BOOL initRaises = made ? send_id_catching(made, @selector(init), &again) : NO;
        if (newRaises || initRaises)
            printf("RAISES\t%s\t%s\n", CLASSES[index],
                   newRaises ? "+new raised" : "-init raised");
        const char *width = "NA";
        if (made && [made respondsToSelector:@selector(frameWidth)])
            width = [[NSString stringWithFormat:@"%lld", (long long)send_id(made, @selector(frameWidth))] UTF8String];
        printf("UNAVAILABLE\t%s\town-init=%d\t+new-answers=%d\t-init-answers=%d\t%s\n",
               CLASSES[index], implements_init(cls), made != nil, again != nil, width);
        if ([cls respondsToSelector:@selector(isSupported)])
            printf("SUPPORTED\t%s\t%d\n", CLASSES[index], send_bool(cls, @selector(isSupported)));
    }
    return 0;
}
