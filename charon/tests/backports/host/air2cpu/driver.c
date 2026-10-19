/* driver.c — a translated kernel run the way the port's compute encoder will run it.
 *
 * A workgroup is run as real threads, one per thread of the group, because that is the only way a
 * barrier means anything: thread 0 must not pass a barrier before threads 1..n-1 have written their
 * slots, and a group run one thread after another does exactly that. iOS 6 has no pthread_barrier, so
 * the rendezvous is a mutex and a condition variable - the count of threads that have arrived, and a
 * generation that is bumped and broadcast when the last one arrives.
 *
 * The numbers this prints are compared with what Apple's own Metal produces for the same kernel on
 * the same input, by compare.py. A kernel air2cpu refused is absent from the table, which is the
 * honest answer: this program says so and says nothing about it.
 */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "../../../../packages/a/apple-backports/air2cpu-abi.h"
#include <string.h>

/* The rendezvous of one workgroup: how many of its threads have arrived at the current barrier, and
   which generation of the barrier they are all waiting for. */
typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t arrived;
    uint32_t threads;
    uint32_t count;
    uint32_t generation;
} Workgroup;

static void rendezvous(void *context, uint32_t tid, uint32_t threads)
{
    Workgroup *group = context;
    (void)tid;
    pthread_mutex_lock(&group->mutex);
    uint32_t generation = group->generation;
    if (++group->count == threads) {
        group->count = 0;
        group->generation++;
        pthread_cond_broadcast(&group->arrived);
    } else {
        while (generation == group->generation)
            pthread_cond_wait(&group->arrived, &group->mutex);
    }
    pthread_mutex_unlock(&group->mutex);
}

typedef struct {
    const air2cpu_kernel *kernel;
    void *buffers[8];
    Workgroup *group;
    uint32_t threads;
    char *block;
    uint32_t blockBytes;
} Work;

typedef struct {
    uint32_t tid;
    charon_v4i thread, group, size;
    Work *work;
} ThreadArgument;

static void *runOneThread(void *argument)
{
    ThreadArgument *slot = argument;
    slot->work->kernel->function(slot->work->buffers, slot->thread, slot->group, slot->size,
                                 slot->work->block, slot->work->blockBytes, rendezvous, slot->work->group);
    return NULL;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    /* 16 threads of 4 elements each is what the three one-dimensional kernels touch, so the buffer is
       that wide and every write lands inside it. The two-dimensional and three-dimensional kernels
       index differently, so each is dispatched the grid its own formula assumes - and the oracle
       dispatches the same shape for the same kernel, or the two numbers are not about the same work. */
    const uint32_t count = 64;   // as oracle.m
    /* the threadgroup block, 64 bytes of headroom, which is what these kernels ask of it */
    char *block = calloc(1, 256);
    const uint32_t blockBytes = 256;
    float *values = malloc(count * sizeof(float));

    printf("kernels=%u\n", air2cpu_kernel_count);
    for (unsigned index = 0; index < air2cpu_kernel_count; index++) {
        /* threads (x, y, z) and the number of groups, per kernel, by its name */
        uint32_t tx = 16, ty = 1, tz = 1, gx = 1, gy = 1, gz = 1;
        const char *name = air2cpu_kernels[index].name;
        if (name && strcmp(name, "grid2Kernel") == 0) { tx = 8; ty = 2; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "grid3Kernel") == 0) { tx = 2; ty = 2; tz = 2; gx = 1; gy = 1; gz = 1; }
        // atomicFamilyKernel is a group of EIGHT with two slots per thread, which is 16 of
        // Metal's 30 threadgroup slots, and it writes 32 cells - so the dispatch and the buffer
        // follow the kernel rather than a default that happens to fit the others.
        else if (name && strcmp(name, "atomicFamilyKernel") == 0) { tx = 8; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "atomicFamilyKernelProbe") == 0) { tx = 8; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "blockProbe") == 0) { tx = 8; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "shareProbe") == 0) { tx = 8; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "readbackProbe") == 0) { tx = 8; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && (strcmp(name, "argNoBar") == 0 || strcmp(name, "argBarrier") == 0 || strcmp(name, "localArray") == 0)) { tx = 1; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "positionKernel") == 0) { tx = 16; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        else if (name && strcmp(name, "positionKernel") == 0) { tx = 16; ty = 1; tz = 1; gx = 1; gy = 1; gz = 1; }
        uint32_t each = tx * ty * tz;
        /* a fresh buffer per kernel, seeded the way the oracle seeds it, so a kernel's answer is not
           the previous kernel's leftovers */
        // the same seed as oracle.m: 1, 1, 2, 2, ... so > and >= differ for half the threads
        // 1.0f, 2.0f, ... as bits, which is what the oracle and the harness seed, so all three
        // sides start from the same numbers and a sum of them is exact
        for (uint32_t element = 0; element < count; element++)
            values[element] = (float)(element + 1);
        memset(block, 0, blockBytes);

        uint32_t groups = gx * gy * gz;
        for (uint32_t g = 0; g < groups; g++) {
            uint32_t cx = g % gx, cy = (g / gx) % gy, cz = g / (gx * gy);
            Workgroup rendezvous;
            pthread_mutex_init(&rendezvous.mutex, NULL);
            pthread_cond_init(&rendezvous.arrived, NULL);
            rendezvous.threads = each;
            rendezvous.count = 0;
            rendezvous.generation = 0;

            void *buffers[8];
            for (uint32_t slot = 0; slot < 8; slot++)
                buffers[slot] = values;
            Work work;
            work.kernel = &air2cpu_kernels[index];
            for (uint32_t slot = 0; slot < 8; slot++)
                work.buffers[slot] = buffers[slot];
            work.group = &rendezvous;
            work.threads = each;
            work.block = block;
            work.blockBytes = blockBytes;

            pthread_t pool[64];
            ThreadArgument slots[64];
            uint32_t spawned = each < 64 ? each : 64;
            for (uint32_t t = 0; t < spawned; t++) {
                slots[t].tid = t;
                slots[t].thread.x = (int32_t)(t % tx);
                slots[t].thread.y = (int32_t)((t / tx) % ty);
                slots[t].thread.z = (int32_t)(t / (tx * ty));
                slots[t].group.x = (int32_t)cx;
                slots[t].group.y = (int32_t)cy;
                slots[t].group.z = (int32_t)cz;
                slots[t].size.x = (int32_t)tx;
                slots[t].size.y = (int32_t)ty;
                slots[t].size.z = (int32_t)tz;
                slots[t].work = &work;
                if (pthread_create(&pool[t], NULL, runOneThread, &slots[t]) != 0) {
                    fprintf(stderr, "driver: cannot start thread %u of %u\n", t, spawned);
                    return 1;
                }
            }
            for (uint32_t t = 0; t < spawned; t++)
                pthread_join(pool[t], NULL);
            pthread_mutex_destroy(&rendezvous.mutex);
            pthread_cond_destroy(&rendezvous.arrived);
        }

        printf("OUT %s", air2cpu_kernels[index].name);
        for (uint32_t element = 0; element < count; element++)
            printf(" %.6g", values[element]);
        printf("\n");
    }
    free(block);
    free(values);
    return 0;
}
