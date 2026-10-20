#import "JSInternal.h"

static NSMapTable<id, JSContext *> *revenant_context_registry;
static NSLock *revenant_context_registry_lock;

static NSMapTable<id, JSContext *> *ContextRegistry(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_context_registry = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                          valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality];
        revenant_context_registry_lock = [NSLock new];
    });
    return revenant_context_registry;
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
        _globalContext = JSGlobalContextCreateInGroup([virtualMachine revenant_group], NULL);
        [self revenant_register];
        __weak JSContext *weakSelf = self;
        _exceptionHandler = [^(JSContext *context, JSValue *exception) {
            (void)context;
            weakSelf.exception = exception;
        } copy];
        [JSValue revenant_installPromiseInContext:self];
    }
    return self;
}

- (void)revenant_register
{
    NSMapTable<id, JSContext *> *registry = ContextRegistry();
    [revenant_context_registry_lock lock];
    [registry setObject:self forKey:(__bridge id)_globalContext];
    [revenant_context_registry_lock unlock];
}

- (void)dealloc
{
    NSMapTable<id, JSContext *> *registry = ContextRegistry();
    [revenant_context_registry_lock lock];
    if (![registry objectForKey:(__bridge id)_globalContext])
        [registry removeObjectForKey:(__bridge id)_globalContext];
    [revenant_context_registry_lock unlock];
    JSGlobalContextRelease(_globalContext);
}

+ (nullable JSContext *)revenant_wrapperForGlobalContext:(JSGlobalContextRef)context create:(BOOL)create
{
    if (!context)
        return nil;
    NSMapTable<id, JSContext *> *registry = ContextRegistry();
    [revenant_context_registry_lock lock];
    JSContext *found = [registry objectForKey:(__bridge id)context];
    [revenant_context_registry_lock unlock];
    if (found || !create)
        return found;
    JSGlobalContextRetain(context);
    JSVirtualMachine *vm = [JSVirtualMachine revenant_machineForGroup:JSContextGetGroup(context)] ?: [[JSVirtualMachine alloc] initWithRevenantGroup:JSContextGetGroup(context) retained:YES];
    return [[JSContext alloc] initRevenantWrapping:context virtualMachine:vm];
}

- (instancetype)initRevenantWrapping:(JSGlobalContextRef)context virtualMachine:(JSVirtualMachine *)virtualMachine
{
    if ((self = [super init])) {
        _virtualMachine = virtualMachine;
        _globalContext = context;
        [self revenant_register];
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
    return [self revenant_wrapperForGlobalContext:jsGlobalContextRef create:YES];
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
    return [JSValue revenant_valueWithJSValueRef:JSContextGetGlobalObject(_globalContext) context:self];
}

- (JSValue *)exception
{
    return _exception;
}

- (void)setException:(JSValue *)exception
{
    _exception = exception;
}

- (void)revenant_noteException:(JSValueRef)exception
{
    if (!exception)
        return;
    JSValue *value = [JSValue revenant_valueWithJSValueRef:exception context:self];
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
    JSStringRef body = revenant_js_string(script ?: @"");
    JSStringRef url = sourceURL ? revenant_js_string(sourceURL.absoluteString) : NULL;
    JSValueRef exception = NULL;
    revenant_js_enter();
    JSValueRef result = JSEvaluateScript(_globalContext, body, NULL, url, 1, &exception);
    JSStringRelease(body);
    if (url)
        JSStringRelease(url);
    JSValue *value = [JSValue revenant_valueWithJSValueRef:exception ? JSValueMakeUndefined(_globalContext) : result context:self];
    JSValue *thrown = exception ? [JSValue revenant_valueWithJSValueRef:exception context:self] : nil;
    revenant_js_leave();
    if (thrown)
        [self revenant_noteException:thrown.JSValueRef];
    return value;
}

+ (JSContext *)currentContext
{
    RevenantJSFrame *frame = RevenantCurrentFrame();
    return frame ? (__bridge JSContext *)frame->context : nil;
}

+ (JSValue *)currentThis
{
    RevenantJSFrame *frame = RevenantCurrentFrame();
    return frame ? (__bridge JSValue *)frame->thisValue : nil;
}

+ (JSValue *)currentCallee
{
    RevenantJSFrame *frame = RevenantCurrentFrame();
    return frame ? (__bridge JSValue *)frame->callee : nil;
}

+ (NSArray *)currentArguments
{
    RevenantJSFrame *frame = RevenantCurrentFrame();
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
