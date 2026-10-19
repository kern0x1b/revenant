#import "JSInternal.h"

/*
 * "Conditionally retained": the release's JSManagedValue keeps its JavaScript value alive for as
 * long as either the JavaScript object graph or the graph reported to -[JSVirtualMachine
 * addManagedReference:withOwner:] reaches it, and reads back nil once the collector has taken it.
 * It holds the JavaScript value, not the Objective-C JSValue it was made from, and holds neither
 * the value's global object nor its context alive (WebKit's JSManagedValue.mm: a WeakValueRef and
 * a Weak<JSGlobalObject>).
 *
 * Here, over the release's C API:
 * - an object is held weakly in the virtual machine's weak object map (JSInternal.h,
 *   JSVirtualMachine.m), and so is the value's global object: a read answers nil once the global
 *   object is gone, as WebKit's does, and only while it is alive is the value's JSGlobalContextRef
 *   used at all. A weak map's destroyed callback cannot say so instead: measured on the host, it
 *   runs neither when its global object is collected nor when the group is torn down, and on the
 *   iPad 2 (6.1.3) it runs when its global object is destroyed, not when a value's is;
 * - the weak map lives in the virtual machine's own global context, which this retains, and with
 *   it the context group: the C API has no other way to know the group is still there, and a map
 *   read after its group is gone reads freed memory. This keeps the heap, not the value's global
 *   object or context;
 * - a primitive (undefined, null, a boolean, a number) and a string are kept by value and made
 *   again in the same context on each read, as WebKit keeps a primitive directly. WebKit holds a
 *   string weakly; a string references nothing, so keeping it cannot form the cycle this class
 *   exists to break, and when the collector would have taken it is not observable.
 *
 * What an owner keeps is JSVirtualMachine.m's.
 */

@interface JSManagedValue ()
{
    JSGlobalContextRef _weakContext;
    JSWeakObjectMapRef _weak;
    JSGlobalContextRef _globalContext;
    JSType _type;
    BOOL _boolean;
    double _number;
    NSString *_string;
}
@end

@implementation JSManagedValue

+ (JSManagedValue *)managedValueWithValue:(JSValue *)value
{
    return [[self alloc] initWithValue:value];
}

+ (JSManagedValue *)managedValueWithValue:(JSValue *)value andOwner:(id)owner
{
    JSManagedValue *managed = [[self alloc] initWithValue:value];
    if (value)
        [value.context.virtualMachine addManagedReference:managed withOwner:owner];
    return managed;
}

/* The two keys this holds in the weak map: addresses inside this object, so no other key's. */
- (void *)charon_objectKey
{
    return (__bridge void *)self;
}

- (void *)charon_globalKey
{
    return &_globalContext;
}

- (instancetype)initWithValue:(JSValue *)value
{
    if (!(self = [super init]))
        return nil;
    JSContext *context = value.context;
    JSGlobalContextRef globalContext = context.JSGlobalContextRef;
    if (!globalContext)
        return self;
    _weakContext = JSGlobalContextRetain([context.virtualMachine charon_weakContext:&_weak]);
    _globalContext = globalContext;
    JSWeakObjectMapSet(_weakContext, _weak, self.charon_globalKey, JSContextGetGlobalObject(globalContext));
    JSValueRef ref = value.JSValueRef;
    _type = JSValueGetType(globalContext, ref);
    switch (_type) {
    case kJSTypeBoolean:
        _boolean = JSValueToBoolean(globalContext, ref);
        break;
    case kJSTypeNumber:
        _number = JSValueToNumber(globalContext, ref, NULL);
        break;
    case kJSTypeString: {
        JSStringRef string = JSValueToStringCopy(globalContext, ref, NULL);
        _string = charon_ns_string(string);
        if (string)
            JSStringRelease(string);
        break;
    }
    case kJSTypeObject:
        JSWeakObjectMapSet(_weakContext, _weak, self.charon_objectKey, (JSObjectRef)ref);
        break;
    default:
        break;
    }
    return self;
}

- (void)dealloc
{
    if (!_weakContext)
        return;
    JSWeakObjectMapRemove(_weakContext, _weak, self.charon_objectKey);
    JSWeakObjectMapRemove(_weakContext, _weak, self.charon_globalKey);
    JSGlobalContextRelease(_weakContext);
}

- (JSObjectRef)charon_object
{
    if (!_weakContext || _type != kJSTypeObject)
        return NULL;
    return JSWeakObjectMapGet(_weakContext, _weak, self.charon_objectKey);
}

- (JSValue *)value
{
    /* held in a volatile local, so the collector's scan of this thread's stack keeps the global
     * object - and with it the context ref used below - alive until this returns */
    volatile JSObjectRef global = _weakContext ? JSWeakObjectMapGet(_weakContext, _weak, self.charon_globalKey) : NULL;
    if (!global)
        return nil;
    JSGlobalContextRef context = _globalContext;
    JSValueRef ref = NULL;
    switch (_type) {
    case kJSTypeUndefined:
        ref = JSValueMakeUndefined(context);
        break;
    case kJSTypeNull:
        ref = JSValueMakeNull(context);
        break;
    case kJSTypeBoolean:
        ref = JSValueMakeBoolean(context, _boolean);
        break;
    case kJSTypeNumber:
        ref = JSValueMakeNumber(context, _number);
        break;
    case kJSTypeString: {
        JSStringRef string = charon_js_string(_string);
        ref = JSValueMakeString(context, string);
        JSStringRelease(string);
        break;
    }
    case kJSTypeObject:
        ref = [self charon_object];
        break;
    default:
        break;
    }
    if (!ref)
        return nil;
    return [JSValue charon_valueWithJSValueRef:ref context:[JSContext charon_wrapperForGlobalContext:context create:YES]];
}

@end
