// gradient-class.m — what the host's gradient kernel declares, and whether anything on it could
// switch the per-parameter gradients on.
//
// The release writes the data gradient and leaves resultGradientForGammaVector and
// resultGradientForBetaVector at nothing. Before that is a defect in this port, the question is
// whether MPS's own class offers a switch, or whether the gamma vector has to be passed at all.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <objc/runtime.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
// What the host's gradient kernel actually declares, and what its own name list says about gamma.
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
        // a getter has no colon in its selector and returns something; that is the property surface
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
