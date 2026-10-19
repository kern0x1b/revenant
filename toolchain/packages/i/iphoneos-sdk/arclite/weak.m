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

typedef id (*revenant_store_weak_function)(id *, id);
typedef id (*revenant_load_function)(id *);
typedef void (*revenant_destroy_function)(id *);
typedef void (*revenant_copy_weak_function)(id *, id *);

#define REVENANT_NATIVE(type, name)                                   \
    static type revenant_native_##name(void)                          \
    {                                                               \
        static type found;                                          \
        static int looked;                                          \
        if (!looked) {                                              \
            found = (type)dlsym(RTLD_DEFAULT, #name);               \
            looked = 1;                                             \
        }                                                           \
        return found;                                               \
    }

REVENANT_NATIVE(revenant_store_weak_function, objc_initWeak)
REVENANT_NATIVE(revenant_store_weak_function, objc_storeWeak)
REVENANT_NATIVE(revenant_load_function, objc_loadWeakRetained)
REVENANT_NATIVE(revenant_load_function, objc_loadWeak)
REVENANT_NATIVE(revenant_destroy_function, objc_destroyWeak)
REVENANT_NATIVE(revenant_copy_weak_function, objc_copyWeak)
REVENANT_NATIVE(revenant_copy_weak_function, objc_moveWeak)

enum { REVENANT_BUCKETS = 64 };

struct revenant_referrers {
    id object;
    id **locations;
    unsigned count;
    unsigned capacity;
};

struct revenant_bucket {
    struct revenant_referrers *entries;
    unsigned count;
    unsigned capacity;
};

static struct revenant_bucket revenant_buckets[REVENANT_BUCKETS];
static pthread_mutex_t revenant_weak_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t revenant_weak_once = PTHREAD_ONCE_INIT;
static IMP revenant_original_release;
static IMP revenant_original_dealloc;

static struct revenant_bucket *revenant_bucket_of(id object)
{
    return &revenant_buckets[((uintptr_t)object >> 4) % REVENANT_BUCKETS];
}

static struct revenant_referrers *revenant_find(struct revenant_bucket *bucket, id object)
{
    for (unsigned index = 0; index < bucket->count; index++) {
        if (bucket->entries[index].object == object)
            return &bucket->entries[index];
    }
    return NULL;
}

static void revenant_forget(struct revenant_bucket *bucket, struct revenant_referrers *entry)
{
    free(entry->locations);
    *entry = bucket->entries[--bucket->count];
}

static void revenant_clear(id object)
{
    struct revenant_bucket *bucket = revenant_bucket_of(object);
    struct revenant_referrers *entry = revenant_find(bucket, object);
    if (!entry)
        return;
    for (unsigned index = 0; index < entry->count; index++) {
        if (*entry->locations[index] == object)
            *entry->locations[index] = nil;
    }
    revenant_forget(bucket, entry);
}

static void revenant_release_hook(id self, SEL command)
{
    pthread_mutex_lock(&revenant_weak_lock);
    if (((unsigned long (*)(id, SEL))objc_msgSend)(self, sel_registerName("retainCount")) == 1)
        revenant_clear(self);
    pthread_mutex_unlock(&revenant_weak_lock);
    ((void (*)(id, SEL))revenant_original_release)(self, command);
}

static void revenant_dealloc_hook(id self, SEL command)
{
    pthread_mutex_lock(&revenant_weak_lock);
    revenant_clear(self);
    pthread_mutex_unlock(&revenant_weak_lock);
    ((void (*)(id, SEL))revenant_original_dealloc)(self, command);
}

static void revenant_weak_setup(void)
{
    Class root = objc_getClass("NSObject");
    Method release = class_getInstanceMethod(root, sel_registerName("release"));
    Method dealloc = class_getInstanceMethod(root, sel_registerName("dealloc"));
    revenant_original_release = method_setImplementation(release, (IMP)revenant_release_hook);
    revenant_original_dealloc = method_setImplementation(dealloc, (IMP)revenant_dealloc_hook);
}

static void revenant_refuse(id object)
{
    fprintf(stderr, "cannot form weak reference to instance (%p) of class %s: it manages its own retain count, "
                    "so this iOS release cannot learn when it is deallocated\n",
            (void *)object, object_getClassName(object));
    abort();
}

static void revenant_unregister(id *location, id object)
{
    struct revenant_bucket *bucket = revenant_bucket_of(object);
    struct revenant_referrers *entry = revenant_find(bucket, object);
    if (!entry)
        return;
    for (unsigned index = 0; index < entry->count; index++) {
        if (entry->locations[index] == location) {
            entry->locations[index] = entry->locations[--entry->count];
            break;
        }
    }
    if (entry->count == 0)
        revenant_forget(bucket, entry);
}

static void revenant_register(id *location, id object)
{
    Class found = object_getClass(object);
    if (class_getMethodImplementation(found, sel_registerName("release")) != (IMP)revenant_release_hook ||
        class_getMethodImplementation(found, sel_registerName("dealloc")) == NULL)
        revenant_refuse(object);
    struct revenant_bucket *bucket = revenant_bucket_of(object);
    struct revenant_referrers *entry = revenant_find(bucket, object);
    if (!entry) {
        if (bucket->count == bucket->capacity) {
            bucket->capacity = bucket->capacity ? bucket->capacity * 2 : 8;
            bucket->entries = realloc(bucket->entries, bucket->capacity * sizeof *bucket->entries);
        }
        entry = &bucket->entries[bucket->count++];
        *entry = (struct revenant_referrers){ object, NULL, 0, 0 };
    }
    if (entry->count == entry->capacity) {
        entry->capacity = entry->capacity ? entry->capacity * 2 : 4;
        entry->locations = realloc(entry->locations, entry->capacity * sizeof *entry->locations);
    }
    entry->locations[entry->count++] = location;
}

static id revenant_store_weak(id *location, id object)
{
    pthread_once(&revenant_weak_once, revenant_weak_setup);
    pthread_mutex_lock(&revenant_weak_lock);
    id previous = *location;
    if (previous)
        revenant_unregister(location, previous);
    if (object)
        revenant_register(location, object);
    *location = object;
    pthread_mutex_unlock(&revenant_weak_lock);
    return object;
}

__attribute__((visibility("hidden"))) id objc_storeWeak(id *location, id object)
{
    revenant_store_weak_function native = revenant_native_objc_storeWeak();
    if (native)
        __attribute__((musttail)) return native(location, object);
    return revenant_store_weak(location, object);
}

__attribute__((visibility("hidden"))) id objc_initWeak(id *location, id object)
{
    revenant_store_weak_function native = revenant_native_objc_initWeak();
    if (native)
        __attribute__((musttail)) return native(location, object);
    *location = nil;
    return revenant_store_weak(location, object);
}

__attribute__((visibility("hidden"))) id objc_loadWeakRetained(id *location)
{
    revenant_load_function native = revenant_native_objc_loadWeakRetained();
    if (native)
        __attribute__((musttail)) return native(location);
    pthread_once(&revenant_weak_once, revenant_weak_setup);
    pthread_mutex_lock(&revenant_weak_lock);
    id object = *location;
    if (object)
        ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName("retain"));
    pthread_mutex_unlock(&revenant_weak_lock);
    return object;
}

