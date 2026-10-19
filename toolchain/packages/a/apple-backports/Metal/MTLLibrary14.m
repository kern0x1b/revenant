#import "RevenantMetal.h"

@implementation RevenantMetalLibrary (Descriptors14)

- (id<MTLFunction>)newFunctionWithDescriptor:(MTLFunctionDescriptor *)descriptor error:(NSError **)error
{
    return [self revenantFunctionNamed:descriptor.name specializedName:descriptor.specializedName options:descriptor.options constantValues:descriptor.constantValues error:error];
}

- (void)newFunctionWithDescriptor:(MTLFunctionDescriptor *)descriptor completionHandler:(void (^)(id<MTLFunction> function, NSError *error))completionHandler
{
    NSError *error = nil;
    id<MTLFunction> function = [self newFunctionWithDescriptor:descriptor error:&error];
    completionHandler(function, error);
}

- (id<MTLFunction>)newIntersectionFunctionWithDescriptor:(MTLIntersectionFunctionDescriptor *)descriptor error:(NSError **)error
{
    if (error)
        *error = RevenantMetalError(22, @"this device has no ray tracing, so a library of it holds no intersection function");
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

- (NSString *)installName
{
    return [self revenantInstallName];
}

@end
