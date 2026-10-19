#import "CharonCoreData.h"
#import <objc/runtime.h>
#include <dlfcn.h>
#include <pthread.h>

static pthread_key_t charon_context_key;
static NSHashTable *charon_models;
static void (*charon_perform_original)(id, SEL, void (^)(void));
static void (*charon_perform_and_wait_original)(id, SEL, void (^)(void));
static id (*charon_coordinator_init_original)(id, SEL, NSManagedObjectModel *);

NSManagedObjectContext *charon_current_context(void)
{
    return (__bridge NSManagedObjectContext *)pthread_getspecific(charon_context_key);
}

NSArray *charon_registered_models(void)
{
    @synchronized (charon_models) {
        return charon_models.allObjects;
    }
}

static void (^charon_in_scope(NSManagedObjectContext *context, void (^block)(void)))(void)
{
    return [^{
        void *outer = pthread_getspecific(charon_context_key);
        pthread_setspecific(charon_context_key, (__bridge void *)context);
        @try {
            block();
        } @finally {
            pthread_setspecific(charon_context_key, outer);
        }
    } copy];
}

static void charon_perform(NSManagedObjectContext *self, SEL _cmd, void (^block)(void))
{
    charon_perform_original(self, _cmd, block ? charon_in_scope(self, block) : block);
}

static void charon_perform_and_wait(NSManagedObjectContext *self, SEL _cmd, void (^block)(void))
{
    charon_perform_and_wait_original(self, _cmd, block ? charon_in_scope(self, block) : block);
}

static id charon_coordinator_init(NSPersistentStoreCoordinator *self, SEL _cmd, NSManagedObjectModel *model)
{
    id made = charon_coordinator_init_original(self, _cmd, model);
    if (made && model)
        @synchronized (charon_models) {
            [charon_models addObject:model];
        }
    return made;
}

__attribute__((constructor)) static void charon_hook_core_data(void)
{
    pthread_key_create(&charon_context_key, NULL);
    charon_models = [NSHashTable weakObjectsHashTable];
    Dl_info container, library;
    if (!dladdr((__bridge const void *)objc_getClass("NSPersistentContainer"), &container)
        || !dladdr((const void *)charon_hook_core_data, &library) || container.dli_fbase != library.dli_fbase)
        return;
    Class context = objc_getClass("NSManagedObjectContext");
    Method perform = class_getInstanceMethod(context, @selector(performBlock:));
    Method performAndWait = class_getInstanceMethod(context, @selector(performBlockAndWait:));
    Method coordinator = class_getInstanceMethod(objc_getClass("NSPersistentStoreCoordinator"), @selector(initWithManagedObjectModel:));
    if (perform)
        charon_perform_original = (void (*)(id, SEL, void (^)(void)))method_setImplementation(perform, (IMP)charon_perform);
    if (performAndWait)
        charon_perform_and_wait_original = (void (*)(id, SEL, void (^)(void)))method_setImplementation(performAndWait, (IMP)charon_perform_and_wait);
    if (coordinator)
        charon_coordinator_init_original = (id (*)(id, SEL, NSManagedObjectModel *))method_setImplementation(coordinator, (IMP)charon_coordinator_init);
}
