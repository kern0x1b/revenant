#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc > 2 && strcmp(argv[2], "resolve") == 0) {
        void *found = dlsym(RTLD_DEFAULT, argv[1]);
        printf("resolved\t%s\t%d\n", argv[1], found ? 0 : 1);
        return found ? 0 : 1;
    }
    const char *mode = argc > 1 ? argv[1] : "clean";
    if (strcmp(mode, "crash") == 0) {
        printf("about to die\n");
        fflush(stdout);
        raise(SIGSEGV);
    }
    if (strcmp(mode, "missing") == 0) {
        printf("value\t1\n");
        return 0;
    }
    printf("value\t1\t1\n");
    return 0;
}
