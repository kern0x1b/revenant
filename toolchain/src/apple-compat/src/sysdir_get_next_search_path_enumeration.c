#include "sysdir_user.h"

__attribute__((visibility("hidden")))
unsigned int sysdir_get_next_search_path_enumeration(unsigned int state, char *path)
{
    return sysdir_user_next(state, path);
}
