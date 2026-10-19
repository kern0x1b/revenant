#import "JSInternal.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>

/*
 * Every symbol this file defines is Charon's own (the charon_/Charon prefix modules/apple/
 * backports.lua's internal_symbol() keys on), never a real SDK name, and that is deliberate: it
 * is the one place in this package that must be kept whole on every band regardless of whether
 * JSValue, JSContext or any other class here gets reexported from the release instead of carried.
 * A helper functions like these two ever needed unconditionally - charon_js_box/unbox, the string
 * bridge, the block- and opaque-object JSClassRefs, the callback frame stack - used to live inside
 * JSValue.m and JSContext.m, the same object files as the JSValue/JSContext classes themselves.
 * Once a band's release genuinely carries JavaScriptCore (iOS 7.0 and later), those two classes
 * are reexported from the system instead of kept, and band() in backports.lua drops their whole
 * object file - taking these helpers down with it, even though JSExportBridge.m (whose own class,
 * CharonExportBinding, is never a real SDK name and so is always kept) calls them unconditionally
 * on every band. That produced "Undefined symbols: _charon_js_box" etc. at write_deb's
 * multi-band link step only - never at a single-release build(), which never reexports anything -
 * confirmed by instrumenting link() directly: kept every JavaScriptCore object on the 6.1.3 band,
 * kept only JSExportBridge.o on the 7.0 band. Moving them here, where nothing but Charon's own
 * names is defined, means band() always keeps this object regardless of what else in the library
 * gets reexported.
 */


JSStringRef charon_js_string(NSString *string)
{
    return JSStringCreateWithCFString((__bridge CFStringRef)(string ?: @""));
}

NSString *charon_ns_string(JSStringRef string)
{
    return string ? CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, string)) : @"";
}

