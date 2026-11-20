#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

#include "workers.h"

enum { ROUNDS = 200000, PARTS = 50, CELLS = 4, MOST = 4 };

struct job {
    int worker;
    uint64_t a, b, c, result;
};

static unsigned failures;
static volatile unsigned turn, waiting, inside;
static volatile unsigned char shared[PARTS];
static unsigned met;
static unsigned long long elapsed;

static unsigned long long microseconds(void)
{
    struct timeval now;
    gettimeofday(&now, NULL);
    return (unsigned long long)now.tv_sec * 1000000 + (unsigned long long)now.tv_usec;
}

static void until(volatile unsigned *counter, unsigned wanted)
{
    while (*counter < wanted) {
    }
}

static uint64_t part(const struct job *job)
{
    uint64_t rounds = ROUNDS / PARTS;
    switch (job->worker) {
    case PAIR_SWAP:
        return run(job->worker, job->a, job->b, job->c, rounds);
    case PAIR_STORE:
        return run(job->worker, job->a, job->b, rounds, 0);
    default:
        return run(job->worker, job->a, rounds, 0, 0);
    }
}

static void *job_run(void *argument)
{
    struct job *job = argument;
    for (unsigned at = 0; at < PARTS; at++) {
        __sync_fetch_and_add(&waiting, 1);
        until(&turn, at + 1);
        if (__sync_add_and_fetch(&inside, 1) > 1)
            shared[at] = 1;
        job->result += part(job);
        __sync_fetch_and_sub(&inside, 1);
    }
    return NULL;
}

static void together(struct job *jobs, unsigned count)
{
    pthread_t threads[MOST];
    turn = waiting = inside = 0;
    for (unsigned at = 0; at < PARTS; at++)
        shared[at] = 0;
    for (unsigned index = 0; index < count; index++)
        pthread_create(&threads[index], NULL, job_run, &jobs[index]);
    unsigned long long from = microseconds();
    for (unsigned at = 0; at < PARTS; at++) {
        until(&waiting, (at + 1) * count);
        turn = at + 1;
    }
    for (unsigned index = 0; index < count; index++)
        pthread_join(threads[index], NULL);
    elapsed = microseconds() - from;
    met = 0;
    for (unsigned at = 0; at < PARTS; at++)
        met += shared[at];
}

static void verdict(const char *name, unsigned threads, unsigned long long wrong, unsigned long long all, const char *what)
{
    char side[96] = "";
    if (threads > 1)
        snprintf(side, sizeof side, ", two threads at work at once in %u of %u parts", met, (unsigned)PARTS);
    if (wrong) {
        printf("FAIL %s with %u threads: %llu of %llu %s (%llu us%s)\n", name, threads, wrong, all, what, elapsed, side);
        failures++;
    } else if (threads > 1 && !met) {
        printf("APART %s with %u threads: none of %llu %s, which proves nothing: in none of %u parts were two threads at work at once (%llu us)\n", name, threads, all, what,
               (unsigned)PARTS, elapsed);
        failures++;
    } else {
        printf("ok %s with %u threads: none of %llu %s (%llu us%s)\n", name, threads, all, what, elapsed, side);
    }
}

static void counted(const char *name, int worker, unsigned threads)
{
    static _Alignas(16) u128 cell;
    struct job jobs[MOST];
    cell = 0;
    for (unsigned index = 0; index < threads; index++)
        jobs[index] = (struct job){worker, (uintptr_t)&cell, 0, 0, 0};
    together(jobs, threads);
    uint64_t all = (uint64_t)threads * ROUNDS, low = (uint64_t)cell, high = (uint64_t)(cell >> 64);
    uint64_t least = low < high ? low : high;
    verdict(name, threads, low > all || high > all ? all : all - least, all, "updates lost");
}

static void counted32(unsigned threads)
{
    static _Alignas(8) uint32_t cell[2];
    struct job jobs[MOST];
    cell[0] = cell[1] = 0;
    for (unsigned index = 0; index < threads; index++)
        jobs[index] = (struct job){PAIR32_ADD, (uintptr_t)cell, 0, 0, 0};
    together(jobs, threads);
    uint32_t all = threads * ROUNDS, least = cell[0] < cell[1] ? cell[0] : cell[1];
    verdict("pairs.add32", threads, cell[0] > all || cell[1] > all ? all : all - least, all, "updates lost");
}

static u128 token(unsigned number)
{
    return ((u128)~(uint64_t)number << 64) | number;
}

