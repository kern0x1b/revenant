#include <errno.h>
#include <stdio.h>
#include <sys/stdio.h>

__attribute__((visibility("hidden")))
int renamex_np(const char *from, const char *to, unsigned int flags)
{
    const unsigned int known = RENAME_SECLUDE | RENAME_SWAP | RENAME_EXCL | RENAME_NOFOLLOW_ANY;
    if (flags == 0) {
        return rename(from, to);
    }
    if (flags & ~known) {
        errno = EINVAL;
        return -1;
    }
    errno = ENOTSUP;
    return -1;
}