static BOOL IsCFBoolean(id value)
{
    return value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

/*
 * A block's Objective-C type encoding, read as the documented clang Block ABI lays it out
 * (clang's docs/Block-ABI-Apple.rst): a block literal is {isa, flags, reserved, invoke,
 * descriptor}; the descriptor is {reserved, size}, then {copy, dispose} when
 * BLOCK_HAS_COPY_DISPOSE (1 << 25) is set, then the encoding when BLOCK_HAS_SIGNATURE (1 << 30)
 * is. The compiler that built the block writes it there, not the runtime, so the release's
 * libsystem_blocks has no say in it. This is the pointer _Block_signature (an SPI of
 * Block_private.h) answers - measured equal on the host for a global, a capturing and a
 * primitive-typed block - read without the SPI. A block with no signature (built by a compiler
 * older than blocks' extended encodings) answers NULL.
 */
struct CharonBlockDescriptor { unsigned long reserved; unsigned long size; void *rest[]; };
struct CharonBlockLayout { void *isa; int flags; int reserved; void *invoke; struct CharonBlockDescriptor *descriptor; };
enum { CharonBlockHasCopyDispose = 1 << 25, CharonBlockHasSignature = 1 << 30 };

static const char *BlockSignature(id block)
{
    struct CharonBlockLayout *layout = (__bridge void *)block;
    if (!(layout->flags & CharonBlockHasSignature))
        return NULL;
    void **field = layout->descriptor->rest;
    if (layout->flags & CharonBlockHasCopyDispose)
        field += 2;
    return *(const char **)field;
}

typedef enum { CharonTypeVoid, CharonTypeJSValue, CharonTypeId, CharonTypeClass, CharonTypeScalar, CharonTypeUnsupported } CharonTypeKind;
typedef struct { CharonTypeKind kind; __unsafe_unretained Class objcClass; } CharonType;

/* The end of the one type at `cursor`, qualifiers, nesting and trailing offset included. */
static const char *SkipType(const char *cursor)
{
    while (*cursor && strchr("rnNoORVA", *cursor))
        cursor++;
    char open = *cursor, close = open == '{' ? '}' : open == '(' ? ')' : open == '[' ? ']' : 0;
    if (close) {
        int depth = 0;
        do {
            if (*cursor == open)
                depth++;
            else if (*cursor == close)
                depth--;
            cursor++;
        } while (*cursor && depth);
    } else if (open == '^') {
        cursor = SkipType(cursor + 1);
    } else if (open == '@') {
        cursor++;
        if (*cursor == '"') {
            const char *end = strchr(cursor + 1, '"');
            cursor = end ? end + 1 : cursor + strlen(cursor);
        } else if (*cursor == '?') {
            cursor++;
            if (*cursor == '<') {
                const char *end = cursor;
                for (int depth = 0; *end; end++)
                    if (*end == '<')
                        depth++;
                    else if (*end == '>' && !--depth)
                        break;
                cursor = *end ? end + 1 : end;
            }
        }
    } else if (*cursor) {
        cursor++;
    }
    while (*cursor >= '0' && *cursor <= '9')
        cursor++;
    return cursor;
}

/* Which of the four structs JSValue converts `type` (`{CGPoint=dd}`) is, by its name. */
typedef enum { CharonStructNone, CharonStructPoint, CharonStructSize, CharonStructRect, CharonStructRange } CharonStruct;

static CharonStruct StructKind(const char *type)
{
    static const struct { const char *name; CharonStruct kind; } known[] = {
        {"CGPoint", CharonStructPoint}, {"CGSize", CharonStructSize}, {"CGRect", CharonStructRect}, {"_NSRange", CharonStructRange}};
    if (*type != '{')
        return CharonStructNone;
    for (size_t index = 0; index < sizeof(known) / sizeof(known[0]); index++) {
        size_t length = strlen(known[index].name);
        if (!strncmp(type + 1, known[index].name, length) && type[1 + length] == '=')
            return known[index].kind;
    }
    return CharonStructNone;
}

/*
 * One type of a block's extended encoding (`@"NSString"` names the class), classified as the
 * release's own JSContext treats it (measured against the host's, tests/backports/host/jscontext):
 * JSValue, id, any other class - `@"Class<Protocol>"` counts as the class, a bare `@"<Protocol>"`
 * as id; a C number, bool, CGPoint, CGSize, CGRect or NSRange is a scalar; anything else - a
 * block, Class, SEL, a pointer, another struct, a class the runtime does not know - is
 * unsupported, and the release does not make such a block a function at all (`typeof` answers
 * "object").
 */
static const char *SkipQualifiers(const char *cursor)
{
    while (*cursor && strchr("rnNoORVA", *cursor))
        cursor++;
    return cursor;
}

static CharonType ClassifyType(const char *cursor)
{
    cursor = SkipQualifiers(cursor);
    CharonType type = {CharonTypeUnsupported, Nil};
    switch (*cursor) {
    case 'v':
        type.kind = CharonTypeVoid;
        break;
    case '@': {
        if (cursor[1] != '"') {
            type.kind = cursor[1] == '?' ? CharonTypeUnsupported : CharonTypeId;
            break;
        }
        const char *name = cursor + 2;
        size_t length = strcspn(name, "\"<");
        if (!length) {
            type.kind = CharonTypeId;
            break;
        }
        type.objcClass = NSClassFromString([[NSString alloc] initWithBytes:name length:length encoding:NSUTF8StringEncoding]);
        if (type.objcClass)
            type.kind = type.objcClass == [JSValue class] ? CharonTypeJSValue : CharonTypeClass;
        break;
    }
    case 'c': case 'i': case 's': case 'l': case 'q': case 'C': case 'I': case 'S': case 'L': case 'Q':
    case 'f': case 'd': case 'B':
        type.kind = CharonTypeScalar;
        break;
    case '{':
        /* the four structs JSValue converts; any other struct makes no function (measured) */
        if (StructKind(cursor) != CharonStructNone)
            type.kind = CharonTypeScalar;
        break;
    }
    return type;
}

/* Whether a block is a function to JavaScript, from its encoding: its return is void, an object
 * or a scalar, and every argument is a class, id or a scalar. */
static BOOL BlockIsFunction(id block)
{
    const char *cursor = BlockSignature(block);
    if (!cursor)
        return NO;
    CharonTypeKind returned = ClassifyType(cursor).kind;
    /* any object, a block included, is returned boxed */
    if (returned != CharonTypeVoid && returned != CharonTypeScalar && *SkipQualifiers(cursor) != '@')
        return NO;
    cursor = SkipQualifiers(SkipType(cursor));
    if (cursor[0] != '@' || cursor[1] != '?') /* argument 0 is the block itself */
        return NO;
    for (cursor = SkipType(cursor); *cursor; cursor = SkipType(cursor)) {
        CharonTypeKind kind = ClassifyType(cursor).kind;
        if (kind == CharonTypeUnsupported || kind == CharonTypeVoid)
            return NO;
    }
    return YES;
}

/* One JavaScript argument as its declared class wants it, per the release: JSValue takes the
 * value itself, id takes -toObject, a class goes through charon_js_to_class. */
static id ObjectArgument(JSContextRef ctx, JSContext *context, CharonType type, JSValueRef value, JSValueRef *exception)
{
    switch (type.kind) {
    case CharonTypeJSValue:
        return [JSValue charon_valueWithJSValueRef:value context:context];
    case CharonTypeClass:
        return charon_js_to_class(ctx, value, type.objcClass, exception);
    default:
        return charon_js_unbox(ctx, value);
    }
}

id charon_js_argument(JSContextRef context, const char *type, JSValueRef value, JSValueRef *exception)
{
    JSContext *wrapper = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(context) create:YES];
    return ObjectArgument(context, wrapper, ClassifyType(type), value, exception);
}

const char *charon_js_skip_type(const char *type)
{
    return SkipType(type);
}

/*
 * A C number, bool or one of the four structs, as the release's bridge converts it for a block's or
 * JSExport method's argument (ObjCCallbackFunction.mm, CallbackArgument*; measured on the host for
 * thirteen types against twenty-seven values): char, short, int, long and their unsigned forms take
 * ECMAScript ToInt32 of the number, cast to the type; long long, unsigned long long, float and
 * double take the number cast to the type; bool takes ToBoolean; CGPoint, CGSize, CGRect and
 * NSRange take -toPoint, -toSize, -toRect and -toRange. A number whose valueOf or toString throws
 * leaves the exception in *exception and sets nothing. NO for any other type.
 */