static void swapped(unsigned threads)
{
    static _Alignas(16) u128 cells[CELLS], mine[MOST];
    struct job jobs[MOST];
    unsigned char seen[CELLS + MOST + 1] = {0};
    for (unsigned index = 0; index < CELLS; index++)
        cells[index] = token(index + 1);
    for (unsigned index = 0; index < threads; index++) {
        mine[index] = token(CELLS + index + 1);
        jobs[index] = (struct job){PAIR_SWAP, (uintptr_t)cells, CELLS - 1, (uintptr_t)&mine[index], 0};
    }
    together(jobs, threads);
    unsigned missing = 0;
    for (unsigned index = 0; index < CELLS + threads; index++) {
        u128 held = index < CELLS ? cells[index] : mine[index - CELLS];
        uint64_t number = (uint64_t)held;
        if ((uint64_t)(held >> 64) == ~number && number >= 1 && number <= CELLS + threads)
            seen[number] = 1;
    }
    for (unsigned number = 1; number <= CELLS + threads; number++)
        missing += !seen[number];
    verdict("pairs.swap", threads, missing, CELLS + threads, "tokens lost or torn");
}

static void torn(unsigned threads)
{
    static _Alignas(16) u128 cell;
    struct job jobs[MOST];
    cell = token(0);
    for (unsigned index = 0; index < threads; index++) {
        if (index % 2)
            jobs[index] = (struct job){PAIR_TORN, (uintptr_t)&cell, 0, 0, 0};
        else
            jobs[index] = (struct job){PAIR_STORE, (uintptr_t)&cell, index + 1, 0, 0};
    }
    together(jobs, threads);
    unsigned long long wrong = 0;
    for (unsigned index = 1; index < threads; index += 2)
        wrong += jobs[index].result;
    verdict("pairs.torn", threads, wrong, (unsigned long long)(threads / 2) * ROUNDS, "pairs read with one half of another store");
}

static void bare(void)
{
    static _Alignas(16) u128 cell;
    cell = token(7);
    uint64_t status = run(PAIR_BARE, (uintptr_t)&cell, 0, 0, 0);
    if (status != 1 || cell != token(7)) {
        printf("FAIL pairs.bare: a pair store with no load before it answered %llu and %s the pair\n", (unsigned long long)status, cell != token(7) ? "changed" : "kept");
        failures++;
    } else {
        printf("ok pairs.bare: a pair store with no load before it failed and stored nothing\n");
    }
}

static uint64_t missing(uint64_t found, uint64_t wanted)
{
    return found > wanted ? wanted : wanted - found;
}

static int overlapping(void)
{
    static _Alignas(16) uint64_t words[4];
    struct job jobs[2] = {{PAIR_ADD, (uintptr_t)&words[1], 0, 0, 0}, {PAIR_ADD, (uintptr_t)&words[2], 0, 0, 0}};
    together(jobs, 2);
    verdict("pairs.overlap", 2, missing(words[1], ROUNDS) + missing(words[2], 2 * ROUNDS) + missing(words[3], ROUNDS), 4 * ROUNDS,
            "updates lost by two pairs that share a word");
    return failures != 0;
}

static int overlapping32(void)
{
    static _Alignas(16) uint32_t words[4];
    struct job jobs[2] = {{PAIR32_ADD, (uintptr_t)&words[0], 0, 0, 0}, {PAIR32_ADD, (uintptr_t)&words[1], 0, 0, 0}};
    together(jobs, 2);
    verdict("pairs.overlap32", 2, missing(words[0], ROUNDS) + missing(words[1], 2 * ROUNDS) + missing(words[2], ROUNDS), 4 * ROUNDS,
            "updates lost by two 32-bit pairs that share a word");
    return failures != 0;
}

static int mode(int argc, char **argv)
{
    if (argc > 1 && !strcmp(argv[1], "--overlap"))
        return overlapping();
    if (argc > 1 && !strcmp(argv[1], "--overlap32"))
        return overlapping32();
    return -1;
}

static void scenarios(void)
{
    bare();
    counted("pairs.add", PAIR_ADD, 1);
    counted("pairs.cas", PAIR_CAS, 1);
    counted32(1);
    for (unsigned threads = 2; threads <= MOST; threads += 2) {
        counted("pairs.add", PAIR_ADD, threads);
        counted("pairs.cas", PAIR_CAS, threads);
        counted32(threads);
        swapped(threads);
        torn(threads);
    }
}
