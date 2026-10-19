#include <dirent.h>
#include <fcntl.h>
#include <sys/param.h>
#include <unistd.h>

__attribute__((visibility("hidden")))
DIR *charon_fdopendir(int descriptor)
{
    char path[MAXPATHLEN];
    if (fcntl(descriptor, F_GETPATH, path) == -1) {
        return NULL;
    }
    DIR *directory = opendir(path);
    if (directory != NULL) {
        close(descriptor);
    }
    return directory;
}