BOOL charon_js_set_scalar_argument(NSInvocation *invocation, NSUInteger index, const char *type, JSContextRef ctx, JSValueRef value, JSValueRef *exception)
{
    type = SkipQualifiers(type);
    double number = 0;
    if (*type && strchr("cislCISLqQfd", *type)) {
        number = JSValueToNumber(ctx, value, exception);
        if (*exception)
            return YES;
    }
    int32_t integer = (int32_t)charon_js_uint32(number);
#define CHARON_SET(T, v) do { T set = (T)(v); [invocation setArgument:&set atIndex:index]; } while (0)
    switch (*type) {
    case 'c': CHARON_SET(char, integer); return YES;
    case 's': CHARON_SET(short, integer); return YES;
    case 'i': CHARON_SET(int, integer); return YES;
    case 'l': CHARON_SET(long, integer); return YES;
    case 'C': CHARON_SET(unsigned char, integer); return YES;
    case 'S': CHARON_SET(unsigned short, integer); return YES;
    case 'I': CHARON_SET(unsigned int, integer); return YES;
    case 'L': CHARON_SET(unsigned long, integer); return YES;
    /* the release's own cast, out of range and NaN included, as its compiler makes it for this architecture */
    case 'q': CHARON_SET(long long, number); return YES;
    case 'Q': CHARON_SET(unsigned long long, number); return YES;
    case 'f': CHARON_SET(float, number); return YES;
    case 'd': CHARON_SET(double, number); return YES;
    case 'B': CHARON_SET(bool, JSValueToBoolean(ctx, value)); return YES;
    }
#undef CHARON_SET
    CharonStruct kind = StructKind(type);
    if (kind == CharonStructNone)
        return NO;
    JSContext *context = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES];
    JSValue *wrapped = [JSValue charon_valueWithJSValueRef:value context:context];
    switch (kind) {
    case CharonStructPoint: { CGPoint point = wrapped.toPoint; [invocation setArgument:&point atIndex:index]; break; }
    case CharonStructSize: { CGSize size = wrapped.toSize; [invocation setArgument:&size atIndex:index]; break; }
    case CharonStructRect: { CGRect rect = wrapped.toRect; [invocation setArgument:&rect atIndex:index]; break; }
    case CharonStructRange: { NSRange range = wrapped.toRange; [invocation setArgument:&range atIndex:index]; break; }
    case CharonStructNone: break;
    }
    return YES;
}

/*
 * What an invocation returned, as the release's bridge gives it to JavaScript (CallbackResult*):
 * void is undefined, an object is boxed, a C number is that number (a char included), bool is a
 * boolean, the four structs are JSValue's +valueWithPoint:... objects.
 */
JSValueRef charon_js_invocation_result(NSInvocation *invocation, const char *type, JSContextRef ctx)
{
    type = SkipQualifiers(type);
#define CHARON_GET(T) do { T got = 0; [invocation getReturnValue:&got]; return JSValueMakeNumber(ctx, (double)got); } while (0)
    switch (*type) {
    case 'v': return JSValueMakeUndefined(ctx);
    case '@':
    case '#': {
        __unsafe_unretained id object = nil;
        [invocation getReturnValue:&object];
        return charon_js_box(ctx, object);
    }
    case 'c': CHARON_GET(char);
    case 's': CHARON_GET(short);
    case 'i': CHARON_GET(int);
    case 'l': CHARON_GET(long);
    case 'q': CHARON_GET(long long);
    case 'C': CHARON_GET(unsigned char);
    case 'S': CHARON_GET(unsigned short);
    case 'I': CHARON_GET(unsigned int);
    case 'L': CHARON_GET(unsigned long);
    case 'Q': CHARON_GET(unsigned long long);
    case 'f': CHARON_GET(float);
    case 'd': CHARON_GET(double);
    case 'B': {
        bool got = false;
        [invocation getReturnValue:&got];
        return JSValueMakeBoolean(ctx, got);
    }
    }
#undef CHARON_GET
    JSContext *context = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES];
    switch (StructKind(type)) {
    case CharonStructPoint: { CGPoint point; [invocation getReturnValue:&point]; return [JSValue valueWithPoint:point inContext:context].JSValueRef; }
    case CharonStructSize: { CGSize size; [invocation getReturnValue:&size]; return [JSValue valueWithSize:size inContext:context].JSValueRef; }
    case CharonStructRect: { CGRect rect; [invocation getReturnValue:&rect]; return [JSValue valueWithRect:rect inContext:context].JSValueRef; }
    case CharonStructRange: { NSRange range; [invocation getReturnValue:&range]; return [JSValue valueWithRange:range inContext:context].JSValueRef; }
    case CharonStructNone: break;
    }
    return JSValueMakeUndefined(ctx);
}

/*
 * The block's encoding as NSMethodSignature documents its input: plain Objective-C type encodings,
 * without the class names (`@"NSString"`) and block signatures (`@?<v@?>`) of the extended form.
 */
static NSMethodSignature *BlockMethodSignature(const char *extended)
{
    size_t length = strlen(extended);
    char *plain = malloc(length + 1), *out = plain;
    for (const char *cursor = extended; *cursor;) {
        if (cursor[0] == '@' && cursor[1] == '"') {
            *out++ = '@';
            const char *end = strchr(cursor + 2, '"');
            cursor = end ? end + 1 : cursor + strlen(cursor);
        } else if (cursor[0] == '@' && cursor[1] == '?' && cursor[2] == '<') {
            *out++ = '@';
            *out++ = '?';
            cursor += 2;
            for (int depth = 0; *cursor; cursor++) {
                if (*cursor == '<')
                    depth++;
                else if (*cursor == '>' && !--depth) {
                    cursor++;
                    break;
                }
            }
        } else {
            *out++ = *cursor++;
        }
    }
    *out = 0;
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:plain];
    free(plain);
    return signature;
}

/*
 * A block is exported as a JS function through one shared JSClassRef, whose private data on
 * each JSObjectRef is the retained block. It is called as the release calls it: through an
 * NSInvocation whose target is the block (ObjCCallbackFunction.mm, CallbackBlock), which carries
 * every C type the encoding names. Object arguments are converted by the class the encoding
 * declares, the others by charon_js_set_scalar_argument; a missing argument is undefined.
 */
