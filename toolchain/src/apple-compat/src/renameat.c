#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/param.h>

int revenant_resolve_at(int directory, const char *path, char *resolved);

__attribute__((visibility("hidden")))
int renameat(int from_directory, const char *from, int to_directory, const char *to)
{
    char source[MAXPATHLEN];
    char target[MAXPATHLEN];
    if (revenant_resolve_at(from_directory, from, source) == -1 ||
        revenant_resolve_at(to_directory, to, target) == -1) {
        return -1;
    }
    return rename(source, target);
}
