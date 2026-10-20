#include <pthread.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

enum BLAS_THREADING : unsigned int {
    BLAS_THREADING_MULTI_THREADED = 0,
    BLAS_THREADING_SINGLE_THREADED = 1,
    BLAS_THREADING_MAX_OPTIONS = 2
};

int BLASSetThreading(const enum BLAS_THREADING threading);
enum BLAS_THREADING BLASGetThreading(void);

static pthread_key_t revenant_blas_threading;
static pthread_once_t revenant_blas_threading_once = PTHREAD_ONCE_INIT;
static int revenant_blas_threading_ready;

static void RevenantBLASThreadingMakeKey(void)
{
    revenant_blas_threading_ready = pthread_key_create(&revenant_blas_threading, NULL) == 0;
}

static enum BLAS_THREADING RevenantBLASThreading(void)
{
    void *stored;
    pthread_once(&revenant_blas_threading_once, RevenantBLASThreadingMakeKey);
    if (!revenant_blas_threading_ready) {
        return BLAS_THREADING_MULTI_THREADED;
    }
    stored = pthread_getspecific(revenant_blas_threading);
    return stored ? (enum BLAS_THREADING)(long)stored : BLAS_THREADING_MULTI_THREADED;
}

int BLASSetThreading(const enum BLAS_THREADING threading)
{
    if (threading < BLAS_THREADING_MULTI_THREADED || threading >= BLAS_THREADING_MAX_OPTIONS) {
        return -1;
    }
    pthread_once(&revenant_blas_threading_once, RevenantBLASThreadingMakeKey);
    if (!revenant_blas_threading_ready ||
        pthread_setspecific(revenant_blas_threading, (void *)(long)threading) != 0) {
        return -1;
    }
    return 0;
}

enum BLAS_THREADING BLASGetThreading(void)
{
    return RevenantBLASThreading();
}
