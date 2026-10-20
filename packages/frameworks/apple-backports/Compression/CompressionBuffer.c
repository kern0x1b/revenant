#include <compression.h>
#include <lz4/lz4.h>
#include <lzfse/lzfse.h>
#include <lzfse/lzfse_internal.h>
#include <lzfse/lzvn_decode_base.h>
#include <lzma/lzma.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib/zlib.h>

static const uint8_t kCompressedBlock[4] = {'b', 'v', '4', '1'};
static const uint8_t kStoredBlock[4] = {'b', 'v', '4', '-'};
static const uint8_t kEndOfStream[4] = {'b', 'v', '4', '$'};

enum { kLZ4BlockSize = 0x10000 };

#define COMPRESSION_EXPORT __attribute__((visibility("default")))

enum decode_status { kDecodeFailed, kDecodeDone, kDecodeFull };

static enum decode_status decoded(size_t *n, size_t bytes, enum decode_status status)
{
    *n = bytes;
    return status;
}

static void put32(uint8_t *at, uint32_t value)
{
    at[0] = (uint8_t)value;
    at[1] = (uint8_t)(value >> 8);
    at[2] = (uint8_t)(value >> 16);
    at[3] = (uint8_t)(value >> 24);
}

static uint32_t get32(const uint8_t *at)
{
    return (uint32_t)at[0] | (uint32_t)at[1] << 8 | (uint32_t)at[2] << 16 | (uint32_t)at[3] << 24;
}

static size_t encode_lz4_block(uint8_t *dst, size_t room, const uint8_t *src, size_t raw)
{
    enum { kEndSize = 4, kCompressedHeader = 12, kStoredHeader = 8 };
    size_t limit = room > kCompressedHeader + kEndSize ? room - kCompressedHeader - kEndSize : 0;
    if (limit > raw - 1) limit = raw - 1;
    int packed = limit ? LZ4_compress_default((const char *)src, (char *)dst + kCompressedHeader, (int)raw, (int)limit + 1) : 0;
    if (packed > 0 && (size_t)packed <= limit) {
        memcpy(dst, kCompressedBlock, 4);
        put32(dst + 4, (uint32_t)raw);
        put32(dst + 8, (uint32_t)packed);
        return kCompressedHeader + (size_t)packed;
    }
    if (kStoredHeader + raw + kEndSize > room) return 0;
    memcpy(dst, kStoredBlock, 4);
    put32(dst + 4, (uint32_t)raw);
    memcpy(dst + kStoredHeader, src, raw);
    return kStoredHeader + raw;
}

static size_t encode_lz4_frame(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size)
{
    enum { kEndSize = 4 };
    size_t out = 0, done = 0;
    while (done < src_size) {
        size_t raw = src_size - done < kLZ4BlockSize ? src_size - done : kLZ4BlockSize;
        size_t written = encode_lz4_block(dst + out, dst_size - out, src + done, raw);
        if (!written) return 0;
        out += written;
        done += raw;
    }
    if (out + kEndSize > dst_size) return 0;
    memcpy(dst + out, kEndOfStream, 4);
    return out + kEndSize;
}

static enum decode_status decode_lz4_frame(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size, size_t *n)
{
    enum { kDictionary = 0x10000 };
    size_t in = 0, out = 0;
    for (;;) {
        if (in + 4 > src_size) return decoded(n, 0, kDecodeFailed);
        if (memcmp(src + in, kEndOfStream, 4) == 0) return decoded(n, out, kDecodeDone);
        if (in + 8 > src_size) return decoded(n, 0, kDecodeFailed);
        uint32_t raw = get32(src + in + 4);
        if (memcmp(src + in, kStoredBlock, 4) == 0) {
            if (raw > src_size - in - 8) return decoded(n, 0, kDecodeFailed);
            if (raw > dst_size - out) {
                memcpy(dst + out, src + in + 8, dst_size - out);
                return decoded(n, dst_size, kDecodeFull);
            }
            memcpy(dst + out, src + in + 8, raw);
            in += 8 + raw;
            out += raw;
        } else if (memcmp(src + in, kCompressedBlock, 4) == 0) {
            if (in + 12 > src_size) return decoded(n, 0, kDecodeFailed);
            uint32_t packed = get32(src + in + 8);
            if (packed > src_size - in - 12) return decoded(n, 0, kDecodeFailed);
            size_t room = dst_size - out;
            size_t dictionary = out < kDictionary ? out : kDictionary;
            const char *dict = (const char *)dst + out - dictionary;
            char *block = raw <= room ? (char *)dst + out : malloc(raw);
            if (!block) return decoded(n, 0, kDecodeFailed);
            int got = LZ4_decompress_safe_usingDict((const char *)src + in + 12, block, (int)packed, (int)raw, dict,
                                                    (int)dictionary);
            if (raw > room) {
                if (got == (int)raw) memcpy(dst + out, block, room);
                free(block);
                return got == (int)raw ? decoded(n, dst_size, kDecodeFull) : decoded(n, 0, kDecodeFailed);
            }
            if ((uint32_t)got != raw) return decoded(n, 0, kDecodeFailed);
            in += 12 + packed;
            out += raw;
        } else {
            return decoded(n, 0, kDecodeFailed);
        }
    }
}

