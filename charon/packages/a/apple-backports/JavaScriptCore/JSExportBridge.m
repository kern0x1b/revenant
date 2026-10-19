#import "JSInternal.h"
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

/*
 * JSExport turns a protocol's required properties and instance methods into a JavaScript
 * wrapper's own properties and functions. One JSClassRef, shared by every JSExport-conforming
 * object regardless of its own Objective-C class, does the dispatch: its getProperty callback
 * looks the requested name up in a per-class table (built once, from protocol_copyPropertyList
 * and protocol_copyMethodDescriptionList over every JSExport-incorporating protocol the class or
 * its superclasses conform to) and either reads a property through the real accessor or hands
 * back a bound function that calls the real method - both through the object's own
 * -methodSignatureForSelector:, not a re-derivation of the protocol's encoding, so the argument
 * and return types marshaled are the ones the class actually implements.
 *
 * Supported argument and return types: id and Objective-C instance pointers, BOOL, the C integer
 * types up to 64 bits, float and double, and the four structs JSValue itself converts - CGPoint,
 * CGRect, CGSize, NSRange. A method outside that set is still exported - calling it from
 * JavaScript throws rather than reading an argument off the wrong-sized slot.
 */

/*
 * argumentTypes points at the first argument's type in the entry's extended type encoding - the
 * form that names each argument's class, which the release converts arguments by - or is NULL
 * when there is none, and the arguments are then converted as id. A method's comes from
 * _protocol_getMethodTypeEncoding, an SPI of objc-runtime's private header: the public
 * protocol_getMethodDescription answers the plain encoding, with every class reduced to `@`, and
 * no public call answers the extended one. The release's own bridge (WebKit's ObjCCallbackFunction)
 * reads it the same way; iOS 6's libobjc exports it (coordination/corpus/caches/6.0.tsv). A
 * property setter's is the property's own type, public through property_getAttributes. Both
 * strings belong to the runtime and live as long as the protocol.
 */
typedef struct {
    SEL selector;
    BOOL isMethod;
    const char *argumentTypes;
} CharonExportEntry;

extern const char *_protocol_getMethodTypeEncoding(Protocol *protocol, SEL selector, BOOL isRequiredMethod, BOOL isInstanceMethod);

/* The first argument's type in a method's extended encoding: past the return type, self and _cmd. */
static const char *MethodArgumentTypes(Protocol *protocol, SEL selector)
{
    const char *types = _protocol_getMethodTypeEncoding(protocol, selector, YES, YES);
    if (!types)
        return NULL;
    for (int skip = 0; skip < 3 && *types; skip++)
        types = charon_js_skip_type(types);
    return types;
}

@interface CharonExportBinding : NSObject
@property (nonatomic, strong) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) const char *argumentTypes;
@end

@implementation CharonExportBinding
@synthesize target = _target;
@synthesize selector = _selector;
@synthesize argumentTypes = _argumentTypes;
@end

static NSMapTable<Class, NSDictionary *> *ExportTables(void)
{
    static NSMapTable<Class, NSDictionary *> *tables;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tables = [NSMapTable strongToStrongObjectsMapTable];
    });
    return tables;
}

static NSString *JavaScriptNameForSelector(NSString *selectorName)
{
    /* doFoo:withBar: -> doFooWithBar, per JSExport.h's default conversion */
    NSArray<NSString *> *pieces = [selectorName componentsSeparatedByString:@":"];
    if (pieces.count <= 1)
        return selectorName;
    NSMutableString *name = [pieces[0] mutableCopy];
    for (NSUInteger index = 1; index < pieces.count; index++) {
        NSString *piece = pieces[index];
        if (piece.length == 0)
            continue;
        [name appendString:[[piece substringToIndex:1] uppercaseString]];
        [name appendString:[piece substringFromIndex:1]];
    }
    return name;
}

