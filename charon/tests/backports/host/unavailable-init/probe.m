// The HOST's own answer, for every class whose SDK header closes -init and +new with NS_UNAVAILABLE.
//
//     clang -fobjc-arc -w probe.m -framework Foundation -o probe && \
//         ./probe /System/Library/Frameworks/SensorKit.framework/SensorKit < classes.txt
//
// One line per class, and the line answers four questions:
//
//   CLASS <name> own-init=<0|1> own-new=<0|1> init=<answer> new=<answer>
//
// An answer is `ok <the class of what came back>` - or `ok nil`, which is an answer and not a missing one:
// AVCaptureDeviceDiscoverySession's own -init returns nil and raises nothing (measured, and the port answers
// the same). The `-init` of every other class here either raises or answers with an object.
//
// `own-init` and `own-new` are whether the selector is in the CLASS's own method list, read through
// class_copyMethodList - which is what a corpus row asks about, and which an inherited selector is
// not in. `init=` and `new=` are what a caller reaches at run time, and they are a separate question
// because NS_UNAVAILABLE is a promise about source and adds nothing to behaviour: an answer is either
// `ok <class>` or `raises <exception name> (<reason>)`.
//
// Both calls are guarded, because at least one class of the eighteen the framework ships raises, and a
// probe that stopped at the first raise would answer one class and call it a measurement.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#include <stdio.h>

static int owns(Class cls, SEL selector, int classMethod)
{
    unsigned int count = 0;
    Method *methods = classMethod ? class_copyMethodList(object_getClass(cls), &count)
                                  : class_copyMethodList(cls, &count);
    int found = 0;
    for (unsigned int i = 0; i < count && !found; i++)
        found = sel_isEqual(method_getName(methods[i]), selector) != 0;
    free(methods);
    return found;
}

static void answer(Class cls, const char *label, SEL selector, int classMethod)
{
    @try {
        // A class method is sent to the class; an instance method needs an instance, and the instance is
        // allocated first - asking `[[cls alloc] init]` is the whole of what a caller does.
        //
        // Sent with objc_msgSend and not with -performSelector:, because performSelector: takes this process
        // down on one of these classes where objc_msgSend answers it - MEASURED on this host for
        // AVCaptureDeviceDiscoverySession: `[[cls alloc] performSelector:@selector(init)]` is SIGSEGV (exit
        // 139) while `objc_msgSend(allocated, @selector(init))` answers nil, and `+new` answers nil through
        // either. performSelector: is not a different method, it is the same IMP reached by a longer road,
        // so the two paths cannot be two answers; one of them is a crash.
        id made;
        if (classMethod) {
            made = ((id (*)(id, SEL))objc_msgSend)(cls, selector);
        } else {
            id allocated = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
            made = ((id (*)(id, SEL))objc_msgSend)(allocated, selector);
        }
        printf(" %s=ok %s", label, made ? [[made class] description].UTF8String : "nil");
    } @catch (NSException *exception) {
        printf(" %s=raises %s (%s)", label, exception.name.UTF8String,
               exception.reason ? exception.reason.UTF8String : "");
    }
}

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (argc != 2) {
        fprintf(stderr, "usage: probe <framework-path> < classes.txt\n");
        return 2;
    }
    void *library = dlopen(argv[1], RTLD_LAZY);
    if (!library) {
        printf("NOFRAMEWORK %s\n", argv[1]);
        return 2;
    }
    char name[256];
    while (fgets(name, sizeof(name), stdin)) {
        char *newline = strchr(name, '\n');
        if (newline)
            *newline = 0;
        if (!name[0] || name[0] == '#')
            continue;
        Class cls = objc_getClass(name);
        if (!cls) {
            printf("CLASS %s absent\n", name);
            continue;
        }
        printf("CLASS %s own-init=%d own-new=%d", name, owns(cls, @selector(init), 0),
               owns(cls, @selector(new), 1));
        answer(cls, "init", @selector(init), 0);
        answer(cls, "new", @selector(new), 1);
        printf("\n");
    }
    return 0;
}
