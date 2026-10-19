#import "JSInternal.h"

#import <objc/runtime.h>

/*
 * A JSVirtualMachine is a JSContextGroupRef - one per group, as WebKit's JSVMWrapperCache keeps -
 * and the graph -addManagedReference:withOwner: reports. What the graph means, measured against the
 * host's own JavaScriptCore (tests/backports/host/jscontext/checks.m): a managed value is kept while
 * its owner is reachable from JavaScript - through a wrapper of the owner, or through an owner of
 * the owner that is - and not while the owner is merely alive in Objective-C. An owner out of
 * JavaScript's reach keeps nothing, and a managed closure that references its own owner's wrapper
 * keeps neither alive once JavaScript lets go of the owner. The release's collector asks the graph
 * for opaque roots while it marks; the iOS 6 C API has no hook into the collector, so here the
 * graph is built inside JavaScript, where the collector follows it by itself:
 *
 * - every object that takes part - an owner, an owned object, a JSManagedValue, and every object
 *   that has a wrapper - has a token, associated with the object (one per virtual machine), that
 *   records what the object owns (with a count, as WebKit's graph counts) and who owns it;
 * - a token has a node: a JavaScript object in a global context of the virtual machine's own, found
 *   through a weak object map and referenced only by private properties (JSInternal.h), never
 *   protected. A node references the node of everything its object owns, and a JSManagedValue's
 *   node references the managed value's JavaScript object;
 * - every wrapper of an object (charon_js_box keeps one per object and global context) references
 *   the object's node.
 *
 * So the collector keeps a managed value exactly while a wrapper of its owner, or of an owner up
 * the graph, is reachable; a cycle through a wrapper is collected like any other cycle. A node
 * nothing references is collected and made again from its token when it is needed.
 *
 * Locking: _lock guards the tokens' records and is never held across a C API call, because a
 * token's -dealloc, which takes _lock and then calls the C API, can run on any thread: a wrapper's
 * object is released after the collection that finalized it, by the thread that collected
 * (charon_js_release_soon), never inside the collection. The engine applies each C API call
 * atomically; an edge is brought to its record's state and the record re-read until no other
 * thread changed it in between. _nodeLock only serialises making a node, so two threads never make
 * two nodes for one token; it is never taken from -dealloc.
 *
 * The virtual machine's own global context is made with it and is its only reference to the group:
 * the 2012 engine's JSContextGroupRelease drops a reference with no lock and without the group's
 * identifier table, so a group whose last reference it drops frees its identifiers against the
 * wrong table and crashes (JSContextRef.cpp and StringImpl's destructor in JavaScriptCore-7536.26.7;
 * measured on the iPad 2 with the C API alone, where JSGlobalContextRelease dropping the last
 * reference does not). So the last reference this holds is always let go by JSGlobalContextRelease.
 */

@interface CharonGraphEdge : NSObject
{
@public
    NSInteger _count;
    NSUInteger _generation;
}
@end

@implementation CharonGraphEdge
@end

@interface CharonGraphToken : NSObject
{
@public
    __weak JSVirtualMachine *_machine;
    __weak id _object;
    NSMapTable<CharonGraphToken *, CharonGraphEdge *> *_owned;
    NSHashTable<CharonGraphToken *> *_owners;
    NSMapTable *_wrapperKeys;
    JSStringRef _name;
}
@end

@interface JSVirtualMachine ()
{
    JSContextGroupRef _group; /* kept by _weakContext */
    NSLock *_lock;
    NSRecursiveLock *_nodeLock;
    JSGlobalContextRef _weakContext;
    JSWeakObjectMapRef _weak;
    JSObjectRef _isArray; /* the weak context's own Array.isArray and Object.prototype.toString */
    JSObjectRef _classOf;
    NSHashTable<CharonGraphToken *> *_tokens;
}
- (void)charon_forgetToken:(CharonGraphToken *)token;
@end

@implementation CharonGraphToken

- (void)dealloc
{
    [_machine charon_forgetToken:self];
    JSStringRelease(_name);
}

@end

static NSString *const CharonNodeName = @"charon.managed.node";
static NSString *const CharonValueName = @"charon.managed.value";

static JSClassRef NodeClass(void)
{
    static JSClassRef nodeClass;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "CharonManagedNode";
        nodeClass = JSClassCreate(&definition);
    });
    return nodeClass;
}

