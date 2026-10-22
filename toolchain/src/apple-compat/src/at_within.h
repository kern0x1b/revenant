#ifndef REVENANT_AT_WITHIN_H
#define REVENANT_AT_WITHIN_H

#include <fcntl.h>
#include <sys/param.h>

typedef int (*revenant_at_operation)(void *context);

struct revenant_at_pair {
    int directory;
    const char *first;
    const char *second;
    char first_path[MAXPATHLEN];
    char second_path[MAXPATHLEN];
};

int __pthread_fchdir(int descriptor);
int revenant_at_within(int directory, revenant_at_operation operation, void *context);
int revenant_at_pair(int first_directory, const char *first, int second_directory, const char *second, struct revenant_at_pair *pair);

#endif
