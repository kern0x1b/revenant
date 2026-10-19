// differential.m - the port's sparse mapping refusals beside Metal's own, on the macOS 26 host.
//
// Metal's side runs in a child process per case, made after fork() and creating every object inside the child:
// an object made before fork() and used after it crashed the child with a signal in the measurement that
// facts/Metal/SparseMapping26.md records. The child's stderr goes to a file in this run's folder, and the
// parent reads the reason from there. Metal's refusal is an assertion that aborts (status 134); a call Metal
// accepts exits 0.
//
// The port's side is the three decision functions of packages/a/apple-backports/Metal/MTL4SparseMapping26.m,
// compiled beside this file. The port's MTL4CommandQueue methods are not compiled here: their file needs the
// port's OpenGL ES queue, which the host has no way to make. The method's only job is to raise the reason the
// function returns, and the case where the function returns no reason is the one the method refuses anyway.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

NSString *CharonMetal4SparseBufferUpdateRefusal(BOOL bufferIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *CharonMetal4SparseBufferCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);
NSString *CharonMetal4SparseTextureUpdateRefusal(BOOL textureIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *CharonMetal4SparseTextureCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);

static int checks;
static int failures;
static const char *folder;

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

// The Metal cases. Each one builds its objects in the child and makes the one call; `which` names the case.
typedef enum {
    CaseBufferPlain = 0,          // plain buffer, automatic heap: buffer refusal
    CaseBufferSparseAutoHeap,     // sparse buffer, automatic heap: heap refusal
    CaseBufferSparsePlacement,    // sparse buffer, placement heap, map: accepted (the requirements hold)
    CaseBufferSparseNilHeapMap,   // sparse buffer, nil heap, map: nil-heap refusal
    CaseBufferCopySparseSource,   // sparse source, plain destination: destination refusal
    CaseBufferCopyPlainSource,    // plain source, plain destination: source refusal
    CaseTextureUpdatePlain,       // plain texture, automatic heap: accepted by Metal
    CaseTextureCopyPlain,         // plain textures: accepted by Metal
} Case;

static int run_metal(Case which, const char *name)
{
    char path[1024];
    snprintf(path, sizeof path, "%s/%s.stderr", folder, name);
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        int fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0644);
        dup2(fd, STDERR_FILENO);
        @autoreleasepool {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            id<MTL4CommandQueue> queue = [device newMTL4CommandQueue];
            MTLHeapDescriptor *heapDescriptor = [[MTLHeapDescriptor alloc] init];
            heapDescriptor.size = 1 << 20;
            heapDescriptor.storageMode = MTLStorageModePrivate;
            if (which == CaseBufferSparsePlacement) {
                heapDescriptor.type = MTLHeapTypePlacement;
                heapDescriptor.maxCompatiblePlacementSparsePageSize = MTLSparsePageSize64;
            }
            id<MTLHeap> heap = (which == CaseBufferSparseNilHeapMap) ? nil : [device newHeapWithDescriptor:heapDescriptor];

            BOOL sparseBuffer = which == CaseBufferSparseAutoHeap || which == CaseBufferSparsePlacement ||
                                which == CaseBufferSparseNilHeapMap || which == CaseBufferCopySparseSource;
            id<MTLBuffer> buffer = sparseBuffer
                ? [device newBufferWithLength:65536 options:MTLResourceStorageModePrivate placementSparsePageSize:MTLSparsePageSize64]
                : [device newBufferWithLength:65536 options:MTLResourceStorageModePrivate];
            id<MTLBuffer> second = [device newBufferWithLength:65536 options:MTLResourceStorageModePrivate];

            MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                          width:4 height:4 mipmapped:NO];
            textureDescriptor.storageMode = MTLStorageModePrivate;
            id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
            id<MTLTexture> other = [device newTextureWithDescriptor:textureDescriptor];

            switch (which) {
                case CaseBufferPlain:
                case CaseBufferSparseAutoHeap:
                case CaseBufferSparsePlacement:
                case CaseBufferSparseNilHeapMap: {
                    MTL4UpdateSparseBufferMappingOperation operation;
                    operation.mode = MTLSparseTextureMappingModeMap;
                    operation.bufferRange = NSMakeRange(0, 1);
                    operation.heapOffset = 0;
                    [queue updateBufferMappings:buffer heap:heap operations:&operation count:1];
                    break;
                }
                case CaseBufferCopySparseSource:
                case CaseBufferCopyPlainSource: {
                    MTL4CopySparseBufferMappingOperation operation;
                    operation.sourceRange = NSMakeRange(0, 1);
                    operation.destinationOffset = 0;
                    [queue copyBufferMappingsFromBuffer:buffer toBuffer:second operations:&operation count:1];
                    break;
                }
                case CaseTextureUpdatePlain: {
                    MTL4UpdateSparseTextureMappingOperation operation;
                    operation.mode = MTLSparseTextureMappingModeMap;
                    operation.textureRegion = MTLRegionMake2D(0, 0, 1, 1);
                    operation.textureLevel = 0;
                    operation.textureSlice = 0;
                    operation.heapOffset = 0;
                    [queue updateTextureMappings:texture heap:heap operations:&operation count:1];
                    break;
                }
                case CaseTextureCopyPlain: {
                    MTL4CopySparseTextureMappingOperation operation;
                    operation.sourceRegion = MTLRegionMake2D(0, 0, 1, 1);
                    operation.sourceLevel = 0;
                    operation.sourceSlice = 0;
                    operation.destinationOrigin = MTLOriginMake(0, 0, 0);
                    operation.destinationLevel = 0;
                    operation.destinationSlice = 0;
                    [queue copyTextureMappingsFromTexture:texture toTexture:other operations:&operation count:1];
                    break;
                }
            }
        }
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    if (WIFSIGNALED(status))
        return 128 + WTERMSIG(status);
    return WEXITSTATUS(status);
}

