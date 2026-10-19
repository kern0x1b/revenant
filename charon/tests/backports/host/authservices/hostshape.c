#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *open_framework(const char *name)
{
    if (strchr(name, '/')) {
        void *handle = dlopen(name, RTLD_LAZY);
        if (handle)
            return handle;
        fprintf(stderr, "%s: %s\n", name, dlerror());
    }
    char path[4096];
    const char *roots[] = {
        "/System/Library/Frameworks/%s.framework/%s",
        "/System/Library/PrivateFrameworks/%s.framework/Versions/A/%s",
        NULL
    };
    for (int index = 0; roots[index]; ++index) {
        snprintf(path, sizeof path, roots[index], name, name);
        void *handle = dlopen(path, RTLD_LAZY);
        if (handle)
            return handle;
    }
    fprintf(stderr, "none of the default frameworks opened for %s: %s\n", name, dlerror());
    return NULL;
}

static int one_method(const char *framework, const char *className, const char *selectorName)
{
    if (!open_framework(framework))
        return 1;
    Class cls = objc_getClass(className);
    if (!cls) { fprintf(stderr, "no class %s\n", className); return 1; }
    SEL sel = sel_registerName(selectorName);
    Method method = class_getInstanceMethod(cls, sel);
    if (!method)
        method = class_getClassMethod(cls, sel);
    if (!method) { fprintf(stderr, "no method -%s on %s\n", selectorName, className); return 1; }
    const char *encoding = method_getTypeEncoding(method);
    char stripped[128];
    size_t at = 0;
    for (const char *cursor = encoding; *cursor && at + 1 < sizeof stripped; ++cursor) {
        if (!(*cursor >= '0' && *cursor <= '9'))
            stripped[at++] = *cursor;
    }
    stripped[at] = 0;
    printf("%s -%s types %s raw %s\n", className, selectorName, stripped, encoding);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 4)
        return one_method(argv[1], argv[2], argv[3]);

    if (argc != 3) {
        fprintf(stderr, "usage: %s <framework-name> <cases-file>\n", argv[0]);
        return 2;
    }
    void *handle = open_framework(argv[1]);
    if (!handle) {
        fprintf(stderr, "%s.framework did not open: %s\n", argv[1], dlerror());
        return 1;
    }
    FILE *cases = fopen(argv[2], "r");
    if (!cases) {
        fprintf(stderr, "%s: cannot read\n", argv[2]);
        return 1;
    }

    printf("class\tselector\tkind\tstate\thost\n");
    char line[4096];
    int asked = 0, missing = 0;
    while (fgets(line, sizeof line, cases)) {
        size_t length = strlen(line);
        while (length && (line[length - 1] == '\n' || line[length - 1] == '\r'))
            line[--length] = 0;
        if (!length || line[0] == '#')
            continue;
        char className[256], selector[512], kind[32], state[64];
        if (sscanf(line, "%255[^\t]\t%511[^\t]\t%31[^\t]\t%63s", className, selector, kind, state) != 4) {
            fprintf(stderr, "a case is not four tab-separated fields: %s\n", line);
            fclose(cases);
            return 2;
        }
        ++asked;
        Class cls = objc_getClass(className);
        int present = 0;
        if (cls) {
            SEL sel = sel_registerName(selector);
            present = (strcmp(kind, "class") == 0) ? (class_getClassMethod(cls, sel) != NULL)
                                                  : (class_getInstanceMethod(cls, sel) != NULL);
        }
        if (!present)
            ++missing;
        printf("%s\t%s\t%s\t%s\t%s\n", className, selector, kind, state, present ? "yes" : "no");
    }
    fclose(cases);
    fprintf(stderr, "hostshape: %d cases, %d the host does not answer\n", asked, missing);
    return 0;
}
