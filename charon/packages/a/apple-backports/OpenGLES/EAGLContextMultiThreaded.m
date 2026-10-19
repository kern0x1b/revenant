#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import "../CharonSayOnce.h"
#import <objc/runtime.h>
#import <pthread.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char charon_multithreaded_key;
static const char charon_lock_key;

static pthread_mutex_t *charon_mutex_new(void)
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

static void charon_lock(pthread_mutex_t *mutex)
{
    if (mutex)
        pthread_mutex_lock(mutex);
}

static void charon_unlock(pthread_mutex_t *mutex)
{
    if (mutex)
        pthread_mutex_unlock(mutex);
}

static pthread_mutex_t *charon_mutex_of(id owner)
{
    NSValue *boxed = owner ? objc_getAssociatedObject(owner, &charon_lock_key) : nil;
    return boxed ? (pthread_mutex_t *)boxed.pointerValue : NULL;
}

static pthread_mutex_t *charon_mutex_for(id owner)
{
    pthread_mutex_t *mutex = charon_mutex_of(owner);
    if (mutex)
        return mutex;
    @synchronized ([EAGLContext class]) {
        mutex = charon_mutex_of(owner);
        if (!mutex) {
            mutex = charon_mutex_new();
            objc_setAssociatedObject(owner, &charon_lock_key, [NSValue valueWithPointer:mutex], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return mutex;
}

static pthread_mutex_t *charon_current_mutex(void)
{
    static pthread_mutex_t *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = charon_mutex_new();
    });
    return shared;
}

typedef BOOL (*CharonSetCurrentContext)(Class, SEL, EAGLContext *);
typedef BOOL (*CharonRenderbufferStorage)(id, SEL, NSUInteger, id<EAGLDrawable>);
typedef BOOL (*CharonPresentRenderbuffer)(id, SEL, id<EAGLDrawable>);

@interface EAGLContext (CharonMultiThreaded)
@property (getter=isMultiThreaded, nonatomic) BOOL multiThreaded;
@end

static void charon_install_multi_threaded_guards(void);

@implementation EAGLContext (CharonMultiThreaded)

@dynamic multiThreaded;

- (BOOL)isMultiThreaded
{
    return [objc_getAssociatedObject(self, &charon_multithreaded_key) boolValue];
}

- (void)setMultiThreaded:(BOOL)multiThreaded
{
    if (multiThreaded)
        charon_install_multi_threaded_guards();
    objc_setAssociatedObject(self, &charon_multithreaded_key, @(multiThreaded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void charon_install_multi_threaded_guards(void)
{
    static dispatch_once_t installed;
    dispatch_once(&installed, ^{
        charon_say_once_for(@"EAGLContext.multiThreaded",
                            @"CharonOpenGLES: an EAGLContext was marked multiThreaded; +setCurrentContext:, "
                            @"-renderbufferStorage:fromDrawable: and -presentRenderbuffer: are now serialised "
                            @"by a recursive lock of the port's own, one per context.");

        SEL setCurrent = @selector(setCurrentContext:);
        Method setCurrentMethod = class_getClassMethod([EAGLContext class], setCurrent);
        if (setCurrentMethod) {
            CharonSetCurrentContext original = (CharonSetCurrentContext)method_getImplementation(setCurrentMethod);
            IMP replaced = imp_implementationWithBlock(^(Class self_, EAGLContext *context) {
                pthread_mutex_t *current = charon_current_mutex();
                charon_lock(current);
                pthread_mutex_t *own = [context isMultiThreaded] ? charon_mutex_for(context) : NULL;
                charon_lock(own);
                BOOL answered = original(self_, setCurrent, context);
                charon_unlock(own);
                charon_unlock(current);
                return answered;
            });
            class_replaceMethod([EAGLContext class], setCurrent, replaced, method_getTypeEncoding(setCurrentMethod));
        }

        SEL storage = @selector(renderbufferStorage:fromDrawable:);
        Method storageMethod = class_getInstanceMethod([EAGLContext class], storage);
        if (storageMethod) {
            CharonRenderbufferStorage original = (CharonRenderbufferStorage)method_getImplementation(storageMethod);
            IMP replaced = imp_implementationWithBlock(^(id self_, NSUInteger format, id<EAGLDrawable> drawable) {
                if (![self_ isMultiThreaded])
                    return original(self_, storage, format, drawable);
                pthread_mutex_t *mutex = charon_mutex_for(self_);
                charon_lock(mutex);
                BOOL answered = original(self_, storage, format, drawable);
                charon_unlock(mutex);
                return answered;
            });
            class_replaceMethod([EAGLContext class], storage, replaced, method_getTypeEncoding(storageMethod));
        }

        SEL present = @selector(presentRenderbuffer:);
        Method presentMethod = class_getInstanceMethod([EAGLContext class], present);
        if (presentMethod) {
            CharonPresentRenderbuffer original = (CharonPresentRenderbuffer)method_getImplementation(presentMethod);
            IMP replaced = imp_implementationWithBlock(^(id self_, id<EAGLDrawable> drawable) {
                if (![self_ isMultiThreaded])
                    return original(self_, present, drawable);
                pthread_mutex_t *mutex = charon_mutex_for(self_);
                charon_lock(mutex);
                BOOL answered = original(self_, present, drawable);
                charon_unlock(mutex);
                return answered;
            });
            class_replaceMethod([EAGLContext class], present, replaced, method_getTypeEncoding(presentMethod));
        }
    });
}

@end