static void WeakDestroyed(JSWeakObjectMapRef map, void *data)
{
    (void)map;
    (void)data;
}

/* The function a NULL-terminated path of names reaches from a fresh context's global object, protected. */
static JSObjectRef OwnFunction(JSGlobalContextRef context, const char *const *path)
{
    JSValueRef value = JSContextGetGlobalObject(context);
    for (; *path; path++) {
        JSStringRef name = JSStringCreateWithUTF8CString(*path);
        value = JSObjectGetProperty(context, (JSObjectRef)value, name, NULL);
        JSStringRelease(name);
    }
    JSValueProtect(context, value);
    return (JSObjectRef)value;
}

/*
 * What the graph records for an object, as WebKit's getInternalObjcObject: a JSValue that wraps an
 * Objective-C object stands for that object. A JSManagedValue stands for itself, not for an object
 * its value wraps: its node keeps the value, the wrapper then keeps the wrapped object's node, and
 * the release keeps the managed wrapper too (checks.m, "a managed wrapper ... through its owner").
 */
static id GraphObject(id object)
{
    if ([object isKindOfClass:[JSValue class]]) {
        JSValue *value = object;
        id wrapped = charon_js_wrapped_object(value.context.JSGlobalContextRef, value.JSValueRef);
        if (wrapped)
            return wrapped;
    }
    return object;
}

static NSMapTable *charon_machines;
static NSLock *charon_machines_lock;

static void MachinesInit(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        /* keyed by the JSContextGroupRef itself, an opaque C pointer (see JSContext.m's registry) */
        charon_machines = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality];
        charon_machines_lock = [NSLock new];
    });
}

@implementation JSVirtualMachine

- (instancetype)init
{
    return [self initWithCharonGroup:JSContextGroupCreate() retained:NO];
}

/*
 * `retained` is NO when the group is a fresh one just created for us (this owns the sole
 * reference, and lets it go once its own global context holds the group), YES when adopting the
 * group of a JSGlobalContextRef handed in through +[JSContext contextWithJSGlobalContextRef:] (some
 * other owner holds its reference; this holds its own through its global context).
 */
- (instancetype)initWithCharonGroup:(JSContextGroupRef)group retained:(BOOL)retained
{
    if ((self = [super init])) {
        _group = group;
        _weakContext = JSGlobalContextCreateInGroup(_group, NULL);
        /* the reference JSContextGroupCreate made is ours; _weakContext now keeps the group */
        if (!retained)
            JSContextGroupRelease(_group);
        _weak = JSWeakObjectMapCreate(_weakContext, NULL, WeakDestroyed);
        _isArray = OwnFunction(_weakContext, (const char *const[]){"Array", "isArray", NULL});
        _classOf = OwnFunction(_weakContext, (const char *const[]){"Object", "prototype", "toString", NULL});
        _lock = [NSLock new];
        _nodeLock = [NSRecursiveLock new];
        _tokens = [NSHashTable weakObjectsHashTable];
        MachinesInit();
        [charon_machines_lock lock];
        [charon_machines setObject:self forKey:(__bridge id)_group];
        [charon_machines_lock unlock];
    }
    return self;
}

+ (nullable JSVirtualMachine *)charon_machineForGroup:(JSContextGroupRef)group
{
    MachinesInit();
    [charon_machines_lock lock];
    JSVirtualMachine *machine = [charon_machines objectForKey:(__bridge id)group];
    [charon_machines_lock unlock];
    return machine;
}

/*
 * The graph ends with the virtual machine, as WebKit's does: every node this made lets go of what
 * it references, though a wrapper may still reference the node. The group goes last, with this
 * machine's own global context.
 */
- (void)dealloc
{
    [charon_machines_lock lock];
    if ([charon_machines objectForKey:(__bridge id)_group] == nil)
        [charon_machines removeObjectForKey:(__bridge id)_group];
    [charon_machines_lock unlock];
    for (CharonGraphToken *token in _tokens.allObjects) {
        JSObjectRef node = JSWeakObjectMapGet(_weakContext, _weak, (__bridge void *)token);
        if (!node)
            continue;
        for (CharonGraphToken *owned in token->_owned.keyEnumerator.allObjects)
            JSObjectDeletePrivateProperty(_weakContext, node, owned->_name);
    }
    JSValueUnprotect(_weakContext, _isArray);
    JSValueUnprotect(_weakContext, _classOf);
    JSGlobalContextRelease(_weakContext);
}

