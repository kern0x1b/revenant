// The apple-compat calls against the host's own libc, on the same generated inputs (seed printed).
// The charon functions are declared here by hand, so the oracle calls below stay the host's.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int charon_fstatat(int directory, const char *path, struct stat *buffer, int flags);
int charon_unlinkat(int directory, const char *path, int flags);
DIR *charon_fdopendir(int descriptor);

static uint64_t state;
static uint64_t next(void)
{
    state += 0x9E3779B97F4A7C15ULL;
    uint64_t z = state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

static const char *names[] = {"a", "b.txt", "sub", "sub/c", "..", ".", "missing", "sub/../a", "", "/", "a/"};

int main(int argc, char **argv)
{
    const char *dir = argv[1];
    state = argc > 2 ? strtoull(argv[2], NULL, 10) : 20261014;
    printf("seed: %llu\n", (unsigned long long)state);
    if (chdir(dir) != 0) return 1;
    int base = open(".", O_RDONLY);
    int sub = open("sub", O_RDONLY);
    int file = open("a", O_RDONLY | O_CREAT, 0644);
    if (base < 0 || sub < 0 || file < 0) return 2;
    int fds[] = {AT_FDCWD, base, sub, file};
    for (int i = 0; i < 400; i++) {
        int fd = fds[next() % 4];
        const char *name = names[next() % 11];
        int flags = (next() % 2) ? AT_SYMLINK_NOFOLLOW : 0;
        struct stat mine, theirs;
        memset(&mine, 0, sizeof mine);
        memset(&theirs, 0, sizeof theirs);
        errno = 0;
        int a = charon_fstatat(fd, name, &mine, flags);
        int ea = errno;
        errno = 0;
        int b = fstatat(fd, name, &theirs, flags);
        int eb = errno;
        int same = a == b && ea == eb && (a != 0 || (mine.st_ino == theirs.st_ino && mine.st_mode == theirs.st_mode && mine.st_size == theirs.st_size));
        printf("fstatat[%d] fd=%d name=%s flags=%d ours=%d/%d theirs=%d/%d %s\n", i, fd, name, flags, a, ea, b, eb, same ? "same" : "DIFFERENT");
    }
    // fdopendir: the entries of the directory, read through a descriptor opened on it.
    for (int i = 0; i < 3; i++) {
        int d = open(i == 0 ? "sub" : ".", O_RDONLY);
        int copy = dup(d);
        DIR *mine = charon_fdopendir(copy);
        DIR *theirs = fdopendir(d);
        printf("fdopendir[%d] mine=%s theirs=%s\n", i, mine ? "open" : "NULL", theirs ? "open" : "NULL");
        if (mine) closedir(mine);
        if (theirs) closedir(theirs);
    }
    // unlinkat: create a file, remove it with each implementation, check it is gone.
    for (int i = 0; i < 20; i++) {
        char name[64];
        snprintf(name, sizeof name, "u-%d.txt", i);
        int c = open(name, O_CREAT | O_WRONLY, 0644);
        close(c);
        int r = charon_unlinkat(AT_FDCWD, name, 0);
        struct stat s;
        int gone = stat(name, &s) == -1 && errno == ENOENT;
        printf("unlinkat[%d] %s rc=%d gone=%d\n", i, name, r, gone);
    }
    printf("done\n");
    return 0;
}