static size_t encode_zlib(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size)
{
    z_stream s;
    memset(&s, 0, sizeof s);
    if (deflateInit2(&s, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) != Z_OK) return 0;
    uLong bound = deflateBound(&s, (uLong)src_size);
    uint8_t *stream = malloc(bound);
    size_t out = 0;
    if (stream) {
        s.next_in = (Bytef *)src;
        s.avail_in = (uInt)src_size;
        s.next_out = stream;
        s.avail_out = (uInt)bound;
        if (deflate(&s, Z_FINISH) == Z_STREAM_END && s.total_out <= dst_size) {
            memcpy(dst, stream, (size_t)s.total_out);
            out = (size_t)s.total_out;
        }
        free(stream);
    }
    deflateEnd(&s);
    return out;
}

static enum decode_status decode_zlib(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size, size_t *n)
{
    z_stream s;
    memset(&s, 0, sizeof s);
    if (inflateInit2(&s, -15) != Z_OK) return decoded(n, 0, kDecodeFailed);
    s.next_in = (Bytef *)src;
    s.avail_in = (uInt)src_size;
    s.next_out = dst;
    s.avail_out = (uInt)dst_size;
    int status = inflate(&s, Z_FINISH);
    enum decode_status result = decoded(n, 0, kDecodeFailed);
    if (status == Z_STREAM_END) result = decoded(n, (size_t)s.total_out, kDecodeDone);
    else if (status == Z_BUF_ERROR && s.avail_out == 0) result = decoded(n, dst_size, kDecodeFull);
    inflateEnd(&s);
    return result;
}

static enum decode_status decode_lz4_raw(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size, size_t *n)
{
    size_t in = 0, out = 0;
    for (;;) {
        if (in == src_size) return decoded(n, out, kDecodeDone);
        uint8_t token = src[in++];
        size_t literals = token >> 4;
        if (literals == 15) {
            uint8_t more;
            do {
                if (in == src_size) return decoded(n, 0, kDecodeFailed);
                more = src[in++];
                literals += more;
            } while (more == 255);
        }
        if (src_size - in < literals) return decoded(n, 0, kDecodeFailed);
        size_t room = dst_size - out;
        size_t copied = literals < room ? literals : room;
        memcpy(dst + out, src + in, copied);
        out += copied;
        in += copied;
        if (copied < literals) return decoded(n, dst_size, kDecodeFull);
        if (in == src_size) return decoded(n, out, kDecodeDone);
        if (in + 2 > src_size) return decoded(n, 0, kDecodeFailed);
        size_t offset = (size_t)src[in] | (size_t)src[in + 1] << 8;
        in += 2;
        if (offset == 0 || offset > out) return decoded(n, 0, kDecodeFailed);
        size_t match = (token & 15) + 4;
        if ((token & 15) == 15) {
            uint8_t more;
            do {
                if (in == src_size) return decoded(n, 0, kDecodeFailed);
                more = src[in++];
                match += more;
            } while (more == 255);
        }
        for (size_t i = 0; i < match; i++) {
            if (out == dst_size) return decoded(n, dst_size, kDecodeFull);
            dst[out] = dst[out - offset];
            out++;
        }
    }
}

enum { kLZMAPreset = 6 };

static size_t encode_lzma(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size)
{
    size_t bound = lzma_stream_buffer_bound(src_size);
    uint8_t *stream = malloc(bound);
    size_t out = 0;
    if (stream) {
        size_t pos = 0;
        if (lzma_easy_buffer_encode(kLZMAPreset, LZMA_CHECK_NONE, NULL, src, src_size, stream, &pos, bound) == LZMA_OK && pos <= dst_size) {
            memcpy(dst, stream, pos);
            out = pos;
        }
        free(stream);
    }
    return out;
}

