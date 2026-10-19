#include <dlfcn.h>
#include <objc/objc.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct objc_method *Method;

extern id objc_msgSend(id, SEL, ...);
extern Class objc_getClass(const char *name);
extern Class object_getClass(id object);
extern const char *object_getClassName(id object);
extern Method class_getInstanceMethod(Class found, SEL name);
extern IMP class_getMethodImplementation(Class found, SEL name);
extern IMP method_setImplementation(Method method, IMP implementation);

typedef id (*charon_store_weak_function)(id *, id);
typedef id (*charon_load_function)(id *);
typedef void (*charon_destroy_function)(id *);
typedef void (*charon_copy_weak_function)(id *, id *);

#define CHARON_NATIVE(type, name)                                   \
    static type charon_native_##name(void)                          \
    {                                                               \
        static type found;                                          \
        static int looked;                                          \
        if (!looked) {                                              \
            found = (type)dlsym(RTLD_DEFAULT, #name);               \
            looked = 1;                                             \
        }                                                           \
        return found;                                               \
    }

CHARON_NATIVE(charon_store_weak_function, objc_initWeak)
CHARON_NATIVE(charon_store_weak_function, objc_storeWeak)
CHARON_NATIVE(charon_load_function, objc_loadWeakRetained)
CHARON_NATIVE(charon_load_function, objc_loadWeak)
CHARON_NATIVE(charon_destroy_function, objc_destroyWeak)
CHARON_NATIVE(charon_copy_weak_function, objc_copyWeak)
CHARON_NATIVE(charon_copy_weak_function, objc_moveWeak)

enum { CHARON_BUCKETS = 64 };

struct charon_referrers {
    id object;
    id **locations;
    unsigned count;
    unsigned capacity;
};

struct charon_bucket {
    struct charon_referrers *entries;
    unsigned count;
    unsigned capacity;
};

static struct charon_bucket charon_buckets[CHARON_BUCKETS];
static pthread_mutex_t charon_weak_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t charon_weak_once = PTHREAD_ONCE_INIT;
static IMP charon_original_release;
static IMP charon_original_dealloc;

static struct charon_bucket *charon_bucket_of(id object)
{
    return &charon_buckets[((uintptr_t)object >> 4) % CHARON_BUCKETS];
}

static struct charon_referrers *charon_find(struct charon_bucket *bucket, id object)
{
    for (unsigned index = 0; index < bucket->count; index++) {
        if (bucket->entries[index].object == object)
            return &bucket->entries[index];
    }
    return NULL;
}

static void charon_forget(struct charon_bucket *bucket, struct charon_referrers *entry)
{
    free(entry->locations);
    *entry = bucket->entries[--bucket->count];
}

static void charon_clear(id object)
{
    struct charon_bucket *bucket = charon_bucket_of(object);
    struct charon_referrers *entry = charon_find(bucket, object);
    if (!entry)
        return;
    for (unsigned index = 0; index < entry->count; index++) {
        if (*entry->locations[index] == object)
            *entry->locations[index] = nil;
    }
    charon_forget(bucket, entry);
}

static void charon_release_hook(id self, SEL command)
{
    pthread_mutex_lock(&charon_weak_lock);
    if (((unsigned long (*)(id, SEL))objc_msgSend)(self, sel_registerName("retainCount")) == 1)
        charon_clear(self);
    pthread_mutex_unlock(&charon_weak_lock);
    ((void (*)(id, SEL))charon_original_release)(self, command);
}

static void charon_dealloc_hook(id self, SEL command)
{
    pthread_mutex_lock(&charon_weak_lock);
    charon_clear(self);
    pthread_mutex_unlock(&charon_weak_lock);
    ((void (*)(id, SEL))charon_original_dealloc)(self, command);
}

static void charon_weak_setup(void)
{
    Class root = objc_getClass("NSObject");
    Method release = class_getInstanceMethod(root, sel_registerName("release"));
    Method dealloc = class_getInstanceMethod(root, sel_registerName("dealloc"));
    charon_original_release = method_setImplementation(release, (IMP)charon_release_hook);
    charon_original_dealloc = method_setImplementation(dealloc, (IMP)charon_dealloc_hook);
}

static void charon_refuse(id object)
{
    fprintf(stderr, "cannot form weak reference to instance (%p) of class %s: it manages its own retain count, "
                    "so this iOS release cannot learn when it is deallocated\n",
            (void *)object, object_getClassName(object));
    abort();
}

static void charon_unregister(id *location, id object)
{
    struct charon_bucket *bucket = charon_bucket_of(object);
    struct charon_referrers *entry = charon_find(bucket, object);
    if (!entry)
        return;
    for (unsigned index = 0; index < entry->count; index++) {
        if (entry->locations[index] == location) {
            entry->locations[index] = entry->locations[--entry->count];
            break;
        }
    }
    if (entry->count == 0)
        charon_forget(bucket, entry);
}

static void charon_register(id *location, id object)
{
    Class found = object_getClass(object);
    if (class_getMethodImplementation(found, sel_registerName("release")) != (IMP)charon_release_hook ||
        class_getMethodImplementation(found, sel_registerName("dealloc")) == NULL)
        charon_refuse(object);
    struct charon_bucket *bucket = charon_bucket_of(object);
    struct charon_referrers *entry = charon_find(bucket, object);
    if (!entry) {
        if (bucket->count == bucket->capacity) {
            bucket->capacity = bucket->capacity ? bucket->capacity * 2 : 8;
            bucket->entries = realloc(bucket->entries, bucket->capacity * sizeof *bucket->entries);
        }
        entry = &bucket->entries[bucket->count++];
        *entry = (struct charon_referrers){ object, NULL, 0, 0 };
    }
    if (entry->count == entry->capacity) {
        entry->capacity = entry->capacity ? entry->capacity * 2 : 4;
        entry->locations = realloc(entry->locations, entry->capacity * sizeof *entry->locations);
    }
    entry->locations[entry->count++] = location;
}

static id charon_store_weak(id *location, id object)
{
    pthread_once(&charon_weak_once, charon_weak_setup);
    pthread_mutex_lock(&charon_weak_lock);
    id previous = *location;
    if (previous)
        charon_unregister(location, previous);
    if (object)
        charon_register(location, object);
    *location = object;
    pthread_mutex_unlock(&charon_weak_lock);
    return object;
}

__attribute__((visibility("hidden"))) id objc_storeWeak(id *location, id object)
{
    charon_store_weak_function native = charon_native_objc_storeWeak();
    if (native)
        __attribute__((musttail)) return native(location, object);
    return charon_store_weak(location, object);
}

__attribute__((visibility("hidden"))) id objc_initWeak(id *location, id object)
{
    charon_store_weak_function native = charon_native_objc_initWeak();
    if (native)
        __attribute__((musttail)) return native(location, object);
    *location = nil;
    return charon_store_weak(location, object);
}

__attribute__((visibility("hidden"))) id objc_loadWeakRetained(id *location)
{
    charon_load_function native = charon_native_objc_loadWeakRetained();
    if (native)
        __attribute__((musttail)) return native(location);
    pthread_once(&charon_weak_once, charon_weak_setup);
    pthread_mutex_lock(&charon_weak_lock);
    id object = *location;
    if (object)
        ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName("retain"));
    pthread_mutex_unlock(&charon_weak_lock);
    return object;
}

__attribute__((visibility("hidden"))) id objc_loadWeak(id *location)
{
    charon_load_function native = charon_native_objc_loadWeak();
    if (native)
        __attribute__((musttail)) return native(location);
    id object = objc_loadWeakRetained(location);
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName("autorelease"));
}

__attribute__((visibility("hidden"))) void objc_destroyWeak(id *location)
{
    charon_destroy_function native = charon_native_objc_destroyWeak();
    if (native)
        __attribute__((musttail)) return native(location);
    charon_store_weak(location, nil);
}

__attribute__((visibility("hidden"))) void objc_copyWeak(id *destination, id *source)
{
    charon_copy_weak_function native = charon_native_objc_copyWeak();
    if (native)
        __attribute__((musttail)) return native(destination, source);
    id object = objc_loadWeakRetained(source);
    objc_initWeak(destination, object);
    ((void (*)(id, SEL))objc_msgSend)(object, sel_registerName("release"));
}

__attribute__((visibility("hidden"))) void objc_moveWeak(id *destination, id *source)
{
    charon_copy_weak_function native = charon_native_objc_moveWeak();
    if (native)
        __attribute__((musttail)) return native(destination, source);
    objc_copyWeak(destination, source);
    objc_destroyWeak(source);
}
