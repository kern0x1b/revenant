#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>

static const char *leaf(const char *path)
{
    const char *mark = strrchr(path, '/');
    return mark ? mark + 1 : path;
}

static void row(const char *label, Class cls, const char *selector, int isClassMethod)
{
    if (cls == nil) {
        printf("%-26s %-34s nil class: nothing answers\n", label, selector);
        return;
    }
    const char *image = "(no dladdr)";
    static Dl_info info;
    if (dladdr((__bridge const void *)cls, &info) && info.dli_fname) image = leaf(info.dli_fname);

    SEL sel = sel_registerName(selector);
    Method (*ask)(Class, SEL) = isClassMethod ? class_getClassMethod : class_getInstanceMethod;
    BOOL responds = ask(cls, sel) != NULL;
    const char *where = "(nowhere)";

    unsigned int count = 0;
    Method *own = class_copyMethodList(isClassMethod ? object_getClass(cls) : cls, &count);
    if (own) {
        for (unsigned int i = 0; i < count; i++) {
            if (method_getName(own[i]) == sel) { where = class_getName(cls); break; }
        }
        free(own);
    }
    if (strcmp(where, "(nowhere)") == 0) {
        for (Class up = class_getSuperclass(cls); up; up = class_getSuperclass(up)) {
            unsigned int n = 0;
            Method *inherited = class_copyMethodList(isClassMethod ? object_getClass(up) : up, &n);
            int found = 0;
            if (inherited) {
                for (unsigned int i = 0; i < n; i++) {
                    if (method_getName(inherited[i]) == sel) { found = 1; break; }
                }
                free(inherited);
            }
            if (found) {
                char buffer[256];
                snprintf(buffer, sizeof buffer, "%s (inherited)", class_getName(up));
                where = buffer;
                break;
            }
        }
    }
    printf("%-26s %-34s responds=%s defined-by=%-34s from=%s\n",
           label, selector, responds ? "YES" : "no", where, image);
}

int main(void)
{
    printf("-- the fifteen rows, asked of the port's own classes --\n");

    printf("+[VNFaceLandmarkRegion new]\n");
    row("VNFaceLandmarkRegion", objc_getClass("RevenantVNFaceLandmarkRegion"), "new", 1);

    static const char *instance_rows[][2] = {
        {"RevenantVNCoreMLModel",          "init"},
        {"RevenantVNCoreMLRequest",        "init"},
        {"RevenantVNCoreMLRequest",        "initWithCompletionHandler:"},
        {"RevenantVNFaceLandmarkRegion",   "init"},
        {"RevenantVNFaceLandmarks",        "init"},
        {"RevenantVNImageRequestHandler",  "init"},
        {"RevenantVNTargetedImageRequest", "init"},
        {"RevenantVNTargetedImageRequest", "initWithCompletionHandler:"},
        {"RevenantVNTrackObjectRequest",   "init"},
        {"RevenantVNTrackObjectRequest",   "initWithCompletionHandler:"},
        {"RevenantVNTrackRectangleRequest","init"},
        {"RevenantVNTrackRectangleRequest","initWithCompletionHandler:"},
        {"RevenantVNTrackingRequest",      "init"},
        {"RevenantVNTrackingRequest",      "initWithCompletionHandler:"},
        {NULL, NULL},
    };
    for (int i = 0; instance_rows[i][0]; i++) {
        const char *label = instance_rows[i][0] + strlen("Revenant");
        printf("-[%s %s]\n", label, instance_rows[i][1]);
        row(label, objc_getClass(instance_rows[i][0]), instance_rows[i][1], 0);
    }

    printf("-- the control, and what the host's own Vision answers for the same fifteen --\n");
    printf("VNNoClassOfThisName (the control) = %s\n",
           objc_getClass("VNNoClassOfThisName") ? "found" : "nil class");

    for (int i = 0; instance_rows[i][0]; i++) {
        const char *name = instance_rows[i][0] + strlen("Revenant");
        Class system = objc_getClass(name);
        if (!system) {
            printf("%-26s %-34s host: no such class\n", name, instance_rows[i][1]);
            continue;
        }
        static Dl_info info;
        const char *image = "(no dladdr)";
        if (dladdr((__bridge const void *)system, &info) && info.dli_fname) image = leaf(info.dli_fname);
        SEL sel = sel_registerName(instance_rows[i][1]);
        unsigned int n = 0;
        Method *own = class_copyMethodList(system, &n);
        const char *writer = "inherited";
        if (own) {
            for (unsigned int j = 0; j < n; j++) {
                if (method_getName(own[j]) == sel) { writer = "own"; break; }
            }
            free(own);
        }
        printf("%-26s %-34s host responds=%s defined-by=%-9s from=%s\n",
               name, instance_rows[i][1],
               class_getInstanceMethod(system, sel) ? "YES" : "no", writer, image);
    }
    Class newclass = objc_getClass("VNFaceLandmarkRegion");
    if (newclass) {
        SEL sel = sel_registerName("new");
        unsigned int n = 0;
        Method *own = class_copyMethodList(object_getClass(newclass), &n);
        const char *writer = "inherited";
        if (own) {
            for (unsigned int j = 0; j < n; j++) {
                if (method_getName(own[j]) == sel) { writer = "own"; break; }
            }
            free(own);
        }
        static Dl_info info;
        const char *image = "(no dladdr)";
        if (dladdr((__bridge const void *)newclass, &info) && info.dli_fname) image = leaf(info.dli_fname);
        printf("%-26s %-34s host responds=%s defined-by=%-9s from=%s\n", "VNFaceLandmarkRegion", "new",
               class_getClassMethod(newclass, sel) ? "YES" : "no", writer, image);
    }

    return 0;
}
