#import "JSInternal.h"

/*
 * The port's own ES5 promise, in a file of its own, and why it is a file of its own.
 *
 * It was JSValue.m's, and the 6.1.3 gate refused JSValue.m with "JSValue.m defines JSValue from iOS
 * 7.0 and JSObjectMakeDeferredPromise from iOS 16.0; an object carries API that arrived in one
 * release". The split put the JSValue class in JSValue.m and JSObjectMakeDeferredPromise in
 * JSObjectMakeDeferredPromise16.m, and the promise in between is this file.
 *
 * It is here and not promoted into JSInternal.h as a `static inline`, and the reason is that two of
 * these helpers would then be WRONG rather than merely copied. PromiseClass and CaptureClass hold
 * their JSClassRef in a `static` function-local created under `dispatch_once`, so a `static inline`
 * copy in a header gives every translation unit its own class ref under the same class name, and
 * PromiseState answers by IDENTITY - JSValueIsObjectOfClass(ctx, value, PromiseClass()) - so a
 * promise minted through one copy's makePromise reads as "not a promise" through the other copy's
 * promiseState. CharonPromiseSource is a 260-line script and would be a second copy of it per unit.
 * One copy, here, is the shape AGENTS.md names: "define it in a file that exports no API symbol of
 * its own". `nm -gU` on this file reports nothing the release test weighs, so band() keeps this
 * object in EVERY band, and that is what lets the 16.0 object below call it: from iOS 7.0 to 15.x,
 * JSValue.m is re-exported to the release's own JSValue and is not in the library at all.
 *
 * Two entry points, both `charon_js_`-prefixed so modules/apple/backports.lua's internal_symbol()
 * filters them and the release test never has to place them - the same shape as charon_js_enter,
 * charon_js_leave and charon_js_note_jobs in JSInternal.m:
 * charon_js_promise_constructor, which JSValue.m's +charon_installPromiseInContext: calls, and
 * charon_js_deferred_promise, which both JSValue.m's +[JSValue valueWithNewPromiseInContext:
 * fromExecutor:] and JSObjectMakeDeferredPromise16.m call. Everything else in here is `static` and
 * has exactly one caller.
 */

/*
 * Promises. The release's engine (2012) has none, so one is built here, the way the JavaScriptCore
 * that has them builds its own: the algorithms are script (WebKit's PromiseOperations.js and
 * PromiseConstructor.js are too), and the state a promise keeps is a private property of an object
 * made with a JSClassRef whose class name is "Promise", which script cannot see or change and which
 * makes Object.prototype.toString answer "[object Promise]". Reactions run as jobs from the queue in
 * JSInternal.m, when the outermost call into script returns. What the 2012 engine cannot iterate
 * does not exist in it: arrays, strings and arguments objects are all the iterables it has, and
 * Promise.all/race/allSettled take exactly those. The constructor is found again through the
 * virtual machine's weak object map, keyed by the global object, so a context has one for as long
 * as anything can reach it; a context -init makes also gets it as its global Promise, and a context
 * adopted from elsewhere (a web view's page) is left as its owner made it.
 */
