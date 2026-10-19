#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <sys/time.h>

enum {
    CHARON_UL_COMPARE_AND_WAIT = 1,
    CHARON_UL_COMPARE_AND_WAIT64 = 5,
    CHARON_ULOCK_OPERATION = 0xff,
    CHARON_ULOCK_BUCKETS = 64,
};

struct charon_ulock_bucket {
    pthread_mutex_t mutex;
    pthread_cond_t woken;
    unsigned waiters;
};

static struct charon_ulock_bucket charon_ulock_buckets[CHARON_ULOCK_BUCKETS] = {
    [0 ... CHARON_ULOCK_BUCKETS - 1] = { PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, 0 },
};

__attribute__((visibility("hidden")))
struct charon_ulock_bucket *charon_ulock_bucket(void *address)
{
    uintptr_t key = (uintptr_t)address;
    key ^= key >> 7;
    key ^= key >> 13;
    return &charon_ulock_buckets[key % CHARON_ULOCK_BUCKETS];
}

static int charon_ulock_holds(uint32_t operation, void *address, uint64_t value)
{
    if ((operation & CHARON_ULOCK_OPERATION) == CHARON_UL_COMPARE_AND_WAIT64) {
        uint64_t current;
        memcpy(&current, address, sizeof current);
        return current == value;
    }
    uint32_t current;
    memcpy(&current, address, sizeof current);
    return current == (uint32_t)value;
}

__attribute__((visibility("hidden")))
int __ulock_wait(uint32_t operation, void *address, uint64_t value, uint32_t timeout)
{
    uint32_t kind = operation & CHARON_ULOCK_OPERATION;
    if (!address || (kind != CHARON_UL_COMPARE_AND_WAIT && kind != CHARON_UL_COMPARE_AND_WAIT64)) {
        errno = EINVAL;
        return -1;
    }
    struct charon_ulock_bucket *bucket = charon_ulock_bucket(address);
    pthread_mutex_lock(&bucket->mutex);
    if (!charon_ulock_holds(operation, address, value)) {
        pthread_mutex_unlock(&bucket->mutex);
        return 0;
    }
    int result = 0;
    bucket->waiters++;
    if (timeout == 0) {
        pthread_cond_wait(&bucket->woken, &bucket->mutex);
    } else {
        struct timeval now;
        gettimeofday(&now, NULL);
        uint64_t microseconds = (uint64_t)now.tv_usec + timeout;
        struct timespec deadline = {
            .tv_sec = now.tv_sec + (time_t)(microseconds / 1000000),
            .tv_nsec = (long)(microseconds % 1000000) * 1000,
        };
        if (pthread_cond_timedwait(&bucket->woken, &bucket->mutex, &deadline) == ETIMEDOUT) {
            errno = ETIMEDOUT;
            result = -1;
        }
    }
    bucket->waiters--;
    pthread_mutex_unlock(&bucket->mutex);
    return result;
}