static enum decode_status decode_lzma(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size, size_t *n)
{
    lzma_stream s = LZMA_STREAM_INIT;
    if (lzma_stream_decoder(&s, UINT64_MAX, 0) != LZMA_OK) return decoded(n, 0, kDecodeFailed);
    s.next_in = src;
    s.avail_in = src_size;
    s.next_out = dst;
    s.avail_out = dst_size;
    lzma_ret status;
    do {
        status = lzma_code(&s, LZMA_FINISH);
    } while (status == LZMA_OK && s.avail_out > 0);
    size_t out = dst_size - s.avail_out;
    lzma_end(&s);
    if (status == LZMA_STREAM_END) return decoded(n, out, kDecodeDone);
    if (s.avail_out == 0 && (status == LZMA_OK || status == LZMA_BUF_ERROR)) return decoded(n, dst_size, kDecodeFull);
    return decoded(n, 0, kDecodeFailed);
}

static int lzfse_holds_no_bytes(const uint8_t *src, size_t src_size)
{
    static const uint8_t kStored[4] = {'b', 'v', 'x', '-'}, kEnd[4] = {'b', 'v', 'x', '$'};
    size_t in = 0;
    for (;;) {
        if (in + 4 > src_size) return 0;
        if (memcmp(src + in, kEnd, 4) == 0) return in + 4 == src_size;
        if (memcmp(src + in, kStored, 4) != 0 || in + 8 > src_size || get32(src + in + 4) != 0) return 0;
        in += 8;
    }
}

static enum decode_status decode_lzfse(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size, void *scratch, size_t *n)
{
    void *work = scratch ? scratch : malloc(lzfse_decode_scratch_size());
    if (!work) return decoded(n, 0, kDecodeFailed);
    size_t out = lzfse_decode_buffer(dst, dst_size, src, src_size, work);
    if (!scratch) free(work);
    if (out) return decoded(n, out, out == dst_size ? kDecodeFull : kDecodeDone);
    return decoded(n, 0, lzfse_holds_no_bytes(src, src_size) ? kDecodeDone : kDecodeFailed);
}

static enum decode_status decode_codec(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size, void *scratch,
                                       compression_algorithm algorithm, size_t *n)
{
    switch (algorithm) {
    case COMPRESSION_LZFSE: return decode_lzfse(dst, dst_size, src, src_size, scratch, n);
    case COMPRESSION_ZLIB: return decode_zlib(dst, dst_size, src, src_size, n);
    case COMPRESSION_LZ4: return decode_lz4_frame(dst, dst_size, src, src_size, n);
    case COMPRESSION_LZ4_RAW: return decode_lz4_raw(dst, dst_size, src, src_size, n);
    case COMPRESSION_LZMA: return decode_lzma(dst, dst_size, src, src_size, n);
    default: return decoded(n, 0, kDecodeFailed);
    }
}

COMPRESSION_EXPORT size_t compression_encode_scratch_buffer_size(compression_algorithm algorithm)
{
    switch (algorithm) {
    case COMPRESSION_LZFSE: return lzfse_encode_scratch_size();
    default: return 0;
    }
}

COMPRESSION_EXPORT size_t compression_decode_scratch_buffer_size(compression_algorithm algorithm)
{
    switch (algorithm) {
    case COMPRESSION_LZFSE: return lzfse_decode_scratch_size();
    default: return 0;
    }
}

COMPRESSION_EXPORT size_t compression_encode_buffer(uint8_t *__restrict dst_buffer, size_t dst_size, const uint8_t *__restrict src_buffer,
                                 size_t src_size, void *__nullable scratch_buffer, compression_algorithm algorithm)
{
    if (!dst_buffer || !src_buffer && src_size) return 0;
    switch (algorithm) {
    case COMPRESSION_LZFSE:
        {
            void *work = scratch_buffer ? scratch_buffer : malloc(lzfse_encode_scratch_size());
            size_t bound = 2 * src_size + 4096;
            uint8_t *stream = work ? malloc(bound) : NULL;
            size_t out = 0;
            if (stream) {
                size_t n = lzfse_encode_buffer(stream, bound, src_buffer, src_size, work);
                if (n && n <= dst_size) {
                    memcpy(dst_buffer, stream, n);
                    out = n;
                }
                free(stream);
            }
            if (!scratch_buffer) free(work);
            return out;
        }
    case COMPRESSION_ZLIB:
        return encode_zlib(dst_buffer, dst_size, src_buffer, src_size);
    case COMPRESSION_LZ4:
        return encode_lz4_frame(dst_buffer, dst_size, src_buffer, src_size);
    case COMPRESSION_LZMA:
        return encode_lzma(dst_buffer, dst_size, src_buffer, src_size);
    case COMPRESSION_LZ4_RAW:
        if (!src_size) return 0;
        if (src_size > 0x7fffffff || dst_size > 0x7fffffff) return 0;
        {
            int bound = LZ4_compressBound((int)src_size);
            char *stream = malloc((size_t)bound);
            size_t out = 0;
            if (stream) {
                int n = LZ4_compress_default((const char *)src_buffer, stream, (int)src_size, bound);
                if (n > 0 && (size_t)n <= dst_size) {
                    memcpy(dst_buffer, stream, (size_t)n);
                    out = (size_t)n;
                }
                free(stream);
            }
            return out;
        }
    default:
        return 0;
    }
}

