#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

static void probe(const char *name)
{
    charonDeallocs = 0;
    printf("%s:\n", name);
    fflush(stdout);
    @autoreleasepool {
        CharonWeakWindow *object = [[CharonWeakWindow alloc] init];
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
