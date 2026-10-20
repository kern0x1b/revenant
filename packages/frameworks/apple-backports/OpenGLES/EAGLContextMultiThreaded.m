#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import "../RevenantSayOnce.h"
#import <objc/runtime.h>
#import <pthread.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char revenant_multithreaded_key;
static const char revenant_lock_key;

static pthread_mutex_t *revenant_mutex_new(void)
{
    pthread_mutex_t *mutex = calloc(1, sizeof(pthread_mutex_t));
    if (!mutex)
        return NULL;
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    int recursive = pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    int ready = recursive == 0 && pthread_mutex_init(mutex, &attributes) == 0;
    pthread_mutexattr_destroy(&attributes);
    if (!ready) {
        free(mutex);
        return NULL;
    }
    return mutex;
}

static void revenant_lock(pthread_mutex_t *mutex)
{
    if (mutex)
        pthread_mutex_lock(mutex);
}

static void revenant_unlock(pthread_mutex_t *mutex)
{
    if (mutex)
        pthread_mutex_unlock(mutex);
}

static pthread_mutex_t *revenant_mutex_of(id owner)
{
    NSValue *boxed = owner ? objc_getAssociatedObject(owner, &revenant_lock_key) : nil;
    return boxed ? (pthread_mutex_t *)boxed.pointerValue : NULL;
}

static pthread_mutex_t *revenant_mutex_for(id owner)
{
    pthread_mutex_t *mutex = revenant_mutex_of(owner);
    if (mutex)
        return mutex;
    @synchronized ([EAGLContext class]) {
        mutex = revenant_mutex_of(owner);
        if (!mutex) {
            mutex = revenant_mutex_new();
            objc_setAssociatedObject(owner, &revenant_lock_key, [NSValue valueWithPointer:mutex], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return mutex;
}

static pthread_mutex_t *revenant_current_mutex(void)
{
    static pthread_mutex_t *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = revenant_mutex_new();
    });
    return shared;
}

typedef BOOL (*RevenantSetCurrentContext)(Class, SEL, EAGLContext *);
typedef BOOL (*RevenantRenderbufferStorage)(id, SEL, NSUInteger, id<EAGLDrawable>);
typedef BOOL (*RevenantPresentRenderbuffer)(id, SEL, id<EAGLDrawable>);

@interface EAGLContext (RevenantMultiThreaded)
@property (getter=isMultiThreaded, nonatomic) BOOL multiThreaded;
@end

static void revenant_install_multi_threaded_guards(void);

@implementation EAGLContext (RevenantMultiThreaded)

@dynamic multiThreaded;

- (BOOL)isMultiThreaded
{
    return [objc_getAssociatedObject(self, &revenant_multithreaded_key) boolValue];
}

- (void)setMultiThreaded:(BOOL)multiThreaded
{
    if (multiThreaded)
        revenant_install_multi_threaded_guards();
    objc_setAssociatedObject(self, &revenant_multithreaded_key, @(multiThreaded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void revenant_install_multi_threaded_guards(void)
{
    static dispatch_once_t installed;
    dispatch_once(&installed, ^{
        revenant_say_once_for(@"EAGLContext.multiThreaded",
                            @"RevenantOpenGLES: an EAGLContext was marked multiThreaded; +setCurrentContext:, "
                            @"-renderbufferStorage:fromDrawable: and -presentRenderbuffer: are now serialised "
                            @"by a recursive lock of the port's own, one per context.");

        SEL setCurrent = @selector(setCurrentContext:);
        Method setCurrentMethod = class_getClassMethod([EAGLContext class], setCurrent);
        if (setCurrentMethod) {
            RevenantSetCurrentContext original = (RevenantSetCurrentContext)method_getImplementation(setCurrentMethod);
            IMP replaced = imp_implementationWithBlock(^(Class self_, EAGLContext *context) {
                pthread_mutex_t *current = revenant_current_mutex();
                revenant_lock(current);
                pthread_mutex_t *own = [context isMultiThreaded] ? revenant_mutex_for(context) : NULL;
                revenant_lock(own);
                BOOL answered = original(self_, setCurrent, context);
                revenant_unlock(own);
                revenant_unlock(current);
                return answered;
            });
            class_replaceMethod([EAGLContext class], setCurrent, replaced, method_getTypeEncoding(setCurrentMethod));
        }

        SEL storage = @selector(renderbufferStorage:fromDrawable:);
        Method storageMethod = class_getInstanceMethod([EAGLContext class], storage);
        if (storageMethod) {
            RevenantRenderbufferStorage original = (RevenantRenderbufferStorage)method_getImplementation(storageMethod);
            IMP replaced = imp_implementationWithBlock(^(id self_, NSUInteger format, id<EAGLDrawable> drawable) {
                if (![self_ isMultiThreaded])
                    return original(self_, storage, format, drawable);
                pthread_mutex_t *mutex = revenant_mutex_for(self_);
                revenant_lock(mutex);
                BOOL answered = original(self_, storage, format, drawable);
                revenant_unlock(mutex);
                return answered;
            });
            class_replaceMethod([EAGLContext class], storage, replaced, method_getTypeEncoding(storageMethod));
        }

        SEL present = @selector(presentRenderbuffer:);
        Method presentMethod = class_getInstanceMethod([EAGLContext class], present);
        if (presentMethod) {
            RevenantPresentRenderbuffer original = (RevenantPresentRenderbuffer)method_getImplementation(presentMethod);
            IMP replaced = imp_implementationWithBlock(^(id self_, id<EAGLDrawable> drawable) {
                if (![self_ isMultiThreaded])
                    return original(self_, present, drawable);
                pthread_mutex_t *mutex = revenant_mutex_for(self_);
                revenant_lock(mutex);
                BOOL answered = original(self_, present, drawable);
                revenant_unlock(mutex);
                return answered;
            });
            class_replaceMethod([EAGLContext class], present, replaced, method_getTypeEncoding(presentMethod));
        }
    });
}

@end