// The reason Metal printed, read back from the child's stderr: the text between the backquote and the quote of
// Metal's assertion, as the child wrote it.
static NSString *reason_of(const char *name)
{
    char path[1024];
    snprintf(path, sizeof path, "%s/%s.stderr", folder, name);
    NSString *text = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:path] encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSRange open = [text rangeOfString:@"failed assertion `"];
    if (open.location == NSNotFound)
        return nil;
    NSString *rest = [text substringFromIndex:NSMaxRange(open)];
    NSRange close = [rest rangeOfString:@"'"];
    return close.location == NSNotFound ? nil : [rest substringToIndex:close.location];
}

// A case Metal refuses: its status is the abort, its reason is the port's refusal text, and the port must
// return that exact text from its decision.
static void same_refusal(const char *name, Case which, NSString *portReason, NSString *what)
{
    checks++;
    int status = run_metal(which, name);
    NSString *metal = reason_of(name);
    if (status != 134) {
        fail(@"%@: Metal did not abort (status %d)", what, status);
        return;
    }
    if (![metal isEqualToString:portReason])
        fail(@"%@: Metal says <%@> and the port says <%@>", what, metal ?: @"nothing", portReason ?: @"nothing");
}

// A case Metal accepts. The port's decision must return no refusal for the inputs Metal was given, which
// is the arithmetic of the requirements, and the divergence is named: the method refuses the call anyway.
static void same_acceptance(const char *name, Case which, NSString *portReason, NSString *what)
{
    checks++;
    int status = run_metal(which, name);
    if (status != 0) {
        fail(@"%@: Metal did not accept the call (status %d)", what, status);
        return;
    }
    if (portReason)
        fail(@"%@: the port's decision refuses a call Metal accepts, with <%@>, and it is not one of the refusals this port makes", what, portReason);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 2) {
            printf("usage: differential <folder>\n");
            return 2;
        }
        folder = argv[1];

        // Buffer update, the three refusals Metal measured and the one it accepts.
        same_refusal("buffer-plain", CaseBufferPlain,
                     CharonMetal4SparseBufferUpdateRefusal(NO, YES, NO, YES),
                     @"a plain buffer, automatic heap");
        same_refusal("buffer-sparse-auto", CaseBufferSparseAutoHeap,
                     CharonMetal4SparseBufferUpdateRefusal(YES, YES, NO, YES),
                     @"a sparse buffer, automatic heap");
        same_refusal("buffer-sparse-nil", CaseBufferSparseNilHeapMap,
                     CharonMetal4SparseBufferUpdateRefusal(YES, NO, NO, YES),
                     @"a sparse buffer, nil heap, map");
        same_acceptance("buffer-sparse-placement", CaseBufferSparsePlacement,
                        CharonMetal4SparseBufferUpdateRefusal(YES, YES, YES, YES),
                        @"a sparse buffer, placement heap, map");

        // Buffer copy: the source is named before the destination.
        same_refusal("copy-sparse-source", CaseBufferCopySparseSource,
                     CharonMetal4SparseBufferCopyRefusal(YES, NO),
                     @"a sparse source, plain destination");
        same_refusal("copy-plain-source", CaseBufferCopyPlainSource,
                     CharonMetal4SparseBufferCopyRefusal(NO, NO),
                     @"a plain source, plain destination");

        // Texture forms: Metal accepts both with plain textures, so the port's refusal is its own, and the
        // check is that the port refuses with its own text and Metal's status is recorded as accepted.
        checks++;
        if (run_metal(CaseTextureUpdatePlain, "texture-update-plain") != 0)
            fail(@"texture update: Metal did not accept a plain texture with an automatic heap");
        if (!CharonMetal4SparseTextureUpdateRefusal(NO, YES, NO, YES))
            fail(@"texture update: the port's decision accepts a plain texture, and the port cannot map a tile");
        checks++;
        if (run_metal(CaseTextureCopyPlain, "texture-copy-plain") != 0)
            fail(@"texture copy: Metal did not accept plain textures");
        if (!CharonMetal4SparseTextureCopyRefusal(NO, NO))
            fail(@"texture copy: the port's decision accepts plain textures, and the port cannot map a tile");

        // The decision's order, pinned without Metal: a placement sparse buffer with a placement heap is the
        // only input the requirements accept, and the port's buffers never are sparse.
        checks++;
        if (CharonMetal4SparseBufferUpdateRefusal(YES, YES, YES, YES) != nil)
            fail(@"the requirements hold for a sparse buffer and a placement heap, and the decision refuses them");
        checks++;
        if (![CharonMetal4SparseBufferUpdateRefusal(NO, YES, YES, NO) isEqualToString:@"Buffer is not a Placement Sparse Buffer"])
            fail(@"the buffer check is not first: a plain buffer with a placement heap is named for the heap");

        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
