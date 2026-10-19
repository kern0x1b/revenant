#import "CharonMetal.h"

// The 14.0 members of a library. A function descriptor names a function and says how to make it: the port
// makes it the way the library makes any function, and keeps the descriptor's options (facts/Metal/LibraryDescriptors.md).
// The type is executable: the port's libraries are the translated form of an executable metallib, and a dynamic
// library is one a pipeline links rather than dispatches, which the port does not carry.
@implementation CharonMetalLibrary (Descriptors14)

- (id<MTLFunction>)newFunctionWithDescriptor:(MTLFunctionDescriptor *)descriptor error:(NSError **)error
{
    return [self charonFunctionNamed:descriptor.name specializedName:descriptor.specializedName options:descriptor.options constantValues:descriptor.constantValues error:error];
}

- (void)newFunctionWithDescriptor:(MTLFunctionDescriptor *)descriptor completionHandler:(void (^)(id<MTLFunction> function, NSError *error))completionHandler
{
    NSError *error = nil;
    id<MTLFunction> function = [self newFunctionWithDescriptor:descriptor error:&error];
    completionHandler(function, error);
}

// An intersection function is for ray tracing, and the device this port runs on, the SGX 543, has no ray
// tracing, so there is no intersection function for a library of it to hold. The refusal is the device's
// answer and not a missing feature: facts/Metal/LibraryDescriptors.md gives the reason, and coordination/crutches.md
// names this as a nil that stands for the hardware.
- (id<MTLFunction>)newIntersectionFunctionWithDescriptor:(MTLIntersectionFunctionDescriptor *)descriptor error:(NSError **)error
{
    if (error)
        *error = CharonMetalError(22, @"this device has no ray tracing, so a library of it holds no intersection function");
    return nil;
}

- (void)newIntersectionFunctionWithDescriptor:(MTLIntersectionFunctionDescriptor *)descriptor completionHandler:(void (^)(id<MTLFunction> function, NSError *error))completionHandler
{
    NSError *error = nil;
    id<MTLFunction> function = [self newIntersectionFunctionWithDescriptor:descriptor error:&error];
    completionHandler(function, error);
}

- (MTLLibraryType)type
{
    return MTLLibraryTypeExecutable;
}

// The install name is the one the metallib carries, which the translator copies into library.json (tools/air2es/
// metallib2es.lua); a library the translator wrote without one has none, and the answer is nil. Measured on the
// host for a library loaded from a file: facts/Metal/LibraryDescriptors.md.
- (NSString *)installName
{
    return [self charonInstallName];
}

@end
