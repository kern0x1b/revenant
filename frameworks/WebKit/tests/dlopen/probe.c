#include <dlfcn.h>
#include <stdio.h>

/* Loads each image named on the command line with RTLD_NOW, so every undefined symbol must resolve now. A failure prints
 * dlerror() as dyld wrote it, and the exit status counts the failures. */
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
