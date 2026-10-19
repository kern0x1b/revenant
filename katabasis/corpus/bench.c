#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t crc_table[256];

static void crc_init(void)
{
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t c = i;
        for (int k = 0; k < 8; k++)
            c = c & 1 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        crc_table[i] = c;
    }
}

static uint32_t crc32_buffer(const uint8_t *data, size_t length)
{
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < length; i++)
        c = crc_table[(c ^ data[i]) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFFu;
}

static uint64_t xorshift_state = 88172645463325252ull;

static uint64_t xorshift(void)
{
    xorshift_state ^= xorshift_state << 13;
    xorshift_state ^= xorshift_state >> 7;
    xorshift_state ^= xorshift_state << 17;
    return xorshift_state;
}

static int compare_long(const void *a, const void *b)
{
    long x = *(const long *)a, y = *(const long *)b;
    return x < y ? -1 : x > y;
}

struct node {
    struct node *next;
    long value;
};

static long list_sum(size_t count)
{
    struct node *head = NULL;
    for (size_t i = 0; i < count; i++) {
        struct node *n = malloc(sizeof *n);
        n->value = (long)(i * 7 % 1000);
        n->next = head;
        head = n;
    }
    long sum = 0;
    while (head) {
        struct node *next = head->next;
        sum += head->value;
        free(head);
        head = next;
    }
    return sum;
}

static double matrix(int n)
{
    double *a = malloc(sizeof(double) * n * n), *b = malloc(sizeof(double) * n * n), *c = calloc(n * n, sizeof(double));
    for (int i = 0; i < n * n; i++) {
        a[i] = (double)(i % 17) / 3.0;
        b[i] = (double)(i % 13) / 7.0;
    }
    for (int i = 0; i < n; i++)
        for (int k = 0; k < n; k++)
            for (int j = 0; j < n; j++)
                c[i * n + j] += a[i * n + k] * b[k * n + j];
    double trace = 0;
    for (int i = 0; i < n; i++)
        trace += c[i * n + i];
    free(a);
    free(b);
    free(c);
    return trace;
}

int main(int argc, char **argv)
{
    int scale = argc > 1 ? atoi(argv[1]) : 1;
    crc_init();
    size_t length = 1 << 16;
    uint8_t *buffer = malloc(length);
    for (size_t i = 0; i < length; i++)
        buffer[i] = (uint8_t)xorshift();
    uint32_t crc = 0;
    for (int r = 0; r < scale; r++)
        crc = crc32_buffer(buffer, length);
    size_t count = 20000 * scale;
    long *values = malloc(sizeof(long) * count);
    for (size_t i = 0; i < count; i++)
        values[i] = (long)(xorshift() % 1000000);
    qsort(values, count, sizeof(long), compare_long);
    long median = values[count / 2];
    long sum = list_sum(10000 * scale);
    double trace = matrix(40 + 10 * scale);
    char text[128];
    snprintf(text, sizeof text, "crc=%08x median=%ld sum=%ld trace=%.3f", crc, median, sum, trace);
    printf("%s len=%zu\n", text, strlen(text));
    free(values);
    free(buffer);
    return 0;
}
