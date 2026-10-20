#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct OpaqueJSWeakObjectMap *JSWeakObjectMapRef;
typedef void (*JSWeakMapDestroyedCallback)(JSWeakObjectMapRef map, void *_Nullable data);
extern JSWeakObjectMapRef JSWeakObjectMapCreate(JSContextRef ctx, void *_Nullable data, JSWeakMapDestroyedCallback destructor);
extern void JSWeakObjectMapSet(JSContextRef ctx, JSWeakObjectMapRef map, void *key, JSObjectRef object);
extern JSObjectRef _Nullable JSWeakObjectMapGet(JSContextRef ctx, JSWeakObjectMapRef map, void *key);
extern void JSWeakObjectMapRemove(JSContextRef ctx, JSWeakObjectMapRef map, void *key);
extern bool JSObjectSetPrivateProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef _Nullable value);
extern bool JSObjectDeletePrivateProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
extern JSValueRef _Nullable JSObjectGetPrivateProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);

@interface JSVirtualMachine (RevenantInternal)
- (JSContextGroupRef)revenant_group;
- (instancetype)initWithRevenantGroup:(JSContextGroupRef)group retained:(BOOL)retained;
+ (nullable JSVirtualMachine *)revenant_machineForGroup:(JSContextGroupRef)group;
- (JSGlobalContextRef)revenant_weakContext:(JSWeakObjectMapRef _Nonnull *_Nonnull)outWeak;
- (JSGlobalContextRef)revenant_ownContextIsArray:(JSObjectRef _Nonnull *_Nonnull)outIsArray classOf:(JSObjectRef _Nonnull *_Nonnull)outClassOf;
- (JSObjectRef)revenant_wrapperOf:(id)object class:(JSClassRef)jsClass context:(JSContextRef)context;
@end

@interface JSManagedValue (RevenantInternal)
- (nullable JSObjectRef)revenant_object;
@end

@interface JSContext (RevenantInternal)
+ (nullable JSContext *)revenant_wrapperForGlobalContext:(JSGlobalContextRef)context create:(BOOL)create;
- (void)revenant_noteException:(JSValueRef)exception;
@end

@interface JSValue (RevenantInternal)
+ (instancetype)revenant_valueWithJSValueRef:(JSValueRef)value context:(JSContext *)context;
+ (void)revenant_installPromiseInContext:(JSContext *)context;
@end

JSValueRef revenant_js_box(JSContextRef context, id _Nullable object);

id _Nullable revenant_js_unbox(JSContextRef context, JSValueRef value);

NSString *_Nullable revenant_js_to_string(JSContextRef context, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
NSNumber *revenant_js_to_number(JSContextRef context, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
NSDate *_Nullable revenant_js_to_date(JSContextRef context, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
NSArray *_Nullable revenant_js_to_array(JSContextRef context, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
NSDictionary *_Nullable revenant_js_to_dictionary(JSContextRef context, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
id _Nullable revenant_js_to_class(JSContextRef context, JSValueRef value, Class objcClass, JSValueRef _Nullable *_Nonnull exception);

id _Nullable revenant_js_argument(JSContextRef context, const char *type, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
const char *revenant_js_skip_type(const char *type);

BOOL revenant_js_is_array(JSContextRef context, JSValueRef value);
BOOL revenant_js_is_date(JSContextRef context, JSValueRef value);

BOOL revenant_js_set_scalar_argument(NSInvocation *invocation, NSUInteger index, const char *type, JSContextRef context, JSValueRef value, JSValueRef _Nullable *_Nonnull exception);
JSValueRef revenant_js_invocation_result(NSInvocation *invocation, const char *type, JSContextRef context);

uint32_t revenant_js_uint32(double value);

JSValueRef revenant_js_type_error(JSContextRef context, NSString *message);

id _Nullable revenant_js_wrapped_object(JSContextRef context, JSValueRef value);

void revenant_js_wrapper_made(JSContextRef context, JSObjectRef wrapper, JSClassRef jsClass);

JSStringRef revenant_js_string(NSString *string);
NSString *revenant_ns_string(JSStringRef string);

JSClassRef revenant_js_export_class(void);
BOOL revenant_js_class_conforms_to_export(Class objcClass);

void revenant_js_push_callback(JSContext *context, JSValue *_Nullable thisValue, JSValue *_Nullable callee, NSArray<JSValue *> *_Nullable arguments);
JSValue *_Nullable revenant_js_pop_callback(void);

void revenant_js_enter(void);
void revenant_js_release_soon(const void *object);
void revenant_js_release_pending(void);
void revenant_js_leave(void);
void revenant_js_note_jobs(JSContextRef context, JSObjectRef drain);

JSObjectRef _Nullable revenant_js_promise_constructor(JSContext *context);
JSObjectRef _Nullable revenant_js_deferred_promise(JSContext *context, JSObjectRef _Nullable *_Nonnull outResolve, JSObjectRef _Nullable *_Nonnull outReject, JSValueRef _Nullable *_Nonnull outException);

typedef struct RevenantJSFrame {
    struct RevenantJSFrame *up;
    const void *context;
    const void *_Nullable thisValue;
    const void *_Nullable callee;
    const void *_Nullable arguments;
    void *_Nullable preservedException;
} RevenantJSFrame;

RevenantJSFrame *_Nullable RevenantCurrentFrame(void);

NS_ASSUME_NONNULL_END
