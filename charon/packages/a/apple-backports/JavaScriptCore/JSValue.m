#import "JSInternal.h"
#import <CoreGraphics/CoreGraphics.h>

@interface JSValue ()
{
    JSValueRef _value;
    JSContext *_context;
}
@end

@implementation JSValue

+ (instancetype)charon_valueWithJSValueRef:(JSValueRef)value context:(JSContext *)context
{
    JSValue *result = [self alloc];
    result->_value = value;
    result->_context = context;
    JSValueProtect(context.JSGlobalContextRef, value);
    return result;
}

+ (JSValue *)valueWithJSValueRef:(JSValueRef)value inContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:value context:context];
}

- (void)dealloc
{
    JSValueUnprotect(_context.JSGlobalContextRef, _value);
}

- (JSValueRef)JSValueRef
{
    return _value;
}

- (JSContext *)context
{
    return _context;
}

+ (JSValue *)valueWithObject:(id)value inContext:(JSContext *)context
{
    if ([value isKindOfClass:[JSValue class]])
        return value;
    return [self charon_valueWithJSValueRef:charon_js_box(context.JSGlobalContextRef, value) context:context];
}

+ (JSValue *)valueWithBool:(BOOL)value inContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:JSValueMakeBoolean(context.JSGlobalContextRef, value) context:context];
}

+ (JSValue *)valueWithDouble:(double)value inContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:JSValueMakeNumber(context.JSGlobalContextRef, value) context:context];
}

+ (JSValue *)valueWithInt32:(int32_t)value inContext:(JSContext *)context
{
    return [self valueWithDouble:value inContext:context];
}

+ (JSValue *)valueWithUInt32:(uint32_t)value inContext:(JSContext *)context
{
    return [self valueWithDouble:value inContext:context];
}

+ (JSValue *)valueWithNewObjectInContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:JSObjectMake(context.JSGlobalContextRef, NULL, NULL) context:context];
}

+ (JSValue *)valueWithNewArrayInContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:JSObjectMakeArray(context.JSGlobalContextRef, 0, NULL, NULL) context:context];
}

+ (JSValue *)valueWithNewRegularExpressionFromPattern:(NSString *)pattern flags:(NSString *)flags inContext:(JSContext *)context
{
    JSStringRef patternString = charon_js_string(pattern);
    JSStringRef flagsString = charon_js_string(flags);
    JSValueRef arguments[2] = {JSValueMakeString(context.JSGlobalContextRef, patternString), JSValueMakeString(context.JSGlobalContextRef, flagsString)};
    JSValueRef exception = NULL;
    JSObjectRef result = JSObjectMakeRegExp(context.JSGlobalContextRef, 2, arguments, &exception);
    JSStringRelease(patternString);
    JSStringRelease(flagsString);
    if (exception)
        [context charon_noteException:exception];
    return [self charon_valueWithJSValueRef:result context:context];
}

+ (JSValue *)valueWithNewErrorFromMessage:(NSString *)message inContext:(JSContext *)context
{
    JSStringRef text = charon_js_string(message);
    JSValueRef argument = JSValueMakeString(context.JSGlobalContextRef, text);
    JSStringRelease(text);
    JSObjectRef result = JSObjectMakeError(context.JSGlobalContextRef, 1, &argument, NULL);
    return [self charon_valueWithJSValueRef:result context:context];
}

+ (JSValue *)valueWithNullInContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:JSValueMakeNull(context.JSGlobalContextRef) context:context];
}

+ (JSValue *)valueWithUndefinedInContext:(JSContext *)context
{
    return [self charon_valueWithJSValueRef:JSValueMakeUndefined(context.JSGlobalContextRef) context:context];
}

/* A conversion that runs script (a valueOf or toString) and throws reports the exception to the
 * context's handler and answers NaN, 0 or nil, as the release's JSValue does. */
static id Reported(JSContext *context, id result, JSValueRef exception)
{
    if (exception)
        [context charon_noteException:exception];
    return result;
}

- (id)toObject
{
    return charon_js_unbox(_context.JSGlobalContextRef, _value);
}

- (id)toObjectOfClass:(Class)expectedClass
{
    id object = self.toObject;
    return [object isKindOfClass:expectedClass] ? object : nil;
}

