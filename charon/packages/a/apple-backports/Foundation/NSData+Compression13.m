#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <zlib.h>
#include <string.h>

typedef struct {
    const char *(*version)(void);
    int (*startDeflate)(z_streamp, int, int, int, int, int, const char *, int);
    int (*runDeflate)(z_streamp, int);
    int (*finishDeflate)(z_streamp);
    int (*startInflate)(z_streamp, int, const char *, int);
    int (*runInflate)(z_streamp, int);
    int (*finishInflate)(z_streamp);
} CharonZlib;

static const CharonZlib *charon_zlib(void)
{
    static CharonZlib zlib;
    static BOOL loaded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/usr/lib/libz.1.dylib", RTLD_LAZY);
        if (!handle)
            return;
        zlib.version = dlsym(handle, "zlibVersion");
        zlib.startDeflate = dlsym(handle, "deflateInit2_");
        zlib.runDeflate = dlsym(handle, "deflate");
        zlib.finishDeflate = dlsym(handle, "deflateEnd");
        zlib.startInflate = dlsym(handle, "inflateInit2_");
        zlib.runInflate = dlsym(handle, "inflate");
        zlib.finishInflate = dlsym(handle, "inflateEnd");
        loaded = zlib.version && zlib.startDeflate && zlib.runDeflate && zlib.finishDeflate && zlib.startInflate && zlib.runInflate && zlib.finishInflate;
    });
    return loaded ? &zlib : NULL;
}

static NSData *charon_zlib_compress(NSData *input)
{
    const CharonZlib *zlib = charon_zlib();
    if (!zlib)
        return nil;
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (zlib->startDeflate(&stream, 5, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, zlib->version(), (int)sizeof(stream)) != Z_OK)
        return nil;
    NSMutableData *output = [NSMutableData data];
    unsigned char buffer[16384];
    stream.next_in = (Bytef *)input.bytes;
    stream.avail_in = (uInt)input.length;
    int status;
    do {
        stream.next_out = buffer;
        stream.avail_out = sizeof(buffer);
        status = zlib->runDeflate(&stream, Z_FINISH);
        [output appendBytes:buffer length:sizeof(buffer) - stream.avail_out];
    } while (status == Z_OK || status == Z_BUF_ERROR);
    zlib->finishDeflate(&stream);
    return status == Z_STREAM_END ? output : nil;
}

static NSData *charon_zlib_decompress(NSData *input)
{
    const CharonZlib *zlib = charon_zlib();
    if (!zlib || !input.length)
        return nil;
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (zlib->startInflate(&stream, -15, zlib->version(), (int)sizeof(stream)) != Z_OK)
        return nil;
    NSMutableData *output = [NSMutableData data];
    unsigned char buffer[16384];
    stream.next_in = (Bytef *)input.bytes;
    stream.avail_in = (uInt)input.length;
    int status;
    do {
        stream.next_out = buffer;
        stream.avail_out = sizeof(buffer);
        status = zlib->runInflate(&stream, Z_NO_FLUSH);
        [output appendBytes:buffer length:sizeof(buffer) - stream.avail_out];
    } while (status == Z_OK);
    zlib->finishInflate(&stream);
    return status == Z_STREAM_END ? output : nil;
}

static const NSUInteger charon_lz4_block = 65536;

static void charon_put32(NSMutableData *data, uint32_t value)
{
    unsigned char bytes[4] = {value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF};
    [data appendBytes:bytes length:4];
}

static uint32_t charon_get32(const unsigned char *bytes)
{
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) | ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static void charon_lz4_length(NSMutableData *out, NSUInteger extra)
{
    while (extra >= 255) {
        unsigned char full = 255;
        [out appendBytes:&full length:1];
        extra -= 255;
    }
    unsigned char rest = (unsigned char)extra;
    [out appendBytes:&rest length:1];
}

static void charon_lz4_sequence(NSMutableData *out, const unsigned char *literals, NSUInteger literalLength, NSUInteger offset, NSUInteger matchLength)
{
    unsigned char token = (unsigned char)((literalLength >= 15 ? 15 : literalLength) << 4);
    if (matchLength)
        token |= (unsigned char)(matchLength - 4 >= 15 ? 15 : matchLength - 4);
    [out appendBytes:&token length:1];
    if (literalLength >= 15)
        charon_lz4_length(out, literalLength - 15);
    [out appendBytes:literals length:literalLength];
    if (!matchLength)
        return;
    unsigned char distance[2] = {offset & 0xFF, (offset >> 8) & 0xFF};
    [out appendBytes:distance length:2];
    if (matchLength - 4 >= 15)
        charon_lz4_length(out, matchLength - 4 - 15);
}

