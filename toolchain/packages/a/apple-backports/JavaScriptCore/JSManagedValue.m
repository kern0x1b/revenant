#import "JSInternal.h"

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
