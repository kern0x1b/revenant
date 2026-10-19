#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import "../CharonSayOnce.h"
#import <objc/runtime.h>
#import <pthread.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// What the header says of `multiThreaded` is that the context may be used from more than one
// thread. The release has no such property and no way to be told, and its own context is entered
// through three entry points that are not safe to enter twice at once. So the flag is the port's,
// and it does the thing it says: with it set, every call that reaches the release's context through
// one of those three is serialised by a recursive lock the port owns, and a context is entered by
// one thread at a time. With the flag clear nothing is wrapped at all, and the release's own code
// runs untouched - the wrappers are not installed until an application first asks for the flag, and
// from then on every context pays one associated-object read to find out whether it wants the lock.

static const char charon_multithreaded_key;
static const char charon_lock_key;

// The lock is keyed per context, so two contexts never wait for each other. +setCurrentContext: is a
// property of the process rather than of a context and has one lock of its own. All of them are
// recursive, because a call can reach the context from inside a call that already holds its lock -
// presenting a renderbuffer of a context the same code just made current - and must not deadlock on
// itself.

// No lock is better than a lock that is not there: a context whose mutex could not be made is left
// unguarded, which is the release's own behaviour, rather than guarded by a mutex nothing initialised.
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
            // A pthread_mutex_t is not an object, so it travels boxed in an NSValue: sending the raw
            // pointer retain would be the NSMapTable trap this repository already records, and the
            // port frees the mutex with the process.
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

// The three entry points, each with the arguments the release's own metadata gives it.
typedef BOOL (*CharonSetCurrentContext)(Class, SEL, EAGLContext *);
typedef BOOL (*CharonRenderbufferStorage)(id, SEL, NSUInteger, id<EAGLDrawable>);
typedef BOOL (*CharonPresentRenderbuffer)(id, SEL, id<EAGLDrawable>);

// The property is declared again here because @dynamic in a category needs a declaration of its own
// to answer to; the accessors below are the ones, and the value lives in an associated object
// because the release's class has no ivar of ours to put it in.
@interface EAGLContext (CharonMultiThreaded)
@property (getter=isMultiThreaded, nonatomic) BOOL multiThreaded;
@end

// The installation is a C function and not a method of the category: a selector a category adds is
// API the package carries, and this one is not API any application can call, so it has no business in
// a category the registry has to describe.
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
    // Once for the process, and not once per context or per call. class_replaceMethod returns the
    // implementation it replaced, so a second installation would take the first installation's block as
    // its "original" and chain another lock around it: N marks for N contexts would take each mutex N
    // times per call and leak three block-derived IMPs each time, since imp_implementationWithBlock's
    // result has to be freed with imp_removeBlock and a replacement's previous IMP is not freed for us.
    // One installation is already correct for every context, because each wrapper asks the context it
    // was handed whether that context is marked before it takes anything.
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
                // The process lock always, because which context is current is one fact of the process;
                // the context's own lock as well when it is marked, so a context cannot be swapped in
                // while another thread is inside it. Always taken in that order, and both recursive.
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
