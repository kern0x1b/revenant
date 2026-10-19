#import "JSInternal.h"

JSObjectRef JSObjectMakeDeferredPromise(JSContextRef context, JSObjectRef *resolve, JSObjectRef *reject, JSValueRef *exception)
{
    if (resolve)
        *resolve = NULL;
    if (reject)
        *reject = NULL;
    if (exception)
        *exception = NULL;
    JSValueRef thrown = NULL;
    if (!context)
        return NULL;
    JSObjectRef promise = charon_js_deferred_promise([JSContext charon_wrapperForGlobalContext:context create:YES], resolve, reject, &thrown);
    if (!promise) {
        if (exception)
            *exception = thrown;
        return NULL;
    }
    if (exception)
        *exception = NULL;
    charon_js_leave();
    return promise;
}
