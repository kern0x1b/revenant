#import "JSInternal.h"

/*
 * JSObjectMakeDeferredPromise (JSObjectRef.cpp:279) is this same promise: one made in `context`, with
 * the two functions that settle it handed back for the caller to call later. The 2012 engine has no
 * promise of its own - JSC::Promise is 0 among the JSC:: symbols the 6.1.3 cache carries - so this is
 * the port's own ES5 promise, the one +[JSValue valueWithNewPromiseInContext:fromExecutor:] builds and
 * the one DeferredPromise above makes: nothing here is built twice. The difference from a release
 * with a native promise is the one that row already records - its reactions run from the job queue in
 * JSInternal.m when the outermost call into script returns, and on the next run loop turn for a
 * caller no call is inside, where a native promise drains the microtask queue at the end of the call
 * that queued the job. NULL and an exception in *exception when the promise could not be made, which
 * is what the function's own contract says.
 */
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

