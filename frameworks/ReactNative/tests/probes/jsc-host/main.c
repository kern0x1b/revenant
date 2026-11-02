#include <JavaScriptCore/JavaScript.h>
#include <stdio.h>

int main(void) {
    JSGlobalContextRef context = JSGlobalContextCreate(NULL);
    JSStringRef source = JSStringCreateWithUTF8CString("1 + 2 * 3");
    JSValueRef exception = NULL;
    JSValueRef result = JSEvaluateScript(context, source, NULL, NULL, 1, &exception);
    JSStringRef text = JSValueToStringCopy(context, result, &exception);
    char buffer[64];
    JSStringGetUTF8CString(text, buffer, sizeof buffer);
    printf("rn-spike: JSEvaluateScript(\"1 + 2 * 3\") = %s\n", buffer);
    JSStringRelease(text);
    JSStringRelease(source);
    JSGlobalContextRelease(context);
    return 0;
}
