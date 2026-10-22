#include <CommonCrypto/CommonRandom.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/clonefile.h>
#include <sys/stat.h>
#include <sys/stdio.h>
#include <sys/time.h>
#include <sysdir.h>
#include <time.h>
#include <unistd.h>

static int failed;

static void expect(int ok, const char *what)
{
    if (!ok) {
        printf("FAIL  %s\n", what);
        failed = 1;
    }
}

static int exists(const char *path)
{
    struct stat info;
    return stat(path, &info) == 0;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("FAIL  the named shims test needs a scratch folder\n");
        return 2;
    }
    const char *root = argv[1];
    char file[1024], link[1024], moved[1024], made[1024];
    snprintf(file, sizeof file, "%s/file", root);
    snprintf(link, sizeof link, "%s/link", root);
    snprintf(moved, sizeof moved, "%s/moved", root);
    snprintf(made, sizeof made, "%s/made", root);

    int dir = open(root, O_RDONLY);
    expect(dir >= 0, "the scratch folder must open for a directory descriptor");

    expect(mkdirat(dir, "made", 0700) == 0, "mkdirat must create the folder under its descriptor");
    struct stat info;
    expect(fstatat(dir, "made", &info, 0) == 0 && S_ISDIR(info.st_mode), "fstatat must see the folder mkdirat made");
    expect(fstatat(dir, "made", &info, AT_SYMLINK_NOFOLLOW) == 0, "fstatat must accept AT_SYMLINK_NOFOLLOW");
    expect(fstatat(dir, "made", &info, 0x100) == -1 && errno == EINVAL, "fstatat must refuse flags it does not know");

    int written = openat(dir, "file", O_CREAT | O_WRONLY, 0600);
    expect(written >= 0, "openat must create a file under the descriptor");
    if (written >= 0) {
        expect(write(written, "shim", 4) == 4, "the file openat made must take a write");
        close(written);
    }
    expect(openat(dir, "missing", O_RDONLY) == -1 && errno == ENOENT, "openat must report a missing file as ENOENT");

    expect(linkat(dir, "file", dir, "link", 0) == 0, "linkat must make a hard link under the descriptors");
    expect(exists(link), "the link linkat made must exist");
    expect(linkat(dir, "file", dir, "link", 0) == -1 && errno == EEXIST, "linkat must refuse to replace a name");
    expect(linkat(dir, "file", dir, "link2", 0x1000) == -1 && errno == EINVAL, "linkat must refuse flags it does not know");
    expect(linkat(dir, "file", dir, "link2", AT_SYMLINK_FOLLOW) == 0, "linkat must accept AT_SYMLINK_FOLLOW");
    expect(unlinkat(dir, "link2", 0) == 0, "unlinkat must remove the link made with AT_SYMLINK_FOLLOW");

    expect(renameat(dir, "link", dir, "moved") == 0, "renameat must move a name between descriptors");
    expect(!exists(link) && exists(moved), "renameat must leave the new name only");

    expect(renamex_np(moved, link, 0) == 0, "renamex_np with no flags must rename");
    expect(exists(link) && !exists(moved), "renamex_np with no flags must leave the new name only");

    errno = 0;
    expect(renamex_np(link, file, RENAME_EXCL) == -1 && errno == ENOTSUP, "renamex_np RENAME_EXCL must report ENOTSUP, so the caller falls back");
    expect(exists(link) && exists(file), "a refused renamex_np must leave both names as they were");
    errno = 0;
    expect(renamex_np(link, file, 0x80000000u) == -1 && errno == EINVAL, "renamex_np must refuse flags it does not know");

    int source = open(file, O_RDONLY);
    expect(source >= 0, "the file to clone must open");
    errno = 0;
    expect(fclonefileat(source, dir, "clone", 0) == -1 && errno == ENOTSUP,
           "fclonefileat must report ENOTSUP so copies fall back to copyfile");
    close(source);

    DIR *listing = fdopendir(open(root, O_RDONLY));
    expect(listing != NULL, "fdopendir must open the folder a descriptor names");
    if (listing != NULL) {
        int seen = 0;
        struct dirent *entry;
        while ((entry = readdir(listing)) != NULL) {
            if (strcmp(entry->d_name, "made") == 0 || strcmp(entry->d_name, "file") == 0 || strcmp(entry->d_name, "link") == 0) {
                seen++;
            }
        }
        expect(seen == 3, "readdir must list the names the folder holds");
        closedir(listing);
    }

    expect(unlinkat(dir, "link", 0) == 0 && !exists(link), "unlinkat must remove a file under the descriptor");
    expect(unlinkat(dir, "made", AT_REMOVEDIR) == 0 && !exists(made), "unlinkat with AT_REMOVEDIR must remove a folder");
    expect(unlinkat(dir, "made", 0x100) == -1 && errno == EINVAL, "unlinkat must refuse flags it does not know");

    struct timespec now;
    expect(clock_gettime(CLOCK_REALTIME, &now) == 0 && now.tv_sec > 1500000000, "clock_gettime must read the calendar clock");
    expect(clock_gettime(CLOCK_MONOTONIC, &now) == 0, "clock_gettime must read a monotonic clock");
    expect(clock_gettime(999, &now) == -1 && errno == EINVAL, "clock_gettime must refuse a clock it does not know");

    unsigned char bytes[64];
    memset(bytes, 0, sizeof bytes);
    expect(CCRandomGenerateBytes(bytes, sizeof bytes) == kCCSuccess, "CCRandomGenerateBytes must succeed");
    int nonzero = 0;
    for (size_t at = 0; at < sizeof bytes; at++) {
        nonzero |= bytes[at] != 0;
    }
    expect(nonzero, "CCRandomGenerateBytes must fill the buffer");
    expect(CCRandomGenerateBytes(NULL, 0) == kCCSuccess, "CCRandomGenerateBytes of nothing must succeed");
    expect(CCRandomGenerateBytes(NULL, 8) == kCCParamError, "CCRandomGenerateBytes must refuse a NULL buffer");

    char path[1024];
    unsigned int state = sysdir_start_search_path_enumeration(SYSDIR_DIRECTORY_DOCUMENT, SYSDIR_DOMAIN_MASK_USER);
    expect(state != 0, "sysdir must enumerate the user's documents folder");
    if (state != 0) {
        expect(sysdir_get_next_search_path_enumeration(state, path) == 0 && strcmp(path, "~/Documents") == 0,
               "sysdir must answer the user's documents folder as ~/Documents, once");
    }
    expect(sysdir_start_search_path_enumeration(SYSDIR_DIRECTORY_APPLICATION, SYSDIR_DOMAIN_MASK_USER) == 0,
           "sysdir must answer nothing for a directory the user domain does not have");
    expect(sysdir_start_search_path_enumeration(SYSDIR_DIRECTORY_DOCUMENT, SYSDIR_DOMAIN_MASK_LOCAL) == 0,
           "sysdir must answer nothing for a domain it does not carry");

    close(dir);
    return failed;
}