__attribute__((visibility("hidden"))) id objc_loadWeak(id *location)
{
    revenant_load_function native = revenant_native_objc_loadWeak();
    if (native)
        __attribute__((musttail)) return native(location);
    id object = objc_loadWeakRetained(location);
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName("autorelease"));
}

__attribute__((visibility("hidden"))) void objc_destroyWeak(id *location)
{
    revenant_destroy_function native = revenant_native_objc_destroyWeak();
    if (native)
        __attribute__((musttail)) return native(location);
    revenant_store_weak(location, nil);
}

__attribute__((visibility("hidden"))) void objc_copyWeak(id *destination, id *source)
{
    revenant_copy_weak_function native = revenant_native_objc_copyWeak();
    if (native)
        __attribute__((musttail)) return native(destination, source);
    id object = objc_loadWeakRetained(source);
    objc_initWeak(destination, object);
    ((void (*)(id, SEL))objc_msgSend)(object, sel_registerName("release"));
}

__attribute__((visibility("hidden"))) void objc_moveWeak(id *destination, id *source)
{
    revenant_copy_weak_function native = revenant_native_objc_moveWeak();
    if (native)
        __attribute__((musttail)) return native(destination, source);
    objc_copyWeak(destination, source);
    objc_destroyWeak(source);
}
