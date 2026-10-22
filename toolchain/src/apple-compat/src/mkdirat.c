#include <errno.h>
#include <fcntl.h>
#include <sys/param.h>
#include <sys/stat.h>

int revenant_resolve_at(int directory, const char *path, char *resolved);

__attribute__((visibility("hidden")))
int mkdirat(int directory, const char *path, mode_t mode)
{
    char resolved[MAXPATHLEN];
    if (revenant_resolve_at(directory, path, resolved) == -1) {
        return -1;
    }
    return mkdir(resolved, mode);
}
