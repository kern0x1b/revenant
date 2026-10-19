#import "JSInternal.h"

static NSMapTable<id, JSContext *> *charon_context_registry;
static NSLock *charon_context_registry_lock;

/* The registry, made with its lock on first use: take it before taking the lock. */
static NSMapTable<id, JSContext *> *ContextRegistry(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        /* keyed by the JSGlobalContextRef itself, an opaque C pointer with no Objective-C object
         * behind it - NSPointerFunctionsOpaqueMemory tells the map table not to send it retain
         * and release, which is what strongToWeakObjectsMapTable's ordinary object keys do and
         * would crash on. The value is a real JSContext, held weakly: the registry answers the
         * same wrapper for as long as one is alive, and stops answering once nothing else is. */
        charon_context_registry = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                          valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality];
        charon_context_registry_lock = [NSLock new];
    });
    return charon_context_registry;
}

@interface JSContext ()
{
    JSGlobalContextRef _globalContext;
    JSVirtualMachine *_virtualMachine;
    JSValue *_exception;
    NSString *_name;
    BOOL _inspectable;
}
@end

@implementation JSContext

@synthesize exceptionHandler = _exceptionHandler;

- (instancetype)init
{
    return [self initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
}

- (instancetype)initWithVirtualMachine:(JSVirtualMachine *)virtualMachine
{
    if ((self = [super init])) {
        _virtualMachine = virtualMachine;
        _globalContext = JSGlobalContextCreateInGroup([virtualMachine charon_group], NULL);
        [self charon_register];
        __weak JSContext *weakSelf = self;
        _exceptionHandler = [^(JSContext *context, JSValue *exception) {
            (void)context;
            weakSelf.exception = exception;
        } copy];
        [JSValue charon_installPromiseInContext:self];
    }
    return self;
}

- (void)charon_register
{
    NSMapTable<id, JSContext *> *registry = ContextRegistry();
    [charon_context_registry_lock lock];
    [registry setObject:self forKey:(__bridge id)_globalContext];
    [charon_context_registry_lock unlock];
}

- (void)dealloc
{
    NSMapTable<id, JSContext *> *registry = ContextRegistry();
    [charon_context_registry_lock lock];
    /* a wrapper made for the same global context once this one's weak entry read nil stays */
    if (![registry objectForKey:(__bridge id)_globalContext])
        [registry removeObjectForKey:(__bridge id)_globalContext];
    [charon_context_registry_lock unlock];
    JSGlobalContextRelease(_globalContext);
}

+ (nullable JSContext *)charon_wrapperForGlobalContext:(JSGlobalContextRef)context create:(BOOL)create
{
    if (!context)
        return nil;
    NSMapTable<id, JSContext *> *registry = ContextRegistry();
    [charon_context_registry_lock lock];
    JSContext *found = [registry objectForKey:(__bridge id)context];
    [charon_context_registry_lock unlock];
    if (found || !create)
        return found;
    JSGlobalContextRetain(context);
    JSVirtualMachine *vm = [JSVirtualMachine charon_machineForGroup:JSContextGetGroup(context)] ?: [[JSVirtualMachine alloc] initWithCharonGroup:JSContextGetGroup(context) retained:YES];
    return [[JSContext alloc] initCharonWrapping:context virtualMachine:vm];
}

- (instancetype)initCharonWrapping:(JSGlobalContextRef)context virtualMachine:(JSVirtualMachine *)virtualMachine
{
    if ((self = [super init])) {
        _virtualMachine = virtualMachine;
        _globalContext = context;
        [self charon_register];
        __weak JSContext *weakSelf = self;
        _exceptionHandler = [^(JSContext *ctx, JSValue *exception) {
            (void)ctx;
            weakSelf.exception = exception;
        } copy];
    }
    return self;
}

- (JSGlobalContextRef)JSGlobalContextRef
{
    return _globalContext;
}

+ (JSContext *)contextWithJSGlobalContextRef:(JSGlobalContextRef)jsGlobalContextRef
{
    return [self charon_wrapperForGlobalContext:jsGlobalContextRef create:YES];
}

- (JSVirtualMachine *)virtualMachine
{
    return _virtualMachine;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
}

- (BOOL)isInspectable
{
    return _inspectable;
}

- (void)setInspectable:(BOOL)inspectable
{
    _inspectable = inspectable;
}

- (JSValue *)globalObject
{
    return [JSValue charon_valueWithJSValueRef:JSContextGetGlobalObject(_globalContext) context:self];
}

- (JSValue *)exception
{
    return _exception;
}

- (void)setException:(JSValue *)exception
{
    _exception = exception;
}

- (void)charon_noteException:(JSValueRef)exception
{
    if (!exception)
        return;
    JSValue *value = [JSValue charon_valueWithJSValueRef:exception context:self];
    if (_exceptionHandler)
        _exceptionHandler(self, value);
    else
        _exception = value;
}

- (JSValue *)evaluateScript:(NSString *)script
{
    return [self evaluateScript:script withSourceURL:nil];
}

- (JSValue *)evaluateScript:(NSString *)script withSourceURL:(NSURL *)sourceURL
{
    self.exception = nil;
    JSStringRef body = charon_js_string(script ?: @"");
    JSStringRef url = sourceURL ? charon_js_string(sourceURL.absoluteString) : NULL;
    JSValueRef exception = NULL;
    charon_js_enter();
    JSValueRef result = JSEvaluateScript(_globalContext, body, NULL, url, 1, &exception);
    JSStringRelease(body);
    if (url)
        JSStringRelease(url);
    /* Both are held by a JSValue before the jobs the script queued run and can collect. */
    JSValue *value = [JSValue charon_valueWithJSValueRef:exception ? JSValueMakeUndefined(_globalContext) : result context:self];
    JSValue *thrown = exception ? [JSValue charon_valueWithJSValueRef:exception context:self] : nil;
    charon_js_leave();
    if (thrown)
        [self charon_noteException:thrown.JSValueRef];
    return value;
}

+ (JSContext *)currentContext
{
    CharonJSFrame *frame = CharonCurrentFrame();
    return frame ? (__bridge JSContext *)frame->context : nil;
}

+ (JSValue *)currentThis
{
    CharonJSFrame *frame = CharonCurrentFrame();
    return frame ? (__bridge JSValue *)frame->thisValue : nil;
}

+ (JSValue *)currentCallee
{
    CharonJSFrame *frame = CharonCurrentFrame();
    return frame ? (__bridge JSValue *)frame->callee : nil;
}

+ (NSArray *)currentArguments
{
    CharonJSFrame *frame = CharonCurrentFrame();
    return frame ? (__bridge NSArray *)frame->arguments : nil;
}

- (JSValue *)objectForKeyedSubscript:(id)key
{
    return [self.globalObject objectForKeyedSubscript:key];
}

- (void)setObject:(id)object forKeyedSubscript:(NSObject<NSCopying> *)key
{
    [self.globalObject setObject:object forKeyedSubscript:(id)key];
}

@end
