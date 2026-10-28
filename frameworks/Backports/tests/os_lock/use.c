#include <os/lock.h>

static void flagged(os_unfair_lock_flags_t flags)
{
    (void)flags;
}

void os_lock_flags_probe(void)
{
    os_unfair_lock_flags_t flags = 0;
    flagged(flags);
}