COMPRESSION_EXPORT size_t compression_decode_buffer(uint8_t *__restrict dst_buffer, size_t dst_size, const uint8_t *__restrict src_buffer,
                                 size_t src_size, void *__nullable scratch_buffer, compression_algorithm algorithm)
{
    if (!dst_buffer || !src_buffer) return 0;
    size_t n = 0;
    enum decode_status status = decode_codec(dst_buffer, dst_size, src_buffer, src_size, scratch_buffer, algorithm, &n);
    if (algorithm == COMPRESSION_LZMA && status == kDecodeFull) return 0;
    return n;
}

enum { kStreamBlock = 0x10000, kLZFSEBlock = 0x8000, kOutputCapacity = 2 * 0x10000 + 8192, kPendingCapacity = 2 * 0x10000 + 16 };
enum { kChunkMax = 1 << 30, kLZFSEWindow = LZFSE_ENCODE_MAX_D_VALUE };
static const uint8_t kLZFSEEndOfStream[4] = {'b', 'v', 'x', '$'};
#define NO_OUTPUT ((size_t)-1)

struct layer_stream {
    compression_stream_operation operation;
    compression_algorithm algorithm;
    z_stream z;
    lzma_stream lz;
    void *work;
    uint8_t *pending;
    size_t pending_size;
    uint8_t *history;
    size_t history_size;
    size_t history_capacity;
    uint8_t *out;
    size_t out_size, out_done, out_capacity;
    size_t blocks;
    uint8_t *input;
    size_t input_size, input_capacity;
    size_t stored_left;
    uint8_t *frame;
    size_t frame_capacity;
    uint8_t *block;
    size_t block_capacity;
    lzvn_decoder_state lzvn;
    size_t lzvn_w, lzvn_n_raw;
    size_t lzvn_left;
    int lzvn_active;
    int ended, failed;
};

static void history_append(struct layer_stream *st, const uint8_t *data, size_t n);
static int stream_append_input(struct layer_stream *st, const uint8_t *src, size_t size);

static size_t take_input(struct layer_stream *st, compression_stream *s, size_t limit)
{
    size_t room = limit - st->pending_size;
    size_t n = s->src_size < room ? s->src_size : room;
    if (n) {
        memcpy(st->pending + st->pending_size, s->src_ptr, n);
        st->pending_size += n;
        s->src_ptr += n;
        s->src_size -= n;
    }
    return n;
}

static int lzfse_block(struct layer_stream *st)
{
    size_t n = lzfse_encode_buffer(st->out, kOutputCapacity, st->pending, st->pending_size, st->work);
    if (n < 4 || memcmp(st->out + n - 4, kLZFSEEndOfStream, 4) != 0) return 0;
    st->out_size = n - 4;
    st->out_done = 0;
    st->pending_size = 0;
    st->blocks++;
    return 1;
}

static int step_lz4_encode(struct layer_stream *st, compression_stream *s, int finalize)
{
    size_t taken = take_input(st, s, kStreamBlock);
    if (st->pending_size == kStreamBlock) {
        size_t n = encode_lz4_block(st->out, kOutputCapacity, st->pending, kStreamBlock);
        if (!n) return -1;
        st->out_size = n;
        st->out_done = 0;
        st->pending_size = 0;
        return 1;
    }
    if (taken) return 1;
    if (!finalize) return 0;
    if (st->pending_size) {
        size_t n = encode_lz4_block(st->out, kOutputCapacity, st->pending, st->pending_size);
        if (!n) return -1;
        st->out_size = n;
        st->out_done = 0;
        st->pending_size = 0;
    }
    memcpy(st->out + st->out_size, kEndOfStream, 4);
    st->out_size += 4;
    st->ended = 1;
    return 1;
}

static int step_lzfse_encode(struct layer_stream *st, compression_stream *s, int finalize)
{
    size_t taken = take_input(st, s, kLZFSEBlock);
    if (st->pending_size == kLZFSEBlock) return lzfse_block(st) ? 1 : -1;
    if (taken) return 1;
    if (!finalize) return 0;
    if (st->pending_size == 0 && st->blocks == 0) {
        size_t n = lzfse_encode_buffer(st->out, kOutputCapacity, st->pending, 0, st->work);
        if (!n) return -1;
        st->out_size = n;
        st->out_done = 0;
    } else {
        if (st->pending_size && !lzfse_block(st)) return -1;
        memcpy(st->out + st->out_size, kLZFSEEndOfStream, 4);
        st->out_size += 4;
    }
    st->ended = 1;
    return 1;
}

