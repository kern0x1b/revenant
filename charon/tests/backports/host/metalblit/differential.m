// differential.m — the port's blits beside macOS Metal's, on the same inputs, in one process.
//
// What runs here is the port's own code, compiled from packages/a/apple-backports/Metal with its
// classes renamed, so the two cannot be confused for one another. What it covers is the part of a
// blit that is the port's own arithmetic rather than a call into OpenGL ES 2.0: the buffer-to-buffer
// copy, the byte-value fill, and the refusals. The texture side of a blit and the mip chain are ES 2.0
// objects, which a host has no way to make — the answers macOS Metal gives for those are recorded by
// oracle.m into metalblit-expectations.h and held to on the device by tests/backports/device/metalblit.m.
//
// Every expectation below is Apple's, measured by oracle.m and written into that header. Nothing here
// is checked against the port's own idea of what the answer should be.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <dlfcn.h>
#import "metalblit-expectations.h"

@interface CharonHostCharonMetalBuffer : NSObject
- (instancetype)initWithLength:(NSUInteger)length bytes:(const void *)bytes;
- (void *)bytes;
- (NSUInteger)length;
@end

@interface CharonHostCharonMetalBlitEncoder : NSObject
- (void)copyFromBuffer:(id)sourceBuffer sourceOffset:(NSUInteger)sourceOffset
               toBuffer:(id)destinationBuffer destinationOffset:(NSUInteger)destinationOffset size:(NSUInteger)size;
- (void)fillBuffer:(id)buffer range:(NSRange)range value:(uint8_t)value;
- (void)optimizeContentsForCPUAccess:(id)texture;
- (void)optimizeContentsForCPUAccess:(id)texture slice:(NSUInteger)slice level:(NSUInteger)level;
- (void)optimizeContentsForGPUAccess:(id)texture;
- (void)optimizeContentsForGPUAccess:(id)texture slice:(NSUInteger)slice level:(NSUInteger)level;
@end

static int checks;
static int failures;

// The port REFUSES two blits Metal does not, and says why in its log. A refusal that is only LOGGED
// is not a result: the framework's objection was that the run printed "blit of 80 bytes at offset 8
// runs past the 64 bytes..." and still counted green, because the only thing compared was that the
// buffer was unchanged. So the words are captured and compared too, and a blit the port did not refuse
// fails on both counts.
static int failures;

// The port REFUSES two blits Metal does not, and says why in its log. A refusal that is only LOGGED
// is not a result: the framework's objection was that the run printed "blit of 80 bytes at offset 8
// runs past the 64 bytes..." and still counted green, because the only thing compared was that the
// buffer was unchanged. So the words are captured and compared too, and a blit the port did not
// refuse fails on both counts.
//
// NSLog is a C FUNCTION, not a method, so a method swizzle intercepts nothing - which the first
// attempt at this found, because the capture came back empty. It is interposed as a symbol instead:
// this definition wins at link time against the port's object, and the real one is reached through
// RTLD_NEXT.
static NSMutableArray *logged;

void NSLog(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    if (logged)
        [logged addObject:text];
    typedef void (*NSLogFunction)(NSString *, ...);
    static NSLogFunction real;
    if (!real)
        real = (NSLogFunction)dlsym(RTLD_NEXT, "NSLog");
    // the text goes through as TEXT, so the real NSLog does not read the digits in it as
    // conversion specifiers and print a different number than the one the port refused
    if (real)
        real(@"%@", text);
}

static void install_log_capture(void)
{
    logged = [NSMutableArray array];
}

// The port REFUSES two blits Metal does not, and says why in its log. A refusal that is only LOGGED
// is not a result: the framework's objection was that the run printed "blit of 80 bytes at offset 8
// runs past the 64 bytes..." and still counted green, because the only thing compared was that the
// buffer was unchanged. So the words are captured and compared too, and a blit the port did not refuse
// fails on both counts.

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static NSData *fromHex(const char *hex, NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger index = 0; index < length; index++) {
        unsigned value = 0;
        sscanf(hex + index * 2, "%2x", &value);
        bytes[index] = (uint8_t)value;
    }
    return data;
}

