#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

struct darwin_dirstat {
    off_t total_size;
    uint64_t descendants;
};

int dirstat_np(const char *path, int flags, struct darwin_dirstat *ds, size_t dirstat_size);

static char root[1024];

static void inside(char *buffer, size_t capacity, const char *name)
{
    snprintf(buffer, capacity, "%s/%s", root, name);
}

static void regular(const char *name, size_t size)
{
    char path[2048];
    inside(path, sizeof path, name);
    int descriptor = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (descriptor == -1) {
        printf("FAIL  create %s\n", name);
        return;
    }
    char block[4096];
    memset(block, 'x', sizeof block);
    while (size) {
        size_t chunk = size < sizeof block ? size : sizeof block;
        if (write(descriptor, block, chunk) != (ssize_t)chunk) {
            printf("FAIL  write %s\n", name);
            break;
        }
        size -= chunk;
    }
    close(descriptor);
}

static void folder(const char *name)
{
    char path[2048];
    inside(path, sizeof path, name);
    if (mkdir(path, 0755) == -1)
        printf("FAIL  mkdir %s\n", name);
}

static void hard_link(const char *target, const char *name)
{
    char from[2048], to[2048];
    inside(from, sizeof from, target);
    inside(to, sizeof to, name);
    if (link(from, to) == -1)
        printf("FAIL  link %s\n", name);
}

static void symbolic_link(const char *target, const char *name)
{
    char path[2048];
    inside(path, sizeof path, name);
    if (symlink(target, path) == -1)
        printf("FAIL  symlink %s\n", name);
}

static void build(void)
{
    folder("d1");
    folder("d2");
    folder("d3");
    folder("d3/e");
    folder("sub");
    folder("big");
    folder("locked");
    folder("locked/inner");
    regular("a", 1);
    regular("b", 5000);
    regular("d2/c", 0);
    hard_link("b", "d2/b2");
    symbolic_link("a", "s");
    symbolic_link("nowhere", "dangle");
    symbolic_link("sub", "tosub");
    regular("d3/e/f", 100);
    regular("sub/one", 3000);
    for (int index = 0; index < 400; index++) {
        char name[64];
        snprintf(name, sizeof name, "big/file_with_a_long_name_%03d", index);
        regular(name, 0);
    }
    hard_link("sub/one", "big/one_link");
    regular("locked/inner/x", 200);
    char path[2048];
    inside(path, sizeof path, "locked");
    chmod(path, 0);
}

static void restore(void)
{
    char path[2048];
    inside(path, sizeof path, "locked");
    chmod(path, 0755);
}

static void query(const char *label, const char *path, int flags, size_t size)
{
    struct darwin_dirstat ds;
    memset(&ds, 0x5a, sizeof ds);
    errno = 0;
    int result = dirstat_np(path, flags, &ds, size);
    if (result == -1)
        printf("%-30s -1 errno=%d\n", label, errno);
    else
        printf("%-30s 0 total=%lld descendants=%llu\n", label, (long long)ds.total_size, (unsigned long long)ds.descendants);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("FAIL  usage: dirstat_np_test <empty folder>\n");
        return 2;
    }
    setvbuf(stdout, NULL, _IONBF, 0);
    snprintf(root, sizeof root, "%s", argv[1]);
    build();
    char path[2048];
    query("root flags 0", root, 0, 16);
    query("root flags 2", root, 2, 16);
    query("root unknown bit 4", root, 4, 16);
    query("root fast only 1", root, 1, 16);
    query("root fast and fallback 3", root, 3, 16);
    query("root flags -1", root, -1, 16);
    query("root size 0", root, 2, 0);
    query("root size 8", root, 2, 8);
    query("root size 24", root, 2, 24);
    query("root size 64", root, 2, 64);
    snprintf(path, sizeof path, "%s/", root);
    query("root with trailing slash", path, 2, 16);
    inside(path, sizeof path, "nope");
    query("missing", path, 2, 16);
    query("empty path", "", 2, 16);
    inside(path, sizeof path, "a");
    query("regular file", path, 2, 16);
    inside(path, sizeof path, "s");
    query("symlink to a file", path, 2, 16);
    inside(path, sizeof path, "dangle");
    query("dangling symlink", path, 2, 16);
    inside(path, sizeof path, "tosub");
    query("symlink to a folder", path, 2, 16);
    inside(path, sizeof path, "d1");
    query("empty folder", path, 2, 16);
    inside(path, sizeof path, "d2");
    query("folder with hard link", path, 2, 16);
    query("folder with hard link flags 0", path, 0, 16);
    inside(path, sizeof path, "d3");
    query("nested folders", path, 2, 16);
    inside(path, sizeof path, "big");
    query("many files and a hard link", path, 2, 16);
    inside(path, sizeof path, "locked");
    query("unreadable folder", path, 2, 16);
    inside(path, sizeof path, "a");
    query("fast only on a file", path, 1, 16);
    restore();
    return 0;
}
