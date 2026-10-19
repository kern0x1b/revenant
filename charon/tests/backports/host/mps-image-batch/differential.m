#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

NSUInteger CharonHostMPSImageBatchIncrementReadCount(MPSImageBatch *batch, NSInteger amount);
void CharonHostMPSImageBatchSynchronize(MPSImageBatch *batch, id<MTLCommandBuffer> cmdBuf);

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

static NSString *stderr_path(int which, int port, char *buffer, size_t size)
{
    snprintf(buffer, size, "%s/%s-%d.stderr", folder, port ? "port" : "metal", which);
    return [NSString stringWithUTF8String:buffer];
}

static int synchronise_status(int which, int port)
{
    char buffer[1024];
    NSString *path = stderr_path(which, port, buffer, sizeof buffer);
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        int fd = open(path.UTF8String, O_CREAT | O_TRUNC | O_WRONLY, 0644);
        dup2(fd, STDERR_FILENO);
        @autoreleasepool {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            id<MTLCommandQueue> queue = [device newCommandQueue];
            id<MTLCommandBuffer> cb = [queue commandBuffer];
            MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                   width:4 height:4 featureChannels:1];
            MPSImage *plain = [[MPSImage alloc] initWithDevice:device imageDescriptor:d];
            MPSTemporaryImage *temp = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            MPSImageBatch *batch = which == 0 ? @[plain] : which == 1 ? @[plain, temp] : @[temp];
            if (port)
                CharonHostMPSImageBatchSynchronize(batch, cb);
            else
                MPSImageBatchSynchronize(batch, cb);
        }
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) ? 128 + WTERMSIG(status) : WEXITSTATUS(status);
}

static NSString *stderr_of(int which, int port)
{
    char buffer[1024];
    NSString *path = stderr_path(which, port, buffer, sizeof buffer);
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 2) {
            printf("usage: differential <folder>\n");
            return 2;
        }
        folder = argv[1];

        checks++;
        if (synchronise_status(0, 0) != 0)
            fail(@"Metal refused a synchronise of a plain image");
        if (synchronise_status(0, 1) != 0)
            fail(@"the port refused a synchronise of a plain image");
        for (int which = 1; which <= 2; which++) {
            checks++;
            int metal = synchronise_status(which, 0);
            int port = synchronise_status(which, 1);
            if (metal != 134)
                fail(@"Metal's synchronise of case %d returned status %d and should abort (134)", which, metal);
            if (port != 134)
                fail(@"the port's synchronise of case %d returned status %d and should end the process (134)", which, port);
            NSString *needle = which == 1 ? @"image[1] is a temporary image" : @"image[0] is a temporary image";
            checks++;
            if ([stderr_of(which, 0) rangeOfString:needle].location == NSNotFound)
                fail(@"Metal's refusal of case %d does not name the image (%@)", which, needle);
            checks++;
            if ([stderr_of(which, 1) rangeOfString:needle].location == NSNotFound)
                fail(@"the port's refusal of case %d does not name the image (%@)", which, needle);
        }

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> cb = [queue commandBuffer];
        MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                               width:4 height:4 featureChannels:1];

        {
            MPSTemporaryImage *a = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            MPSTemporaryImage *b = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            MPSImageBatch *batch = @[a, a, b];
            NSUInteger metal = MPSImageBatchIncrementReadCount(batch, 2);
            NSUInteger metalA = a.readCount, metalB = b.readCount;

            MPSTemporaryImage *c = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            MPSTemporaryImage *c2 = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            MPSImageBatch *portBatch = @[c, c, c2];
            NSUInteger port = CharonHostMPSImageBatchIncrementReadCount(portBatch, 2);

            checks++;
            if (metal != 2)
                fail(@"Metal counted %lu distinct images in a batch of two, and the expectation is 2", (unsigned long)metal);
            if (port != metal)
                fail(@"the port counted %lu distinct images and Metal %lu", (unsigned long)port, (unsigned long)metal);
            checks++;
            if (metalA != 3 || metalB != 3)
                fail(@"Metal's counts after +2 are %lu and %lu, and the expectation is 3 and 3", (unsigned long)metalA, (unsigned long)metalB);
            checks++;
            if (c.readCount != metalA || c2.readCount != metalB)
                fail(@"the port's counts after +2 are %lu and %lu, and Metal's are %lu and %lu",
                     (unsigned long)c.readCount, (unsigned long)c2.readCount, (unsigned long)metalA, (unsigned long)metalB);
        }

        {
            MPSImage *plain = [[MPSImage alloc] initWithDevice:device imageDescriptor:d];
            MPSImageBatch *plainOnly = @[plain, plain];
            NSUInteger metal = MPSImageBatchIncrementReadCount(plainOnly, 1);
            NSUInteger port = CharonHostMPSImageBatchIncrementReadCount(plainOnly, 1);
            checks++;
            if (metal != 0 || port != 0)
                fail(@"plain images counted: Metal %lu, the port %lu, and the expectation is 0 for both",
                     (unsigned long)metal, (unsigned long)port);
        }

        {
            MPSTemporaryImage *t = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            MPSImageBatchIncrementReadCount(@[t], -1);
            NSUInteger metal = t.readCount;

            MPSTemporaryImage *u = [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d];
            CharonHostMPSImageBatchIncrementReadCount(@[u], -1);
            checks++;
            if (u.readCount != metal)
                fail(@"after -1 the port's count is %lu and Metal's is %lu", (unsigned long)u.readCount, (unsigned long)metal);
        }

        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