static NSData *charon_lz4_compress_block(const unsigned char *in, NSUInteger length)
{
    NSMutableData *out = [NSMutableData data];
    NSUInteger anchor = 0;
    if (length >= 13) {
        uint32_t table[4096];
        memset(table, 0, sizeof(table));
        NSUInteger limit = length - 12;
        NSUInteger at = 1;
        while (at < limit) {
            uint32_t sequence;
            memcpy(&sequence, in + at, 4);
            uint32_t slot = (sequence * 2654435761u) >> 20;
            NSUInteger candidate = table[slot];
            table[slot] = (uint32_t)at;
            uint32_t earlier;
            memcpy(&earlier, in + candidate, 4);
            if (candidate >= at || at - candidate > 65535 || earlier != sequence) {
                at++;
                continue;
            }
            NSUInteger matchLength = 4;
            while (at + matchLength < length - 5 && in[candidate + matchLength] == in[at + matchLength])
                matchLength++;
            charon_lz4_sequence(out, in + anchor, at - anchor, at - candidate, matchLength);
            at += matchLength;
            anchor = at;
        }
    }
    charon_lz4_sequence(out, in + anchor, length - anchor, 0, 0);
    return out;
}

static NSData *charon_lz4_compress(NSData *input)
{
    NSMutableData *out = [NSMutableData data];
    const unsigned char *bytes = input.bytes;
    for (NSUInteger start = 0; start < input.length; start += charon_lz4_block) {
        NSUInteger length = MIN(charon_lz4_block, input.length - start);
        NSData *block = charon_lz4_compress_block(bytes + start, length);
        if (block.length < length) {
            [out appendBytes:"bv41" length:4];
            charon_put32(out, (uint32_t)length);
            charon_put32(out, (uint32_t)block.length);
            [out appendData:block];
        } else {
            [out appendBytes:"bv4-" length:4];
            charon_put32(out, (uint32_t)length);
            [out appendBytes:bytes + start length:length];
        }
    }
    [out appendBytes:"bv4$" length:4];
    return out;
}

static BOOL charon_lz4_decompress_block(const unsigned char *in, NSUInteger inLength, NSMutableData *out)
{
    NSUInteger at = 0;
    while (at < inLength) {
        unsigned char token = in[at++];
        NSUInteger literals = token >> 4;
        if (literals == 15) {
            unsigned char more;
            do {
                if (at >= inLength)
                    return NO;
                more = in[at++];
                literals += more;
            } while (more == 255);
        }
        if (literals > inLength - at || out.length + literals > 0x7FFFFFFFu)
            return NO;
        [out appendBytes:in + at length:literals];
        at += literals;
        if (at == inLength)
            break;
        if (inLength - at < 2)
            return NO;
        NSUInteger offset = in[at] | ((NSUInteger)in[at + 1] << 8);
        at += 2;
        NSUInteger match = token & 15;
        if (match == 15) {
            unsigned char more;
            do {
                if (at >= inLength)
                    return NO;
                more = in[at++];
                match += more;
            } while (more == 255);
        }
        match += 4;
        if (!offset || offset > out.length || out.length + match > 0x7FFFFFFFu)
            return NO;
        for (NSUInteger copied = 0; copied < match; copied++) {
            unsigned char byte = ((const unsigned char *)out.bytes)[out.length - offset];
            [out appendBytes:&byte length:1];
        }
    }
    return YES;
}