static JSValueRef CallBlock(JSContextRef ctx, JSObjectRef function, JSObjectRef _Nullable thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    id block = (__bridge id)JSObjectGetPrivate(function);
    JSContext *context = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES];
    const char *encoding = BlockSignature(block);
    NSMethodSignature *signature = BlockMethodSignature(encoding);
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    /* -setArgument:atIndex: copies bytes only; an object converted below must outlive -invoke */
    [invocation retainArguments];
    invocation.target = block;
    const char *cursor = SkipType(SkipType(encoding)); /* past the return type and the block itself */
    for (NSUInteger index = 1; index < signature.numberOfArguments; index++, cursor = SkipType(cursor)) {
        JSValueRef value = index - 1 < argumentCount ? arguments[index - 1] : JSValueMakeUndefined(ctx);
        JSValueRef failure = NULL;
        CharonType type = ClassifyType(cursor);
        if (type.kind == CharonTypeScalar) {
            charon_js_set_scalar_argument(invocation, index, [signature getArgumentTypeAtIndex:index], ctx, value, &failure);
        } else {
            id object = ObjectArgument(ctx, context, type, value, &failure);
            if (!failure)
                [invocation setArgument:&object atIndex:index];
        }
        if (failure) {
            if (exception)
                *exception = failure;
            return JSValueMakeUndefined(ctx);
        }
    }
    NSMutableArray<JSValue *> *callArguments = [NSMutableArray arrayWithCapacity:argumentCount];
    for (size_t index = 0; index < argumentCount; index++)
        [callArguments addObject:[JSValue charon_valueWithJSValueRef:arguments[index] context:context]];
    JSValue *thisValue = thisObject ? [JSValue charon_valueWithJSValueRef:thisObject context:context] : nil;
    charon_js_push_callback(context, thisValue, [JSValue charon_valueWithJSValueRef:function context:context], callArguments);
    [invocation invoke];
    JSValue *thrown = charon_js_pop_callback();
    if (thrown) {
        if (exception)
            *exception = thrown.JSValueRef;
        return JSValueMakeUndefined(ctx);
    }
    return charon_js_invocation_result(invocation, signature.methodReturnType, ctx);
}

static void BlockFinalize(JSObjectRef object)
{
    charon_js_release_soon(JSObjectGetPrivate(object));
}

static JSValueRef BlockCallAsFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    return CallBlock(ctx, function, thisObject, argumentCount, arguments, exception);
}

/* `new` on a block, as the release allows it: the block runs with no `this`, and what it returns
 * must be an object. */
static JSObjectRef BlockCallAsConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    JSValueRef failure = NULL;
    JSValueRef result = CallBlock(ctx, constructor, NULL, argumentCount, arguments, &failure);
    if (!failure && !JSValueIsObject(ctx, result))
        failure = charon_js_type_error(ctx, @"Objective-C blocks called as constructors must return an object.");
    if (failure) {
        if (exception)
            *exception = failure;
        return NULL;
    }
    return (JSObjectRef)result;
}

static void DefineHidden(JSContextRef ctx, JSObjectRef object, const char *name, JSValueRef value, JSPropertyAttributes attributes)
{
    JSStringRef string = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, object, string, value, attributes | kJSPropertyAttributeDontEnum, NULL);
    JSStringRelease(string);
}

/*
 * A block's function is a function to script, as the release's is (measured on the host): it has
 * a read-only `length` of 0 and `name` of "" and a `prototype` object of its own, and its
 * prototype is the context's Function.prototype, so call, apply and bind work. The properties go
 * on first, while nothing read-only of that prototype's shadows them. Function.prototype is read
 * off a function the engine itself makes, so a script that replaced the global Function changes
 * nothing. JSObjectMake sets a new object's prototype after the class's initialize callback, so
 * this runs once the wrapper is made (charon_js_wrapper_made).
 */
static void MakeBlockFunction(JSContextRef ctx, JSObjectRef object)
{
    DefineHidden(ctx, object, "length", JSValueMakeNumber(ctx, 0), kJSPropertyAttributeReadOnly);
    JSStringRef empty = JSStringCreateWithUTF8CString("");
    DefineHidden(ctx, object, "name", JSValueMakeString(ctx, empty), kJSPropertyAttributeReadOnly);
    JSStringRelease(empty);
    DefineHidden(ctx, object, "prototype", JSObjectMake(ctx, NULL, NULL), kJSPropertyAttributeNone);
    JSObjectSetPrototype(ctx, object, JSObjectGetPrototype(ctx, JSObjectMakeFunctionWithCallback(ctx, NULL, NULL)));
}

static JSClassRef BlockClass(void)
{
    static JSClassRef blockClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "Function";
        definition.callAsFunction = BlockCallAsFunction;
        definition.callAsConstructor = BlockCallAsConstructor;
        definition.finalize = BlockFinalize;
        blockClass = JSClassCreate(&definition);
    });
    return blockClass;
}

/* An opaque wrapper for a plain Objective-C object that JSExport does not describe: it round
 * trips through -toObject, but exposes no properties or methods to JavaScript. */
static void OpaqueFinalize(JSObjectRef object)
{
    charon_js_release_soon(JSObjectGetPrivate(object));
}

void charon_js_wrapper_made(JSContextRef context, JSObjectRef wrapper, JSClassRef jsClass)
{
    if (jsClass == BlockClass())
        MakeBlockFunction(context, wrapper);
}

