#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <sys/time.h>

enum {
    REVENANT_UL_COMPARE_AND_WAIT = 1,
    REVENANT_UL_COMPARE_AND_WAIT64 = 5,
    REVENANT_ULOCK_OPERATION = 0xff,
    REVENANT_ULOCK_BUCKETS = 64,
};

struct revenant_ulock_bucket {
    pthread_mutex_t mutex;
    pthread_cond_t woken;
    unsigned waiters;
};

static struct revenant_ulock_bucket revenant_ulock_buckets[REVENANT_ULOCK_BUCKETS] = {
    [0 ... REVENANT_ULOCK_BUCKETS - 1] = { PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, 0 },
};

__attribute__((visibility("hidden")))
struct revenant_ulock_bucket *revenant_ulock_bucket(void *address)
{
    uintptr_t key = (uintptr_t)address;
    key ^= key >> 7;
    key ^= key >> 13;
    return &revenant_ulock_buckets[key % REVENANT_ULOCK_BUCKETS];
}

static int revenant_ulock_holds(uint32_t operation, void *address, uint64_t value)
{
    if ((operation & REVENANT_ULOCK_OPERATION) == REVENANT_UL_COMPARE_AND_WAIT64) {
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
    uint32_t kind = operation & REVENANT_ULOCK_OPERATION;
    if (!address || (kind != REVENANT_UL_COMPARE_AND_WAIT && kind != REVENANT_UL_COMPARE_AND_WAIT64)) {
        errno = EINVAL;
        return -1;
    }
    struct revenant_ulock_bucket *bucket = revenant_ulock_bucket(address);
    pthread_mutex_lock(&bucket->mutex);
    if (!revenant_ulock_holds(operation, address, value)) {
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