- (BOOL)toBool
{
    return JSValueToBoolean(_context.JSGlobalContextRef, _value);
}


- (double)toDouble
{
    JSValueRef exception = NULL;
    double value = JSValueToNumber(_context.JSGlobalContextRef, _value, &exception);
    if (exception) {
        [_context charon_noteException:exception];
        return NAN;
    }
    return value;
}

- (int32_t)toInt32
{
    return (int32_t)charon_js_uint32(self.toDouble);
}

- (uint32_t)toUInt32
{
    return (uint32_t)self.toInt32;
}

- (NSNumber *)toNumber
{
    JSValueRef exception = NULL;
    return Reported(_context, charon_js_to_number(_context.JSGlobalContextRef, _value, &exception), exception);
}

- (NSString *)toString
{
    JSValueRef exception = NULL;
    return Reported(_context, charon_js_to_string(_context.JSGlobalContextRef, _value, &exception), exception);
}

- (NSDate *)toDate
{
    JSValueRef exception = NULL;
    return Reported(_context, charon_js_to_date(_context.JSGlobalContextRef, _value, &exception), exception);
}

- (NSArray *)toArray
{
    JSValueRef exception = NULL;
    return Reported(_context, charon_js_to_array(_context.JSGlobalContextRef, _value, &exception), exception);
}

- (NSDictionary *)toDictionary
{
    JSValueRef exception = NULL;
    return Reported(_context, charon_js_to_dictionary(_context.JSGlobalContextRef, _value, &exception), exception);
}

- (BOOL)isUndefined
{
    return JSValueIsUndefined(_context.JSGlobalContextRef, _value);
}

- (BOOL)isNull
{
    return JSValueIsNull(_context.JSGlobalContextRef, _value);
}

- (BOOL)isBoolean
{
    return JSValueIsBoolean(_context.JSGlobalContextRef, _value);
}

- (BOOL)isNumber
{
    return JSValueIsNumber(_context.JSGlobalContextRef, _value);
}

- (BOOL)isString
{
    return JSValueIsString(_context.JSGlobalContextRef, _value);
}

- (BOOL)isObject
{
    return JSValueIsObject(_context.JSGlobalContextRef, _value);
}

/* JSValueIsArray and JSValueIsDate only arrived in iOS 9; the object's own class answers the
 * same without them (charon_js_is_array, charon_js_is_date). */
- (BOOL)isArray
{
    return charon_js_is_array(_context.JSGlobalContextRef, _value);
}

- (BOOL)isDate
{
    return charon_js_is_date(_context.JSGlobalContextRef, _value);
}

- (BOOL)isEqualToObject:(id)value
{
    JSValue *other = [JSValue valueWithObject:value inContext:_context];
    return JSValueIsStrictEqual(_context.JSGlobalContextRef, _value, other.JSValueRef);
}

- (BOOL)isEqualWithTypeCoercionToObject:(id)value
{
    JSValue *other = [JSValue valueWithObject:value inContext:_context];
    JSValueRef exception = NULL;
    BOOL equal = JSValueIsEqual(_context.JSGlobalContextRef, _value, other.JSValueRef, &exception);
    if (exception)
        [_context charon_noteException:exception];
    return equal;
}

- (BOOL)isInstanceOf:(id)value
{
    JSValue *constructor = [JSValue valueWithObject:value inContext:_context];
    if (!JSValueIsObject(_context.JSGlobalContextRef, constructor.JSValueRef))
        return NO;
    JSValueRef exception = NULL;
    BOOL result = JSValueIsInstanceOfConstructor(_context.JSGlobalContextRef, _value, JSValueToObject(_context.JSGlobalContextRef, constructor.JSValueRef, &exception), &exception);
    if (exception)
        [_context charon_noteException:exception];
    return result;
}

- (JSValue *)callWithArguments:(NSArray *)arguments
{
    return [self charon_callWithArguments:arguments thisValue:NULL asConstructor:NO];
}

- (JSValue *)constructWithArguments:(NSArray *)arguments
{
    return [self charon_callWithArguments:arguments thisValue:NULL asConstructor:YES];
}