static const char CharonPromiseSource[] =
    "(function (makePromise, promiseState, callFunction, noteJobs, reportError) {\n"
    "'use strict';\n"
    "var TypeErrorConstructor = TypeError, isArray = Array.isArray, toTag = Object.prototype.toString;\n"
    "var define = Object.defineProperty, PENDING = 0, FULFILLED = 1, REJECTED = 2;\n"
    "var jobs = [], head = 0;\n"
    "function drain() {\n"
    "    while (head < jobs.length) {\n"
    "        var job = jobs[head];\n"
    "        jobs[head++] = undefined;\n"
    "        try { job(); } catch (error) { reportError(error); }\n"
    "    }\n"
    "    jobs.length = 0;\n"
    "    head = 0;\n"
    "}\n"
    "function enqueue(job) {\n"
    "    jobs[jobs.length] = job;\n"
    "    if (jobs.length - head === 1)\n"
    "        noteJobs(drain);\n"
    "}\n"
    "function isObject(value) {\n"
    "    return value !== null && (typeof value === 'object' || typeof value === 'function');\n"
    "}\n"
    "function settle(state, outcome, value) {\n"
    "    var reactions = state.reactions;\n"
    "    state.outcome = outcome;\n"
    "    state.value = value;\n"
    "    state.reactions = undefined;\n"
    "    for (var index = 0; index < reactions.length; index++)\n"
    "        react(reactions[index], outcome, value);\n"
    "}\n"
    "function react(reaction, outcome, value) {\n"
    "    enqueue(function () {\n"
    "        var handler = outcome === FULFILLED ? reaction.onFulfilled : reaction.onRejected, result;\n"
    "        if (handler === undefined) {\n"
    "            if (outcome === FULFILLED)\n"
    "                reaction.resolve(value);\n"
    "            else\n"
    "                reaction.reject(value);\n"
    "            return;\n"
    "        }\n"
    "        try {\n"
    "            result = handler(value);\n"
    "        } catch (error) {\n"
    "            reaction.reject(error);\n"
    "            return;\n"
    "        }\n"
    "        reaction.resolve(result);\n"
    "    });\n"
    "}\n"
    "function resolvingFunctions(promise, state) {\n"
    "    var alreadyResolved = false;\n"
    "    function resolve(resolution) {\n"
    "        if (alreadyResolved)\n"
    "            return;\n"
    "        alreadyResolved = true;\n"
    "        if (resolution === promise)\n"
    "            return settle(state, REJECTED, new TypeErrorConstructor('Cannot resolve a promise with itself'));\n"
    "        if (!isObject(resolution))\n"
    "            return settle(state, FULFILLED, resolution);\n"
    "        var then;\n"
    "        try {\n"
    "            then = resolution.then;\n"
    "        } catch (error) {\n"
    "            return settle(state, REJECTED, error);\n"
    "        }\n"
    "        if (typeof then !== 'function')\n"
    "            return settle(state, FULFILLED, resolution);\n"
    "        enqueue(function () {\n"
    "            var functions = resolvingFunctions(promise, state);\n"
    "            try {\n"
    "                callFunction(then, resolution, functions.resolve, functions.reject);\n"
    "            } catch (error) {\n"
    "                functions.reject(error);\n"
    "            }\n"
    "        });\n"
    "    }\n"
    "    function reject(reason) {\n"
    "        if (alreadyResolved)\n"
    "            return;\n"
    "        alreadyResolved = true;\n"
    "        settle(state, REJECTED, reason);\n"
    "    }\n"
    "    return { resolve: resolve, reject: reject };\n"
    "}\n"
    "function newState() {\n"
    "    return { outcome: PENDING, value: undefined, reactions: [] };\n"
    "}\n"
    "function Promise(executor) {\n"
    "    if (!(this instanceof Promise) || promiseState(this) !== undefined)\n"
    "        throw new TypeErrorConstructor('Promise constructor cannot be called without new');\n"
    "    if (typeof executor !== 'function')\n"
    "        throw new TypeErrorConstructor('Promise constructor takes a function argument');\n"
    "    var state = newState(), promise = makePromise(prototype, state), functions = resolvingFunctions(promise, state);\n"
    "    try {\n"
    "        executor(functions.resolve, functions.reject);\n"
    "    } catch (error) {\n"
    "        functions.reject(error);\n"
    "    }\n"
    "    return promise;\n"
    "}\n"
    "var prototype = Promise.prototype;\n"
    "function capability(C) {\n"
    "    if (C === Promise) {\n"
    "        var state = newState(), promise = makePromise(prototype, state), functions = resolvingFunctions(promise, state);\n"
    "        return { promise: promise, resolve: functions.resolve, reject: functions.reject };\n"
    "    }\n"
    "    if (typeof C !== 'function')\n"
    "        throw new TypeErrorConstructor('A promise capability needs a constructor');\n"
    "    var resolve, reject;\n"
    "    var made = new C(function (resolveFunction, rejectFunction) {\n"
    "        if (resolve !== undefined || reject !== undefined)\n"
    "            throw new TypeErrorConstructor('A promise executor was called twice');\n"
    "        resolve = resolveFunction;\n"
    "        reject = rejectFunction;\n"
    "    });\n"
    "    if (typeof resolve !== 'function' || typeof reject !== 'function')\n"
    "        throw new TypeErrorConstructor('A promise constructor did not supply its resolving functions');\n"
    "    return { promise: made, resolve: resolve, reject: reject };\n"
    "}\n"
    /* The engine has no @@species; the one thing it stands for that an ES5 script can build is a
     * constructor whose prototype inherits Promise.prototype, and that is what is kept. */
    "function speciesConstructor(promise) {\n"
    "    var C = promise.constructor;\n"
    "    if (C === undefined)\n"
    "        return Promise;\n"
    "    if (!isObject(C))\n"
    "        throw new TypeErrorConstructor('A promise\\'s constructor property is not an object');\n"
    "    if (C !== Promise && typeof C === 'function' && isObject(C.prototype) && C.prototype instanceof Promise)\n"
    "        return C;\n"
    "    return Promise;\n"
    "}\n"
    "function promiseResolve(C, value) {\n"
    "    if (promiseState(value) !== undefined && value.constructor === C)\n"
    "        return value;\n"
    "    var made = capability(C);\n"
    "    made.resolve(value);\n"
    "    return made.promise;\n"
    "}\n"
    "function then(onFulfilled, onRejected) {\n"
    "    var state = promiseState(this);\n"
    "    if (state === undefined)\n"
    "        throw new TypeErrorConstructor('Promise.prototype.then called on an object that is not a promise');\n"
    "    var made = capability(speciesConstructor(this));\n"
    "    var reaction = { resolve: made.resolve, reject: made.reject,\n"
    "        onFulfilled: typeof onFulfilled === 'function' ? onFulfilled : undefined,\n"
    "        onRejected: typeof onRejected === 'function' ? onRejected : undefined };\n"
    "    if (state.outcome === PENDING)\n"
    "        state.reactions[state.reactions.length] = reaction;\n"
    "    else\n"
    "        react(reaction, state.outcome, state.value);\n"
    "    return made.promise;\n"
    "}\n"
    "function catchRejection(onRejected) {\n"
    "    return this.then(undefined, onRejected);\n"
    "}\n"
    "function runFinally(onFinally) {\n"
    "    var promise = this;\n"
    "    if (!isObject(promise))\n"
    "        throw new TypeErrorConstructor('Promise.prototype.finally called on a value that is not an object');\n"
    "    var C = speciesConstructor(promise);\n"
    "    if (typeof onFinally !== 'function')\n"
    "        return promise.then(onFinally, onFinally);\n"
    "    return promise.then(function (value) {\n"
    "        return promiseResolve(C, onFinally()).then(function () { return value; });\n"
    "    }, function (reason) {\n"
    "        return promiseResolve(C, onFinally()).then(function () { throw reason; });\n"
    "    });\n"
    "}\n"
    "function resolveStatic(value) {\n"
    "    if (!isObject(this))\n"
    "        throw new TypeErrorConstructor('Promise.resolve called on a value that is not an object');\n"
    "    return promiseResolve(this, value);\n"
    "}\n"
    "function rejectStatic(reason) {\n"
    "    var made = capability(this);\n"
    "    made.reject(reason);\n"
    "    return made.promise;\n"
    "}\n"
    /* Each iterable this engine has, walked the way its iterator would: an array or arguments object
     * by index up to a length read before each step, a string by code point. */
    "function forEachOf(iterable, visit) {\n"
    "    var index;\n"
    "    if (typeof iterable === 'string') {\n"
    "        for (index = 0; index < iterable.length; index++) {\n"
    "            var unit = iterable.charCodeAt(index), next = iterable.charCodeAt(index + 1);\n"
    "            if (unit >= 0xD800 && unit <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF) {\n"
    "                visit(iterable.charAt(index) + iterable.charAt(index + 1));\n"
    "                index++;\n"
    "            } else {\n"
    "                visit(iterable.charAt(index));\n"
    "            }\n"
    "        }\n"
    "        return;\n"
    "    }\n"
    "    if (!isArray(iterable) && callFunction(toTag, Object(iterable)) !== '[object Arguments]')\n"
    "        throw new TypeErrorConstructor('The value is not iterable');\n"
    "    for (index = 0; index < iterable.length; index++)\n"
    "        visit(iterable[index]);\n"
    "}\n"
    "function combine(C, iterable, onEach, onEnd) {\n"
    "    var made = capability(C);\n"
    "    try {\n"
    "        var resolveFunction = C.resolve;\n"
    "        if (typeof resolveFunction !== 'function')\n"
    "            throw new TypeErrorConstructor('Promise resolve is not a function');\n"
    "        var values = [], remaining = 1, index = 0;\n"
    "        forEachOf(iterable, function (item) {\n"
    "            var position = index++;\n"
    "            values[position] = undefined;\n"
    "            remaining++;\n"
    "            var called = false;\n"
    "            onEach(callFunction(resolveFunction, C, item), made, function (value) {\n"
    "                if (called)\n"
    "                    return;\n"
    "                called = true;\n"
    "                values[position] = value;\n"
    "                if (--remaining === 0)\n"
    "                    made.resolve(values);\n"
    "            });\n"
    "        });\n"
    "        if (onEnd && --remaining === 0)\n"
    "            made.resolve(values);\n"
    "    } catch (error) {\n"
    "        made.reject(error);\n"
    "    }\n"
    "    return made.promise;\n"
    "}\n"
    "function all(iterable) {\n"
    "    return combine(this, iterable, function (next, made, store) {\n"
    "        next.then(store, made.reject);\n"
    "    }, true);\n"
    "}\n"
    "function allSettled(iterable) {\n"
    "    return combine(this, iterable, function (next, made, store) {\n"
    "        next.then(function (value) {\n"
    "            store({ status: 'fulfilled', value: value });\n"
    "        }, function (reason) {\n"
    "            store({ status: 'rejected', reason: reason });\n"
    "        });\n"
    "    }, true);\n"
    "}\n"
    "function race(iterable) {\n"
    "    return combine(this, iterable, function (next, made) {\n"
    "        next.then(made.resolve, made.reject);\n"
    "    }, false);\n"
    "}\n"
    "function method(target, name, value) {\n"
    "    define(target, name, { value: value, writable: true, enumerable: false, configurable: true });\n"
    "}\n"
    "method(prototype, 'then', then);\n"
    "method(prototype, 'catch', catchRejection);\n"
    "method(prototype, 'finally', runFinally);\n"
    "method(Promise, 'resolve', resolveStatic);\n"
    "method(Promise, 'reject', rejectStatic);\n"
    "method(Promise, 'all', all);\n"
    "method(Promise, 'allSettled', allSettled);\n"
    "method(Promise, 'race', race);\n"
    "define(Promise, 'prototype', { writable: false });\n"
    "return Promise;\n"
    "})";

