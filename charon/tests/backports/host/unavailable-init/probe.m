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
