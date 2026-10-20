#import "JSInternal.h"

static const char RevenantPromiseSource[] =
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

static NSString *const RevenantPromiseStateName = @"revenant.promise.state";

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


static JSValueRef MakePromise(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    JSObjectRef promise = JSObjectMake(ctx, PromiseClass(), NULL);
    JSObjectSetPrototype(ctx, promise, arguments[0]);
    JSStringRef name = revenant_js_string(RevenantPromiseStateName);
    bool kept = argumentCount == 2 && JSObjectSetPrivateProperty(ctx, promise, name, arguments[1]);
    JSStringRelease(name);
    if (!kept) {
        *exception = revenant_js_type_error(ctx, @"this release's JavaScriptCore keeps no private property on a promise object");
        return JSValueMakeUndefined(ctx);
    }
    return promise;
}

static JSValueRef PromiseState(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    (void)exception;
    if (argumentCount < 1 || !JSValueIsObjectOfClass(ctx, arguments[0], PromiseClass()))
        return JSValueMakeUndefined(ctx);
    JSStringRef name = revenant_js_string(RevenantPromiseStateName);
    JSValueRef state = JSObjectGetPrivateProperty(ctx, (JSObjectRef)arguments[0], name);
    JSStringRelease(name);
    return state ?: JSValueMakeUndefined(ctx);
}

static JSValueRef CallFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    JSObjectRef callee = argumentCount > 0 ? JSValueToObject(ctx, arguments[0], exception) : NULL;
    if (!callee || !JSObjectIsFunction(ctx, callee)) {
        if (!*exception)
            *exception = revenant_js_type_error(ctx, @"the value is not a function");
        return JSValueMakeUndefined(ctx);
    }
    JSObjectRef receiver = argumentCount > 1 ? JSValueToObject(ctx, arguments[1], exception) : NULL;
    if (*exception)
        return JSValueMakeUndefined(ctx);
    size_t count = argumentCount > 2 ? argumentCount - 2 : 0;
    return JSObjectCallAsFunction(ctx, callee, receiver, count, count ? arguments + 2 : NULL, exception);
}

static JSValueRef NoteJobs(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    JSObjectRef drain = argumentCount > 0 ? JSValueToObject(ctx, arguments[0], exception) : NULL;
    if (drain)
        revenant_js_note_jobs(ctx, drain);
    return JSValueMakeUndefined(ctx);
}

static JSValueRef ReportError(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function;
    (void)thisObject;
    (void)exception;
    if (argumentCount > 0)
        [[JSContext revenant_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES] revenant_noteException:arguments[0]];
    return JSValueMakeUndefined(ctx);
}

static JSObjectRef PromiseHelper(JSContextRef ctx, const char *name, JSObjectCallAsFunctionCallback callback)
{
    JSStringRef string = JSStringCreateWithUTF8CString(name);
    JSObjectRef helper = JSObjectMakeFunctionWithCallback(ctx, string, callback);
    JSStringRelease(string);
    return helper;
}

typedef struct RevenantPromiseCapture {
    JSValueRef resolve;
    JSValueRef reject;
} RevenantPromiseCapture;

static JSValueRef CaptureExecutor(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)thisObject;
    (void)exception;
    RevenantPromiseCapture *capture = JSObjectGetPrivate(function);
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
        definition.className = "RevenantPromiseExecutor";
        definition.callAsFunction = CaptureExecutor;
        captureClass = JSClassCreate(&definition);
    });
    return captureClass;
}

JSObjectRef revenant_js_promise_constructor(JSContext *context)
{
    JSGlobalContextRef ctx = context.JSGlobalContextRef;
    JSWeakObjectMapRef weak;
    JSGlobalContextRef weakContext = [context.virtualMachine revenant_weakContext:&weak];
    void *key = JSContextGetGlobalObject(ctx);
    JSObjectRef constructor = JSWeakObjectMapGet(weakContext, weak, key);
    if (constructor)
        return constructor;
    JSStringRef source = JSStringCreateWithUTF8CString(RevenantPromiseSource);
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
        [context revenant_noteException:exception];
        return NULL;
    }
    constructor = (JSObjectRef)made;
    JSWeakObjectMapSet(weakContext, weak, key, constructor);
    return constructor;
}

JSObjectRef revenant_js_deferred_promise(JSContext *context, JSObjectRef *outResolve, JSObjectRef *outReject, JSValueRef *outException)
{
    JSGlobalContextRef ctx = context.JSGlobalContextRef;
    revenant_js_enter();
    JSObjectRef constructor = revenant_js_promise_constructor(context);
    if (!constructor) {
        revenant_js_leave();
        *outException = NULL;
        return NULL;
    }
    RevenantPromiseCapture capture = {NULL, NULL};
    JSObjectRef executor = JSObjectMake(ctx, CaptureClass(), &capture);
    JSValueRef argument = executor;
    JSValueRef exception = NULL;
    JSObjectRef promise = JSObjectCallAsConstructor(ctx, constructor, 1, &argument, &exception);
    JSObjectSetPrivate(executor, NULL);
    *outResolve = NULL;
    *outReject = NULL;
    if (exception || !promise || !capture.resolve || !capture.reject) {
        revenant_js_leave();
        *outException = exception;
        return NULL;
    }
    *outResolve = capture.resolve;
    *outReject = capture.reject;
    *outException = NULL;
    return promise;
}
