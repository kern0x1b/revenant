#ifndef REVENANT_AT_WITHIN_H
#define REVENANT_AT_WITHIN_H

#include <fcntl.h>

typedef int (*revenant_at_operation)(void *context);

int revenant_at_within(int directory, revenant_at_operation operation, void *context);
int revenant_at_pair(int first_directory, const char *first, int second_directory, const char *second, int *directory);

#endif
