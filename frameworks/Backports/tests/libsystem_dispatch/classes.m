#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>

extern char revenant_queue_class __asm__("_OBJC_CLASS_$_OS_dispatch_queue");
extern char revenant_source_class __asm__("_OBJC_CLASS_$_OS_dispatch_source");

static unsigned checks;

static void require(BOOL value, const char *label)
{
    if (!value) {
        fprintf(stderr, "FAIL %s\n", label);
        exit(1);
    }
    checks++;
    printf("PASS %s\n", label);
}

static unsigned finalized;

static void finalize(void *context)
{
    (*(unsigned *)context)++;
}

static void check_class(Class bound, const char *name, id object, const char *proxy_name)
{
    char label[160];
    Class named = objc_getClass(name);
    snprintf(label, sizeof label, "the system registers %s", name);
    require(named != Nil, label);
    snprintf(label, sizeof label, "the symbol the image binds for %s is the library's proxy", name);
    Class proxy = objc_getClass(proxy_name);
    require(bound == proxy && proxy != named, label);
    snprintf(label, sizeof label, "the class message to the bound %s answers the system's class", name);
    require([bound class] == named, label);
    snprintf(label, sizeof label, "%s answers its own name", name);
    require(strcmp(class_getName([bound class]), name) == 0, label);
    snprintf(label, sizeof label, "an object of %s is a kind of the class the bound symbol names", name);
    require([object isKindOfClass:[bound class]], label);
    snprintf(label, sizeof label, "the proxy of %s sits under the system's class", name);
    require(class_getSuperclass(proxy) == named, label);
    printf("INFO %s instance size %zu, proxy %zu\n", name, (size_t)class_getInstanceSize(named), (size_t)class_getInstanceSize(proxy));
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class queue_class = (Class)&revenant_queue_class;
        Class source_class = (Class)&revenant_source_class;
        dispatch_queue_t queue = dispatch_queue_create("revenant.libsystem.classes", NULL);
        check_class(queue_class, "OS_dispatch_queue", (id)queue, "RevenantOS_dispatch_queue");
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        check_class(source_class, "OS_dispatch_source", (id)source, "RevenantOS_dispatch_source");
        require(![(id)source isKindOfClass:[queue_class class]], "a source is not a kind of the queue class");
        require(![(id)queue isKindOfClass:[source_class class]], "a queue is not a kind of the source class");
        require([[(id)queue description] length] > 0, "a queue describes itself");
        require([NSStringFromClass([queue_class class]) isEqualToString:@"OS_dispatch_queue"], "the class name reads back");
        require([queue_class superclass] == class_getSuperclass(objc_getClass("OS_dispatch_queue")), "the superclass is the system's");
        require([queue_class isSubclassOfClass:[queue_class class]], "the class is a subclass of itself");
        dispatch_source_cancel(source);
        dispatch_resume(source);
        dispatch_release(source);
        dispatch_queue_t retained = dispatch_queue_create("revenant.libsystem.retain", NULL);
        dispatch_set_context(retained, &finalized);
        dispatch_set_finalizer_f(retained, finalize);
        [(id)retained retain];
        dispatch_retain(retained);
        dispatch_release(retained);
        [(id)retained release];
        require(finalized == 0, "retain and release through the object and the C calls share one count");
        dispatch_sync(retained, ^{
        });
        [(id)retained release];
        dispatch_release(queue);
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        });
        usleep(100000);
        require(finalized == 1, "the last release finalizes the object once");
    }
    printf("%u checks passed\n", checks);
    return 0;
}