enum block_walk { kBlockBad, kBlockMore, kBlockReady, kBlockEnd };

static uint32_t packed_field(uint64_t word, int offset, int bits)
{
    return (uint32_t)((word >> offset) & ((UINT64_C(1) << bits) - 1));
}

static enum block_walk lzfse_block_walk(const uint8_t *src, size_t avail, size_t *size, size_t *n_raw)
{
    if (avail < 4) {
        *size = 4;
        return kBlockMore;
    }
    uint32_t magic = get32(src);
    if (magic == LZFSE_ENDOFSTREAM_BLOCK_MAGIC) {
        *size = 4;
        return kBlockEnd;
    }
    if (magic == LZFSE_UNCOMPRESSED_BLOCK_MAGIC) {
        if (avail < sizeof(uncompressed_block_header)) {
            *size = sizeof(uncompressed_block_header);
            return kBlockMore;
        }
        *n_raw = get32(src + offsetof(uncompressed_block_header, n_raw_bytes));
        *size = sizeof(uncompressed_block_header) + *n_raw;
    } else if (magic == LZFSE_COMPRESSEDLZVN_BLOCK_MAGIC) {
        if (avail < sizeof(lzvn_compressed_block_header)) {
            *size = sizeof(lzvn_compressed_block_header);
            return kBlockMore;
        }
        *n_raw = get32(src + offsetof(lzvn_compressed_block_header, n_raw_bytes));
        *size = sizeof(lzvn_compressed_block_header) + get32(src + offsetof(lzvn_compressed_block_header, n_payload_bytes));
    } else if (magic == LZFSE_COMPRESSEDV1_BLOCK_MAGIC) {
        if (avail < sizeof(lzfse_compressed_block_header_v1)) {
            *size = sizeof(lzfse_compressed_block_header_v1);
            return kBlockMore;
        }
        lzfse_compressed_block_header_v1 h1;
        memcpy(&h1, src, sizeof h1);
        *n_raw = h1.n_raw_bytes;
        *size = sizeof h1 + h1.n_literal_payload_bytes + h1.n_lmd_payload_bytes;
    } else if (magic == LZFSE_COMPRESSEDV2_BLOCK_MAGIC) {
        if (avail < offsetof(lzfse_compressed_block_header_v2, freq)) {
            *size = offsetof(lzfse_compressed_block_header_v2, freq);
            return kBlockMore;
        }
        lzfse_compressed_block_header_v2 h2;
        memcpy(&h2, src, offsetof(lzfse_compressed_block_header_v2, freq));
        size_t header = packed_field(h2.packed_fields[2], 0, 32);
        if (avail < header) {
            *size = header;
            return kBlockMore;
        }
        *n_raw = get32(src + offsetof(lzfse_compressed_block_header_v2, n_raw_bytes));
        size_t literal_payload = packed_field(h2.packed_fields[0], 20, 20), lmd_payload = packed_field(h2.packed_fields[1], 40, 20);
        *size = header + literal_payload + lmd_payload;
    } else {
        return kBlockBad;
    }
    if (avail < *size) return kBlockMore;
    return kBlockReady;
}

static int take_block_input(struct layer_stream *st, compression_stream *s, size_t size)
{
    size_t want = size - st->input_size;
    size_t n = s->src_size < want ? s->src_size : want;
    if (!n) return 0;
    if (!stream_append_input(st, s->src_ptr, n)) return -1;
    s->src_ptr += n;
    s->src_size -= n;
    return 1;
}

static int reserve(uint8_t **buf, size_t *capacity, size_t need)
{
    if (*capacity >= need) return 1;
    uint8_t *grown = realloc(*buf, need);
    if (!grown) return 0;
    *buf = grown;
    *capacity = need;
    return 1;
}

static int lzvn_start(struct layer_stream *st, uint32_t n_raw, uint32_t n_payload)
{
    size_t w = st->history_size;
    if ((size_t)n_raw > SIZE_MAX - w - 1) return -1;
    if (!reserve(&st->block, &st->block_capacity, w + n_raw + 1)) return -1;
    memcpy(st->block, st->history, w);
    memset(&st->lzvn, 0, sizeof st->lzvn);
    st->lzvn.dst_begin = st->block;
    st->lzvn.dst = st->block + w;
    st->lzvn_w = w;
    st->lzvn_n_raw = n_raw;
    st->lzvn_left = n_payload;
    st->input_size = 0;
    st->lzvn_active = 1;
    return 1;
}

