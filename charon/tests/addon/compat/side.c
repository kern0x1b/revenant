
#include <stdint.h>
typedef struct { uint32_t value; } lock_t;
void os_unfair_lock_lock(lock_t *);
void os_unfair_lock_unlock(lock_t *);
__attribute__((visibility("default"))) void SIDE_lock(lock_t *lock) { os_unfair_lock_lock(lock); }
__attribute__((visibility("default"))) void SIDE_unlock(lock_t *lock) { os_unfair_lock_unlock(lock); }