static JSClassRef OpaqueClass(void)
{
    static JSClassRef opaqueClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "CharonOpaqueObject";
        definition.finalize = OpaqueFinalize;
        opaqueClass = JSClassCreate(&definition);
    });
    return opaqueClass;
}

id charon_js_wrapped_object(JSContextRef context, JSValueRef value)
{
    if (!JSValueIsObjectOfClass(context, value, BlockClass()) && !JSValueIsObjectOfClass(context, value, OpaqueClass()) &&
        !JSValueIsObjectOfClass(context, value, charon_js_export_class()))
        return nil;
    return (__bridge id)JSObjectGetPrivate((JSObjectRef)value);
}

static JSObjectRef Wrapper(JSContextRef context, id object, JSClassRef jsClass)
{
    JSContext *wrapper = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(context) create:YES];
    return [wrapper.virtualMachine charon_wrapperOf:object class:jsClass context:context];
}

JSValueRef charon_js_box(JSContextRef context, id object)
{
    if (!object)
        return JSValueMakeUndefined(context);
    /* a JSValue passed back in as a plain `id` is already a JavaScript value - unwrap it rather
     * than wrapping the wrapper as a fresh opaque object */
    if ([object isKindOfClass:[JSValue class]])
        return ((JSValue *)object).JSValueRef;
    if (object == (id)kCFNull || [object isKindOfClass:[NSNull class]])
        return JSValueMakeNull(context);
    if (IsCFBoolean(object))
        return JSValueMakeBoolean(context, [object boolValue]);
    if ([object isKindOfClass:[NSNumber class]])
        return JSValueMakeNumber(context, [object doubleValue]);
    if ([object isKindOfClass:[NSString class]]) {
        JSStringRef string = charon_js_string(object);
        JSValueRef value = JSValueMakeString(context, string);
        JSStringRelease(string);
        return value;
    }
    if ([object isKindOfClass:[NSDate class]])
        return JSObjectMakeDate(context, 1, (const JSValueRef[]){JSValueMakeNumber(context, [(NSDate *)object timeIntervalSince1970] * 1000.0)}, NULL);
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        NSUInteger count = array.count;
        JSValueRef *values = count ? malloc(sizeof(JSValueRef) * count) : NULL;
        for (NSUInteger index = 0; index < count; index++)
            values[index] = charon_js_box(context, array[index]);
        JSValueRef result = JSObjectMakeArray(context, count, values, NULL);
        free(values);
        return result;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        JSObjectRef result = JSObjectMake(context, NULL, NULL);
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            JSStringRef name = charon_js_string([key description]);
            JSObjectSetProperty(context, result, name, charon_js_box(context, value), kJSPropertyAttributeNone, NULL);
            JSStringRelease(name);
        }];
        return result;
    }
    if ([object isKindOfClass:NSClassFromString(@"NSBlock")])
        return Wrapper(context, object, BlockIsFunction(object) ? BlockClass() : OpaqueClass());
    if (charon_js_class_conforms_to_export(object_getClass(object)))
        return Wrapper(context, object, charon_js_export_class());
    return Wrapper(context, object, OpaqueClass());
}

JSValueRef charon_js_type_error(JSContextRef context, NSString *message)
{
    JSContext *wrapper = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(context) create:YES];
    return [wrapper[@"TypeError"] constructWithArguments:@[message]].JSValueRef;
}

/* Object.prototype.toString of the object `value` (classOf) or Array.isArray(value), both the
 * virtual machine's own. Neither can throw for an object (ES5 15.2.4.2, 15.4.3.2). */
static JSValueRef AskOwnContext(JSContextRef context, JSValueRef value, BOOL classOf)
{
    JSVirtualMachine *machine = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(context) create:YES].virtualMachine;
    JSObjectRef isArray, toString;
    JSGlobalContextRef own = [machine charon_ownContextIsArray:&isArray classOf:&toString];
    return classOf ? JSObjectCallAsFunction(own, toString, (JSObjectRef)value, 0, NULL, NULL)
                   : JSObjectCallAsFunction(own, isArray, NULL, 1, &value, NULL);
}

BOOL charon_js_is_array(JSContextRef context, JSValueRef value)
{
    return JSValueIsObject(context, value) && JSValueToBoolean(context, AskOwnContext(context, value, NO));
}

BOOL charon_js_is_date(JSContextRef context, JSValueRef value)
{
    if (!JSValueIsObject(context, value))
        return NO;
    JSStringRef tag = JSValueToStringCopy(context, AskOwnContext(context, value, YES), NULL);
    BOOL date = JSStringIsEqualToUTF8CString(tag, "[object Date]");
    JSStringRelease(tag);
    return date;
}

uint32_t charon_js_uint32(double value)
{
    if (!(value == value) || isinf(value))
        return 0;
    return (uint32_t)(int64_t)fmod(trunc(value), 4294967296.0);
}

/*
 * JSValue's container conversion, walked as the release's JSContainerConvertor walks it: every
 * object met is recorded once against the Objective-C object made for it, so a cycle or a shared
 * reference answers that same object (`d[@"self"] == d`), and containers are filled from a
 * worklist rather than by recursion, so depth costs no stack. null is NSNull wherever it stands;
 * undefined is nil at the top, NSNull in an array, and left out of a dictionary. An array is read
 * by its length, anything else by its enumerable property names, inherited ones included. A
 * getter that throws is passed over and the exception reported nowhere, as the release does
 * (measured: its handler is not called). Each recorded value is protected until the walk ends,
 * since the map and worklist live on the heap where the collector does not look.
 */
