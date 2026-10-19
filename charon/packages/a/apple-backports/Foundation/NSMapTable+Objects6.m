#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <pthread.h>

@class CharonMapEntry, CharonWeakMapTable;

static pthread_mutex_t charon_weak_lock;
static pthread_once_t charon_weak_lock_once = PTHREAD_ONCE_INIT;
static BOOL charon_native_weak;

static void charon_weak_lock_make(void)
{
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&charon_weak_lock, &attributes);
    pthread_mutexattr_destroy(&attributes);
    void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY | RTLD_NOLOAD);
    if (objc) {
        charon_native_weak = dlsym(objc, "objc_loadWeakRetained") != NULL;
        dlclose(objc);
    }
}

static void charon_lock(void)
{
    pthread_once(&charon_weak_lock_once, charon_weak_lock_make);
    pthread_mutex_lock(&charon_weak_lock);
}

static BOOL charon_has_native_weak(void)
{
    pthread_once(&charon_weak_lock_once, charon_weak_lock_make);
    return charon_native_weak;
}

static void charon_unlock(void)
{
    pthread_mutex_unlock(&charon_weak_lock);
}

@interface CharonSideWatch : NSObject {
@public
    __unsafe_unretained CharonMapEntry *_entry;
    BOOL _onKey;
}
@end

@interface CharonMapEntry : NSObject {
@public
    __unsafe_unretained id _key;
    __unsafe_unretained id _value;
    __weak id _weakRefKey;
    __weak id _weakRefValue;
    BOOL _nativeKey;
    BOOL _nativeValue;
    __unsafe_unretained CharonSideWatch *_keyWatch;
    __unsafe_unretained CharonSideWatch *_valueWatch;
    __unsafe_unretained CharonWeakMapTable *_table;
    id _heldKey;
    id _heldValue;
    BOOL _weakValue;
    NSUInteger _hash;
}
- (instancetype)initWithKey:(id)key;
- (instancetype)initWithWeakKey:(id)key weakValue:(BOOL)weakValue table:(CharonWeakMapTable *)table;
- (instancetype)initWithHeldKey:(id)key weakValue:(BOOL)weakValue table:(CharonWeakMapTable *)table;
- (id)key;
- (id)value;
- (void)setValue:(id)value;
- (void)detach;
@end

@interface CharonWeakMapTable : NSMapTable {
@public
    NSMutableArray *_pending;
}
- (instancetype)initWithWeakKeys:(BOOL)weakKeys weakValues:(BOOL)weakValues;
@end

