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