- (JSValue *)charon_callWithArguments:(NSArray *)arguments thisValue:(JSObjectRef)thisObject asConstructor:(BOOL)asConstructor
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef function = JSValueToObject(ctx, _value, &exception);
    if (!function) {
        if (exception)
            [_context charon_noteException:exception];
        return [JSValue valueWithUndefinedInContext:_context];
    }
    NSUInteger count = arguments.count;
    JSValueRef *values = count ? malloc(sizeof(JSValueRef) * count) : NULL;
    for (NSUInteger index = 0; index < count; index++)
        values[index] = charon_js_box(ctx, arguments[index]);
    JSValueRef result;
    charon_js_enter();
    if (asConstructor)
        result = JSObjectCallAsConstructor(ctx, function, count, values, &exception);
    else
        result = JSObjectCallAsFunction(ctx, function, thisObject, count, values, &exception);
    free(values);
    JSValue *value = [JSValue charon_valueWithJSValueRef:(exception || !result) ? JSValueMakeUndefined(ctx) : result context:_context];
    JSValue *thrown = exception ? [JSValue charon_valueWithJSValueRef:exception context:_context] : nil;
    charon_js_leave();
    if (thrown)
        [_context charon_noteException:thrown.JSValueRef];
    return value;
}

- (JSValue *)invokeMethod:(NSString *)method withArguments:(NSArray *)arguments
{
    JSValue *function = [self valueForProperty:method];
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef thisObject = JSValueToObject(ctx, _value, &exception);
    if (exception)
        [_context charon_noteException:exception];
    return [function charon_callWithArguments:arguments thisValue:thisObject asConstructor:NO];
}

- (JSValue *)valueForProperty:(NSString *)property
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef object = JSValueToObject(ctx, _value, &exception);
    if (!object) {
        if (exception)
            [_context charon_noteException:exception];
        return [JSValue valueWithUndefinedInContext:_context];
    }
    JSStringRef name = charon_js_string(property);
    JSValueRef result = JSObjectGetProperty(ctx, object, name, &exception);
    JSStringRelease(name);
    if (exception)
        [_context charon_noteException:exception];
    return [JSValue charon_valueWithJSValueRef:result ?: JSValueMakeUndefined(ctx) context:_context];
}

- (void)setValue:(id)value forProperty:(NSString *)property
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef object = JSValueToObject(ctx, _value, &exception);
    if (!object)
        return;
    JSStringRef name = charon_js_string(property);
    JSObjectSetProperty(ctx, object, name, charon_js_box(ctx, value), kJSPropertyAttributeNone, &exception);
    JSStringRelease(name);
    if (exception)
        [_context charon_noteException:exception];
}

- (BOOL)deleteProperty:(NSString *)property
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef object = JSValueToObject(ctx, _value, &exception);
    if (!object)
        return NO;
    JSStringRef name = charon_js_string(property);
    BOOL result = JSObjectDeleteProperty(ctx, object, name, &exception);
    JSStringRelease(name);
    if (exception)
        [_context charon_noteException:exception];
    return result;
}

- (BOOL)hasProperty:(NSString *)property
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef object = JSValueToObject(ctx, _value, &exception);
    if (!object)
        return NO;
    JSStringRef name = charon_js_string(property);
    BOOL result = JSObjectHasProperty(ctx, object, name);
    JSStringRelease(name);
    return result;
}

- (void)defineProperty:(NSString *)property descriptor:(id)descriptor
{
    JSValue *definePropertyFunction = [[self.context.globalObject valueForProperty:@"Object"] valueForProperty:@"defineProperty"];
    [definePropertyFunction callWithArguments:@[self, property, descriptor]];
}

- (JSValue *)valueAtIndex:(NSUInteger)index
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef object = JSValueToObject(ctx, _value, &exception);
    if (!object)
        return [JSValue valueWithUndefinedInContext:_context];
    JSValueRef result = JSObjectGetPropertyAtIndex(ctx, object, (unsigned)index, &exception);
    if (exception)
        [_context charon_noteException:exception];
    return [JSValue charon_valueWithJSValueRef:result ?: JSValueMakeUndefined(ctx) context:_context];
}

- (void)setValue:(id)value atIndex:(NSUInteger)index
{
    JSContextRef ctx = _context.JSGlobalContextRef;
    JSValueRef exception = NULL;
    JSObjectRef object = JSValueToObject(ctx, _value, &exception);
    if (!object)
        return;
    JSObjectSetPropertyAtIndex(ctx, object, (unsigned)index, charon_js_box(ctx, value), &exception);
    if (exception)
        [_context charon_noteException:exception];
}

