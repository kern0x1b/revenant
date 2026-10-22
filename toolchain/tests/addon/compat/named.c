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
    if (chdir(root) != 0) {
        printf("FAIL  the scratch folder must be the working directory\n");
        return 2;
    }
    const char *file = "file";
    const char *alias = "alias";
    const char *moved = "moved";
    const char *made = "made";
    char absolute_made[1024], absolute_file[1024];
    snprintf(absolute_made, sizeof absolute_made, "%s/made", root);
    snprintf(absolute_file, sizeof absolute_file, "%s/file", root);

    int dir = open(root, O_RDONLY);
    expect(dir >= 0, "the scratch folder must open for a directory descriptor");

    expect(mkdirat(AT_FDCWD, made, 0700) == 0, "mkdirat must create a folder against the working directory");
    struct stat info;
    expect(fstatat(AT_FDCWD, made, &info, 0) == 0 && S_ISDIR(info.st_mode), "fstatat must see the folder mkdirat made");
    expect(fstatat(AT_FDCWD, made, &info, AT_SYMLINK_NOFOLLOW) == 0, "fstatat must accept AT_SYMLINK_NOFOLLOW");
    expect(fstatat(AT_FDCWD, made, &info, 0x100) == -1 && errno == EINVAL, "fstatat must refuse flags it does not know");
    expect(mkdirat(dir, "other", 0700) == 0 && exists("other"), "mkdirat against a descriptor must make the folder inside it");
    expect(fstatat(dir, made, &info, 0) == 0 && S_ISDIR(info.st_mode), "fstatat against a descriptor must see the folder inside it");
    errno = 0;
    expect(fstatat(dir, "missing", &info, 0) == -1 && errno == ENOENT, "fstatat against a descriptor must report a missing name as ENOENT");
    expect(fstatat(dir, absolute_made, &info, 0) == 0, "an absolute path ignores the descriptor, so fstatat answers it");

    int written = openat(AT_FDCWD, file, O_CREAT | O_WRONLY, 0600);
    expect(written >= 0, "openat must create a file against the working directory");
    if (written >= 0) {
        expect(write(written, "shim", 4) == 4, "the file openat made must take a write");
        close(written);
    }
    expect(openat(AT_FDCWD, "missing", O_RDONLY) == -1 && errno == ENOENT, "openat must report a missing file as ENOENT");
    int by_descriptor = openat(dir, file, O_RDONLY);
    expect(by_descriptor >= 0, "openat against a descriptor must open the file inside it");
    if (by_descriptor >= 0) {
        close(by_descriptor);
    }
    int by_absolute = openat(dir, absolute_file, O_RDONLY);
    expect(by_absolute >= 0, "openat of an absolute path ignores the descriptor");
    if (by_absolute >= 0) {
        close(by_absolute);
    }

    expect(linkat(AT_FDCWD, file, AT_FDCWD, alias, 0) == 0 && exists(alias), "linkat must make a hard link");
    expect(linkat(AT_FDCWD, file, AT_FDCWD, alias, 0) == -1 && errno == EEXIST, "linkat must refuse to replace a name");
    expect(linkat(AT_FDCWD, file, AT_FDCWD, "link2", 0x1000) == -1 && errno == EINVAL, "linkat must refuse flags it does not know");
    expect(symlink(file, "sym") == 0, "the test must make a symbolic link");
    errno = 0;
    expect(linkat(AT_FDCWD, "sym", AT_FDCWD, "plain", 0) == -1 && errno == ENOTSUP,
           "linkat without AT_SYMLINK_FOLLOW must refuse a symbolic link, since link() on this release follows it");
    expect(linkat(AT_FDCWD, "sym", AT_FDCWD, "follow", AT_SYMLINK_FOLLOW) == 0, "linkat with AT_SYMLINK_FOLLOW must link the target");
    struct stat original, followed;
    expect(stat(file, &original) == 0 && stat("follow", &followed) == 0 && original.st_ino == followed.st_ino,
           "the link AT_SYMLINK_FOLLOW made must be a name for the file the symbolic link names");
    errno = 0;
    expect(mkdirat(AT_FDCWD, "sub", 0700) == 0, "the cross-folder checks need a folder to hold a descriptor");
    int sub = open("sub", O_RDONLY | O_DIRECTORY);
    expect(sub >= 0, "the folder the cross-folder checks use must open");
    int inner = openat(AT_FDCWD, "sub/inner", O_CREAT | O_WRONLY, 0600);
    if (inner >= 0) {
        close(inner);
    }
    expect(linkat(sub, "inner", AT_FDCWD, "outer", 0) == 0 && exists("outer") && exists("sub/inner"),
           "linkat from a descriptor's folder to the working directory must link the name across folders");
    expect(renameat(sub, "inner", AT_FDCWD, "moved-out") == 0 && exists("moved-out") && !exists("sub/inner"),
           "renameat from a descriptor's folder to the working directory must move the name out");
    expect(renameat(AT_FDCWD, "moved-out", sub, "back") == 0 && exists("sub/back") && !exists("moved-out"),
           "renameat from the working directory into a descriptor's folder must move the name in");
    expect(renameat(dir, "outer", sub, "outer-in-sub") == 0 && exists("sub/outer-in-sub") && !exists("outer"),
           "renameat between two descriptors' folders must move the name, with the second folder's path rebuilt");
    expect(unlinkat(sub, "back", 0) == 0 && unlinkat(sub, "outer-in-sub", 0) == 0 && !exists("sub/back") && !exists("sub/outer-in-sub"),
           "unlinkat against a descriptor must remove the names the cross-folder calls left in its folder");
    close(sub);
    expect(unlinkat(dir, "sub", AT_REMOVEDIR) == 0 && !exists("sub"), "the emptied cross-folder folder must remove");

    expect(renameat(AT_FDCWD, alias, AT_FDCWD, moved) == 0 && !exists(alias) && exists(moved),
           "renameat must move a name against the working directory");
    expect(renameat(dir, moved, AT_FDCWD, alias) == 0 && exists(alias) && !exists(moved),
           "renameat from a descriptor to the working directory must move the name");
    expect(renameat(AT_FDCWD, alias, dir, moved) == 0 && exists(moved) && !exists(alias),
           "renameat from the working directory into a descriptor must move the name back");
    expect(renameat(dir, moved, dir, "moved-again") == 0 && exists("moved-again") && !exists(moved) &&
           renameat(dir, "moved-again", dir, moved) == 0 && exists(moved),
           "renameat within one descriptor must rename the name inside it and back");

    char moved_path[1024], alias_path[1024];
    snprintf(moved_path, sizeof moved_path, "%s/moved", root);
    snprintf(alias_path, sizeof alias_path, "%s/alias", root);
    expect(renamex_np(moved_path, alias_path, 0) == 0 && exists(alias_path) && !exists(moved_path),
           "renamex_np with no flags must rename");

    errno = 0;
    expect(renamex_np(alias_path, absolute_file, RENAME_EXCL) == -1 && errno == ENOTSUP,
           "renamex_np RENAME_EXCL must report ENOTSUP, so the caller falls back");
    expect(exists(alias_path) && exists(absolute_file), "a refused renamex_np must leave both names as they were");
    errno = 0;
    expect(renamex_np(alias_path, absolute_file, 0x80000000u) == -1 && errno == EINVAL, "renamex_np must refuse flags it does not know");

    int source = open(file, O_RDONLY);
    expect(source >= 0, "the file to clone must open");
    errno = 0;
    expect(fclonefileat(source, AT_FDCWD, "clone", 0) == -1 && errno == ENOTSUP,
           "fclonefileat must report ENOTSUP so copies fall back to copyfile");
    close(source);

    DIR *listing = fdopendir(open(root, O_RDONLY));
    int listed = 0;
    for (struct dirent *entry = listing ? readdir(listing) : NULL; entry != NULL; entry = readdir(listing)) {
        listed |= strcmp(entry->d_name, alias) == 0;
    }
    expect(listing != NULL && listed, "fdopendir must list the folder the descriptor names");
    if (listing != NULL) {
        closedir(listing);
    }

    expect(unlinkat(AT_FDCWD, alias_path, 0) == 0 && !exists(alias_path), "unlinkat must remove a file against the working directory");
    expect(unlinkat(dir, "other", AT_REMOVEDIR) == 0 && !exists("other"), "unlinkat against a descriptor must remove the folder inside it");
    expect(unlinkat(AT_FDCWD, made, AT_REMOVEDIR) == 0 && !exists(made), "unlinkat with AT_REMOVEDIR must remove a folder");
    expect(unlinkat(AT_FDCWD, made, 0x100) == -1 && errno == EINVAL, "unlinkat must refuse flags it does not know");

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
