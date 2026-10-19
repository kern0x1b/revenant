/* buffer.m - the buffer's debug markers and its GPU address, asked the same questions on Apple's own Metal
 * (the host, macOS) and on the port (the iPhone 4S guest, iOS 6.1.3). The output is one line per answer, and
 * the two outputs are compared line for line: a difference is the finding, whichever side is right.
 *
 *     host:  clang -fobjc-arc -framework Foundation -framework Metal buffer.m
 *     port:  the same source, built the way tests/backports/device/commandbuffer-probe is built (xmake, armv7, 6.1.3)
 *
 * A marker names a range for a capture and changes no byte of the buffer, so the probe compares the bytes
 * before and after each call. The GPU address is asked as a relation (nonzero, the same on every read, and
 * different for two live buffers), never as a value: the port's address is a CPU address and Metal's is a
 * GPU one, and those are not the same numbers.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static void answer(const char *key, long value)
{
    printf("%s=%ld\n", key, value);
}

static BOOL sameBytes(id<MTLBuffer> buffer, const uint8_t *expected, NSUInteger length)
{
    return memcmp(buffer.contents, expected, length) == 0;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        answer("device.present", device != nil);
        if (!device)
            return 2;

        enum { length = 64 };
        id<MTLBuffer> buffer = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        answer("buffer.present", buffer != nil);
        if (!buffer)
            return 2;

        uint8_t original[length];
        for (NSUInteger i = 0; i < length; i++)
            original[i] = (uint8_t)(i * 3 + 1);
        memcpy(buffer.contents, original, length);

        /* The GPU address: nonzero, the same on every read for as long as the buffer lives, and different
         * from another live buffer's. */
        uint64_t address = buffer.gpuAddress;
        answer("buffer.gpuAddress.nonzero", address != 0);
        answer("buffer.gpuAddress.stable", buffer.gpuAddress == address);
        id<MTLBuffer> other = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        answer("other.gpuAddress.differs", other.gpuAddress != address);

        /* Debug markers: one over a range, one over the whole buffer, then the bulk removal. Each leaves the
         * bytes as they were, and the address as it was. */
        [buffer addDebugMarker:@"window" range:NSMakeRange(8, 16)];
        answer("marker.add.bytesUnchanged", sameBytes(buffer, original, length));
        answer("marker.add.addressUnchanged", buffer.gpuAddress == address);
        [buffer addDebugMarker:@"whole" range:NSMakeRange(0, length)];
        answer("marker.second.bytesUnchanged", sameBytes(buffer, original, length));
        [buffer removeAllDebugMarkers];
        answer("marker.removeAll.bytesUnchanged", sameBytes(buffer, original, length));
        answer("marker.removeAll.addressUnchanged", buffer.gpuAddress == address);
        [buffer removeAllDebugMarkers];
        answer("marker.removeAll.twice.bytesUnchanged", sameBytes(buffer, original, length));

        /* A marker on a buffer nothing has been written to is no different from one on a written buffer. */
        id<MTLBuffer> empty = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        uint8_t zeros[length];
        memset(zeros, 0, length);
        memset(empty.contents, 0, length);
        [empty addDebugMarker:@"empty" range:NSMakeRange(0, length)];
        answer("empty.marker.bytesUnchanged", sameBytes(empty, zeros, length));
    }
    return 0;
}
