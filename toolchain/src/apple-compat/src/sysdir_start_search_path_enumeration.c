#include "sysdir_user.h"

__attribute__((visibility("hidden")))
unsigned int sysdir_start_search_path_enumeration(unsigned int directory, unsigned int domains)
{
    return sysdir_user_start(directory, domains);
}
