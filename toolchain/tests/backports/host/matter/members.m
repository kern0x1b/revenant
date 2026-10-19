#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <errno.h>
#import <string.h>

static void dump_class(Class cls, const char *name)
{
    printf("class\t%s\n", name);
    unsigned count = 0;
    Method *instance = class_copyMethodList(cls, &count);
    for (unsigned index = 0; index < count; index++) {
        printf("method\t-[%s %s]\n", name, sel_getName(method_getName(instance[index])));
    }
    free(instance);
    Method *own = class_copyMethodList(object_getClass(cls), &count);
    for (unsigned index = 0; index < count; index++) {
        printf("method\t+[%s %s]\n", name, sel_getName(method_getName(own[index])));
    }
    free(own);
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    for (unsigned index = 0; index < count; index++) {
        printf("property\t%s.%s\n", name, property_getName(properties[index]));
    }
    free(properties);
    unsigned protocols = 0;
    Protocol *__unsafe_unretained *adopted = class_copyProtocolList(cls, &protocols);
    for (unsigned index = 0; index < protocols; index++) {
        printf("protocol\t%s\t%s\n", name, protocol_getName(adopted[index]));
    }
    free(adopted);
}

static void dump_protocol(Protocol *protocol, const char *name)
{
    unsigned count = 0;
    const BOOL halves[] = {YES, NO};
    for (unsigned half = 0; half < 2; half++) {
        struct objc_method_description *methods = protocol_copyMethodDescriptionList(protocol, halves[half], YES, &count);
        for (unsigned index = 0; index < count; index++) {
            printf("protocolmethod\t%s\t%s\t%s\n", name, sel_getName(methods[index].name), halves[half] ? "required" : "optional");
        }
        free(methods);
    }
}

static void dump_functions(const char *surface)
{
    FILE *stream = fopen(surface, "r");
    if (!stream) {
        fprintf(stderr, "no surface at %s: %s\n", surface, strerror(errno));
        exit(1);
    }
    char line[4096];
    while (fgets(line, sizeof line, stream)) {
        char *fields[4] = {NULL, NULL, NULL, NULL};
        int held = 0;
        for (char *cursor = strtok(line, "\t"); cursor && held < 4; cursor = strtok(NULL, "\t")) {
            fields[held++] = cursor;
        }
        if (held < 4 || strcmp(fields[0], "Matter") != 0 || strcmp(fields[1], "function") != 0) {
            continue;
        }
        char *name = fields[3];
        size_t length = strlen(name);
        while (length > 0 && (name[length - 1] == '\n' || name[length - 1] == '\r')) {
            name[--length] = 0;
        }
        if (length > 2 && name[length - 1] == ')' && name[length - 2] == '(') {
            name[length - 2] = 0;
        }
        printf("function\t%s\t%s\n", name, dlsym(RTLD_DEFAULT, name) ? "yes" : "no");
    }
    fclose(stream);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        void *image = dlopen("/System/Library/Frameworks/Matter.framework/Matter", RTLD_LAZY | RTLD_LOCAL);
        if (!image) {
            fprintf(stderr, "no Matter.framework on this host: %s\n", dlerror());
            return 1;
        }
        unsigned count = 0;
        Class *classes = objc_copyClassList(&count);
        printf("# %u classes after loading Matter.framework\n", count);
        for (unsigned index = 0; index < count; index++) {
            const char *name = class_getName(classes[index]);
            dump_class(classes[index], name);
        }
        free(classes);
        unsigned protocols = 0;
        Protocol *__unsafe_unretained *adopted = objc_copyProtocolList(&protocols);
        for (unsigned index = 0; index < protocols; index++) {
            dump_protocol(adopted[index], protocol_getName(adopted[index]));
        }
        free(adopted);
        if (argc > 1) {
            dump_functions(argv[1]);
        }
    }
    return 0;
}
