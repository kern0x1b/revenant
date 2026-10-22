#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int openat(int directory, const char *path, int flags, ...);
int fstatat(int directory, const char *path, struct stat *buffer, int flags);
int unlinkat(int directory, const char *path, int flags);
DIR *fdopendir(int descriptor);

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static int remove_contents(int directory)
{
    int duplicate = dup(directory);
    DIR *listing = duplicate >= 0 ? fdopendir(duplicate) : NULL;
    if (listing == NULL) {
        return -1;
    }
    struct dirent *entry;
    while ((entry = readdir(listing)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        struct stat info;
        if (fstatat(directory, entry->d_name, &info, AT_SYMLINK_NOFOLLOW) != 0) {
            closedir(listing);
            return -1;
        }
        if (S_ISDIR(info.st_mode)) {
            int child = openat(directory, entry->d_name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
            if (child < 0 || remove_contents(child) != 0) {
                if (child >= 0) {
                    close(child);
                }
                closedir(listing);
                return -1;
            }
            close(child);
            if (unlinkat(directory, entry->d_name, AT_REMOVEDIR) != 0) {
                closedir(listing);
                return -1;
            }
        } else if (unlinkat(directory, entry->d_name, 0) != 0) {
            closedir(listing);
            return -1;
        }
    }
    closedir(listing);
    return 0;
}

static int count(const char *path)
{
    DIR *listing = opendir(path);
    if (listing == NULL) {
        return -1;
    }
    int found = 0;
    struct dirent *entry;
    while ((entry = readdir(listing)) != NULL) {
        found += strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0;
    }
    closedir(listing);
    return found;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("FAIL  the tree test needs a scratch folder\n");
        return 2;
    }
    char tree[1024], sibling[1024], inner[1024], deep[1024], file[1024];
    snprintf(tree, sizeof tree, "%s/tree", argv[1]);
    snprintf(sibling, sizeof sibling, "%s/sibling", argv[1]);
    snprintf(inner, sizeof inner, "%s/inner", tree);
    snprintf(deep, sizeof deep, "%s/deep", inner);
    expect(mkdir(tree, 0700) == 0 && mkdir(inner, 0700) == 0 && mkdir(deep, 0700) == 0, "the tree test must make its folders");
    expect(mkdir(sibling, 0700) == 0, "the tree test must make a sibling folder");
    int made = 0;
    snprintf(file, sizeof file, "%s/a", tree);
    made |= open(file, O_CREAT | O_WRONLY, 0600) >= 0;
    snprintf(file, sizeof file, "%s/b", inner);
    made |= open(file, O_CREAT | O_WRONLY, 0600) >= 0;
    snprintf(file, sizeof file, "%s/c", deep);
    made |= open(file, O_CREAT | O_WRONLY, 0600) >= 0;
    snprintf(file, sizeof file, "%s/keep", sibling);
    made |= open(file, O_CREAT | O_WRONLY, 0600) >= 0;
    expect(made != 0, "the tree test must make its files");

    int directory = open(tree, O_RDONLY | O_DIRECTORY);
    expect(directory >= 0, "the tree test must open its folder");
    expect(remove_contents(directory) == 0, "emptying a tree through descriptors must succeed");
    close(directory);
    expect(count(tree) == 0, "every entry under the tree must be gone");
    expect(count(sibling) == 1, "the sibling folder must keep its file");
    expect(unlinkat(AT_FDCWD, tree, AT_REMOVEDIR) == 0, "the emptied tree must remove");
    return fails != 0;
}
