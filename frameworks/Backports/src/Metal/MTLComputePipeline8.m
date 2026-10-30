#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#include <pthread.h>

#include <dlfcn.h>

static RevenantMetalFunction *RevenantMetalCornerFunction(void)
{
    static RevenantMetalFunction *corners;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *source = @"#version 100\nattribute vec2 revenant_corner;\nvoid main() {\n    gl_Position = vec4(revenant_corner, 0.0, 1.0);\n}\n";
        NSDictionary *attribute = @{@"name": @"revenant_corner", @"buffer": @0, @"offset": @0, @"stride": @8, @"components": @2, @"scalar": @"float"};
        NSDictionary *reflection = @{@"usesVertexId": @NO, @"uniforms": @[], @"inputs": @[], @"attributes": @[attribute]};
        corners = [[RevenantMetalFunction alloc] initWithName:@"revenant_corners" stage:@"vertex" source:source reflection:reflection];
    });
    return corners;
}

@implementation RevenantMetalComputePipeline {
    void *_function;
    uint32_t _threads;
    uint32_t _blockBytes;
    NSString *_kernel;
    RevenantMetalFunction *_translated;
    RevenantMetalPipeline *_render;
    BOOL _announcedCPURoute;
}

@synthesize label;

- (instancetype)initWithFunction:(id<MTLFunction>)function error:(NSError **)error
{
    NSString *name = function.name;
    if ([function isKindOfClass:[RevenantMetalFunction class]] && [[(RevenantMetalFunction *)function stage] isEqualToString:@"kernel"] && [(RevenantMetalFunction *)function source]) {
        if ((self = [super init])) {
            _kernel = name;
            _translated = (RevenantMetalFunction *)function;
        }
        return self;
    }
    struct KernelEntry { const char *name; void *function; uint32_t buffers; uint32_t block; uint32_t reserved; };
    static const struct KernelEntry *table;
    static unsigned count;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const struct KernelEntry *found = dlsym(RTLD_DEFAULT, "air2cpu_kernels");
        if (!found)
            return;
        table = found;
        const unsigned *total = dlsym(RTLD_DEFAULT, "air2cpu_kernel_count");
        count = total ? *total : 0;
    });
    if (!table) {
        if (error)
            *error = RevenantMetalError(20, @"this library carries no kernel the port could translate: the air2cpu tool in frameworks/Backports/src/air2cpu has not been run over it, or every kernel in it was refused by name, and the log of the build that ran it says which");
        return nil;
    }
    for (unsigned index = 0; index < count; index++) {
        if (!table[index].name || !name || ![name isEqualToString:[NSString stringWithUTF8String:table[index].name]])
            continue;
        if ((self = [super init])) {
            _kernel = name;
            _function = table[index].function;
            _blockBytes = table[index].block;
        }
        return self;
    }
    if (error)
        *error = RevenantMetalError(21, [NSString stringWithFormat:@"%@ is not a kernel this port could translate: the air2cpu tool in frameworks/Backports/src/air2cpu refused it, and the refusal is in the log of the build that ran it",
                                   name ? name : @"that function"]);
    return nil;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (void *)revenantKernelFunction
{
    return _function;
}

- (uint32_t)revenantBlockBytes
{
    return _blockBytes;
}

- (uint32_t)revenantThreads
{
    return _threads;
}

- (void)revenantSetThreads:(uint32_t)threads
{
    _threads = threads;
}

- (NSUInteger)maxTotalThreadsPerThreadgroup
{
    return _threads;
}

- (NSUInteger)threadExecutionWidth
{
    return _threads;
}

- (NSUInteger)maxThreadgroupsPerThreadgroup
{
    return 1;
}

- (NSUInteger)threadgroupMemoryLengthForIndex:(NSUInteger)index
{
    return index == 0 ? _blockBytes : 0;
}

- (void)revenantSetBlockBytes:(uint32_t)bytes
{
    _blockBytes = bytes;
}

- (NSString *)kernelName
{
    return _kernel;
}

- (RevenantMetalFunction *)revenantTranslatedFunction
{
    return _translated;
}

- (RevenantMetalPipeline *)revenantRenderPipeline
{
    if (_render)
        return _render;
    for (NSDictionary *texture in _translated.reflection[@"textures"]) {
        if ([texture[@"cube"] boolValue]) {
            NSLog(@"Metal: %@ samples a cube texture, which the GL dispatch does not bind yet, so the dispatch is not run", _kernel ?: @"the kernel");
            return nil;
        }
    }
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = RevenantMetalCornerFunction();
    descriptor.fragmentFunction = _translated;
    descriptor.colorAttachments[0].writeMask = MTLColorWriteMaskAll;
    NSError *error = nil;
    _render = [[RevenantMetalPipeline alloc] initWithDescriptor:descriptor error:&error];
    if (!_render)
        NSLog(@"Metal: %@ does not link as a render pass, so the dispatch is not run: %@", _kernel ?: @"the kernel", error.localizedDescription);
    return _render;
}

- (void)revenantAnnounceCPURoute
{
    if (_announcedCPURoute)
        return;
    _announcedCPURoute = YES;
    NSLog(@"Metal: %@ runs on the air2cpu CPU route, with one CPU thread per kernel instance and not on the GPU. This is known debt, registered in docs/explanation/backports/metal-on-ios6.md section 3, item 8",
          _kernel ?: @"the kernel");
}

@end
