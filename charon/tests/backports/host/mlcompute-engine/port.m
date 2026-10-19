// The port's own engine, asked the same twenty-one questions through the dylib the library is built as.
//
// The dylib is dlopen'd rather than linked, for the reason the archive is hidden: ggml's symbols are
// compiled -fvisibility=hidden so the engine is never API of an image that links it, and a program cannot
// bind to a hidden symbol in a static archive. The dylib keeps those to itself and, like the gate's, hides
// its own classes - CharonMLCTensor and the rest are the port's own, not API of anything - so this program
// reaches them by name at run time and calls through id, and the only symbol it needs at link time is the
// one it dlsym's. That is what makes the two answers come out of the same arrangement of code the gate
// builds, rather than out of a program that happens to be able to see the engine's symbols.
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#import <dlfcn.h>
// The port's own declarations, for the selectors only: including the header declares them without a
// link-time reference to any class, and the classes themselves are looked up by name below, so every one of
// them has to come from the dylib this program dlopen'd. The dylib is built from the port's own sources
// under their own names - no rename, as the gate builds it - so the names looked up are MLC*.
#import "CharonMLCompute.h"
#import "cases.h"

typedef BOOL (*CharonElementwise)(id layer, id input, id output);

// The four values, each as the bits of the float rather than as a decimal: %g is six significant
// digits and the GELU's constant differs in the seventh, so a decimal comparison cannot see the error
// this differential exists to catch.
static uint32_t charon_bits(float value)
{
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static void print_values(const char *name, const float *values)
{
    printf("activation %s\t%08x,%08x,%08x,%08x\n", name, charon_bits(values[0]), charon_bits(values[1]),
           charon_bits(values[2]), charon_bits(values[3]));
}

int main(int argc, const char **argv)
{
    setbuf(stdout, NULL);
    if (argc < 2) {
        printf("usage: port <the dylib>\n");
        return 2;
    }
    void *library = dlopen(argv[1], RTLD_NOW);
    if (!library) {
        printf("dlopen failed: %s\n", dlerror());
        return 1;
    }
    CharonElementwise elementwise = (CharonElementwise)dlsym(library, "CharonMLCElementwise");
    if (!elementwise) {
        printf("dlsym failed: %s\n", dlerror());
        return 1;
    }
    // A class object is an id, and typed as one the selectors resolve against the declarations above.
    id descriptorClass = NSClassFromString(@"MLCTensorDescriptor");
    id tensorClass = NSClassFromString(@"MLCTensor");
    id dataClass = NSClassFromString(@"MLCTensorData");
    id layerClass = NSClassFromString(@"MLCActivationLayer");
    id activationDescriptorClass = NSClassFromString(@"MLCActivationDescriptor");
    if (!descriptorClass || !tensorClass || !dataClass || !layerClass || !activationDescriptorClass) {
        printf("the dylib does not carry the five classes this test needs\n");
        return 1;
    }
    @autoreleasepool {
        for (int type = 0; type < CHARON_CASES; type++) {
            // MLCDataTypeFloat32, which is 1: 0 is MLCDataTypeInvalid, and a descriptor of a data type
            // with no storage is nil - measured, and the port answers nil for it.
            id descriptor = [descriptorClass descriptorWithShape:@[ @1, @1, @2, @2 ] dataType:1];
            // -bindAndWriteData:toDevice: is what gives a tensor its storage; -copyDataFromDeviceMemoryToBytes:
            // answers NO on a tensor that has none, which is measured, and the engine reads floats.
            float numbers[4] = { 1, 2, 3, 4 };
            id input = [tensorClass tensorWithDescriptor:descriptor];
            [input bindAndWriteData:[dataClass dataWithBytesNoCopy:numbers length:sizeof(numbers)] toDevice:nil];
            id result = [tensorClass tensorWithDescriptor:descriptor];
            [result bindAndWriteData:[dataClass dataWithBytesNoCopy:calloc(1, 4 * sizeof(float)) length:4 * sizeof(float)] toDevice:nil];
            id activationDescriptor = [activationDescriptorClass descriptorWithType:type];
            id layer = [layerClass layerWithDescriptor:activationDescriptor];
            if (!layer || !elementwise(layer, input, result)) {
                printf("activation %s\t(no answer)\n", charon_case_names[type]);
                continue;
            }
            const float *values = [result data].bytes;
            print_values(charon_case_names[type], values);
        }
    }
    dlclose(library);
    return 0;
}
