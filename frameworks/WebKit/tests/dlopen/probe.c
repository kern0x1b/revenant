#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv) {
    int failed = 0;
    for (int i = 1; i < argc; i++) {
        void *handle = dlopen(argv[i], RTLD_NOW);
        if (handle) {
            printf("loaded %s\n", argv[i]);
        } else {
            printf("dlopen %s failed: %s\n", argv[i], dlerror());
            failed++;
        }
        fflush(stdout);
    }
    return failed ? 1 : 0;
}
