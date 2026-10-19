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

        uint64_t address = buffer.gpuAddress;
        answer("buffer.gpuAddress.nonzero", address != 0);
        answer("buffer.gpuAddress.stable", buffer.gpuAddress == address);
        id<MTLBuffer> other = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        answer("other.gpuAddress.differs", other.gpuAddress != address);

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

        id<MTLBuffer> empty = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        uint8_t zeros[length];
        memset(zeros, 0, length);
        memset(empty.contents, 0, length);
        [empty addDebugMarker:@"empty" range:NSMakeRange(0, length)];
        answer("empty.marker.bytesUnchanged", sameBytes(empty, zeros, length));
    }
    return 0;
}
