// What a caller gets for the fifteen initializers the Vision 11.0 rows of this batch are about, measured
// on the port's OWN classes.
//
// The port's classes are compiled here under names of their own (CharonVN...) by the rename header this
// file names in its first comment, exactly as tests/backports/host/vision/run.sh writes it from
// registry/Vision/ios11.json. So every answer below comes from packages/a/apple-backports/Vision and not
// from the Vision of this host: the answer a reader must not accept from the host is precisely the one
// this probe exists to replace, because the host's Vision HAS these classes and the port's classes are the
// ones a caller on 6.1.3 would reach.
//
// The control is a class name no framework carries, asked for beside the others: a nil class answers, so a
// "found" above means the reader saw the class and not that it saw everything.
//
//   build=$(mktemp -d)
//   python3 - packages/a/apple-backports/registry/Vision/ios11.json "$build/rename.h" <<'PY'
//   import json, sys
//   names = set()
//   for entry in json.load(open(sys.argv[1]))["entries"]:
//       if entry["kind"] in ("class", "constant", "function"):
//           names.add(entry["api"].replace("()", ""))
//   with open(sys.argv[2], "w") as out:
//       for name in sorted(names):
//           out.write("#define %s Charon%s\n" % (name, name))
//   PY
//   sdk=$(xcrun --show-sdk-path)
//   xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
//       -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
//       -include "$build/rename.h" -I packages/a/apple-backports/Vision \
//       -framework Foundation -framework Vision -framework CoreGraphics -framework CoreImage \
//       -framework CoreVideo -framework CoreML -framework ImageIO \
//       tools/vision/vn-init-answer.m packages/a/apple-backports/Vision/*.c \
//       packages/a/apple-backports/Vision/*.m -o "$build/vninit" && "$build/vninit"
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

/* The class, its superclass chain and whether the class itself defines the selector. A selector the
 * class does not define is one its superclass answers, and that distinction is the whole of what these
 * fifteen rows claim, so it is asked for directly rather than inferred. */
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
    /* Two different questions, and the difference between them is what these fifteen rows are about:
     *
     *   responds  -- class_getInstanceMethod / class_getClassMethod walk the superclass chain, so they
     *                answer YES for a selector the class inherits. That is what a caller sending the
     *                message reaches.
     *   defined-by-- class_copyMethodList returns a class's OWN methods and nothing inherited, so it is
     *                the only one of the two that can say which class writes the body. Asking the chain
     *                for the owner instead answers the leaf every time and would make every inherited
     *                initializer look like the subclass's own.
     *
     * The pair is chosen by the kind of the row: asking class_getClassMethod for an instance selector
     * answers for nothing and would print a definition the class does not have. */
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
    /* Not defined here: walk up and name the ancestor that does write the body, so the line says what a
     * caller actually reaches rather than only that the row's own class is not the writer. */
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
    row("VNFaceLandmarkRegion", objc_getClass("CharonVNFaceLandmarkRegion"), "new", 1);

    static const char *instance_rows[][2] = {
        {"CharonVNCoreMLModel",          "init"},
        {"CharonVNCoreMLRequest",        "init"},
        {"CharonVNCoreMLRequest",        "initWithCompletionHandler:"},
        {"CharonVNFaceLandmarkRegion",   "init"},
        {"CharonVNFaceLandmarks",        "init"},
        {"CharonVNImageRequestHandler",  "init"},
        {"CharonVNTargetedImageRequest", "init"},
        {"CharonVNTargetedImageRequest", "initWithCompletionHandler:"},
        {"CharonVNTrackObjectRequest",   "init"},
        {"CharonVNTrackObjectRequest",   "initWithCompletionHandler:"},
        {"CharonVNTrackRectangleRequest","init"},
        {"CharonVNTrackRectangleRequest","initWithCompletionHandler:"},
        {"CharonVNTrackingRequest",      "init"},
        {"CharonVNTrackingRequest",      "initWithCompletionHandler:"},
        {NULL, NULL},
    };
    for (int i = 0; instance_rows[i][0]; i++) {
        const char *label = instance_rows[i][0] + strlen("Charon");
        printf("-[%s %s]\n", label, instance_rows[i][1]);
        row(label, objc_getClass(instance_rows[i][0]), instance_rows[i][1], 0);
    }

    printf("-- the control, and what the host's own Vision answers for the same fifteen --\n");
    printf("VNNoClassOfThisName (the control) = %s\n",
           objc_getClass("VNNoClassOfThisName") ? "found" : "nil class");

    /* The same fifteen, asked of the HOST's Vision -- the rename header renamed the port's classes, so
     * the unprefixed names here are Apple's own. This is the line every one of the fifteen rows rests on
     * for saying that the header's NS_UNAVAILABLE is not a runtime absence: Apple's own classes answer
     * these. Measured for all fifteen rather than for one class, because a row that says "the host
     * answers it anyway" has to have been read off the host for that row's own selector. */
    for (int i = 0; instance_rows[i][0]; i++) {
        const char *name = instance_rows[i][0] + strlen("Charon");
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