/*
 * JSExportAs(name, selector) expands to an @optional method that is the @required one with one
 * more keyword appended, "__JS_EXPORT_AS__<name>:(id)argument" - so
 * JSExportAs(doFoo, - (void)doFoo:(id)foo withBar:(id)bar) declares the @optional selector
 * doFoo:withBar:__JS_EXPORT_AS__doFoo: alongside the @required doFoo:withBar:. Recovering the
 * rename means finding that trailing keyword and dropping it to name the @required selector it
 * decorates.
 */
static void CollectRenames(Protocol *protocol, NSMutableDictionary<NSString *, NSString *> *renames)
{
    unsigned optionalCount = 0;
    struct objc_method_description *optional = protocol_copyMethodDescriptionList(protocol, NO, YES, &optionalCount);
    for (unsigned index = 0; index < optionalCount; index++) {
        NSArray<NSString *> *keywords = [NSStringFromSelector(optional[index].name) componentsSeparatedByString:@":"];
        if (keywords.count < 2)
            continue;
        NSString *marker = keywords[keywords.count - 2];
        if (![marker hasPrefix:@"__JS_EXPORT_AS__"])
            continue;
        NSString *jsName = [marker substringFromIndex:@"__JS_EXPORT_AS__".length];
        NSArray<NSString *> *requiredKeywords = [keywords subarrayWithRange:NSMakeRange(0, keywords.count - 2)];
        renames[[[requiredKeywords componentsJoinedByString:@":"] stringByAppendingString:@":"]] = jsName;
    }
    free(optional);
}

static void CollectProtocol(Protocol *protocol, NSMutableDictionary<NSString *, NSValue *> *entries)
{
    if (!protocol_conformsToProtocol(protocol, @protocol(JSExport)))
        return;
    /* a property's getter and setter are required methods of the protocol too; as the release
     * does, they are the property's alone and not exported as methods of their own */
    NSMutableSet<NSString *> *accessors = [NSMutableSet set];
    unsigned propertyCount = 0;
    objc_property_t *properties = protocol_copyPropertyList(protocol, &propertyCount);
    for (unsigned index = 0; index < propertyCount; index++) {
        const char *name = property_getName(properties[index]);
        NSString *propertyName = @(name);
        char *getterAttribute = property_copyAttributeValue(properties[index], "G");
        char *setterAttribute = property_copyAttributeValue(properties[index], "S");
        BOOL readonly = property_copyAttributeValue(properties[index], "R") != NULL;
        SEL getter = sel_registerName(getterAttribute ?: name);
        NSString *defaultSetterName = [NSString stringWithFormat:@"set%@%@:", [[propertyName substringToIndex:1] uppercaseString], [propertyName substringFromIndex:1]];
        SEL setter = sel_registerName(setterAttribute ?: defaultSetterName.UTF8String);
        [accessors addObject:NSStringFromSelector(getter)];
        [accessors addObject:NSStringFromSelector(setter)];
        CharonExportEntry getEntry = {getter, NO, NULL};
        entries[propertyName] = [NSValue value:&getEntry withObjCType:@encode(CharonExportEntry)];
        if (!readonly) {
            CharonExportEntry setEntry = {setter, NO, property_getAttributes(properties[index]) + 1};
            entries[[propertyName stringByAppendingString:@"$set"]] = [NSValue value:&setEntry withObjCType:@encode(CharonExportEntry)];
        }
        free(getterAttribute);
        free(setterAttribute);
    }
    free(properties);

    NSMutableDictionary<NSString *, NSString *> *renames = [NSMutableDictionary dictionary];
    CollectRenames(protocol, renames);

    unsigned methodCount = 0;
    struct objc_method_description *required = protocol_copyMethodDescriptionList(protocol, YES, YES, &methodCount);
    for (unsigned index = 0; index < methodCount; index++) {
        NSString *selectorName = NSStringFromSelector(required[index].name);
        if ([accessors containsObject:selectorName])
            continue;
        NSString *jsName = renames[selectorName] ?: JavaScriptNameForSelector(selectorName);
        CharonExportEntry entry = {required[index].name, YES, MethodArgumentTypes(protocol, required[index].name)};
        entries[jsName] = [NSValue value:&entry withObjCType:@encode(CharonExportEntry)];
    }
    free(required);

    unsigned adoptedCount = 0;
    Protocol *__unsafe_unretained *adopted = protocol_copyProtocolList(protocol, &adoptedCount);
    for (unsigned index = 0; index < adoptedCount; index++)
        CollectProtocol(adopted[index], entries);
    free(adopted);
}

