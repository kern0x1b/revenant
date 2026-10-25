#include <compression.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

int main(int argc, char **argv)
{
    if (argc != 4) return 2;
    size_t in_size = 0;
    uint8_t *in = read_file(argv[2], &in_size);
    if (!in) return 2;
    size_t capacity = in_size * 4 + 65536;
    uint8_t *out = malloc(capacity);
    size_t n = 0;
    if (strcmp(argv[1], "encode") == 0) {
        n = compression_encode_buffer(out, capacity, in, in_size, NULL, COMPRESSION_LZFSE);
    } else if (strcmp(argv[1], "decode") == 0) {
        n = compression_decode_buffer(out, capacity, in, in_size, NULL, COMPRESSION_LZFSE);
    } else {
        return 2;
    }
    if (n == 0) return 3;
    return write_file(argv[3], out, n);
}