- (JSContextGroupRef)charon_group
{
    return _group;
}

/* The object's token; _lock is held. */
- (CharonGraphToken *)charon_tokenOf:(id)object create:(BOOL)create
{
    CharonGraphToken *token = objc_getAssociatedObject(object, (__bridge const void *)self);
    /* a token left by an earlier virtual machine at this address answers another graph */
    if (token && token->_machine != self)
        token = nil;
    if (token || !create)
        return token;
    token = [CharonGraphToken new];
    token->_machine = self;
    token->_object = object;
    token->_owned = [NSMapTable weakToStrongObjectsMapTable];
    token->_owners = [NSHashTable weakObjectsHashTable];
    token->_wrapperKeys = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
    token->_name = JSStringCreateWithUTF8CString([NSString stringWithFormat:@"charon.managed.owned.%p", token].UTF8String);
    objc_setAssociatedObject(object, (__bridge const void *)self, token, OBJC_ASSOCIATION_RETAIN);
    [_tokens addObject:token];
    return token;
}

- (nullable JSObjectRef)charon_nodeOf:(CharonGraphToken *)token create:(BOOL)create
{
    JSGlobalContextRef context = _weakContext;
    JSWeakObjectMapRef weak = _weak;
    JSObjectRef node = JSWeakObjectMapGet(context, weak, (__bridge void *)token);
    if (node || !create)
        return node;
    [_nodeLock lock];
    node = JSWeakObjectMapGet(context, weak, (__bridge void *)token);
    if (!node) {
        node = JSObjectMake(context, NodeClass(), NULL);
        JSWeakObjectMapSet(context, weak, (__bridge void *)token, node);
        id object = token->_object;
        JSObjectRef value = [object isKindOfClass:[JSManagedValue class]] ? [(JSManagedValue *)object charon_object] : NULL;
        if (value) {
            JSStringRef name = charon_js_string(CharonValueName);
            JSObjectSetPrivateProperty(context, node, name, value);
            JSStringRelease(name);
        }
        [_lock lock];
        NSArray<CharonGraphToken *> *owned = token->_owned.keyEnumerator.allObjects;
        [_lock unlock];
        for (CharonGraphToken *each in owned)
            [self charon_syncEdgeFrom:token to:each];
    }
    [_nodeLock unlock];
    return node;
}

/* Bring the owner's node's reference to `owned` to what the owner's record says. */
- (void)charon_syncEdgeFrom:(CharonGraphToken *)owner to:(CharonGraphToken *)owned
{
    JSGlobalContextRef context = _weakContext;
    JSWeakObjectMapRef weak = _weak;
    for (;;) {
        [_lock lock];
        CharonGraphEdge *edge = [owner->_owned objectForKey:owned];
        NSUInteger generation = edge ? edge->_generation : 0;
        BOOL wanted = edge && edge->_count > 0;
        [_lock unlock];
        JSObjectRef node = JSWeakObjectMapGet(context, weak, (__bridge void *)owner);
        if (!node)
            return;
        JSObjectRef target = wanted && owned->_object ? [self charon_nodeOf:owned create:YES] : NULL;
        if (target)
            JSObjectSetPrivateProperty(context, node, owned->_name, target);
        else
            JSObjectDeletePrivateProperty(context, node, owned->_name);
        [_lock lock];
        CharonGraphEdge *now = [owner->_owned objectForKey:owned];
        BOOL settled = now == edge && (!now || now->_generation == generation);
        [_lock unlock];
        if (settled)
            return;
    }
}

- (JSGlobalContextRef)charon_weakContext:(JSWeakObjectMapRef *)outWeak
{
    *outWeak = _weak;
    return _weakContext;
}

- (JSGlobalContextRef)charon_ownContextIsArray:(JSObjectRef *)outIsArray classOf:(JSObjectRef *)outClassOf
{
    *outIsArray = _isArray;
    *outClassOf = _classOf;
    return _weakContext;
}

/*
 * One wrapper per Objective-C object and global object, as the release's bridge keeps (WebKit's
 * JSWrapperMap): boxing an object again answers the same JavaScript object, with whatever script
 * set on it. It is found in the weak map under a key the object's token keeps for that global
 * object. A key outlives a global object whose address a later one takes, harmlessly: the old
 * wrapper is collected with its global object, so the key then finds nothing and takes the new one.
 */
