/*
 * The host's own Matter surface, member by member, read from a live process.
 *
 * The host's Matter.framework is in its dyld shared cache and not on disk, so there is no binary here to read a symbol
 * table or Objective-C metadata out of - writing one out of the cache (dyld.extract) does not carry the metadata in a
 * form this repository's reader can walk, which is why the class and function counts came from the exports and the
 * members could not be read at all. The framework is loaded, though, and a loaded framework answers the runtime:
 * objc_copyClassList gives every class it defines, class_copyMethodList and class_copyPropertyList the selectors and
 * properties of each, and class_copyProtocolList and protocol_copyMethodDescriptionList the protocols and their
 * methods. This is the host's real surface, from the host's own runtime, not a reading of its headers.
 *
 * One line per member, in the registry's own spellings so the comparison needs no translation:
 *
 *   class     MTRDeviceController, every class of the process, whether or not it has any member
 *   method    -[MTRDeviceController readAttributeValue:...]      and +[...] for the class's own
 *   property  MTRDeviceController.clusterState
 *   protocol  MTRDeviceControllerDelegate is the name of a protocol the host's classes name
 *   protocolmethod  MTRDevicePairingDelegate is the method a protocol declares, and whether it requires it
 *
 * Everything is dumped, not only what the corpus asks for: the host carries classes and members of a later release
 * than the SDK the corpus was read from, and dropping them here would hide exactly the difference the comparison is
 * for.
 *
 * The surface's own function rows are asked about by name: a C function is not an Objective-C member, so it is found
 * the only way a process can find one, dlsym over the flat namespace the framework has just joined. The surface's
 * constant rows are not asked about: they are header-declared enumerations, which live in the importing program and
 * are not symbols the framework exports, so asking would answer about this program and not about the host.
 *
 *   sh tests/backports/host/matter/run.sh [out.tsv] [surface.tsv]
 */

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <errno.h>
#import <string.h>

static void dump_class(Class cls, const char *name)
{
    // A class of the framework with no methods, no properties and no protocol is a class all the same: the surface has
    // a row for it, and a reading that only noticed a class through its members would answer that no framework has it.
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
    // struct objc_method_description is {SEL name; char *types} on this SDK, the second field being a type encoding:
    // there is no instance-or-class flag in it to read, and the surface's rows are a protocol and its methods, which
    // are the same name whichever kind of method it is. What is asked for here is which half of the protocol - what it
    // requires and what it allows - because that is what a program has to implement.
    const BOOL halves[] = {YES, NO};
    for (unsigned half = 0; half < 2; half++) {
        struct objc_method_description *methods = protocol_copyMethodDescriptionList(protocol, halves[half], YES, &count);
        for (unsigned index = 0; index < count; index++) {
            printf("protocolmethod\t%s\t%s\t%s\n", name, sel_getName(methods[index].name), halves[half] ? "required" : "optional");
        }
        free(methods);
    }
}

// The function rows of the surface, asked of the loaded framework by name. The surface is a TSV whose first column
// is the framework and whose second is the kind, so a row is only asked about when it is a function of Matter.
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
        // The surface spells a C function with the parentheses of a call; the symbol has no parentheses.
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
        // The framework is loaded, not linked: the host's own Matter.framework, from wherever this macOS keeps it, with
        // the system's own copy of everything it needs beside it.
        void *image = dlopen("/System/Library/Frameworks/Matter.framework/Matter", RTLD_LAZY | RTLD_LOCAL);
        if (!image) {
            fprintf(stderr, "no Matter.framework on this host: %s\n", dlerror());
            return 1;
        }
        // The class list is read after the load, so the framework's +load and its own registration have run.
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
