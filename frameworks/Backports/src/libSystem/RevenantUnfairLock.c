#include "../revenant_impl.h"
#include "unfair_lock.h"

__attribute__((visibility("default"))) void BACKPORT_IMPL(os_unfair_lock_lock)(revenant_unfair_lock *lock)
{
    revenant_unfair_lock_lock(lock, revenant_unfair_self());
}

__attribute__((visibility("default"))) void BACKPORT_IMPL(os_unfair_lock_unlock)(revenant_unfair_lock *lock)
{
    revenant_unfair_unlock(lock, revenant_unfair_self());
}
