#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static void answer(const char *key, long value)
{
    printf("%s=%ld\n", key, value);
}

static NSString *const source = @"#include <metal_stdlib>\n"
                                 "using namespace metal;\n"
                                 "constant int scale [[function_constant(0)]];\n"
                                 "kernel void fill(device float *out [[buffer(0)]], uint i [[thread_position_in_grid]]) {\n"
                                 "    out[i] = float(scale);\n"
                                 "}\n";

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        answer("device.present", device != nil);
        if (!device)
            return 2;

        NSError *error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
        answer("library.present", library != nil);
        if (!library)
            return 2;
        answer("library.type", library.type);
        NSString *installName = library.installName;
        printf("library.installName=%s\n", installName ? [installName UTF8String] : "(nil)");

        MTLFunctionDescriptor *descriptor = [[MTLFunctionDescriptor alloc] init];
        answer("descriptor.options.default", descriptor.options);
        descriptor.name = @"fill";
        descriptor.specializedName = @"fill_scale3";
        MTLFunctionConstantValues *values = [[MTLFunctionConstantValues alloc] init];
        int three = 3;
        [values setConstantValue:&three type:MTLDataTypeInt atIndex:0];
        descriptor.constantValues = values;

        id<MTLFunction> specialized = [library newFunctionWithDescriptor:descriptor error:&error];
        answer("specialized.present", specialized != nil);
        answer("specialized.error.nil", error == nil);
        answer("specialized.name.isSpecializedName", [specialized.name isEqualToString:@"fill_scale3"]);
        answer("specialized.functionType.kernel", specialized.functionType == MTLFunctionTypeKernel);
        answer("specialized.options", specialized.options);

        MTLFunctionDescriptor *plain = [[MTLFunctionDescriptor alloc] init];
        plain.name = @"fill";
        id<MTLFunction> unspecialized = [library newFunctionWithDescriptor:plain error:&error];
        answer("plain.present", unspecialized != nil);
        answer("plain.error.nil", error == nil);
        answer("plain.name.isName", [unspecialized.name isEqualToString:@"fill"]);

        MTLFunctionDescriptor *missing = [[MTLFunctionDescriptor alloc] init];
        missing.name = @"nothere";
        error = nil;
        id<MTLFunction> none = [library newFunctionWithDescriptor:missing error:&error];
        answer("missing.nil", none == nil);
        answer("missing.error.present", error != nil);

        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block id<MTLFunction> handled = nil;
        __block NSError *handledError = nil;
        [library newFunctionWithDescriptor:descriptor completionHandler:^(id<MTLFunction> function, NSError *e) {
            handled = function;
            handledError = e;
            dispatch_semaphore_signal(done);
        }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        answer("handler.present", handled != nil);
        answer("handler.error.nil", handledError == nil);
        answer("handler.name.isSpecializedName", [handled.name isEqualToString:@"fill_scale3"]);
    }
    return 0;
}
