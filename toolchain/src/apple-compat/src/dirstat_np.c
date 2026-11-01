#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

int revenant_at_within(int directory, int (*operation)(void *context), void *context);
int revenant_openat(int directory, const char *path, int flags, ...);
int revenant_fstatat(int directory, const char *path, struct stat *buffer, int flags);

struct darwin_dirstat {
    off_t total_size;
    uint64_t descendants;
};

#define REVENANT_DIRSTAT_FAST_ONLY 0x1
#define REVENANT_DIRSTAT_MAX_DEPTH 128

struct revenant_inode_slot {
    ino_t inode;
    int used;
};

struct revenant_inode_set {
    struct revenant_inode_slot *slots;
    size_t capacity;
    size_t count;
};

struct revenant_walk {
    struct revenant_inode_set inodes;
    dev_t device;
    off_t total_size;
    uint64_t descendants;
};

static int revenant_inode_insert(struct revenant_inode_set *set, ino_t inode)
{
    if ((set->count + 1) * 2 > set->capacity) {
        size_t capacity = set->capacity ? set->capacity * 2 : 64;
        struct revenant_inode_slot *slots = calloc(capacity, sizeof *slots);
        if (slots == NULL) {
            errno = ENOMEM;
            return -1;
        }
        for (size_t index = 0; index < set->capacity; index++) {
            if (set->slots[index].used) {
                size_t slot = set->slots[index].inode & (capacity - 1);
                while (slots[slot].used)
                    slot = (slot + 1) & (capacity - 1);
                slots[slot] = set->slots[index];
            }
        }
        free(set->slots);
        set->slots = slots;
        set->capacity = capacity;
    }
    size_t slot = inode & (set->capacity - 1);
    while (set->slots[slot].used) {
        if (set->slots[slot].inode == inode)
            return 0;
        slot = (slot + 1) & (set->capacity - 1);
    }
    set->slots[slot].inode = inode;
    set->slots[slot].used = 1;
    set->count++;
    return 1;
}

static int revenant_expected_error(int error)
{
    return error == ENOENT || error == ENOTDIR || error == ELOOP || error == EACCES || error == EPERM;
}

struct revenant_listing_request {
    DIR *listing;
};

static int revenant_listing_operation(void *context)
{
    struct revenant_listing_request *request = context;
    request->listing = opendir(".");
    return request->listing == NULL ? -1 : 0;
}

static DIR *revenant_listing(int descriptor)
{
    struct revenant_listing_request request = {NULL};
    revenant_at_within(descriptor, revenant_listing_operation, &request);
    int failure = errno;
    close(descriptor);
    errno = failure;
    return request.listing;
}

static int revenant_walk_folder(struct revenant_walk *walk, DIR *folder, int depth)
{
    int descriptor = dirfd(folder);
    struct dirent *entry;
    for (;;) {
        errno = 0;
        entry = readdir(folder);
        if (entry == NULL)
            return errno == 0 ? 0 : -1;
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        walk->descendants++;
        struct stat info;
        if (revenant_fstatat(descriptor, entry->d_name, &info, AT_SYMLINK_NOFOLLOW) == -1) {
            if (revenant_expected_error(errno))
                continue;
            return -1;
        }
        if (!S_ISDIR(info.st_mode)) {
            int fresh = info.st_nlink > 1 ? revenant_inode_insert(&walk->inodes, info.st_ino) : 1;
            if (fresh == -1)
                return -1;
            if (fresh)
                walk->total_size += (off_t)info.st_blocks * 512;
            continue;
        }
        if (info.st_dev != walk->device)
            continue;
        if (depth >= REVENANT_DIRSTAT_MAX_DEPTH) {
            errno = ELOOP;
            return -1;
        }
        int child = revenant_openat(descriptor, entry->d_name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
        if (child == -1) {
            if (revenant_expected_error(errno))
                continue;
            return -1;
        }
        struct stat opened;
        if (fstat(child, &opened) == -1) {
            int failure = errno;
            close(child);
            errno = failure;
            return -1;
        }
        if (opened.st_dev != info.st_dev || opened.st_ino != info.st_ino) {
            close(child);
            continue;
        }
        DIR *nested = revenant_listing(child);
        if (nested == NULL) {
            if (revenant_expected_error(errno))
                continue;
            return -1;
        }
        int status = revenant_walk_folder(walk, nested, depth + 1);
        closedir(nested);
        if (status == -1)
            return -1;
    }
}

static int revenant_walk_root(const char *path, struct darwin_dirstat *result)
{
    int root = open(path, O_RDONLY | O_DIRECTORY);
    if (root == -1)
        return -1;
    struct stat info;
    if (fstat(root, &info) == -1) {
        int failure = errno;
        close(root);
        errno = failure;
        return -1;
    }
    DIR *listing = revenant_listing(root);
    if (listing == NULL)
        return -1;
    struct revenant_walk walk = {{NULL, 0, 0}, info.st_dev, 0, 0};
    int status = revenant_walk_folder(&walk, listing, 0);
    int failure = errno;
    closedir(listing);
    free(walk.inodes.slots);
    if (status == -1) {
        errno = failure;
        return -1;
    }
    result->total_size = walk.total_size;
    result->descendants = walk.descendants;
    return 0;
}

__attribute__((visibility("hidden")))
int revenant_dirstat_np(const char *path, int flags, struct darwin_dirstat *ds, size_t dirstat_size)
{
    if (path == NULL || ds == NULL) {
        errno = EFAULT;
        return -1;
    }
    if (flags & REVENANT_DIRSTAT_FAST_ONLY) {
        errno = ENOTSUP;
        return -1;
    }
    struct darwin_dirstat result;
    if (revenant_walk_root(path, &result) == -1)
        return -1;
    memcpy(ds, &result, dirstat_size < sizeof result ? dirstat_size : sizeof result);
    return 0;
}

__attribute__((visibility("hidden")))
int dirstat_np(const char *path, int flags, struct darwin_dirstat *ds, size_t dirstat_size)
{
    return revenant_dirstat_np(path, flags, ds, dirstat_size);
}
