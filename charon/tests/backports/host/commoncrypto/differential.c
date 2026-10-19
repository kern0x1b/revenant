#include <CommonCrypto/CommonRandom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern CCRNGStatus charon_host_CCRandomGenerateBytes(void *bytes, size_t count);

static CCRNGStatus always_ok(void *bytes, size_t count)
{
    (void)bytes;
    (void)count;
    return kCCSuccess;
}

typedef CCRNGStatus (*generator)(void *, size_t);

static const size_t counts[] = {0, 1, 15, 16, 17, 32, 4096, 1u << 20, 4u << 20};
static const size_t canary = 64;
static int cases = 0;
static int failures = 0;

static CCRNGStatus call(generator fn, unsigned char *buffer, int null_pointer, size_t count, int *tail_intact,
                        int *written)
{
    size_t i;
    if (!null_pointer) {
        memset(buffer, 0x5a, count + canary);
        memset(buffer + count, 0xa5, canary);
    }
    CCRNGStatus status = fn(null_pointer ? NULL : buffer, count);
    *tail_intact = 1;
    *written = 0;
    if (!null_pointer) {
        for (i = 0; i < canary; i++)
            if (buffer[count + i] != 0xa5)
                *tail_intact = 0;
        for (i = 0; i < count; i++)
            if (buffer[i] != 0x5a) {
                *written = 1;
                break;
            }
    }
    return status;
}

static int check(const char *label, generator port, generator host, size_t count, int null_pointer)
{
    unsigned char *a = malloc(count + canary + 1), *b = malloc(count + canary + 1);
    int tail_a, tail_b, written_a, written_b;
    CCRNGStatus ours = call(port, a, null_pointer, count, &tail_a, &written_a);
    CCRNGStatus theirs = call(host, b, null_pointer, count, &tail_b, &written_b);
    int bounds_ok = tail_a && (null_pointer || count < 16 || written_a);
    int agree = ours == theirs && tail_a == tail_b && written_a == written_b && bounds_ok;
    cases++;
    printf("%s count=%zu null=%d ours=%d host=%d tail=%d written=%d host-tail=%d host-written=%d %s\n", label, count,
           null_pointer, ours, theirs, tail_a, written_a, tail_b, written_b, agree ? "ok" : "DIFFERS");
    free(a);
    free(b);
    return agree;
}

int main(void)
{
    size_t i;
    setvbuf(stdout, NULL, _IONBF, 0);
    for (i = 0; i < sizeof(counts) / sizeof(counts[0]); i++) {
        failures += !check("port", charon_host_CCRandomGenerateBytes, CCRandomGenerateBytes, counts[i], 0);
        failures += !check("port", charon_host_CCRandomGenerateBytes, CCRandomGenerateBytes, counts[i], 1);
    }
    if (check("control", always_ok, CCRandomGenerateBytes, 1, 1)) {
        printf("CONTROL NOT NOTICED: the comparison cannot fail on the NULL class\n");
        failures++;
    } else {
        printf("control noticed\n");
    }
    printf("checks=%d failures=%d\n", cases, failures);
    return failures ? 1 : 0;
}