static int step_lzvn(struct layer_stream *st, compression_stream *s, int finalize)
{
    size_t n = s->src_size < st->lzvn_left ? s->src_size : st->lzvn_left;
    if (n && !stream_append_input(st, s->src_ptr, n)) return -1;
    s->src_ptr += n;
    s->src_size -= n;
    st->lzvn_left -= n;
    lzvn_decoder_state *d = &st->lzvn;
    uint8_t *end = st->block + st->lzvn_w + st->lzvn_n_raw;
    size_t room = (size_t)(end + 1 - d->dst);
    if (room > kOutputCapacity) room = kOutputCapacity;
    d->src = st->input;
    d->src_end = st->input + st->input_size;
    d->dst_end = d->dst + room;
    uint8_t *from = d->dst;
    lzvn_decode(d);
    if (d->dst > end) return -1;
    size_t produced = (size_t)(d->dst - from);
    size_t used = (size_t)(d->src - st->input);
    if (used) {
        memmove(st->input, st->input + used, st->input_size - used);
        st->input_size -= used;
    }
    memcpy(st->out, from, produced);
    st->out_size = produced;
    st->out_done = 0;
    if (d->end_of_stream) {
        if (d->dst != end || st->lzvn_left || st->input_size) return -1;
        history_append(st, st->block + st->lzvn_w, st->lzvn_n_raw);
        st->lzvn_active = 0;
        return 1;
    }
    if (!n && !produced) {
        if (!st->lzvn_left) return -1;
        return finalize ? -1 : 0;
    }
    return 1;
}

static int step_lzfse_decode(struct layer_stream *st, compression_stream *s, int finalize)
{
    if (st->lzvn_active) return step_lzvn(st, s, finalize);
    if (st->stored_left) {
        size_t n = s->src_size < st->stored_left ? s->src_size : st->stored_left;
        if (n > kOutputCapacity) n = kOutputCapacity;
        if (!n) return finalize ? -1 : 0;
        memcpy(st->out, s->src_ptr, n);
        st->out_size = n;
        st->out_done = 0;
        history_append(st, st->out, n);
        s->src_ptr += n;
        s->src_size -= n;
        st->stored_left -= n;
        return 1;
    }
    if (st->input_size >= 8 && get32(st->input) == LZFSE_UNCOMPRESSED_BLOCK_MAGIC) {
        st->stored_left = get32(st->input + 4);
        st->input_size = 0;
        return 1;
    }
    if (st->input_size >= sizeof(lzvn_compressed_block_header) && get32(st->input) == LZFSE_COMPRESSEDLZVN_BLOCK_MAGIC) {
        uint32_t n_raw = get32(st->input + offsetof(lzvn_compressed_block_header, n_raw_bytes));
        if (n_raw) return lzvn_start(st, n_raw, get32(st->input + offsetof(lzvn_compressed_block_header, n_payload_bytes)));
    }
    size_t size = 0, n_raw = 0;
    enum block_walk walk = lzfse_block_walk(st->input, st->input_size, &size, &n_raw);
    if (walk == kBlockBad) return -1;
    if (walk == kBlockEnd) {
        st->ended = 1;
        return 1;
    }
    if (walk == kBlockMore) {
        int took = take_block_input(st, s, size);
        if (took < 0) return -1;
        if (!took) return finalize ? -1 : 0;
        return 1;
    }
    size_t w = st->history_size;
    size_t frame_size = (w ? 8 + w : 0) + size + 4;
    if (!reserve(&st->frame, &st->frame_capacity, frame_size)) return -1;
    size_t p = 0;
    if (w) {
        put32(st->frame, LZFSE_UNCOMPRESSED_BLOCK_MAGIC);
        put32(st->frame + 4, (uint32_t)w);
        memcpy(st->frame + 8, st->history, w);
        p = 8 + w;
    }
    memcpy(st->frame + p, st->input, size);
    put32(st->frame + p + size, LZFSE_ENDOFSTREAM_BLOCK_MAGIC);
    size_t cap = w + n_raw + 1;
    if (!reserve(&st->block, &st->block_capacity, cap)) return -1;
    size_t got = lzfse_decode_buffer(st->block, cap, st->frame, frame_size, st->work);
    if (w + n_raw == 0) {
        if (got != 0 || !lzfse_holds_no_bytes(st->frame, frame_size)) return -1;
    } else if (got != w + n_raw) {
        return -1;
    }
    if (!reserve(&st->out, &st->out_capacity, n_raw ? n_raw : 1)) return -1;
    memcpy(st->out, st->block + w, n_raw);
    st->out_size = n_raw;
    st->out_done = 0;
    history_append(st, st->block + w, n_raw);
    st->input_size = 0;
    return 1;
}

