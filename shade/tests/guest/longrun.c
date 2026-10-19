// longrun.c: stays for the given number of seconds, printing when it starts and ends, so a
// runner started with it shows what the rest of the boot does while a test is still running.
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char **argv)
{
    int seconds = argc > 1 ? atoi(argv[1]) : 60;
    printf("longrun: start pid=%d for %d s\n", getpid(), seconds);
    fflush(stdout);
    sleep(seconds);
    printf("longrun: end\n");
    return 0;
}
