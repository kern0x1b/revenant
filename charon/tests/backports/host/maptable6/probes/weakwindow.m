#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* Whether arclite's own __weak on 4.3 is cleared BEFORE -dealloc, for a class that does not keep its own
   retain count. That is the one measurement the facts call unmeasured and the one the crutches entry's
   narrowing rests on: a __weak reference the runtime clears at the start of deallocation (5.0 and later,
   objc_storeWeak) hands out nothing that a read can retain, while one cleared only afterwards - 4.3's
   arclite, whose weak the SDK's own source learns of a death in object_dispose - leaves the whole of
   -dealloc as a window. So the object below prints what its weak reference reads as its -dealloc runs,
   which is exactly the window in question.

   The class is a plain NSObject subclass: it does not manage its own retain count (it inherits NSObject's
   retain), which is the condition the review names, and arclite's check is by the class's retain, so a
   subclass answers for NSObject as well. The control is the same probe on 5.0, 5.1.1 and 6.0, where the
   runtime's own weak is cleared at the start of deallocation and the answer must be nil.

   Built and run by probes.sh (MAPTABLE6_PROBES=1 adds it to emulate/xmake.lua). Its verdicts are read,
   not asserted: 4.3 is expected to differ from 5.0 and later if the entry's narrowing does not hold. */

static __weak id charonWindowWeak;
static int charonDeallocs;

@interface CharonWeakWindow : NSObject
@end

@implementation CharonWeakWindow

- (void)dealloc
{
    charonDeallocs++;
    printf("  in -dealloc: the weak reference reads %s\n", charonWindowWeak ? "SET" : "nil");
    fflush(stdout);
}

@end

/* One object through the whole life: the weak reference is set while the object is held, -dealloc prints
   what it reads, and the reference is read once more afterwards. */
static void probe(const char *name)
{
    charonDeallocs = 0;
    printf("%s:\n", name);
    fflush(stdout);
    @autoreleasepool {
        CharonWeakWindow *object = [[CharonWeakWindow alloc] init];
        /* ARC forbids @selector(retain), so the selector is made by name: whether the class manages its
           own retain count is what arclite's own __weak refuses, and it is asked of the IMP. */
        SEL retain = sel_registerName("retain");
        printf("  class %s, allowsWeakReference %d, retain %s\n", class_getName(object_getClass(object)),
               (int)[(Class)object_getClass(object) allowsWeakReference],
               class_getMethodImplementation((Class)object_getClass(object), retain) ==
                       [NSObject instanceMethodForSelector:retain] ? "NSObject's" : "its own");
        fflush(stdout);
        charonWindowWeak = object;
        printf("  while held: the weak reference reads %s\n", charonWindowWeak ? "SET" : "nil");
        fflush(stdout);
        object = nil;
    }
    printf("  after release: the weak reference reads %s, %d dealloc%s ran\n",
           charonWindowWeak ? "STILL SET" : "nil", charonDeallocs, charonDeallocs == 1 ? "" : "s");
    fflush(stdout);
}

int main(void)
{
    probe("CharonWeakWindow");
    /* NSObject itself, for the shape of the answer and not for the window: its -dealloc is NSObject's and
       prints nothing, so the line it leaves is what is read afterwards. */
    charonDeallocs = 0;
    @autoreleasepool {
        NSObject *object = [[NSObject alloc] init];
        charonWindowWeak = object;
        printf("NSObject: while held the weak reference reads %s\n", charonWindowWeak ? "SET" : "nil");
        fflush(stdout);
        object = nil;
    }
    printf("NSObject: after release the weak reference reads %s\n", charonWindowWeak ? "STILL SET" : "nil");
    fflush(stdout);
    return 0;
}