static int step_lz4_decode(struct layer_stream *st, compression_stream *s, int finalize)
{
    take_input(st, s, kPendingCapacity);
    uint8_t *p = st->pending;
    size_t have = st->pending_size;
    if (have >= 4 && memcmp(p, kEndOfStream, 4) == 0) {
        st->ended = 1;
        st->pending_size = 0;
        return 1;
    }
    if (have < 8) return finalize ? -1 : 0;
    uint32_t raw = get32(p + 4);
    if (raw > kStreamBlock) return -1;
    int stored = memcmp(p, kStoredBlock, 4) == 0;
    if (!stored && memcmp(p, kCompressedBlock, 4) != 0) return -1;
    size_t need = stored ? 8 + (size_t)raw : 12;
    if (!stored && have >= 12) need = 12 + (size_t)get32(p + 8);
    if (need > 12 + (size_t)kStreamBlock) return -1;
    if (have < need) return finalize ? -1 : 0;
    if (stored) {
        memcpy(st->out, p + 8, raw);
    } else if (LZ4_decompress_safe_usingDict((const char *)p + 12, (char *)st->out, (int)get32(p + 8), (int)raw,
                                             (const char *)st->history, (int)st->history_size) != (int)raw) {
        return -1;
    }
    st->out_size = raw;
    st->out_done = 0;
    history_append(st, st->out, raw);
    memmove(p, p + need, have - need);
    st->pending_size = have - need;
    return 1;
}

static int step_zlib(struct layer_stream *st, compression_stream *s, int finalize)
{
    z_stream *z = &st->z;
    uInt take = s->src_size > kChunkMax ? kChunkMax : (uInt)s->src_size;
    z->next_in = (Bytef *)s->src_ptr;
    z->avail_in = take;
    z->next_out = st->out;
    z->avail_out = kOutputCapacity;
    int r = st->operation == COMPRESSION_STREAM_ENCODE ? deflate(z, finalize ? Z_FINISH : Z_NO_FLUSH)
                                                       : inflate(z, Z_NO_FLUSH);
    size_t used = take - z->avail_in;
    if (used) {
        s->src_ptr += used;
        s->src_size -= used;
    }
    st->out_size = kOutputCapacity - z->avail_out;
    st->out_done = 0;
    if (r == Z_STREAM_END) {
        st->ended = 1;
        return 1;
    }
    if (r != Z_OK && r != Z_BUF_ERROR) return -1;
    return used || st->out_size ? 1 : 0;
}

static int step_lzma(struct layer_stream *st, compression_stream *s, int finalize)
{
    st->lz.next_in = s->src_ptr;
    st->lz.avail_in = s->src_size;
    st->lz.next_out = st->out;
    st->lz.avail_out = kOutputCapacity;
    lzma_ret r = lzma_code(&st->lz, finalize ? LZMA_FINISH : LZMA_RUN);
    size_t used = s->src_size - st->lz.avail_in;
    if (used) {
        s->src_ptr += used;
        s->src_size -= used;
    }
    st->out_size = kOutputCapacity - st->lz.avail_out;
    st->out_done = 0;
    if (r == LZMA_STREAM_END) {
        st->ended = 1;
        return 1;
    }
    if (r == LZMA_BUF_ERROR) return 0;
    if (r != LZMA_OK) return -1;
    return used || st->out_size ? 1 : 0;
}

static int step(struct layer_stream *st, compression_stream *s, int finalize)
{
    switch (st->algorithm) {
    case COMPRESSION_LZFSE:
        return st->operation == COMPRESSION_STREAM_ENCODE ? step_lzfse_encode(st, s, finalize) : step_lzfse_decode(st, s, finalize);
    case COMPRESSION_ZLIB: return step_zlib(st, s, finalize);
    case COMPRESSION_LZ4:
        return st->operation == COMPRESSION_STREAM_ENCODE ? step_lz4_encode(st, s, finalize) : step_lz4_decode(st, s, finalize);
    case COMPRESSION_LZMA: return step_lzma(st, s, finalize);
    default: return -1;
    }
}

static void history_append(struct layer_stream *st, const uint8_t *data, size_t n)
{
    size_t cap = st->history_capacity;
    if (n >= cap) {
        memcpy(st->history, data + n - cap, cap);
        st->history_size = cap;
        return;
    }
    size_t keep = st->history_size < cap - n ? st->history_size : cap - n;
    memmove(st->history, st->history + st->history_size - keep, keep);
    memcpy(st->history + keep, data, n);
    st->history_size = keep + n;
}

static int stream_append_input(struct layer_stream *st, const uint8_t *src, size_t size)
{
    if (size > SIZE_MAX - st->input_size) return 0;
    if (st->input_size + size > st->input_capacity) {
        size_t capacity = st->input_capacity ? st->input_capacity : 65536;
        while (capacity < st->input_size + size) {
            if (capacity > SIZE_MAX / 2) return 0;
            capacity *= 2;
        }
        uint8_t *grown = realloc(st->input, capacity);
        if (!grown) return 0;
        st->input = grown;
        st->input_capacity = capacity;
    }
    memcpy(st->input + st->input_size, src, size);
    st->input_size += size;
    return 1;
}

