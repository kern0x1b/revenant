// The host's PDFKit constants: one row per name, value and the image it came from.
//
// The port's side is NOT linked in: the port's values are the string literals in its committed
// constants object, which the runner reads out of that file, so nothing here has to agree with the
// port's headers and the two sides cannot collide over them.
//
// One fork()ed child per name, because reading a symbol whose pointer is not an object kills the
// process that reads it in the parent - that cost two runs of the read before the fork went in.
//
//   xcrun clang -fobjc-arc -w read-host.m -framework Foundation -o read-host && ./read-host
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    @autoreleasepool {
        void *host = dlopen("/System/Library/Frameworks/PDFKit.framework/PDFKit", RTLD_LAZY);
        if (!host) {
            fprintf(stderr, "no host PDFKit\n");
            return 2;
        }
        if (argc < 2) {
            fprintf(stderr, "usage: read-host names.txt\n");
            return 2;
        }
        FILE *names = fopen(argv[1], "r");
        if (!names) {
            fprintf(stderr, "no names file\n");
            return 2;
        }
        char line[4096];
        while (fgets(line, sizeof(line), names)) {
            size_t length = strlen(line);
            while (length && (line[length - 1] == '\n' || line[length - 1] == '\r'))
                line[--length] = 0;
            if (!length)
                continue;
            int fd[2];
            if (pipe(fd) != 0)
                continue;
            fflush(stdout);
            pid_t pid = fork();
            if (pid == 0) {
                close(fd[0]);
                void *symbol = dlsym(host, line);
                if (!symbol) {
                    const char *m = "no-host-symbol";
                    write(fd[1], m, strlen(m));
                    _exit(0);
                }
                id __unsafe_unretained value = *(id __unsafe_unretained *)symbol;
                if (![value isKindOfClass:[NSString class]]) {
                    const char *m = "not-a-string";
                    write(fd[1], m, strlen(m));
                    _exit(0);
                }
                Dl_info info;
                const char *image = (dladdr(symbol, &info) && info.dli_fname) ? info.dli_fname : "?";
                NSString *text = [value description];
                const char *utf = [text UTF8String] ? [text UTF8String] : "";
                char out[8192];
                snprintf(out, sizeof(out), "%s\t%s", image, utf);
                write(fd[1], out, strlen(out));
                _exit(0);
            }
            close(fd[1]);
            char buf[8192];
            ssize_t got = read(fd[0], buf, sizeof(buf) - 1);
            close(fd[0]);
            int status = 0;
            waitpid(pid, &status, 0);
            if (got <= 0) {
                printf("%s\t%s\n", line, WIFSIGNALED(status) ? "crashed-in-child" : "child-failed");
                continue;
            }
            buf[got] = 0;
            printf("%s\t%s\n", line, buf);
        }
        fclose(names);
    }
    return 0;
}
