#import <Foundation/Foundation.h>
#import <unistd.h>

static void said(const char* stream, int index) {
    if (strcmp(stream, "stdout") == 0) {
        fprintf(stdout, "charon-emulate-output: %s line %d reached the host\n", stream, index);
    } else {
        fprintf(stderr, "charon-emulate-output: %s line %d reached the host\n", stream, index);
    }
}

int main(int argc, char** argv) {
    said("stdout", 1);
    said("stderr", 1);
    if (argc > 1 && strcmp(argv[1], "--hang") == 0) {
        sleep(1);
        said("stdout", 2);
        for (;;) {
            sleep(1);
        }
    }
    return 0;
}
