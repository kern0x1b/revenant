#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

int __pthread_fchdir(int descriptor);

struct darwin_dirstat {
    off_t total_size;
    uint64_t descendants;
};

#define REVENANT_DIRSTAT_FAST_ONLY 0x1

struct revenant_inode_slot {
    ino_t inode;
    int used;
};

struct revenant_inode_set {
    struct revenant_inode_slot *slots;
    size_t capacity;
    size_t count;
};

struct revenant_stack {
    char **paths;
    size_t count;
    size_t capacity;
};

struct revenant_walk {
    struct revenant_inode_set inodes;
    struct revenant_stack pending;
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

static int revenant_stack_push(struct revenant_stack *stack, char *path)
{
    if (stack->count == stack->capacity) {
        size_t capacity = stack->capacity ? stack->capacity * 2 : 64;
        char **paths = realloc(stack->paths, capacity * sizeof *paths);
        if (paths == NULL) {
            errno = ENOMEM;
            return -1;
        }
        stack->paths = paths;
        stack->capacity = capacity;
    }
    stack->paths[stack->count++] = path;
    return 0;
}

static char *revenant_stack_pop(struct revenant_stack *stack)
{
    return stack->count ? stack->paths[--stack->count] : NULL;
}

static char *revenant_join(const char *folder, const char *name)
{
    size_t folder_length = strlen(folder);
    size_t separator = folder_length ? 1 : 0;
    size_t name_length = strlen(name);
    char *joined = malloc(folder_length + separator + name_length + 1);
    if (joined == NULL) {
        errno = ENOMEM;
        return NULL;
    }
    memcpy(joined, folder, folder_length);
    if (separator)
        joined[folder_length] = '/';
    memcpy(joined + folder_length + separator, name, name_length + 1);
    return joined;
}

static int revenant_walk_folder(struct revenant_walk *walk, const char *folder, int top)
{
    DIR *directory = opendir(folder[0] ? folder : ".");
    if (directory == NULL)
        return top ? -1 : 0;
    int status = 0;
    struct dirent *entry;
    while ((entry = readdir(directory)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        walk->descendants++;
        char *child = revenant_join(folder, entry->d_name);
        if (child == NULL) {
            status = -1;
            break;
        }
        struct stat info;
        if (lstat(child, &info) == -1) {
            free(child);
            continue;
        }
        if (S_ISDIR(info.st_mode)) {
            if (info.st_dev == walk->device) {
                if (revenant_stack_push(&walk->pending, child) == -1) {
                    free(child);
                    status = -1;
                    break;
                }
            } else {
                free(child);
            }
            continue;
        }
        int fresh = info.st_nlink > 1 ? revenant_inode_insert(&walk->inodes, info.st_ino) : 1;
        free(child);
        if (fresh == -1) {
            status = -1;
            break;
        }
        if (fresh)
            walk->total_size += (off_t)info.st_blocks * 512;
    }
    closedir(directory);
    return status;
}

static int revenant_walk_tree(struct revenant_walk *walk)
{
    if (revenant_walk_folder(walk, "", 1) == -1)
        return -1;
    char *folder;
    while ((folder = revenant_stack_pop(&walk->pending)) != NULL) {
        int status = revenant_walk_folder(walk, folder, 0);
        free(folder);
        if (status == -1)
            return -1;
    }
    return 0;
}

static int revenant_walk_pinned(const char *path, struct darwin_dirstat *result)
{
    int folder = open(path, O_RDONLY | O_DIRECTORY);
    if (folder == -1)
        return -1;
    struct stat info;
    if (fstat(folder, &info) == -1 || __pthread_fchdir(folder) == -1) {
        int failure = errno;
        close(folder);
        errno = failure;
        return -1;
    }
    struct revenant_walk walk = {{NULL, 0, 0}, {NULL, 0, 0}, info.st_dev, 0, 0};
    int status = revenant_walk_tree(&walk);
    int failure = errno;
    if (__pthread_fchdir(-1) == -1)
        abort();
    close(folder);
    for (size_t index = 0; index < walk.pending.count; index++)
        free(walk.pending.paths[index]);
    free(walk.pending.paths);
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
    if (revenant_walk_pinned(path, &result) == -1)
        return -1;
    memcpy(ds, &result, dirstat_size < sizeof result ? dirstat_size : sizeof result);
    return 0;
}

__attribute__((visibility("hidden")))
int dirstat_np(const char *path, int flags, struct darwin_dirstat *ds, size_t dirstat_size)
{
    return revenant_dirstat_np(path, flags, ds, dirstat_size);
}
