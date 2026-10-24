#include <arpa/inet.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define CONNECTIONS 32
#define ROUNDS 20
#define WAIT_SECONDS 10

static dispatch_semaphore_t writable_signal;
static int writable_flags[CONNECTIONS];

static void on_writable(void *context)
{
    int index = (int)(intptr_t)context;
    if (!writable_flags[index]) {
        writable_flags[index] = 1;
        dispatch_semaphore_signal(writable_signal);
    }
}

static void on_readable(void *context)
{
    (void)context;
}

static int round_failures(int round, dispatch_queue_t queue)
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
    dispatch_source_t writes[CONNECTIONS];
    dispatch_source_t reads[CONNECTIONS];
    int connecting = 0;
    writable_signal = dispatch_semaphore_create(0);
    memset(writable_flags, 0, sizeof writable_flags);
    for (int index = 0; index < CONNECTIONS; index++) {
        descriptors[index] = socket(AF_INET, SOCK_STREAM, 0);
        fcntl(descriptors[index], F_SETFL, fcntl(descriptors[index], F_GETFL, 0) | O_NONBLOCK);
        int status = connect(descriptors[index], (struct sockaddr *)&address, sizeof address);
        if (status == 0 || errno == EINPROGRESS) {
            connecting++;
        } else {
            printf("connect_writable round %d connect %d failed errno %d\n", round, index, errno);
        }
        reads[index] = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, descriptors[index], 0, queue);
        dispatch_source_set_event_handler_f(reads[index], on_readable);
        dispatch_set_context(reads[index], (void *)(intptr_t)index);
        writes[index] = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, descriptors[index], 0, queue);
        dispatch_source_set_event_handler_f(writes[index], on_writable);
        dispatch_set_context(writes[index], (void *)(intptr_t)index);
        dispatch_resume(writes[index]);
    }

    int reached = 0;
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, WAIT_SECONDS * 1000000000LL);
    while (reached < connecting) {
        if (dispatch_semaphore_wait(writable_signal, deadline) != 0)
            break;
        reached++;
    }

    int failures = 0;
    for (int index = 0; index < CONNECTIONS; index++) {
        int error = 0;
        socklen_t size = sizeof error;
        getsockopt(descriptors[index], SOL_SOCKET, SO_ERROR, &error, &size);
        if (!writable_flags[index]) {
            failures++;
            printf("connect_writable round %d connection %d not writable after %d s, so_error %d\n", round, index, WAIT_SECONDS, error);
        }
        dispatch_source_cancel(writes[index]);
        dispatch_resume(writes[index]);
        dispatch_source_cancel(reads[index]);
        dispatch_resume(reads[index]);
        close(descriptors[index]);
    }
    printf("connect_writable round %d %d of %d writable\n", round, reached, CONNECTIONS);
    close(listener);
    return failures;
}

int main(void)
{
    dispatch_queue_t queue = dispatch_queue_create("revenant.connect", NULL);
    int failures = 0;
    for (int round = 0; round < ROUNDS; round++)
        failures += round_failures(round, queue);
    printf("connect_writable %d rounds, %d connections not writable\n", ROUNDS, failures);
    return failures == 0 ? 0 : 1;
}
