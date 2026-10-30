#include <JavaScriptCore/JavaScriptCore.h>

// The JSC C API a React Native host calls. Taking their addresses makes the link resolve each one.
static void *const names[] __attribute__((used)) = {
    (void *)JSValueMakeSymbol, (void *)JSValueIsSymbol, (void *)JSObjectGetPropertyForKey,
    (void *)JSObjectSetPropertyForKey, (void *)JSObjectGetArrayBufferByteLength,
    (void *)JSObjectGetArrayBufferBytesPtr, (void *)JSValueGetTypedArrayType,
    (void *)JSGlobalContextSetInspectable,
};

int main(void)
{
    JSGlobalContextRef context = JSGlobalContextCreate(NULL);
    JSStringRef source = JSStringCreateWithUTF8CString("1 + 1");
    JSValueRef value = JSEvaluateScript(context, source, NULL, NULL, 1, NULL);
    double sum = JSValueToNumber(context, value, NULL);
    JSStringRelease(source);
    JSGlobalContextRelease(context);
    return sum == 2 && names[0] ? 0 : 1;
}
