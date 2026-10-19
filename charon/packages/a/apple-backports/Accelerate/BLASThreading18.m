// BLASSetThreading and BLASGetThreading, the threading model of iOS 18.
//
// The setting is per thread, as the header says: it is kept in thread-local storage, so a thread that
// has set one and a thread that has not answer differently, and the default a thread starts with is
// BLAS_THREADING_MULTI_THREADED, which is what the host answers for a thread that has set nothing
// (measured). A value the library does not have is refused with -1 and leaves the setting as it was
// (measured on the host: BLASSetThreading(99) answers -1 and BLASGetThreading still answers
// BLAS_THREADING_MULTI_THREADED afterwards).
//
// The header this API comes with is not in the SDK the port builds against: thread_api.h arrived with
// iOS 18 and the build SDK is 16.4, so the enumeration and the two prototypes are declared here, as
// the header declares them. The header has to be added to the port's headers for a program to name them
// (facts/Accelerate/BLASThreading.md).
//
// What the model does is worth reading before anything is built on it: the two functions are a value kept
// per thread, and nothing in the library reads it. The header (thread_api.h:24-26) names the call as one
// that sets the threading model for later BLAS and LAPACK calls, and this port does not do that - it cannot, and
// neither does the host's own Accelerate, measured the same way: four threads inside cblas_sgemm leave
// the process with as many threads under the single-threaded model as under the multi-threaded one, so
// the setting does not bring the count down (facts/Accelerate/BLASThreading.md has the numbers). On the
// release there is nothing to set either: BLASSetThreading and BLASGetThreading are in the 18.0 cache and
// in none of 7.1.2, 8.0 and 16.0. So the setting is stored and read back, the two answers the
// header gives are the two answers this gives, and the difference between that and the header's wording
// is a documented one rather than a silent one.

#include <pthread.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// <vecLib/thread_api.h> of iOS 18, which the build SDK does not carry: the enumeration with its
// values, and the two entry points. BLAS_THREADING_MULTI_THREADED is 0 and the two that follow count
// on from it, so BLAS_THREADING_SINGLE_THREADED is 1 and BLAS_THREADING_MAX_OPTIONS is 2.
enum BLAS_THREADING : unsigned int {
    BLAS_THREADING_MULTI_THREADED = 0,
    BLAS_THREADING_SINGLE_THREADED = 1,
    BLAS_THREADING_MAX_OPTIONS = 2
};

int BLASSetThreading(const enum BLAS_THREADING threading);
enum BLAS_THREADING BLASGetThreading(void);

static pthread_key_t charon_blas_threading;
static pthread_once_t charon_blas_threading_once = PTHREAD_ONCE_INIT;
static int charon_blas_threading_ready;

static void CharonBLASThreadingMakeKey(void)
{
    charon_blas_threading_ready = pthread_key_create(&charon_blas_threading, NULL) == 0;
}

// The thread's own setting, or BLAS_THREADING_MULTI_THREADED when it has set none: the value a thread
// starts with is the one Accelerate decides for itself.
static enum BLAS_THREADING CharonBLASThreading(void)
{
    void *stored;
    pthread_once(&charon_blas_threading_once, CharonBLASThreadingMakeKey);
    if (!charon_blas_threading_ready) {
        return BLAS_THREADING_MULTI_THREADED;
    }
    stored = pthread_getspecific(charon_blas_threading);
    return stored ? (enum BLAS_THREADING)(long)stored : BLAS_THREADING_MULTI_THREADED;
}

int BLASSetThreading(const enum BLAS_THREADING threading)
{
    if (threading < BLAS_THREADING_MULTI_THREADED || threading >= BLAS_THREADING_MAX_OPTIONS) {
        return -1;
    }
    pthread_once(&charon_blas_threading_once, CharonBLASThreadingMakeKey);
    if (!charon_blas_threading_ready ||
        pthread_setspecific(charon_blas_threading, (void *)(long)threading) != 0) {
        return -1;
    }
    return 0;
}

enum BLAS_THREADING BLASGetThreading(void)
{
    return CharonBLASThreading();
}