typedef struct {
    JSContextRef context;
    NSMapTable *seen;              /* JSValueRef -> the Objective-C object made for it */
    NSPointerArray *pendingValues; /* worklist: the containers still to fill ... */
    NSMutableArray *pendingObjects; /* ... and their JavaScript objects, by index */
} CharonConvertor;

static void ConvertorRecord(CharonConvertor *convertor, JSValueRef value, id object, BOOL fill)
{
    JSValueProtect(convertor->context, value);
    [convertor->seen setObject:object forKey:(__bridge id)(void *)value];
    if (fill) {
        [convertor->pendingValues addPointer:(void *)value];
        [convertor->pendingObjects addObject:object];
    }
}

static id ConvertorConvert(CharonConvertor *convertor, JSValueRef value)
{
    JSContextRef context = convertor->context;
    switch (JSValueGetType(context, value)) {
    case kJSTypeUndefined:
        return nil;
    case kJSTypeNull:
        return [NSNull null];
    case kJSTypeBoolean:
        return @(JSValueToBoolean(context, value));
    case kJSTypeNumber:
        return @(JSValueToNumber(context, value, NULL));
    case kJSTypeString: {
        JSStringRef string = JSValueToStringCopy(context, value, NULL);
        NSString *result = charon_ns_string(string);
        JSStringRelease(string);
        return result;
    }
    default:
        break;
    }
    id known = [convertor->seen objectForKey:(__bridge id)(void *)value];
    if (known)
        return known;
    id object = charon_js_wrapped_object(context, value);
    BOOL fill = NO;
    if (object) {
    } else if (charon_js_is_date(context, value)) {
        object = [NSDate dateWithTimeIntervalSince1970:JSValueToNumber(context, value, NULL) / 1000.0];
    } else if (charon_js_is_array(context, value)) {
        object = [NSMutableArray array];
        fill = YES;
    } else {
        object = [NSMutableDictionary dictionary];
        fill = YES;
    }
    ConvertorRecord(convertor, value, object, fill);
    return object;
}

static void ConvertorFill(CharonConvertor *convertor, JSObjectRef object, id container)
{
    JSContextRef context = convertor->context;
    if ([container isKindOfClass:[NSMutableArray class]]) {
        JSStringRef lengthName = charon_js_string(@"length");
        uint32_t length = charon_js_uint32(JSValueToNumber(context, JSObjectGetProperty(context, object, lengthName, NULL), NULL));
        JSStringRelease(lengthName);
        for (uint32_t index = 0; index < length; index++) {
            JSValueRef thrown = NULL;
            JSValueRef value = JSObjectGetPropertyAtIndex(context, object, index, &thrown);
            [container addObject:(thrown ? nil : ConvertorConvert(convertor, value)) ?: [NSNull null]];
        }
        return;
    }
    JSPropertyNameArrayRef names = JSObjectCopyPropertyNames(context, object);
    size_t count = JSPropertyNameArrayGetCount(names);
    for (size_t index = 0; index < count; index++) {
        JSStringRef name = JSPropertyNameArrayGetNameAtIndex(names, index);
        JSValueRef thrown = NULL;
        JSValueRef property = JSObjectGetProperty(context, object, name, &thrown);
        id value = thrown ? nil : ConvertorConvert(convertor, property);
        if (value)
            container[charon_ns_string(name)] = value;
    }
    JSPropertyNameArrayRelease(names);
}

/* Convert `value`; a non-nil `container` is the top's container, filled as `value` read that way. */
static id Convert(JSContextRef context, JSValueRef value, id container)
{
    CharonConvertor convertor = {
        context,
        [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality valueOptions:NSPointerFunctionsStrongMemory],
        [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality],
        [NSMutableArray array],
    };
    id result = container;
    if (container)
        ConvertorRecord(&convertor, value, container, YES);
    else
        result = ConvertorConvert(&convertor, value);
    for (NSUInteger next = 0; next < convertor.pendingObjects.count; next++)
        ConvertorFill(&convertor, (JSObjectRef)[convertor.pendingValues pointerAtIndex:next], convertor.pendingObjects[next]);
    for (id key in convertor.seen)
        JSValueUnprotect(context, (__bridge void *)key);
    return result;
}

id charon_js_unbox(JSContextRef context, JSValueRef value)
{
    return value ? Convert(context, value, nil) : nil;
}

/* -toArray and -toDictionary: any object is read as the container asked for, undefined and null
 * are nil, and any other primitive is a TypeError, as the release words it. */
static id ToContainer(JSContextRef context, JSValueRef value, Class containerClass, JSValueRef *exception)
{
    id wrapped = charon_js_wrapped_object(context, value);
    if ([wrapped isKindOfClass:containerClass])
        return wrapped;
    BOOL array = containerClass == [NSArray class];
    if (JSValueIsObject(context, value))
        return Convert(context, value, array ? [NSMutableArray array] : [NSMutableDictionary dictionary]);
    if (!JSValueIsNull(context, value) && !JSValueIsUndefined(context, value))
        *exception = charon_js_type_error(context, array ? @"Cannot convert primitive to NSArray" : @"Cannot convert primitive to NSDictionary");
    return nil;
}

NSArray *charon_js_to_array(JSContextRef context, JSValueRef value, JSValueRef *exception)
{
    return ToContainer(context, value, [NSArray class], exception);
}

NSDictionary *charon_js_to_dictionary(JSContextRef context, JSValueRef value, JSValueRef *exception)
{
    return ToContainer(context, value, [NSDictionary class], exception);
}

