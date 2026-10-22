#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int revenant_openat(int directory, const char *path, int flags, ...);
int revenant_fstatat(int directory, const char *path, struct stat *buffer, int flags);
int revenant_unlinkat(int directory, const char *path, int flags);

#define ROUNDS 20000

static char target[1024], decoy[1024], parked[1024];
static volatile int running = 1;

static void join(char *out, const char *root, const char *name)
{
    snprintf(out, 1024, "%s/%s", root, name);
}

static int make_file(const char *path, const char *text)
{
    int fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0600);
    if (fd < 0) {
        return -1;
    }
    write(fd, text, strlen(text));
    close(fd);
    return 0;
}

static void *swap(void *argument)
{
    (void)argument;
    while (running) {
        rename(target, parked);
        rename(decoy, target);
        rename(parked, decoy);
    }
    return NULL;
}

static int exists(const char *path)
{
    struct stat info;
    return stat(path, &info) == 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("FAIL  the race test needs a scratch folder\n");
        return 2;
    }
    const char *root = argv[1];
    join(target, root, "target");
    join(decoy, root, "decoy");
    join(parked, root, "parked");
    char marker[1100], decoy_marker[1100], leftover_target[1100], leftover_decoy[1100];
    snprintf(marker, sizeof marker, "%s/marker", target);
    snprintf(decoy_marker, sizeof decoy_marker, "%s/marker", decoy);
    snprintf(leftover_target, sizeof leftover_target, "%s/scratch", target);
    snprintf(leftover_decoy, sizeof leftover_decoy, "%s/scratch", decoy);
    if (mkdir(target, 0700) != 0 || mkdir(decoy, 0700) != 0 || make_file(marker, "original") != 0 ||
        make_file(decoy_marker, "decoy") != 0) {
        printf("FAIL  the race test could not make its folders\n");
        return 2;
    }
    struct stat original;
    if (stat(marker, &original) != 0) {
        printf("FAIL  the race test could not read its marker\n");
        return 2;
    }
    int directory = open(target, O_RDONLY);
    if (directory < 0) {
        printf("FAIL  the race test could not open its folder\n");
        return 2;
    }
    pthread_t thread;
    if (pthread_create(&thread, NULL, swap, NULL) != 0) {
        printf("FAIL  the race test could not start the renamer\n");
        return 2;
    }
    int wrong_file = 0, wrong_stat = 0, failed_calls = 0;
    for (int round = 0; round < ROUNDS; round++) {
        int fd = revenant_openat(directory, "marker", O_RDONLY);
        if (fd < 0) {
            failed_calls++;
        } else {
            struct stat seen;
            if (fstat(fd, &seen) != 0 || seen.st_ino != original.st_ino) {
                wrong_file++;
            }
            close(fd);
        }
        struct stat seen;
        if (revenant_fstatat(directory, "marker", &seen, 0) != 0) {
            failed_calls++;
        } else if (seen.st_ino != original.st_ino) {
            wrong_stat++;
        }
        int made = revenant_openat(directory, "scratch", O_CREAT | O_WRONLY, 0600);
        if (made < 0) {
            failed_calls++;
        } else {
            close(made);
        }
        if (revenant_unlinkat(directory, "scratch", 0) != 0) {
            failed_calls++;
        }
    }
    running = 0;
    pthread_join(thread, NULL);
    close(directory);
    int fails = 0;
    if (wrong_file != 0) {
        printf("FAIL  openat through a folder renamed between the calls opened another folder's file %d times\n", wrong_file);
        fails++;
    }
    if (wrong_stat != 0) {
        printf("FAIL  fstatat through a folder renamed between the calls read another folder's file %d times\n", wrong_stat);
        fails++;
    }
    if (failed_calls != 0) {
        printf("FAIL  a call against the renamed folder failed %d times\n", failed_calls);
        fails++;
    }
    if (exists(leftover_target) || exists(leftover_decoy)) {
        printf("FAIL  a file created in the folder was left in the other folder\n");
        fails++;
    }
    if (!exists(decoy_marker) && !exists(marker)) {
        printf("FAIL  both folders' markers were lost\n");
        fails++;
    }
    return fails != 0;
}