static NSString *const CharonPromiseStateName = @"charon.promise.state";

static JSClassRef PromiseClass(void)
{
    static JSClassRef promiseClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "Promise";
        definition.attributes = kJSClassAttributeNoAutomaticPrototype;
        promiseClass = JSClassCreate(&definition);
    });
    return promiseClass;
}


/* makePromise(prototype, state): a promise object holding `state` where script cannot reach it. */
static JSValueRef MakePromise(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    JSObjectRef promise = JSObjectMake(ctx, PromiseClass(), NULL);
    JSObjectSetPrototype(ctx, promise, arguments[0]);
    JSStringRef name = charon_js_string(CharonPromiseStateName);
    bool kept = argumentCount == 2 && JSObjectSetPrivateProperty(ctx, promise, name, arguments[1]);
    JSStringRelease(name);
    if (!kept) {
        *exception = charon_js_type_error(ctx, @"this release's JavaScriptCore keeps no private property on a promise object");
        return JSValueMakeUndefined(ctx);
    }
    return promise;
}

/* promiseState(value): the state makePromise gave `value`, or undefined for anything else. */
static JSValueRef PromiseState(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    (void)exception;
    if (argumentCount < 1 || !JSValueIsObjectOfClass(ctx, arguments[0], PromiseClass()))
        return JSValueMakeUndefined(ctx);
    JSStringRef name = charon_js_string(CharonPromiseStateName);
    JSValueRef state = JSObjectGetPrivateProperty(ctx, (JSObjectRef)arguments[0], name);
    JSStringRelease(name);
    return state ?: JSValueMakeUndefined(ctx);
}

