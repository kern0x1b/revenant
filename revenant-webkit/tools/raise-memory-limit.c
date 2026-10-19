#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <signal.h>

extern int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t size);

static int raiseFor(int32_t pid, uint32_t megabytes)
{
    if (geteuid() == 0 && getuid() != 0)
        setuid(0);

    errno = 0;
    if (memorystatus_control(5 /* set high-water mark */, pid, megabytes, NULL, 0)) {
        fprintf(stderr, "refused for pid %d: errno %d (uid %d euid %d)\n", pid, errno, getuid(), geteuid());
        return 1;
    }
    printf("pid %d may now use %u MB\n", pid, megabytes);
    fflush(stdout);
    return 0;
}

static int watch(const char *pidPath, uint32_t megabytes)
{
    int32_t lastPid = 0;
    for (;;) {
        FILE *file = fopen(pidPath, "r");
        if (file) {
            int32_t pid = 0;
            if (fscanf(file, "%d", &pid) == 1 && pid > 0 && pid != lastPid) {
                if (kill(pid, 0) == 0 && !raiseFor(pid, megabytes))
                    lastPid = pid;
            }
            fclose(file);
        }
        if (lastPid && kill(lastPid, 0) != 0)
            lastPid = 0;
        usleep(1000 * 1000);
    }
    return 0;
}

int main(int argc, char *argv[])
{
    if (argc >= 3 && !strcmp(argv[1], "--watch"))
        return watch(argv[2], (uint32_t)atoi(argc > 3 ? argv[3] : "400"));

    if (argc < 3) {
        fprintf(stderr, "usage: raise-memory-limit <pid> <megabytes>\n");
        fprintf(stderr, "       raise-memory-limit --watch <pidfile> [megabytes]\n");
        return 2;
    }

    return raiseFor(atoi(argv[1]), (uint32_t)atoi(argv[2]));
}