static void same_bytes(NSData *ours, const char *theirsHex, NSUInteger length, NSString *what)
{
    checks++;
    NSData *theirs = fromHex(theirsHex, length);
    if ([ours isEqualToData:theirs])
        return;
    fail(@"%@: the port and Metal differ", what);
    printf("  ours   %s\n", ours.description.UTF8String);
    printf("  Metal  %s\n", theirs.description.UTF8String);
}

int main(void)
{
    @autoreleasepool {
        install_log_capture();
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = [device newCommandQueue];

        // 1. A fill of one byte value over a range, the port's memset against Metal's fill.
        {
            CharonHostCharonMetalBuffer *port = [[CharonHostCharonMetalBuffer alloc] initWithLength:64 bytes:NULL];
            memset(port.bytes, 0, 64);
            CharonHostCharonMetalBlitEncoder *blit = [[CharonHostCharonMetalBlitEncoder alloc] init];
            [blit fillBuffer:port range:NSMakeRange(8, 16) value:0xAB];

            id<MTLBuffer> system = [device newBufferWithLength:64 options:0];
            memset(system.contents, 0, 64);
            id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
            id<MTLBlitCommandEncoder> systemBlit = [commandBuffer blitCommandEncoder];
            [systemBlit fillBuffer:system range:NSMakeRange(8, 16) value:0xAB];
            [systemBlit endEncoding];
            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];
            if (commandBuffer.error)
                fail(@"Metal's fill failed: %@", commandBuffer.error);

            same_bytes([NSData dataWithBytes:port.bytes length:64], metalblit_fill, 64, @"fillBuffer:range:value:");
        }

        // 2. A copy of sixteen bytes from offset eight to offset forty.
        {
            uint8_t pattern[64];
            for (int index = 0; index < 64; index++)
                pattern[index] = (uint8_t)index;

            CharonHostCharonMetalBuffer *portSource = [[CharonHostCharonMetalBuffer alloc] initWithLength:64 bytes:pattern];
            CharonHostCharonMetalBuffer *portDestination = [[CharonHostCharonMetalBuffer alloc] initWithLength:64 bytes:NULL];
            CharonHostCharonMetalBlitEncoder *blit = [[CharonHostCharonMetalBlitEncoder alloc] init];
            [blit copyFromBuffer:portSource sourceOffset:8 toBuffer:portDestination destinationOffset:40 size:16];

            same_bytes([NSData dataWithBytes:portDestination.bytes length:64], metalblit_buffer_copy, 64,
                       @"copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:");
        }

        // 3. The same buffer at both ends, overlapping. The port's copy is a memmove, and this is what
        //    decides that it may be: Metal's own answer for an overlap is recorded beside the answer a
        //    memmove gives, and the two are equal, so a memmove is the right primitive and not a
        //    convenient one.
        {
            uint8_t pattern[64];
            for (int index = 0; index < 64; index++)
                pattern[index] = (uint8_t)index;

            CharonHostCharonMetalBuffer *port = [[CharonHostCharonMetalBuffer alloc] initWithLength:64 bytes:pattern];
            CharonHostCharonMetalBlitEncoder *blit = [[CharonHostCharonMetalBlitEncoder alloc] init];
            [blit copyFromBuffer:port sourceOffset:0 toBuffer:port destinationOffset:8 size:32];

            checks++;
            if (strcmp(fromHex(metalblit_buffer_overlap, 64).description.UTF8String, fromHex(metalblit_buffer_overlap_memmove, 64).description.UTF8String) != 0)
                fail(@"Metal's overlapping copy is not what a memmove gives, and the port's is a memmove: the difference has to be named");
            same_bytes([NSData dataWithBytes:port.bytes length:64], metalblit_buffer_overlap, 64,
                       @"an overlapping copy, which the port makes with a memmove");
        }

        // 4. The two refusals the port makes that Metal does not. Metal writes what fits and says
        //    nothing (oracle.m recorded a region readback that stopped two rows short of the five
        //    asked for, because the buffer ended there); the port refuses the whole blit and says why.
        //    These are pinned here so the divergence cannot widen unnoticed.
        {
            uint8_t pattern[64];
            for (int index = 0; index < 64; index++)
                pattern[index] = (uint8_t)index;

            CharonHostCharonMetalBuffer *port = [[CharonHostCharonMetalBuffer alloc] initWithLength:64 bytes:pattern];
            CharonHostCharonMetalBlitEncoder *blit = [[CharonHostCharonMetalBlitEncoder alloc] init];
            [blit fillBuffer:port range:NSMakeRange(8, 80) value:0xCC];
            [blit copyFromBuffer:port sourceOffset:0 toBuffer:port destinationOffset:32 size:64];

            checks++;
            NSData *after = [NSData dataWithBytes:port.bytes length:64];
            if (![after isEqualToData:[NSData dataWithBytes:pattern length:64]])
                fail(@"a blit past the end of a buffer was made where it should have been refused, and the difference is not one facts/Metal/Blits.md names");
            // And the port must have SAID so, in the words facts/Metal/Blits.md promises. A refusal
            // that only changes the buffer is checked above; one that also says nothing is a silent
            // refusal, and this is what the framework objected to being counted green.
            NSString *said = [logged componentsJoinedByString:@"\n"];
            NSArray *wanted = @[@"80 bytes", @"64 bytes", @"runs past"];
            for (NSString *needle in wanted) {
                checks++;
                if ([said rangeOfString:needle].location == NSNotFound)
                    fail(@"the port refused the blit but did not say %@, and a refusal that is only in the buffer is not a result: it said <%@>",
                         needle, said.length ? said : @"nothing at all");
            }
        }

        // 5. The four access hints of 12.0, on a texture Metal holds. Metal's hints move the texture's
        //    residency and nothing a reader can see, so the bytes are the same after them. The port's
        //    hints do nothing: they take the same texture, leave it alone, and say nothing (the one-time
        //    log they used to keep is gone, and the port must not log).
        {
            MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                  width:4 height:4 mipmapped:NO];
            descriptor.storageMode = MTLStorageModeManaged;
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            uint8_t pixels[64];
            for (int index = 0; index < 64; index++)
                pixels[index] = (uint8_t)(index * 3);
            MTLRegion region = MTLRegionMake2D(0, 0, 4, 4);
            [texture replaceRegion:region mipmapLevel:0 withBytes:pixels bytesPerRow:16];

            id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
            id<MTLBlitCommandEncoder> systemBlit = [commandBuffer blitCommandEncoder];
            [systemBlit optimizeContentsForCPUAccess:texture];
            [systemBlit optimizeContentsForGPUAccess:texture];
            [systemBlit optimizeContentsForCPUAccess:texture slice:0 level:0];
            [systemBlit optimizeContentsForGPUAccess:texture slice:0 level:0];
            [systemBlit endEncoding];
            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];
            if (commandBuffer.error)
                fail(@"Metal refused its own access hints: %@", commandBuffer.error);

            uint8_t after[64];
            [texture getBytes:after bytesPerRow:16 fromRegion:region mipmapLevel:0];
            checks++;
            if (memcmp(after, pixels, 64) != 0)
                fail(@"Metal's access hints changed the bytes of a texture, which a hint must not do");

            CharonHostCharonMetalBlitEncoder *blit = [[CharonHostCharonMetalBlitEncoder alloc] init];
            NSUInteger logBefore = logged.count;
            [blit optimizeContentsForCPUAccess:texture];
            [blit optimizeContentsForGPUAccess:texture];
            [blit optimizeContentsForCPUAccess:texture slice:0 level:0];
            [blit optimizeContentsForGPUAccess:texture slice:0 level:0];
            checks++;
            if (logged.count != logBefore)
                fail(@"the port's access hints said something (%@), and a hint with no effect has nothing to say", [logged lastObject]);
        }

        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
