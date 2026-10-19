#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static __weak id revenantWindowWeak;
static int revenantDeallocs;

@interface RevenantWeakWindow : NSObject
@end

@implementation RevenantWeakWindow

- (void)dealloc
{
    revenantDeallocs++;
    printf("  in -dealloc: the weak reference reads %s\n", revenantWindowWeak ? "SET" : "nil");
    fflush(stdout);
}

@end

static void probe(const char *name)
{
    revenantDeallocs = 0;
    printf("%s:\n", name);
    fflush(stdout);
    @autoreleasepool {
        RevenantWeakWindow *object = [[RevenantWeakWindow alloc] init];
        SEL retain = sel_registerName("retain");
        printf("  class %s, allowsWeakReference %d, retain %s\n", class_getName(object_getClass(object)),
               (int)[(Class)object_getClass(object) allowsWeakReference],
               class_getMethodImplementation((Class)object_getClass(object), retain) ==
                       [NSObject instanceMethodForSelector:retain] ? "NSObject's" : "its own");
        fflush(stdout);
        revenantWindowWeak = object;
        printf("  while held: the weak reference reads %s\n", revenantWindowWeak ? "SET" : "nil");
        fflush(stdout);
        object = nil;
    }
    printf("  after release: the weak reference reads %s, %d dealloc%s ran\n",
           revenantWindowWeak ? "STILL SET" : "nil", revenantDeallocs, revenantDeallocs == 1 ? "" : "s");
    fflush(stdout);
}

int main(void)
{
    probe("RevenantWeakWindow");
    revenantDeallocs = 0;
    @autoreleasepool {
        NSObject *object = [[NSObject alloc] init];
        revenantWindowWeak = object;
        printf("NSObject: while held the weak reference reads %s\n", revenantWindowWeak ? "SET" : "nil");
        fflush(stdout);
        object = nil;
    }
    printf("NSObject: after release the weak reference reads %s\n", revenantWindowWeak ? "STILL SET" : "nil");
    fflush(stdout);
    return 0;
}
