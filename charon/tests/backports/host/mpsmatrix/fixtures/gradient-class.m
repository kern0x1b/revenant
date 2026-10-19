#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <objc/runtime.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
static void dumpClass(NSString *name) {
    Class c = NSClassFromString(name);
    P("\n%s = %p", name.UTF8String, (__bridge void *)c);
    if (!c) { P("\n"); return; }
    unsigned count = 0;
    const char *superName = class_getSuperclass(c) ? class_getName(class_getSuperclass(c)) : "(none)";
    P("  super %s", superName);
    Method *methods = class_copyMethodList(c, &count);
    for (unsigned i = 0; i < count; i++) {
        const char *sel = sel_getName(method_getName(methods[i]));
        const char *types = method_getTypeEncoding(methods[i]);
        if (!strchr(sel, ':') && types && types[0] != 'v')
            P("    %-40s %s\n", sel, types);
    }
    free(methods);
}
int main(void) { @autoreleasepool {
    dumpClass(@"MPSMatrixBatchNormalizationGradient");
    dumpClass(@"MPSMatrixBatchNormalization");
    dumpClass(@"MPSMatrixBinaryKernel");
} return 0; }