static NSDictionary<NSString *, NSValue *> *ExportTableForClass(Class objcClass)
{
    NSMapTable *tables = ExportTables();
    @synchronized(tables) {
        NSDictionary *found = [tables objectForKey:objcClass];
        if (found)
            return found;
    }
    NSMutableDictionary<NSString *, NSValue *> *entries = [NSMutableDictionary dictionary];
    for (Class cursor = objcClass; cursor; cursor = class_getSuperclass(cursor)) {
        unsigned count = 0;
        Protocol *__unsafe_unretained *protocols = class_copyProtocolList(cursor, &count);
        for (unsigned index = 0; index < count; index++)
            CollectProtocol(protocols[index], entries);
        free(protocols);
    }
    @synchronized(tables) {
        [tables setObject:entries forKey:objcClass];
    }
    return entries;
}

BOOL charon_js_class_conforms_to_export(Class objcClass)
{
    for (Class cursor = objcClass; cursor; cursor = class_getSuperclass(cursor)) {
        unsigned count = 0;
        Protocol *__unsafe_unretained *protocols = class_copyProtocolList(cursor, &count);
        BOOL found = NO;
        for (unsigned index = 0; index < count && !found; index++) {
            if (protocol_conformsToProtocol(protocols[index], @protocol(JSExport)))
                found = YES;
        }
        free(protocols);
        if (found)
            return YES;
    }
    return NO;
}

static JSValueRef InvokeSelector(JSContextRef ctx, id target, SEL selector, const char *argumentTypes, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature) {
        JSContext *context = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES];
        if (exception)
            *exception = [JSValue valueWithNewErrorFromMessage:[NSString stringWithFormat:@"%@ does not respond to %@", target, NSStringFromSelector(selector)] inContext:context].JSValueRef;
        return JSValueMakeUndefined(ctx);
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = target;
    /* -setArgument:atIndex: only copies bytes; without this, an object argument set from a local
     * that goes out of scope once its branch below ends dangles by the time -invoke
     * actually runs. */
    [invocation retainArguments];
    NSUInteger expected = signature.numberOfArguments - 2;
    for (NSUInteger index = 0; index < expected; index++) {
        const char *type = [signature getArgumentTypeAtIndex:index + 2];
        JSValueRef value = index < argumentCount ? arguments[index] : JSValueMakeUndefined(ctx);
        const char *declared = argumentTypes && *argumentTypes ? argumentTypes : NULL;
        if (declared)
            argumentTypes = charon_js_skip_type(argumentTypes);
        if (type[0] == '@') {
            /* converted by its declared class; refused before the method runs, as the release does */
            JSValueRef failure = NULL;
            id object = declared ? charon_js_argument(ctx, declared, value, &failure) : charon_js_unbox(ctx, value);
            if (failure) {
                if (exception)
                    *exception = failure;
                return JSValueMakeUndefined(ctx);
            }
            [invocation setArgument:&object atIndex:index + 2];
        } else if (type[0] == '#') {
            id object = charon_js_unbox(ctx, value);
            [invocation setArgument:&object atIndex:index + 2];
        } else {
            JSValueRef failure = NULL;
            if (!charon_js_set_scalar_argument(invocation, index + 2, type, ctx, value, &failure)) {
                JSContext *context = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES];
                failure = [JSValue valueWithNewErrorFromMessage:[NSString stringWithFormat:@"argument %lu of %@ has an unsupported type for JSExport", (unsigned long)index, NSStringFromSelector(selector)] inContext:context].JSValueRef;
            }
            if (failure) {
                if (exception)
                    *exception = failure;
                return JSValueMakeUndefined(ctx);
            }
        }
    }
    [invocation invoke];
    return charon_js_invocation_result(invocation, signature.methodReturnType, ctx);
}

