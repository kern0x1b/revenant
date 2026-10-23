#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

int __pthread_fchdir(int descriptor);

static void report(const char *what, const char *value)
{
    if (value) {
        printf("%s: %s\n", what, value);
    } else {
        printf("%s: NULL errno=%d\n", what, errno);
    }
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("FAIL  the pinned path probe needs a scratch folder\n");
        return 2;
    }
    const char *root = argv[1];
    char path[MAXPATHLEN], folder[MAXPATHLEN], resolved[MAXPATHLEN], buffer[MAXPATHLEN], link_path[MAXPATHLEN];
    snprintf(folder, sizeof folder, "%s/pinned", root);
    mkdir(root, 0700);
    mkdir(folder, 0700);
    snprintf(path, sizeof path, "%s/file", root);
    int file = open(path, O_CREAT | O_WRONLY, 0600);
    if (file >= 0) {
        write(file, "root", 4);
        close(file);
    }
    snprintf(path, sizeof path, "%s/file", folder);
    file = open(path, O_CREAT | O_WRONLY, 0600);
    if (file >= 0) {
        write(file, "pinned", 6);
        close(file);
    }
    if (chdir(root) != 0) {
        printf("FAIL  the probe could not enter its root\n");
        return 2;
    }
    report("process getcwd", getcwd(buffer, sizeof buffer));
    report("process realpath file", realpath("file", resolved));

    int directory = open(folder, O_RDONLY | O_DIRECTORY);
    printf("open pinned folder: fd=%d errno=%d\n", directory, errno);
    int pinned = __pthread_fchdir(directory);
    printf("__pthread_fchdir(folder): %d errno=%d\n", pinned, errno);
    report("pinned getcwd", getcwd(buffer, sizeof buffer));
    report("pinned realpath file", realpath("file", resolved));
    int opened = open("file", O_RDONLY);
    printf("pinned open file: fd=%d errno=%d\n", opened, errno);
    if (opened >= 0) {
        char seen[MAXPATHLEN];
        report("pinned F_GETPATH of the open file", fcntl(opened, F_GETPATH, seen) == 0 ? seen : NULL);
        close(opened);
    }
    snprintf(link_path, sizeof link_path, "%s/file-link", folder);
    unlink(link_path);
    if (symlink("file", link_path) == 0) {
        report("pinned realpath of a relative symbolic link", realpath("file-link", resolved));
        unlink(link_path);
    } else {
        printf("symlink in pinned folder: errno=%d\n", errno);
    }
    int unpinned = __pthread_fchdir(-1);
    printf("__pthread_fchdir(-1): %d errno=%d\n", unpinned, errno);
    report("unpinned getcwd", getcwd(buffer, sizeof buffer));
    report("unpinned realpath file", realpath("file", resolved));
    if (directory >= 0) {
        close(directory);
    }
    return 0;
}