NSString *charon_js_to_string(JSContextRef context, JSValueRef value, JSValueRef *exception)
{
    id wrapped = charon_js_wrapped_object(context, value);
    if ([wrapped isKindOfClass:[NSString class]])
        return wrapped;
    JSStringRef string = JSValueToStringCopy(context, value, exception);
    if (!string)
        return nil;
    NSString *result = charon_ns_string(string);
    JSStringRelease(string);
    return result;
}

NSNumber *charon_js_to_number(JSContextRef context, JSValueRef value, JSValueRef *exception)
{
    id wrapped = charon_js_wrapped_object(context, value);
    if ([wrapped isKindOfClass:[NSNumber class]])
        return wrapped;
    if (JSValueIsBoolean(context, value))
        return @(JSValueToBoolean(context, value));
    double number = JSValueToNumber(context, value, exception);
    return @(*exception ? NAN : number);
}

NSDate *charon_js_to_date(JSContextRef context, JSValueRef value, JSValueRef *exception)
{
    id wrapped = charon_js_wrapped_object(context, value);
    if ([wrapped isKindOfClass:[NSDate class]])
        return wrapped;
    double milliseconds = JSValueToNumber(context, value, exception);
    return *exception ? nil : [NSDate dateWithTimeIntervalSince1970:milliseconds / 1000.0];
}

id charon_js_to_class(JSContextRef context, JSValueRef value, Class objcClass, JSValueRef *exception)
{
    if (objcClass == [NSString class])
        return charon_js_to_string(context, value, exception);
    if (objcClass == [NSNumber class])
        return charon_js_to_number(context, value, exception);
    if (objcClass == [NSDate class])
        return charon_js_to_date(context, value, exception);
    if (objcClass == [NSArray class])
        return charon_js_to_array(context, value, exception);
    if (objcClass == [NSDictionary class])
        return charon_js_to_dictionary(context, value, exception);
    id wrapped = charon_js_wrapped_object(context, value);
    if ([wrapped isKindOfClass:objcClass])
        return wrapped;
    if (!JSValueIsNull(context, value) && !JSValueIsUndefined(context, value))
        *exception = charon_js_type_error(context, @"Argument does not match Objective-C Class");
    return nil;
}

/*
 * +currentContext, +currentThis, +currentCallee and +currentArguments only answer from inside a
 * callback JavaScript makes into Objective-C - a block or a JSExport method. A pthread key holds
 * a small stack of frames, one push per nested callback, so a callback that itself calls back
 * into JavaScript which calls back into Objective-C again still answers correctly for its own
 * frame once the inner one pops.
 */
static pthread_key_t charon_frame_key;
static pthread_once_t charon_frame_once = PTHREAD_ONCE_INIT;

static void CharonMakeFrameKey(void)
{
    pthread_key_create(&charon_frame_key, NULL);
}

CharonJSFrame *CharonCurrentFrame(void)
{
    pthread_once(&charon_frame_once, CharonMakeFrameKey);
    return pthread_getspecific(charon_frame_key);
}

/*
 * One queue of contexts with jobs per thread, and the level of calls into script the thread is
 * at. A context and its drain function are kept (JSGlobalContextRetain, JSValueProtect) from the
 * moment its first job is queued until its drain has run.
 */
typedef struct CharonPendingJobs {
    struct CharonPendingJobs *next;
    JSGlobalContextRef context;
    JSObjectRef drain;
} CharonPendingJobs;

typedef struct CharonReleaseNode {
    struct CharonReleaseNode *next;
    const void *object;
} CharonReleaseNode;

typedef struct CharonJobState {
    unsigned depth;   /* every level of script on this thread's stack: ours and a callback's */
    unsigned entered; /* the levels this port entered itself (charon_js_enter), which a leave ends */
    BOOL scheduled;   /* a run loop turn of this thread is to drain the queue */
    CharonPendingJobs *first;
    CharonPendingJobs *last;
    CharonReleaseNode *releases; /* what this thread's finalizers gave up, oldest first */
    CharonReleaseNode *lastRelease;
} CharonJobState;

static void ReleaseQueued(CharonJobState *state);

static pthread_key_t charon_jobs_key;
static pthread_once_t charon_jobs_once = PTHREAD_ONCE_INIT;

static void CharonFreeJobs(void *value)
{
    CharonJobState *state = value;
    ReleaseQueued(state);
    for (CharonPendingJobs *pending = state->first, *next; pending; pending = next) {
        next = pending->next;
        JSValueUnprotect(pending->context, pending->drain);
        JSGlobalContextRelease(pending->context);
        free(pending);
    }
    free(state);
}

static void CharonMakeJobsKey(void)
{
    pthread_key_create(&charon_jobs_key, CharonFreeJobs);
}

static CharonJobState *CharonJobs(void)
{
    pthread_once(&charon_jobs_once, CharonMakeJobsKey);
    CharonJobState *state = pthread_getspecific(charon_jobs_key);
    if (!state) {
        state = calloc(1, sizeof(CharonJobState));
        pthread_setspecific(charon_jobs_key, state);
    }
    return state;
}

