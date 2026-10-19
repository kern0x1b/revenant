
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

double sin(double);
double cos(double);
float sinf(float);
float cosf(float);
struct pair { double sine; double cosine; };
struct pairf { float sine; float cosine; };
struct pair __sincos_stret(double);
struct pairf __sincosf_stret(float);
size_t __strlcpy_chk(char *, const char *, size_t, size_t);
size_t __strlcat_chk(char *, const char *, size_t, size_t);

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

static int aborts(size_t (*call)(char *, const char *, size_t, size_t))
{
    pid_t child = fork();
    if (child == 0) {
        char small[4] = "";
        call(small, "overflowing", 8, sizeof small);
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT;
}

int main(void)
{
    for (double x = -7.0; x < 7.0; x += 0.37) {
        struct pair both = __sincos_stret(x);
        expect(both.sine == sin(x) && both.cosine == cos(x), "__sincos_stret answers sin and cos of its argument");
        struct pairf bothf = __sincosf_stret((float)x);
        expect(bothf.sine == sinf((float)x) && bothf.cosine == cosf((float)x),
               "__sincosf_stret answers sinf and cosf of its argument");
    }
    char buffer[8] = "";
    expect(__strlcpy_chk(buffer, "abcdefghij", sizeof buffer, sizeof buffer) == 10 && strcmp(buffer, "abcdefg") == 0,
           "__strlcpy_chk truncates as strlcpy does and returns the source length");
    expect(__strlcat_chk(buffer, "xyz", sizeof buffer, sizeof buffer) == 10 && strcmp(buffer, "abcdefg") == 0,
           "__strlcat_chk truncates as strlcat does and returns the length it tried to create");
    expect(aborts(__strlcpy_chk), "__strlcpy_chk aborts when told the destination is larger than it is");
    expect(aborts(__strlcat_chk), "__strlcat_chk aborts when told the destination is larger than it is");
    return fails != 0;
}