/* callFunction(function, thisObject, ...arguments): a call no script can intercept by replacing
 * Function.prototype.call. `thisObject` is always an object here. */
static JSValueRef CallFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    JSObjectRef callee = argumentCount > 0 ? JSValueToObject(ctx, arguments[0], exception) : NULL;
    if (!callee || !JSObjectIsFunction(ctx, callee)) {
        if (!*exception)
            *exception = charon_js_type_error(ctx, @"the value is not a function");
        return JSValueMakeUndefined(ctx);
    }
    JSObjectRef receiver = argumentCount > 1 ? JSValueToObject(ctx, arguments[1], exception) : NULL;
    if (*exception)
        return JSValueMakeUndefined(ctx);
    size_t count = argumentCount > 2 ? argumentCount - 2 : 0;
    return JSObjectCallAsFunction(ctx, callee, receiver, count, count ? arguments + 2 : NULL, exception);
}

/* noteJobs(drain): this context has jobs queued; see charon_js_note_jobs. */
static JSValueRef NoteJobs(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    JSObjectRef drain = argumentCount > 0 ? JSValueToObject(ctx, arguments[0], exception) : NULL;
    if (drain)
        charon_js_note_jobs(ctx, drain);
    return JSValueMakeUndefined(ctx);
}

/* reportError(error): a job threw past its own promise, which is the context's uncaught exception. */
static JSValueRef ReportError(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    (void)exception;
    if (argumentCount > 0)
        [[JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES] charon_noteException:arguments[0]];
    return JSValueMakeUndefined(ctx);
}