/*
 * Objects whose wrappers the collector finalized, waiting to be released outside the collection.
 * A finalizer must call nothing that may collect or allocate, "all functions that have a
 * JSContextRef parameter" included (JSObjectRef.h, JSObjectFinalizeCallback), and on the release's
 * engine (2012) a finalizer runs inside whichever allocation sweeps its block (measured on the iPad
 * 2: inside JSObjectMake); the last release of a wrapped object runs its -dealloc, which may reach
 * the C API (a JSValue, a JSManagedValue, a graph token of JSVirtualMachine). The release's bridge
 * hands such objects to the heap to release after the collection, on the thread that collected
 * (WebKit's Heap::releaseSoon); the C API has no end-of-collection hook, so each thread keeps its
 * own queue here, and releases what its finalizers queued at its own next outermost leave or next
 * run loop turn, whichever comes first, and at its exit. A thread that has no run loop and never
 * calls into script again keeps what it queued until it exits.
 */
void charon_js_release_soon(const void *object)
{
    CharonJobState *state = CharonJobs();
    CharonReleaseNode *node = malloc(sizeof(CharonReleaseNode));
    node->next = NULL;
    node->object = object;
    BOOL wasEmpty = !state->releases;
    if (state->lastRelease)
        state->lastRelease->next = node;
    else
        state->releases = node;
    state->lastRelease = node;
    if (wasEmpty) {
        CFRunLoopRef loop = CFRunLoopGetCurrent();
        CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
            charon_js_release_pending();
        });
        CFRunLoopWakeUp(loop);
    }
}

/* Each release in a pool of its own; a -dealloc that finalizes more queues it here, taken in turn. */
static void ReleaseQueued(CharonJobState *state)
{
    while (state->releases) {
        CharonReleaseNode *node = state->releases;
        state->releases = node->next;
        if (!state->releases)
            state->lastRelease = NULL;
        @autoreleasepool {
            CFRelease(node->object);
        }
        free(node);
    }
}

void charon_js_release_pending(void)
{
    ReleaseQueued(CharonJobs());
}

void charon_js_push_callback(JSContext *context, JSValue *thisValue, JSValue *callee, NSArray<JSValue *> *arguments)
{
    pthread_once(&charon_frame_once, CharonMakeFrameKey);
    CharonJSFrame *frame = calloc(1, sizeof(CharonJSFrame));
    frame->up = CharonCurrentFrame();
    frame->context = CFBridgingRetain(context);
    frame->thisValue = thisValue ? CFBridgingRetain(thisValue) : NULL;
    frame->callee = callee ? CFBridgingRetain(callee) : NULL;
    frame->arguments = arguments ? CFBridgingRetain(arguments) : NULL;
    JSValue *preserved = context.exception;
    frame->preservedException = preserved ? (void *)CFBridgingRetain(preserved) : NULL;
    context.exception = nil;
    pthread_setspecific(charon_frame_key, frame);
    CharonJobs()->depth++;
}

JSValue *charon_js_pop_callback(void)
{
    CharonJSFrame *frame = CharonCurrentFrame();
    if (!frame)
        return nil;
    CharonJobs()->depth--;
    pthread_setspecific(charon_frame_key, frame->up);
    JSContext *context = CFBridgingRelease(frame->context);
    JSValue *thrown = context.exception;
    context.exception = frame->preservedException ? CFBridgingRelease(frame->preservedException) : nil;
    for (const void *held[] = {frame->thisValue, frame->callee, frame->arguments}, **each = held; each < held + 3; each++)
        if (*each)
            CFRelease(*each);
    free(frame);
    return thrown;
}

void charon_js_enter(void)
{
    CharonJobState *state = CharonJobs();
    state->depth++;
    state->entered++;
}

/*
 * Script this port did not enter - a direct C API call, a web view's own page - has no leave of
 * ours to run its jobs at, and neither has a callback such script makes: the callback's own calls
 * into script are levels of ours, but the last of them ends with the caller's script still on the
 * stack, where no job may run. The thread's run loop runs them on its next turn instead. The
 * release runs them as the outermost C API call returns, which nothing outside the engine sees.
 */
static void ScheduleDrain(CharonJobState *state)
{
    if (state->scheduled)
        return;
    state->scheduled = YES;
    CFRunLoopRef loop = CFRunLoopGetCurrent();
    CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
        CharonJobs()->scheduled = NO;
        charon_js_enter();
        charon_js_leave();
    });
    CFRunLoopWakeUp(loop);
}

void charon_js_note_jobs(JSContextRef context, JSObjectRef drain)
{
    CharonJobState *state = CharonJobs();
    CharonPendingJobs *pending = calloc(1, sizeof(CharonPendingJobs));
    pending->context = JSGlobalContextRetain(JSContextGetGlobalContext(context));
    pending->drain = drain;
    JSValueProtect(pending->context, drain);
    if (state->last)
        state->last->next = pending;
    else
        state->first = pending;
    state->last = pending;
    if (!state->entered)
        ScheduleDrain(state);
}

void charon_js_leave(void)
{
    CharonJobState *state = CharonJobs();
    state->entered--;
    if (--state->depth) {
        if (!state->entered && state->first)
            ScheduleDrain(state);
        return;
    }
    /* The drains run a level deep, so a call they make into script and back leaves them alone. */
    state->depth++;
    state->entered++;
    while (state->first) {
        CharonPendingJobs *pending = state->first;
        state->first = pending->next;
        if (!state->first)
            state->last = NULL;
        JSValueRef exception = NULL;
        JSObjectCallAsFunction(pending->context, pending->drain, NULL, 0, NULL, &exception);
        if (exception)
            [[JSContext charon_wrapperForGlobalContext:pending->context create:YES] charon_noteException:exception];
        JSValueUnprotect(pending->context, pending->drain);
        JSGlobalContextRelease(pending->context);
        free(pending);
    }
    state->depth--;
    state->entered--;
    charon_js_release_pending();
}