- (JSValue *)objectForKeyedSubscript:(id)key
{
    return [self valueForProperty:[key description]];
}

- (JSValue *)objectAtIndexedSubscript:(NSUInteger)index
{
    return [self valueAtIndex:index];
}

- (void)setObject:(id)object forKeyedSubscript:(id)key
{
    [self setValue:object forProperty:[key description]];
}

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index
{
    [self setValue:object atIndex:index];
}

/* The release makes these four from a dictionary literal, so their properties come in that
 * dictionary's order, and so do these. */
+ (JSValue *)valueWithPoint:(CGPoint)point inContext:(JSContext *)context
{
    return [self valueWithObject:@{@"x": @(point.x), @"y": @(point.y)} inContext:context];
}

+ (JSValue *)valueWithRange:(NSRange)range inContext:(JSContext *)context
{
    return [self valueWithObject:@{@"location": @(range.location), @"length": @(range.length)} inContext:context];
}

+ (JSValue *)valueWithRect:(CGRect)rect inContext:(JSContext *)context
{
    return [self valueWithObject:@{@"x": @(rect.origin.x), @"y": @(rect.origin.y), @"width": @(rect.size.width), @"height": @(rect.size.height)} inContext:context];
}

+ (JSValue *)valueWithSize:(CGSize)size inContext:(JSContext *)context
{
    return [self valueWithObject:@{@"width": @(size.width), @"height": @(size.height)} inContext:context];
}

- (CGPoint)toPoint
{
    return CGPointMake([[self valueForProperty:@"x"] toDouble], [[self valueForProperty:@"y"] toDouble]);
}

- (NSRange)toRange
{
    return NSMakeRange((NSUInteger)[[self valueForProperty:@"location"] toDouble], (NSUInteger)[[self valueForProperty:@"length"] toDouble]);
}

- (CGRect)toRect
{
    return CGRectMake([[self valueForProperty:@"x"] toDouble], [[self valueForProperty:@"y"] toDouble], [[self valueForProperty:@"width"] toDouble], [[self valueForProperty:@"height"] toDouble]);
}

- (CGSize)toSize
{
    return CGSizeMake([[self valueForProperty:@"width"] toDouble], [[self valueForProperty:@"height"] toDouble]);
}

- (NSString *)description
{
    return self.toString;
}

/* The value of `name` on `object`. */
static JSValueRef NamedProperty(JSContextRef ctx, JSObjectRef object, const char *name)
{
    JSStringRef string = JSStringCreateWithUTF8CString(name);
    JSValueRef value = JSObjectGetProperty(ctx, object, string, NULL);
    JSStringRelease(string);
    return value;
}

/* A context -init made carries the constructor as its global Promise, as one with promises does:
 * writable, configurable and not enumerable (measured on the host). The release's engine makes a
 * fresh global object with no Promise of its own, so nothing is replaced there; on an engine that
 * has one, this constructor replaces it, which is how the host test holds this implementation, not
 * the host's, to the host's answers. It is defined through the context's own Object.defineProperty,
 * read before any script has run in the context: the 2012 engine's JSObjectSetProperty keeps no
 * attribute on a global object (JSGlobalObject::putDirectVirtual puts the value first, then leaves
 * the attributes of the property that now exists, JavaScriptCore-7536.26.7; measured on the iPad
 * 2, kJSPropertyAttributeDontEnum there gives an enumerable global, and ES5's defineProperty does
 * not), where [[DefineOwnProperty]] is ES5's own. */
