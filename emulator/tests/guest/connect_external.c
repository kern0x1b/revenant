#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/event.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define CONNECTIONS 32
#define ROUNDS 20
#define WAIT_SECONDS 10

static double now(void)
{
    struct timeval value;
    gettimeofday(&value, NULL);
    return value.tv_sec + value.tv_usec / 1e6;
}

static int round_failures(int round)
{
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_port = htons(443);
    address.sin_addr.s_addr = inet_addr("104.16.124.96");

    int descriptors[CONNECTIONS];
    int kq = kqueue();
    int connecting = 0;
    for (int index = 0; index < CONNECTIONS; index++) {
        descriptors[index] = socket(AF_INET, SOCK_STREAM, 0);
        fcntl(descriptors[index], F_SETFL, fcntl(descriptors[index], F_GETFL, 0) | O_NONBLOCK);
        int status = connect(descriptors[index], (struct sockaddr *)&address, sizeof address);
        if (status == 0 || errno == EINPROGRESS) {
            connecting++;
        } else {
            printf("connect_external round %d connect %d failed errno %d\n", round, index, errno);
        }
        struct kevent64_s change[2];
        EV_SET64(&change[0], descriptors[index], EVFILT_READ, EV_ADD | EV_DISPATCH | EV_DISABLE, 0, 0, index, 0, 0);
        EV_SET64(&change[1], descriptors[index], EVFILT_WRITE, EV_ADD | EV_DISPATCH | EV_DISABLE, 0, 0, index, 0, 0);
        kevent64(kq, change, 2, NULL, 0, 0, NULL);
    }

    usleep(50000);
    for (int index = 0; index < CONNECTIONS; index++) {
        struct kevent64_s enable;
        EV_SET64(&enable, descriptors[index], EVFILT_WRITE, EV_ENABLE, 0, 0, index, 0, 0);
        kevent64(kq, &enable, 1, NULL, 0, 0, NULL);
    }

    int writable[CONNECTIONS];
    memset(writable, 0, sizeof writable);
    int reached = 0;
    double started = now();
    while (reached < connecting && now() - started < WAIT_SECONDS) {
        struct kevent64_s events[2 * CONNECTIONS];
        struct timespec wait = { 0, 200000000 };
        int count = kevent64(kq, NULL, 0, events, 2 * CONNECTIONS, 0, &wait);
        for (int index = 0; index < count; index++) {
            if (events[index].filter != EVFILT_WRITE)
                continue;
            int slot = (int)events[index].udata;
            if (!writable[slot]) {
                writable[slot] = 1;
                reached++;
            }
        }
    }

    int failures = 0;
    for (int index = 0; index < CONNECTIONS; index++) {
        int error = 0;
        socklen_t size = sizeof error;
        getsockopt(descriptors[index], SOL_SOCKET, SO_ERROR, &error, &size);
        if (!writable[index]) {
            failures++;
            printf("connect_external round %d connection %d not writable after %d s, so_error %d\n", round, index, WAIT_SECONDS, error);
        }
        close(descriptors[index]);
    }
    printf("connect_external round %d %d of %d writable\n", round, reached, CONNECTIONS);
    close(kq);
    return failures;
}

int main(void)
{
    int failures = 0;
    for (int round = 0; round < ROUNDS; round++)
        failures += round_failures(round);
    printf("connect_external %d rounds, %d connections not writable\n", ROUNDS, failures);
    return failures == 0 ? 0 : 1;
}