- (JSObjectRef)charon_wrapperOf:(id)object class:(JSClassRef)jsClass context:(JSContextRef)context
{
    JSGlobalContextRef weakContext = _weakContext;
    JSWeakObjectMapRef weak = _weak;
    JSGlobalContextRef global = JSContextGetGlobalContext(context);
    [_nodeLock lock];
    [_lock lock];
    CharonGraphToken *token = [self charon_tokenOf:object create:YES];
    id key = (__bridge id)NSMapGet(token->_wrapperKeys, global);
    if (!key) {
        key = [NSObject new];
        NSMapInsert(token->_wrapperKeys, global, (__bridge void *)key);
    }
    [_lock unlock];
    JSObjectRef wrapper = JSWeakObjectMapGet(weakContext, weak, (__bridge void *)key);
    if (!wrapper) {
        wrapper = JSObjectMake(context, jsClass, (void *)CFBridgingRetain(object));
        charon_js_wrapper_made(context, wrapper, jsClass);
        JSWeakObjectMapSet(weakContext, weak, (__bridge void *)key, wrapper);
        [self charon_attachWrapper:wrapper token:token context:context];
    }
    [_nodeLock unlock];
    return wrapper;
}

- (void)charon_attachWrapper:(JSObjectRef)wrapper token:(CharonGraphToken *)token context:(JSContextRef)context
{
    id object = token->_object;
    JSObjectRef node = [self charon_nodeOf:token create:YES];
    JSStringRef name = charon_js_string(CharonNodeName);
    bool attached = JSObjectSetPrivateProperty(context, wrapper, name, node);
    JSStringRelease(name);
    if (!attached)
        NSLog(@"JSVirtualMachine: a wrapper of %@ took no private property; what the object owns is not kept through it", [object class]);
}

/* A token's object is gone: its owners' nodes stop referencing it. The name is its own alone. */
- (void)charon_forgetToken:(CharonGraphToken *)token
{
    [_lock lock];
    NSArray<CharonGraphToken *> *owners = token->_owners.allObjects;
    [_lock unlock];
    for (CharonGraphToken *owner in owners) {
        JSObjectRef node = JSWeakObjectMapGet(_weakContext, _weak, (__bridge void *)owner);
        if (node)
            JSObjectDeletePrivateProperty(_weakContext, node, token->_name);
    }
    JSWeakObjectMapRemove(_weakContext, _weak, (__bridge void *)token);
    for (id key in token->_wrapperKeys.objectEnumerator)
        JSWeakObjectMapRemove(_weakContext, _weak, (__bridge void *)key);
}

- (void)addManagedReference:(id)object withOwner:(id)owner
{
    object = GraphObject(object);
    owner = GraphObject(owner);
    if (!object || !owner)
        return;
    [_lock lock];
    CharonGraphToken *ownedToken = [self charon_tokenOf:object create:YES];
    CharonGraphToken *ownerToken = [self charon_tokenOf:owner create:YES];
    CharonGraphEdge *edge = [ownerToken->_owned objectForKey:ownedToken];
    if (!edge) {
        edge = [CharonGraphEdge new];
        [ownerToken->_owned setObject:edge forKey:ownedToken];
    }
    edge->_count++;
    edge->_generation++;
    [ownedToken->_owners addObject:ownerToken];
    [_lock unlock];
    [self charon_syncEdgeFrom:ownerToken to:ownedToken];
}

- (void)removeManagedReference:(id)object withOwner:(id)owner
{
    object = GraphObject(object);
    owner = GraphObject(owner);
    if (!object || !owner)
        return;
    [_lock lock];
    CharonGraphToken *ownedToken = [self charon_tokenOf:object create:NO];
    CharonGraphToken *ownerToken = [self charon_tokenOf:owner create:NO];
    CharonGraphEdge *edge = ownedToken && ownerToken ? [ownerToken->_owned objectForKey:ownedToken] : nil;
    if (!edge || edge->_count == 0) {
        [_lock unlock];
        return;
    }
    edge->_count--;
    edge->_generation++;
    if (edge->_count == 0)
        [ownedToken->_owners removeObject:ownerToken];
    [_lock unlock];
    [self charon_syncEdgeFrom:ownerToken to:ownedToken];
}

@end