+ (void)charon_installPromiseInContext:(JSContext *)context
{
    JSObjectRef constructor = charon_js_promise_constructor(context);
    if (!constructor)
        return;
    JSGlobalContextRef ctx = context.JSGlobalContextRef;
    JSObjectRef global = JSContextGetGlobalObject(ctx);
    JSObjectRef define = (JSObjectRef)NamedProperty(ctx, (JSObjectRef)NamedProperty(ctx, global, "Object"), "defineProperty");
    JSObjectRef descriptor = JSObjectMake(ctx, NULL, NULL);
    const struct { const char *name; JSValueRef value; } fields[] = {
        {"value", constructor},
        {"writable", JSValueMakeBoolean(ctx, true)},
        {"enumerable", JSValueMakeBoolean(ctx, false)},
        {"configurable", JSValueMakeBoolean(ctx, true)},
    };
    for (size_t index = 0; index < sizeof fields / sizeof fields[0]; index++) {
        JSStringRef name = JSStringCreateWithUTF8CString(fields[index].name);
        JSObjectSetProperty(ctx, descriptor, name, fields[index].value, kJSPropertyAttributeNone, NULL);
        JSStringRelease(name);
    }
    JSStringRef name = JSStringCreateWithUTF8CString("Promise");
    JSValueRef arguments[] = {global, JSValueMakeString(ctx, name), descriptor};
    JSStringRelease(name);
    JSValueRef exception = NULL;
    JSObjectCallAsFunction(ctx, define, NULL, 3, arguments, &exception);
    if (exception)
        [context charon_noteException:exception];
}

/*
 * As the release with promises does it: the promise exists before the executor runs, the executor
 * is called as a callback whose this is the promise and whose arguments are its resolving
 * functions, and an exception it sets on the context rejects the promise instead of reaching the
 * exception handler.
 */
+ (JSValue *)valueWithNewPromiseInContext:(JSContext *)context fromExecutor:(void (^)(JSValue *resolve, JSValue *reject))callback
{
    JSObjectRef resolve = NULL, reject = NULL;
    JSValueRef exception = NULL;
    JSObjectRef promise = charon_js_deferred_promise(context, &resolve, &reject, &exception);
    if (!promise) {
        JSValue *thrown = exception ? [JSValue charon_valueWithJSValueRef:exception context:context] : nil;
        [context charon_noteException:thrown.JSValueRef];
        return [JSValue valueWithUndefinedInContext:context];
    }
    JSValue *result = [JSValue charon_valueWithJSValueRef:promise context:context];
    if (callback) {
        JSValue *resolveFunction = [JSValue charon_valueWithJSValueRef:resolve context:context];
        JSValue *rejectFunction = [JSValue charon_valueWithJSValueRef:reject context:context];
        /* The frame holds its arguments unretained; this local keeps them for the call. */
        NSArray<JSValue *> *arguments = @[resolveFunction, rejectFunction];
        charon_js_push_callback(context, result, nil, arguments);
        callback(resolveFunction, rejectFunction);
        JSValue *thrown = charon_js_pop_callback();
        if (thrown)
            [rejectFunction callWithArguments:@[thrown]];
    }
    charon_js_leave();
    return result;
}

/* The release builds these two on the executor form above and so does this. It puts the result
 * or reason into an array literal, so a nil one raises NSInvalidArgumentException out of it
 * (measured on the host: "attempt to insert nil object from objects[0]"); this makes the same
 * literal before any script runs, so the exception reaches the caller without unwinding through
 * the engine's frames. */
+ (JSValue *)valueWithNewPromiseResolvedWithResult:(id)result inContext:(JSContext *)context
{
    NSArray *arguments = @[result];
    return [self valueWithNewPromiseInContext:context fromExecutor:^(JSValue *resolve, JSValue *reject) {
        (void)reject;
        [resolve callWithArguments:arguments];
    }];
}

+ (JSValue *)valueWithNewPromiseRejectedWithReason:(id)reason inContext:(JSContext *)context
{
    NSArray *arguments = @[reason];
    return [self valueWithNewPromiseInContext:context fromExecutor:^(JSValue *resolve, JSValue *reject) {
        (void)resolve;
        [reject callWithArguments:arguments];
    }];
}

/*
 * Symbols. The release's engine has no symbol type: there is no value a symbol could be, and a
 * string or object standing in for one would be a different value that says it is the same. So
 * this refuses at the seam: the context is told a TypeError, as the release with symbols tells it
 * when a symbol is used where it cannot be, and the answer is undefined. -isSymbol is NO because
 * no value of this engine is one.
 */
+ (JSValue *)valueWithNewSymbolFromDescription:(NSString *)description inContext:(JSContext *)context
{
    (void)description;
    JSValue *error = [context[@"TypeError"] constructWithArguments:@[@"this release's JavaScript engine has no symbols"]];
    [context charon_noteException:error.JSValueRef];
    return [JSValue valueWithUndefinedInContext:context];
}

- (BOOL)isSymbol
{
    return NO;
}

@end
