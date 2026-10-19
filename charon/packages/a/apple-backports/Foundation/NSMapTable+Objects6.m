#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <pthread.h>

// iOS 6.0's NSMapTable factories. +strongToStrongObjectsMapTable is the release's own table with strong keys and
// values, as 6.0 builds it. The other three - +weakToStrongObjectsMapTable, +strongToWeakObjectsMapTable and
// +weakToWeakObjectsMapTable - need keys or values that are let go and forgotten once nothing else holds them, which no
// NSMapTable before 6.0 can hold: 4.3's and 5.1.1's refuse NSPointerFunctionsWeakMemory, and with
// NSPointerFunctionsZeroingWeakMemory they keep a released object's entry and hand the dead object out (facts). So below
// 6.0 they are CharonWeakMapTable: each entry holds a strong side strongly and a weak side unretained, told by a watch
// the object holds as an associated object when it goes, and an entry with a side that has gone is dropped before the
// table is next read. Where the runtime has weak references (5.0 and later) a weak side is also held by a __weak one, so
// that a read never takes hold of an object that is being freed; 4.3 has only the watch (facts).

@class CharonMapEntry, CharonWeakMapTable;

// Guards an entry's weak sides and their watches against the objects going on another thread. It is recursive: taking a
// watch off an object releases it, which can be its last release, and the watch's -dealloc takes this lock.
static pthread_mutex_t charon_weak_lock;
static pthread_once_t charon_weak_lock_once = PTHREAD_ONCE_INIT;
// Whether the runtime itself has weak references, as 5.0 and later do: 4.3's are arclite's own, which refuse the objects
// that keep their own retain count (NSCFString among them) by aborting.
static BOOL charon_native_weak;

static void charon_weak_lock_make(void)
{
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&charon_weak_lock, &attributes);
    pthread_mutexattr_destroy(&attributes);
    // Asked of libobjc alone: an image that exports the function (arclite, linked into the process, exports its own) would
    // answer for 4.3, whose arclite refuses the objects that keep their own retain count by aborting.
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

// Held by a key or a value as an associated object, so it goes when the object does, and tells its entry so. An object's
// associated objects are released with it on 4.3 and 5.1.1 for every class measured, CoreFoundation's bridged ones
// included (facts); a __weak reference is not on 4.3, since arclite refuses objects that keep their own retain
// count, NSCFString among them.
@interface CharonSideWatch : NSObject {
@public
    __unsafe_unretained CharonMapEntry *_entry;
    BOOL _onKey;
}
@end

// One entry: its key and value, a weak one not retained and known to be alive until its watch goes, and the hash the key
// had when it went in.
@interface CharonMapEntry : NSObject {
@public
    __unsafe_unretained id _key;
    __unsafe_unretained id _value;
    // The same sides as weak references, for a weak side where the runtime has them: nil from the start of the object's
    // deallocation, so a read through them never retains an object that is being freed.
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
    // Entries with a side that has gone, in the order they went, for the next read to drop.
    NSMutableArray *_pending;
}
- (instancetype)initWithWeakKeys:(BOOL)weakKeys weakValues:(BOOL)weakValues;
@end

// Puts a watch on the object and answers its address, not the object: before iOS 8 a caller cannot take an object
// returned from a function without the autorelease pool keeping it, and then the watch would outlive its removal from
// the object by as long as the pool lives. The object holds the watch, and the entry only needs where it is.
static void *charon_watch(id object, CharonMapEntry *entry, BOOL onKey)
{
    CharonSideWatch *watch = [[CharonSideWatch alloc] init];
    watch->_entry = entry;
    watch->_onKey = onKey;
    // The watch itself is the association's key, so every side of every entry has its own.
    objc_setAssociatedObject(object, (__bridge const void *)watch, watch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return (__bridge void *)watch;
}

// Takes a watch off the object it was put on, with the lock held. The object's own watch cannot finish its -dealloc, which
// takes the lock, so an object that is being freed on another thread is still whole until the lock is let go: that is
// what makes it safe to touch the object here, where an entry's side is known to be alive only while the watch is.
// Only the watch's address is used, as the association's key.
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

// An entry for a lookup: nothing held, nothing watched.
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

// Every path that takes an entry out of its table lets go of it first, so that no watch is left on an object that
// lives on, and no object's death is told to an entry nobody reads: the watches an object holds are as many as the
// entries of live tables that hold it.
- (void)dealloc
{
    [self detach];
}

// Lets go of both sides: the watches come off the objects they are on, a side held strongly is released, and the entry no
// longer tells a table anything.
- (void)detach
{
    if (!_keyWatch && !_valueWatch && !_table && !_heldKey && !_heldValue)
        return;
    __unsafe_unretained id key = nil, value = nil;
    const void *keyWatch = NULL, *valueWatch = NULL;
    __attribute__((objc_precise_lifetime)) id heldKey, heldValue, liveKey, liveValue;
    charon_lock();
    // A side with a weak reference is taken off its object only while the object is alive, held for that long: one that is
    // going takes its watch with it. Released after the lock, since its -dealloc may be anything.
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
    // The sides held here are released at the end, outside the lock.
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

// A value already there is let go of, and taken off its object when it was weak; the new one is held or watched as the
// table says.
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

// An entry is found by the key's -hash and -isEqual:, as 6.0's object personality finds it; the hash is the one the
// key had when it went in, since a key that died can no longer answer and its entry must stay where it was put.
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
    // Equal keys have equal hashes, so the hashes are compared before either key is read: a set asks colliding entries
    // -isEqual:, and reading the key of an entry that is not the one asked for would retain a key that may be in its last
    // release on another thread.
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

// NSMapTable's +alloc and +allocWithZone: hand out its concrete class whichever class they are sent to, and its own
// -init is abstract and raises (facts), so this class makes its instances itself and starts from NSObject's state,
// which -init there leaves as it is.
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

// The entries with a side that has gone, dropped with what they held before anything reads the table: only those the
// watches named, not every entry. A side going is not a change the caller made, so an enumeration under way goes on.
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

// The pairs whose sides are all alive, each held while the block runs.
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

// Before 6.0 NSPointerFunctions answers nil for NSPointerFunctionsWeakMemory; the functions it makes for zeroing weak
// memory (1 << 0, which the iOS SDK marks unavailable) are what 6.0's weak sides have: weak barriers, no acquire or
// relinquish, the object personality's hash and equality (facts).
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

// A key already in the table stays and only its value is replaced, as the release's tables keep their first key.
// A nil key or a nil value changes nothing, as in 6.0's weak table (measured under xmake emulate).
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
        // The entry found is held by the autorelease pool; what it held goes now, as the release lets it go.
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

// NSMapTable's -copy is abstract too, not NSObject's call to -copyWithZone:.
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

// The keys alive when the enumeration starts, held by the autorelease pool the enumeration runs in, so enumerations
// of one table can nest; a change to the table meanwhile raises through the mutations pointer, as it does for the
// release's tables.
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

// Archived as 6.0 archives its weak tables (measured): class NSMapTable, then in order, unkeyed, which a keyed archiver
// numbers "$0" on, the key options and the value options (NSPointerFunctionsWeakMemory for a weak side, strong memory
// for the other), each live key and its value, and nil after the last.
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
    // The release prints each entry's slot; this table has none, so the index is the entry's place in the enumeration.
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
