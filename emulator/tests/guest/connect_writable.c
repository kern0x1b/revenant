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
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(listener, (struct sockaddr *)&address, sizeof address) != 0 || listen(listener, 128) != 0) {
        printf("connect_writable round %d listen failed errno %d\n", round, errno);
        return CONNECTIONS;
    }
    socklen_t length = sizeof address;
    getsockname(listener, (struct sockaddr *)&address, &length);

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
            printf("connect_writable round %d connect %d failed errno %d\n", round, index, errno);
        }
        struct kevent change;
        EV_SET(&change, descriptors[index], EVFILT_WRITE, EV_ADD | EV_ONESHOT, 0, 0, (void *)(intptr_t)index);
        kevent(kq, &change, 1, NULL, 0, NULL);
    }

    int writable[CONNECTIONS];
    memset(writable, 0, sizeof writable);
    int reached = 0;
    double started = now();
    while (reached < connecting && now() - started < WAIT_SECONDS) {
        struct kevent events[CONNECTIONS];
        struct timespec wait = { 0, 200000000 };
        int count = kevent(kq, NULL, 0, events, CONNECTIONS, &wait);
        for (int index = 0; index < count; index++) {
            int slot = (int)(intptr_t)events[index].udata;
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
            printf("connect_writable round %d connection %d not writable after %d s, so_error %d\n", round, index, WAIT_SECONDS, error);
        }
        close(descriptors[index]);
    }
    printf("connect_writable round %d %d of %d writable\n", round, reached, CONNECTIONS);
    close(kq);
    close(listener);
    return failures;
}

int main(void)
{
    int failures = 0;
    for (int round = 0; round < ROUNDS; round++)
        failures += round_failures(round);
    printf("connect_writable %d rounds, %d connections not writable\n", ROUNDS, failures);
    return failures == 0 ? 0 : 1;
}