COMPRESSION_EXPORT compression_status compression_stream_init(compression_stream *stream, compression_stream_operation operation,
                                                             compression_algorithm algorithm)
{
    if (!stream) return COMPRESSION_STATUS_ERROR;
    if (operation != COMPRESSION_STREAM_ENCODE && operation != COMPRESSION_STREAM_DECODE) return COMPRESSION_STATUS_ERROR;
    switch (algorithm) {
    case COMPRESSION_LZFSE:
    case COMPRESSION_ZLIB:
    case COMPRESSION_LZ4:
    case COMPRESSION_LZMA:
        break;
    default:
        return COMPRESSION_STATUS_ERROR;
    }
    struct layer_stream *st = calloc(1, sizeof *st);
    if (!st) return COMPRESSION_STATUS_ERROR;
    st->operation = operation;
    st->algorithm = algorithm;
    st->pending = malloc(kPendingCapacity);
    st->out = malloc(kOutputCapacity);
    st->out_capacity = kOutputCapacity;
    st->history_capacity = algorithm == COMPRESSION_LZFSE && operation == COMPRESSION_STREAM_DECODE ? kLZFSEWindow : kStreamBlock;
    st->history = malloc(st->history_capacity);
    int ok = st->pending && st->out && st->history;
    if (ok && algorithm == COMPRESSION_LZFSE) {
        st->work = malloc(operation == COMPRESSION_STREAM_ENCODE ? lzfse_encode_scratch_size() : lzfse_decode_scratch_size());
        ok = st->work != NULL;
    }
    if (ok && algorithm == COMPRESSION_ZLIB) {
        ok = (operation == COMPRESSION_STREAM_ENCODE
                  ? deflateInit2(&st->z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY)
                  : inflateInit2(&st->z, -15)) == Z_OK;
    }
    if (ok && algorithm == COMPRESSION_LZMA) {
        ok = (operation == COMPRESSION_STREAM_ENCODE ? lzma_easy_encoder(&st->lz, kLZMAPreset, LZMA_CHECK_NONE)
                                                     : lzma_stream_decoder(&st->lz, UINT64_MAX, 0)) == LZMA_OK;
    }
    if (!ok) {
        free(st->work);
        free(st->pending);
        free(st->out);
        free(st->history);
        free(st);
        return COMPRESSION_STATUS_ERROR;
    }
    stream->dst_ptr = NULL;
    stream->dst_size = 0;
    stream->src_ptr = NULL;
    stream->src_size = 0;
    stream->state = st;
    return COMPRESSION_STATUS_OK;
}

COMPRESSION_EXPORT compression_status compression_stream_process(compression_stream *stream, int flags)
{
    struct layer_stream *st = stream ? stream->state : NULL;
    if (!st || st->failed || (stream->src_size && !stream->src_ptr) || (stream->dst_size && !stream->dst_ptr)) {
        return COMPRESSION_STATUS_ERROR;
    }
    int finalize = (flags & COMPRESSION_STREAM_FINALIZE) != 0;
    for (;;) {
        size_t left = st->out_size - st->out_done;
        if (left) {
            size_t n = left < stream->dst_size ? left : stream->dst_size;
            if (n) {
                memcpy(stream->dst_ptr, st->out + st->out_done, n);
                stream->dst_ptr += n;
                stream->dst_size -= n;
                st->out_done += n;
            }
            if (st->out_done < st->out_size) return COMPRESSION_STATUS_OK;
        }
        if (st->ended) return finalize ? COMPRESSION_STATUS_END : COMPRESSION_STATUS_OK;
        int r = step(st, stream, finalize);
        if (r < 0 || (r == 0 && finalize)) {
            st->failed = 1;
            return COMPRESSION_STATUS_ERROR;
        }
        if (r == 0) return COMPRESSION_STATUS_OK;
    }
}

COMPRESSION_EXPORT compression_status compression_stream_destroy(compression_stream *stream)
{
    struct layer_stream *st = stream ? stream->state : NULL;
    if (!st) return COMPRESSION_STATUS_ERROR;
    if (st->algorithm == COMPRESSION_ZLIB) {
        if (st->operation == COMPRESSION_STREAM_ENCODE) deflateEnd(&st->z);
        else inflateEnd(&st->z);
    }
    if (st->algorithm == COMPRESSION_LZMA) lzma_end(&st->lz);
    free(st->work);
    free(st->pending);
    free(st->out);
    free(st->history);
    free(st->input);
    free(st->frame);
    free(st->block);
    free(st);
    stream->state = NULL;
    return COMPRESSION_STATUS_OK;
}
