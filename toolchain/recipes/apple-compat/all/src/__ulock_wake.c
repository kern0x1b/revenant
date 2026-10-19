#include <errno.h>
#include <pthread.h>
#include <stdint.h>

struct charon_ulock_bucket {
    pthread_mutex_t mutex;
    pthread_cond_t woken;
    unsigned waiters;
};

struct charon_ulock_bucket *charon_ulock_bucket(void *address);

__attribute__((visibility("hidden")))
int __ulock_wake(uint32_t operation, void *address, uint64_t value)
{
    (void)operation;
    (void)value;
    if (!address) {
        errno = EINVAL;
        return -1;
    }
    struct charon_ulock_bucket *bucket = charon_ulock_bucket(address);
    pthread_mutex_lock(&bucket->mutex);
    unsigned waiting = bucket->waiters;
    if (waiting)
        pthread_cond_broadcast(&bucket->woken);
    pthread_mutex_unlock(&bucket->mutex);
    if (!waiting) {
        errno = ENOENT;
        return -1;
    }
    return 0;
}
