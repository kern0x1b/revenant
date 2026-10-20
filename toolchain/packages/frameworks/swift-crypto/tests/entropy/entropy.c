#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <CommonCrypto/CommonRandom.h>
#include <Security/SecRandom.h>

#define DRAW_BYTES 16

extern int CCRandomCopyBytes(int generator, void *bytes, size_t count);
#define CC_RANDOM_DEFAULT 0

static void show(int draw, const char *source, int status, const unsigned char *bytes, size_t count)
{
    printf("E| %d %s %d ", draw, source, status);
    for (size_t i = 0; i < count; i++)
        printf("%02x", bytes[i]);
    printf("\n");
    fflush(stdout);
}

static int read_device(const char *path, unsigned char *out, size_t count)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return -1;
    size_t got = 0;
    while (got < count) {
        ssize_t r = read(fd, out + got, count - got);
        if (r <= 0)
            break;
        got += (size_t)r;
    }
    close(fd);
    return (int)got;
}

int main(int argc, char **argv)
{
    int draws = argc > 1 ? atoi(argv[1]) : 1;
    unsigned char buf[DRAW_BYTES];

    for (int draw = 0; draw < draws; draw++) {
        memset(buf, 0, sizeof buf);
        int status = SecRandomCopyBytes(kSecRandomDefault, sizeof buf, buf);
        show(draw, "sec", status, buf, sizeof buf);

        memset(buf, 0, sizeof buf);
        status = (int)CCRandomGenerateBytes(buf, sizeof buf);
        show(draw, "cc", status, buf, sizeof buf);

        memset(buf, 0, sizeof buf);
        status = (int)CCRandomCopyBytes(CC_RANDOM_DEFAULT, buf, sizeof buf);
        show(draw, "cc-copy", status, buf, sizeof buf);

        memset(buf, 0, sizeof buf);
        status = read_device("/dev/random", buf, sizeof buf);
        show(draw, "dev-random", status, buf, sizeof buf);

        memset(buf, 0, sizeof buf);
        status = read_device("/dev/urandom", buf, sizeof buf);
        show(draw, "dev-urandom", status, buf, sizeof buf);
    }
    return 0;
}