static void *charon_watch(id object, CharonMapEntry *entry, BOOL onKey)
{
    CharonSideWatch *watch = [[CharonSideWatch alloc] init];
    watch->_entry = entry;
    watch->_onKey = onKey;
    objc_setAssociatedObject(object, (__bridge const void *)watch, watch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return (__bridge void *)watch;
}

static void charon_unwatch(__unsafe_unretained id object, const void *watch)
{
    if (watch && object)
        objc_setAssociatedObject(object, watch, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation CharonSideWatch

- (void)dealloc
{
    charon_lock();
    __unsafe_unretained CharonMapEntry *entry = _entry;
    if (entry) {
        if (_onKey) {
            entry->_key = nil;
            entry->_keyWatch = nil;
        } else {
            entry->_value = nil;
            entry->_valueWatch = nil;
        }
        __unsafe_unretained CharonWeakMapTable *table = entry->_table;
        if (table) {
            if (!table->_pending)
                table->_pending = [[NSMutableArray alloc] init];
            [table->_pending addObject:entry];
        }
    }
    charon_unlock();
}

@end

@implementation CharonMapEntry

- (instancetype)initWithKey:(id)key
{
    if ((self = [super init])) {
        _key = key;
        _hash = [key hash];
    }
    return self;
}

- (instancetype)initWithWeakKey:(id)key weakValue:(BOOL)weakValue table:(CharonWeakMapTable *)table
{
    if ((self = [self initWithKey:key])) {
        _weakValue = weakValue;
        _table = table;
        _keyWatch = (__bridge CharonSideWatch *)charon_watch(key, self, YES);
        if (charon_has_native_weak()) {
            _weakRefKey = key;
            _nativeKey = YES;
        }
    }
    return self;
}

- (instancetype)initWithHeldKey:(id)key weakValue:(BOOL)weakValue table:(CharonWeakMapTable *)table
{
    if ((self = [self initWithKey:key])) {
        _weakValue = weakValue;
        _table = table;
        _heldKey = key;
    }
    return self;
}

- (void)dealloc
{
    [self detach];
}

- (void)detach
{
    if (!_keyWatch && !_valueWatch && !_table && !_heldKey && !_heldValue)
        return;
    __unsafe_unretained id key = nil, value = nil;
    const void *keyWatch = NULL, *valueWatch = NULL;
    __attribute__((objc_precise_lifetime)) id heldKey, heldValue, liveKey, liveValue;
    charon_lock();
    if (_keyWatch) {
        key = _nativeKey ? (liveKey = _weakRefKey) : _key;
        keyWatch = (__bridge const void *)_keyWatch;
        _keyWatch->_entry = nil;
    }
    if (_valueWatch) {
        value = _nativeValue ? (liveValue = _weakRefValue) : _value;
        valueWatch = (__bridge const void *)_valueWatch;
        _valueWatch->_entry = nil;
    }
    _keyWatch = nil;
    _valueWatch = nil;
    _table = nil;
    _key = nil;
    _value = nil;
    heldKey = _heldKey;
    heldValue = _heldValue;
    _heldKey = nil;
    _heldValue = nil;
    charon_unwatch(key, keyWatch);
    charon_unwatch(value, valueWatch);
    charon_unlock();
}

- (id)key
{
    if (_nativeKey)
        return _weakRefKey;
    charon_lock();
    id key = _key;
    charon_unlock();
    return key;
}

- (id)value
{
    if (_nativeValue)
        return _weakRefValue;
    charon_lock();
    id value = _value;
    charon_unlock();
    return value;
}

- (void)setValue:(id)value
{
    __unsafe_unretained CharonSideWatch *fresh = nil;
    if (_weakValue && value)
        fresh = (__bridge CharonSideWatch *)charon_watch(value, self, NO);
    __unsafe_unretained id old = nil;
    const void *oldWatch = NULL;
    __attribute__((objc_precise_lifetime)) id heldOld, liveOld;
    charon_lock();
    if (_valueWatch) {
        old = _nativeValue ? (liveOld = _weakRefValue) : _value;
        oldWatch = (__bridge const void *)_valueWatch;
        _valueWatch->_entry = nil;
    }
    heldOld = _heldValue;
    _value = value;
    if (_weakValue) {
        _nativeValue = charon_has_native_weak();
        if (_nativeValue)
            _weakRefValue = value;
    }
    _valueWatch = fresh;
    _heldValue = _weakValue ? nil : value;
    charon_unwatch(old, oldWatch);
    charon_unlock();
}

- (NSUInteger)hash
{
    return _hash;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[CharonMapEntry class]])
        return NO;
    if (_hash != ((CharonMapEntry *)other)->_hash)
        return NO;
    id key = [self key], theirs = [(CharonMapEntry *)other key];
    return key && theirs && (key == theirs || [key isEqual:theirs]);
}

@end

@implementation CharonWeakMapTable {
    NSMutableSet *_entries;
    unsigned long _mutations;
    BOOL _weakKeys, _weakValues;
}

+ (instancetype)alloc
{
    return class_createInstance(self, 0);
}

+ (instancetype)allocWithZone:(NSZone *)zone
{
    return class_createInstance(self, 0);
}

- (instancetype)initWithWeakKeys:(BOOL)weakKeys weakValues:(BOOL)weakValues
{
    _entries = [NSMutableSet set];
    _weakKeys = weakKeys;
    _weakValues = weakValues;
    return self;
}

- (void)dealloc
{
    for (CharonMapEntry *entry in _entries)
        [entry detach];
    [self takePending];
}

- (NSArray *)takePending
{
    charon_lock();
    NSArray *pending = _pending;
    _pending = nil;
    charon_unlock();
    return pending;
}

- (void)forgetReleasedKeys
{
    for (CharonMapEntry *entry in [self takePending]) {
        [_entries removeObject:entry];
        [entry detach];
    }
}

- (CharonMapEntry *)entryForKey:(id)key
{
    return [_entries member:[[CharonMapEntry alloc] initWithKey:key]];
}

- (void)enumerateLive:(void (^)(id key, id value))body
{
    [self forgetReleasedKeys];
    for (CharonMapEntry *entry in _entries) {
        id key = entry.key, value = entry.value;
        if (key && value)
            body(key, value);
    }
}

- (NSArray *)liveKeys
{
    NSMutableArray *keys = [NSMutableArray array];
    [self enumerateLive:^(id key, id value) {
        [keys addObject:key];
    }];
    return keys;
}

- (NSPointerFunctions *)keyPointerFunctions
{
    return [NSPointerFunctions pointerFunctionsWithOptions:_weakKeys ? (NSPointerFunctionsOptions)(1UL << 0) : NSPointerFunctionsStrongMemory];
}

- (NSPointerFunctions *)valuePointerFunctions
{
    return [NSPointerFunctions pointerFunctionsWithOptions:_weakValues ? (NSPointerFunctionsOptions)(1UL << 0) : NSPointerFunctionsStrongMemory];
}

- (id)objectForKey:(id)key
{
    return key ? [self entryForKey:key].value : nil;
}

- (void)setObject:(id)object forKey:(id)key
{
    if (!key || !object)
        return;
    [self forgetReleasedKeys];
    CharonMapEntry *entry = [self entryForKey:key];
    if (!entry) {
        entry = _weakKeys ? [[CharonMapEntry alloc] initWithWeakKey:key weakValue:_weakValues table:self]
                          : [[CharonMapEntry alloc] initWithHeldKey:key weakValue:_weakValues table:self];
        [_entries addObject:entry];
    }
    entry.value = object;
    _mutations++;
}

- (void)removeObjectForKey:(id)key
{
    [self forgetReleasedKeys];
    CharonMapEntry *entry = key ? [self entryForKey:key] : nil;
    if (entry) {
        [_entries removeObject:entry];
        [entry detach];
        _mutations++;
    }
}

- (void)removeAllObjects
{
    for (CharonMapEntry *entry in _entries)
        [entry detach];
    [_entries removeAllObjects];
    [self takePending];
    _mutations++;
}

- (NSUInteger)count
{
    [self forgetReleasedKeys];
    return [_entries count];
}

- (NSEnumerator *)keyEnumerator
{
    return [[self liveKeys] objectEnumerator];
}

- (NSEnumerator *)objectEnumerator
{
    NSMutableArray *objects = [NSMutableArray array];
    [self enumerateLive:^(id key, id value) {
        [objects addObject:value];
    }];
    return [objects objectEnumerator];
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self enumerateLive:^(id key, id value) {
        [dictionary setObject:value forKey:key];
    }];
    return dictionary;
}

