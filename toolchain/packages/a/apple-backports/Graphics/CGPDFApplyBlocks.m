#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

void CGPDFArrayApplyBlock(CGPDFArrayRef array, bool (^block)(size_t index, CGPDFObjectRef value, void *info), void *info)
{
    if (!array || !block)
        return;
    size_t count = CGPDFArrayGetCount(array);
    for (size_t index = 0; index < count; index++) {
        CGPDFObjectRef value = NULL;
        if (CGPDFArrayGetObject(array, index, &value) && !block(index, value, info))
            return;
    }
}

typedef struct {
    bool (^block)(const char *key, CGPDFObjectRef value, void *info);
    void *info;
    bool stopped;
} charon_dictionary_context;

static void charon_dictionary_apply(const char *key, CGPDFObjectRef value, void *info)
{
    charon_dictionary_context *context = info;
    if (!context->stopped && !context->block(key, value, context->info))
        context->stopped = true;
}

void CGPDFDictionaryApplyBlock(CGPDFDictionaryRef dict, bool (^block)(const char *key, CGPDFObjectRef value, void *info), void *info)
{
    if (!dict || !block)
        return;
    charon_dictionary_context context = {block, info, false};
    CGPDFDictionaryApplyFunction(dict, charon_dictionary_apply, &context);
}