static JSValueRef BoundFunctionCallAsFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)thisObject;
    CharonExportBinding *binding = (__bridge CharonExportBinding *)JSObjectGetPrivate(function);
    JSContext *context = [JSContext charon_wrapperForGlobalContext:JSContextGetGlobalContext(ctx) create:YES];
    NSMutableArray<JSValue *> *boxedArguments = [NSMutableArray array];
    for (size_t index = 0; index < argumentCount; index++)
        [boxedArguments addObject:[JSValue charon_valueWithJSValueRef:arguments[index] context:context]];
    charon_js_push_callback(context, [JSValue charon_valueWithJSValueRef:thisObject context:context], [JSValue charon_valueWithJSValueRef:function context:context], boxedArguments);
    JSValueRef result = InvokeSelector(ctx, binding.target, binding.selector, binding.argumentTypes, argumentCount, arguments, exception);
    JSValue *thrown = charon_js_pop_callback();
    if (thrown) {
        if (exception)
            *exception = thrown.JSValueRef;
        return JSValueMakeUndefined(ctx);
    }
    return result;
}

static void BoundFunctionFinalize(JSObjectRef object)
{
    charon_js_release_soon(JSObjectGetPrivate(object));
}

static JSClassRef BoundFunctionClass(void)
{
    static JSClassRef boundClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "CharonExportMethod";
        definition.callAsFunction = BoundFunctionCallAsFunction;
        definition.finalize = BoundFunctionFinalize;
        boundClass = JSClassCreate(&definition);
    });
    return boundClass;
}

static BOOL LookupEntry(NSDictionary<NSString *, NSValue *> *table, NSString *name, CharonExportEntry *outEntry)
{
    NSValue *boxed = table[name];
    if (!boxed)
        return NO;
    [boxed getValue:outEntry];
    return YES;
}

static JSValueRef ExportGetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef *exception)
{
    id target = (__bridge id)JSObjectGetPrivate(object);
    if (!target)
        return NULL;
    NSDictionary *table = ExportTableForClass(object_getClass(target));
    NSString *name = charon_ns_string(propertyName);
    CharonExportEntry entry;
    if (!LookupEntry(table, name, &entry))
        return NULL;
    if (!entry.isMethod)
        return InvokeSelector(ctx, target, entry.selector, NULL, 0, NULL, exception);
    CharonExportBinding *binding = [CharonExportBinding new];
    binding.target = target;
    binding.selector = entry.selector;
    binding.argumentTypes = entry.argumentTypes;
    return JSObjectMake(ctx, BoundFunctionClass(), (void *)CFBridgingRetain(binding));
}

static bool ExportSetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef *exception)
{
    id target = (__bridge id)JSObjectGetPrivate(object);
    if (!target)
        return false;
    NSDictionary *table = ExportTableForClass(object_getClass(target));
    NSString *name = [charon_ns_string(propertyName) stringByAppendingString:@"$set"];
    CharonExportEntry entry;
    if (!LookupEntry(table, name, &entry))
        return false;
    InvokeSelector(ctx, target, entry.selector, entry.argumentTypes, 1, &value, exception);
    return true;
}

static bool ExportHasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName)
{
    (void)ctx;
    id target = (__bridge id)JSObjectGetPrivate(object);
    if (!target)
        return false;
    NSDictionary *table = ExportTableForClass(object_getClass(target));
    CharonExportEntry entry;
    return LookupEntry(table, charon_ns_string(propertyName), &entry);
}

static void ExportFinalize(JSObjectRef object)
{
    charon_js_release_soon(JSObjectGetPrivate(object));
}

JSClassRef charon_js_export_class(void)
{
    static JSClassRef exportClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "CharonExportObject";
        definition.getProperty = ExportGetProperty;
        definition.setProperty = ExportSetProperty;
        definition.hasProperty = ExportHasProperty;
        definition.finalize = ExportFinalize;
        exportClass = JSClassCreate(&definition);
    });
    return exportClass;
}