static NSData *charon_lz4_decompress(NSData *input)
{
    const unsigned char *bytes = input.bytes;
    NSUInteger length = input.length;
    NSUInteger at = 0;
    NSMutableData *out = [NSMutableData data];
    while (length - at >= 4) {
        if (!memcmp(bytes + at, "bv4$", 4))
            return at + 4 == length ? out : nil;
        if (length - at < 8)
            return nil;
        uint32_t size = charon_get32(bytes + at + 4);
        if (!memcmp(bytes + at, "bv4-", 4)) {
            if (length - at - 8 < size)
                return nil;
            [out appendBytes:bytes + at + 8 length:size];
            at += 8 + size;
        } else if (!memcmp(bytes + at, "bv41", 4)) {
            if (length - at < 12)
                return nil;
            uint32_t packed = charon_get32(bytes + at + 8);
            if (length - at - 12 < packed || !charon_lz4_decompress_block(bytes + at + 12, packed, out))
                return nil;
            at += 12 + packed;
        } else {
            return nil;
        }
    }
    return nil;
}

static NSData *charon_lzfse_store(NSData *input)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"LZFSE compression on iOS 6 writes the data as uncompressed blocks of the LZFSE format: any LZFSE reader takes it, but it is not smaller");
    });
    NSMutableData *out = [NSMutableData data];
    const unsigned char *bytes = input.bytes;
    NSUInteger length = input.length;
    NSUInteger block = 0x40000000;
    do {
        NSUInteger size = MIN(block, length);
        [out appendBytes:"bvx-" length:4];
        charon_put32(out, (uint32_t)size);
        [out appendBytes:bytes length:size];
        bytes += size;
        length -= size;
    } while (length);
    [out appendBytes:"bvx$" length:4];
    return out;
}

static NSData *charon_lzfse_read(NSData *input)
{
    const unsigned char *bytes = input.bytes;
    NSUInteger length = input.length;
    NSUInteger at = 0;
    NSMutableData *out = [NSMutableData data];
    while (length - at >= 4) {
        if (!memcmp(bytes + at, "bvx$", 4))
            return out;
        if (memcmp(bytes + at, "bvx-", 4) || length - at < 8)
            return nil;
        uint32_t size = charon_get32(bytes + at + 4);
        if (length - at - 8 < size)
            return nil;
        [out appendBytes:bytes + at + 8 length:size];
        at += 8 + size;
    }
    return nil;
}

NSData *charon_lzma_compress(NSData *input);
NSData *charon_lzma_decompress(NSData *input);

static NSData *charon_compress(NSData *data, NSDataCompressionAlgorithm algorithm, BOOL compressing, NSError **error)
{
    if (algorithm < NSDataCompressionAlgorithmLZFSE || algorithm > NSDataCompressionAlgorithmZlib)
        [NSException raise:NSInvalidArgumentException format:@"Unrecognized compression algorithm value: %ld", (long)algorithm];
    NSData *result = nil;
    NSString *reason = nil;
    if (algorithm == NSDataCompressionAlgorithmZlib) {
        result = compressing ? charon_zlib_compress(data) : charon_zlib_decompress(data);
        if (!charon_zlib())
            reason = @"zlib is not available in this process";
    } else if (algorithm == NSDataCompressionAlgorithmLZ4) {
        result = compressing ? charon_lz4_compress(data) : charon_lz4_decompress(data);
    } else if (algorithm == NSDataCompressionAlgorithmLZMA) {
        result = compressing ? charon_lzma_compress(data) : charon_lzma_decompress(data);
    } else {
        result = compressing ? charon_lzfse_store(data) : charon_lzfse_read(data);
        if (!result)
            reason = compressing ? nil : @"only LZFSE data written as uncompressed blocks can be read: the compressed blocks have no published format";
    }
    if (!result && error) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:compressing ? NSCompressionFailedError : NSDecompressionFailedError
                                 userInfo:reason ? @{NSDebugDescriptionErrorKey: reason} : nil];
    }
    return result;
}

@implementation NSData (CharonCompression)

- (NSData *)compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:(NSError **)error
{
    return charon_compress(self, algorithm, YES, error);
}

- (NSData *)decompressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:(NSError **)error
{
    return charon_compress(self, algorithm, NO, error);
}

@end

@implementation NSMutableData (CharonCompression)

- (BOOL)compressUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:(NSError **)error
{
    NSData *result = charon_compress(self, algorithm, YES, error);
    if (!result)
        return NO;
    [self setData:result];
    return YES;
}

- (BOOL)decompressUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:(NSError **)error
{
    NSData *result = charon_compress(self, algorithm, NO, error);
    if (!result)
        return NO;
    [self setData:result];
    return YES;
}

@end