- (NSArray *)allKeys
{
    return [self liveKeys];
}

- (NSArray *)allValues
{
    return [[self objectEnumerator] allObjects];
}

- (id)copy
{
    return [self copyWithZone:NULL];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

- (id)copyWithZone:(NSZone *)zone
{
    CharonWeakMapTable *copy = [[CharonWeakMapTable alloc] initWithWeakKeys:_weakKeys weakValues:_weakValues];
    [self enumerateLive:^(id key, id value) {
        [copy setObject:value forKey:key];
    }];
    return copy;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained[])buffer count:(NSUInteger)length
{
    if (state->state == 0) {
        __autoreleasing NSArray *keys = [self liveKeys];
        state->extra[0] = (unsigned long)(__bridge void *)keys;
        state->mutationsPtr = &_mutations;
    }
    NSArray *keys = (__bridge NSArray *)(void *)state->extra[0];
    NSUInteger total = [keys count], index = state->state, count = 0;
    while (index < total && count < length)
        buffer[count++] = [keys objectAtIndex:index++];
    state->state = index;
    state->itemsPtr = buffer;
    return count;
}

- (Class)classForCoder
{
    return [NSMapTable class];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSUInteger keyOptions = _weakKeys ? NSPointerFunctionsWeakMemory : NSPointerFunctionsStrongMemory;
    NSUInteger valueOptions = _weakValues ? NSPointerFunctionsWeakMemory : NSPointerFunctionsStrongMemory;
    [coder encodeValueOfObjCType:@encode(NSUInteger) at:&keyOptions];
    [coder encodeValueOfObjCType:@encode(NSUInteger) at:&valueOptions];
    [self enumerateLive:^(id key, id value) {
        [coder encodeObject:key];
        [coder encodeObject:value];
    }];
    [coder encodeObject:nil];
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"%@ {\n", NSStringFromClass([NSMapTable class])];
    __block NSUInteger index = 0;
    [self enumerateLive:^(id key, id value) {
        [description appendFormat:@"[%lu] %@ -> %@\n", (unsigned long)index++, key, value];
    }];
    [description appendString:@"}\n"];
    return description;
}

@end

@implementation NSMapTable (CharonObjects6)

+ (instancetype)strongToStrongObjectsMapTable
{
    return [self mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
}

+ (instancetype)weakToStrongObjectsMapTable
{
    return [[CharonWeakMapTable alloc] initWithWeakKeys:YES weakValues:NO];
}

+ (instancetype)strongToWeakObjectsMapTable
{
    return [[CharonWeakMapTable alloc] initWithWeakKeys:NO weakValues:YES];
}

+ (instancetype)weakToWeakObjectsMapTable
{
    return [[CharonWeakMapTable alloc] initWithWeakKeys:YES weakValues:YES];
}

@end
