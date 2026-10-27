#include <compression.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STREAM_INPUT_CHUNK 65536
#define STREAM_OUTPUT_BLOCK 4096

static uint8_t *read_file(const char *path, size_t *size)
{
    FILE *file = fopen(path, "rb");
    if (!file) return NULL;
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    uint8_t *bytes = malloc(length > 0 ? (size_t)length : 1);
    *size = fread(bytes, 1, (size_t)length, file);
    fclose(file);
    return bytes;
}

static int write_file(const char *path, const uint8_t *bytes, size_t size)
{
    FILE *file = fopen(path, "wb");
    if (!file) return 1;
    size_t written = fwrite(bytes, 1, size, file);
    fclose(file);
    return written == size ? 0 : 1;
}

static int stream_run(compression_stream_operation operation, const uint8_t *in, size_t in_size, FILE *out)
{
    compression_stream stream;
    if (compression_stream_init(&stream, operation, COMPRESSION_LZFSE) == COMPRESSION_STATUS_ERROR) return 1;
    uint8_t block[STREAM_OUTPUT_BLOCK];
    size_t offset = 0;
    int ended = 0;
    do {
        size_t chunk = in_size - offset < STREAM_INPUT_CHUNK ? in_size - offset : STREAM_INPUT_CHUNK;
        int last = offset + chunk == in_size;
        stream.src_ptr = in + offset;
        stream.src_size = chunk;
        offset += chunk;
        compression_status status;
        do {
            stream.dst_ptr = block;
            stream.dst_size = sizeof block;
            status = compression_stream_process(&stream, last ? COMPRESSION_STREAM_FINALIZE : 0);
            if (status == COMPRESSION_STATUS_ERROR) {
                compression_stream_destroy(&stream);
                return 2;
            }
            fwrite(block, 1, sizeof block - stream.dst_size, out);
            if (status == COMPRESSION_STATUS_END) {
                ended = 1;
                break;
            }
        } while (stream.src_size > 0 || (last && stream.dst_size == 0));
    } while (offset < in_size);
    compression_stream_destroy(&stream);
    return ended || operation == COMPRESSION_STREAM_ENCODE ? 0 : 4;
}

int main(int argc, char **argv)
{
    if (argc != 4) return 2;
    size_t in_size = 0;
    uint8_t *in = read_file(argv[2], &in_size);
    if (!in) return 2;
    if (strcmp(argv[1], "stream-encode") == 0 || strcmp(argv[1], "stream-decode") == 0) {
        FILE *out = fopen(argv[3], "wb");
        if (!out) return 1;
        int rc = stream_run(strcmp(argv[1], "stream-encode") == 0 ? COMPRESSION_STREAM_ENCODE : COMPRESSION_STREAM_DECODE, in, in_size, out);
        fclose(out);
        return rc;
    }
    size_t capacity = in_size * 4 + 65536;
    uint8_t *out = malloc(capacity);
    size_t n = 0;
    if (strcmp(argv[1], "encode") == 0) {
        n = compression_encode_buffer(out, capacity, in, in_size, NULL, COMPRESSION_LZFSE);
    } else if (strcmp(argv[1], "decode") == 0) {
        for (;;) {
            n = compression_decode_buffer(out, capacity, in, in_size, NULL, COMPRESSION_LZFSE);
            if (n < capacity) break;
            if (capacity >= ((size_t)1 << 28)) return 5;
            capacity *= 2;
            out = realloc(out, capacity);
        }
    } else {
        return 2;
    }
    if (n == 0) return 3;
    return write_file(argv[3], out, n);
}
