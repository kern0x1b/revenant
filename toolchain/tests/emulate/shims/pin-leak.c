#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

int __pthread_fchdir(int descriptor);

#define THREADS 600

static char folder[MAXPATHLEN];
static int failures;

static void *pin(void *argument)
{
    (void)argument;
    int directory = open(folder, O_RDONLY | O_DIRECTORY);
    if (directory < 0) {
        failures++;
        return NULL;
    }
    if (__pthread_fchdir(directory) != 0) {
        failures++;
    }
    close(directory);
    return NULL;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("FAIL  the pin leak test needs a scratch folder\n");
        return 2;
    }
    mkdir(argv[1], 0700);
    snprintf(folder, sizeof folder, "%s/pinned", argv[1]);
    mkdir(folder, 0700);
    for (int round = 0; round < THREADS; round++) {
        pthread_t thread;
        if (pthread_create(&thread, NULL, pin, NULL) != 0) {
            printf("FAIL  thread %d could not start\n", round);
            return 1;
        }
        pthread_join(thread, NULL);
    }
    int fails = 0;
    if (failures != 0) {
        printf("FAIL  %d of %d pinning threads could not pin the folder\n", failures, THREADS);
        fails++;
    }
    char probe[MAXPATHLEN];
    snprintf(probe, sizeof probe, "%s/probe", argv[1]);
    int created = open(probe, O_CREAT | O_WRONLY, 0600);
    if (created < 0) {
        printf("FAIL  a file could not be created after %d pinning threads exited: errno %d\n", THREADS, errno);
        fails++;
    } else {
        close(created);
    }
    int directory = open(folder, O_RDONLY | O_DIRECTORY);
    if (directory < 0 || __pthread_fchdir(directory) != 0 || __pthread_fchdir(-1) != 0) {
        printf("FAIL  the main thread could not pin and unpin the folder after the threads exited: errno %d\n", errno);
        fails++;
    }
    if (directory >= 0) {
        close(directory);
    }
    return fails != 0;
}
