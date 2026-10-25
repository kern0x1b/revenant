#include <unistd.h>

#define REVENANT_INTERPOSED_PPID 4242

static pid_t revenant_replacement_getppid(void) {
    return REVENANT_INTERPOSED_PPID;
}

typedef struct {
    const void *replacement;
    const void *replacee;
} revenant_interpose_tuple;

__attribute__((used, section("__DATA,__interpose")))
static const revenant_interpose_tuple revenant_interpose_table[] = {
    { (const void *)revenant_replacement_getppid, (const void *)getppid },
};
