#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#import <dlfcn.h>
#import "CharonMLCompute.h"
#import "cases.h"

typedef BOOL (*CharonElementwise)(id layer, id input, id output);

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
            id descriptor = [descriptorClass descriptorWithShape:@[ @1, @1, @2, @2 ] dataType:1];
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
