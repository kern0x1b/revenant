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

- (void *)revenant_objectKey
{
    return (__bridge void *)self;
}

- (void *)revenant_globalKey
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
    _weakContext = JSGlobalContextRetain([context.virtualMachine revenant_weakContext:&_weak]);
    _globalContext = globalContext;
    JSWeakObjectMapSet(_weakContext, _weak, self.revenant_globalKey, JSContextGetGlobalObject(globalContext));
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
        _string = revenant_ns_string(string);
        if (string)
            JSStringRelease(string);
        break;
    }
    case kJSTypeObject:
        JSWeakObjectMapSet(_weakContext, _weak, self.revenant_objectKey, (JSObjectRef)ref);
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
    JSWeakObjectMapRemove(_weakContext, _weak, self.revenant_objectKey);
    JSWeakObjectMapRemove(_weakContext, _weak, self.revenant_globalKey);
    JSGlobalContextRelease(_weakContext);
}

- (JSObjectRef)revenant_object
{
    if (!_weakContext || _type != kJSTypeObject)
        return NULL;
    return JSWeakObjectMapGet(_weakContext, _weak, self.revenant_objectKey);
}

- (JSValue *)value
{
    volatile JSObjectRef global = _weakContext ? JSWeakObjectMapGet(_weakContext, _weak, self.revenant_globalKey) : NULL;
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
        JSStringRef string = revenant_js_string(_string);
        ref = JSValueMakeString(context, string);
        JSStringRelease(string);
        break;
    }
    case kJSTypeObject:
        ref = [self revenant_object];
        break;
    default:
        break;
    }
    if (!ref)
        return nil;
    return [JSValue revenant_valueWithJSValueRef:ref context:[JSContext revenant_wrapperForGlobalContext:context create:YES]];
}

@end