static JSObjectRef PromiseHelper(JSContextRef ctx, const char *name, JSObjectCallAsFunctionCallback callback)
{
    JSStringRef string = JSStringCreateWithUTF8CString(name);
    JSObjectRef helper = JSObjectMakeFunctionWithCallback(ctx, string, callback);
    JSStringRelease(string);
    return helper;
}

/* The executor's resolving functions, caught by the executor function the constructor calls. */
typedef struct CharonPromiseCapture {
    JSValueRef resolve;
    JSValueRef reject;
} CharonPromiseCapture;

static JSValueRef CaptureExecutor(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)thisObject;
    (void)exception;
    CharonPromiseCapture *capture = JSObjectGetPrivate(function);
    if (capture && argumentCount >= 2) {
        capture->resolve = arguments[0];
        capture->reject = arguments[1];
    }
    return JSValueMakeUndefined(ctx);
}

static JSClassRef CaptureClass(void)
{
    static JSClassRef captureClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "CharonPromiseExecutor";
        definition.callAsFunction = CaptureExecutor;
        captureClass = JSClassCreate(&definition);
    });
    return captureClass;
}

/* The context's Promise constructor, made the first time it is asked for; NULL only if making it
 * failed, which the context's exception handler has then been told. */
JSObjectRef charon_js_promise_constructor(JSContext *context)
{
    JSGlobalContextRef ctx = context.JSGlobalContextRef;
    JSWeakObjectMapRef weak;
    JSGlobalContextRef weakContext = [context.virtualMachine charon_weakContext:&weak];
    void *key = JSContextGetGlobalObject(ctx);
    JSObjectRef constructor = JSWeakObjectMapGet(weakContext, weak, key);
    if (constructor)
        return constructor;
    JSStringRef source = JSStringCreateWithUTF8CString(CharonPromiseSource);
    JSValueRef exception = NULL;
    JSValueRef factory = JSEvaluateScript(ctx, source, NULL, NULL, 1, &exception);
    JSStringRelease(source);
    JSValueRef made = NULL;
    if (!exception) {
        JSValueRef helpers[] = {
            PromiseHelper(ctx, "makePromise", MakePromise),
            PromiseHelper(ctx, "promiseState", PromiseState),
            PromiseHelper(ctx, "callFunction", CallFunction),
            PromiseHelper(ctx, "noteJobs", NoteJobs),
            PromiseHelper(ctx, "reportError", ReportError),
        };
        made = JSObjectCallAsFunction(ctx, (JSObjectRef)factory, NULL, sizeof helpers / sizeof helpers[0], helpers, &exception);
    }
    if (exception || !made || !JSValueIsObject(ctx, made)) {
        NSLog(@"JSValue: this context's Promise constructor could not be made");
        [context charon_noteException:exception];
        return NULL;
    }
    constructor = (JSObjectRef)made;
    JSWeakObjectMapSet(weakContext, weak, key, constructor);
    return constructor;
}

/*
 * The promise and the two functions that settle it, which +valueWithNewPromiseInContext:fromExecutor:
 * below runs its callback against and JSObjectMakeDeferredPromise hands back: the context's own
 * constructor, an executor that captures the resolving functions, and the promise. NULL when the
 * constructor could not be made or the capture came back empty, with *outException left where the
 * caller reads it - nothing is reported here, because the two callers report it their own way.
 *
 * A call that has entered (charon_js_enter, which is what a job queue waits for before it may run)
 * leaves it entered when it hands a promise back, and the caller leaves it once it is done with it:
 * a job queued by a caller's own callback may not run while that callback's script is still on the
 * stack. Both failure paths below leave it themselves, so a caller that gets NULL must not.
 */
JSObjectRef charon_js_deferred_promise(JSContext *context, JSObjectRef *outResolve, JSObjectRef *outReject, JSValueRef *outException)
{
    JSGlobalContextRef ctx = context.JSGlobalContextRef;
    charon_js_enter();
    JSObjectRef constructor = charon_js_promise_constructor(context);
    if (!constructor) {
        charon_js_leave();
        *outException = NULL;
        return NULL;
    }
    CharonPromiseCapture capture = {NULL, NULL};
    JSObjectRef executor = JSObjectMake(ctx, CaptureClass(), &capture);
    JSValueRef argument = executor;
    JSValueRef exception = NULL;
    JSObjectRef promise = JSObjectCallAsConstructor(ctx, constructor, 1, &argument, &exception);
    JSObjectSetPrivate(executor, NULL);
    *outResolve = NULL;
    *outReject = NULL;
    if (exception || !promise || !capture.resolve || !capture.reject) {
        charon_js_leave();
        *outException = exception;
        return NULL;
    }
    *outResolve = capture.resolve;
    *outReject = capture.reject;
    *outException = NULL;
    return promise;
}

