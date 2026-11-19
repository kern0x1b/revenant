#include <signal.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "scenarios.h"
#include "xl_state.h"
#include "lifted.h"
#include "../../src/runtime/xl_budget_lines.h"

uint32_t rellume_aarch64_stxp(volatile uint64_t *address, uint32_t armed, uint64_t seen_low, uint64_t seen_high, uint64_t low, uint64_t high);
void xl_pair_read(struct xl_pair_count *count);

typedef struct {
    _Alignas(16) uint8_t bytes[XL_STATE_SIZE];
} state_t;

static uint64_t lifted(void (*function)(void *), uint64_t a, uint64_t b, uint64_t c, uint64_t d)
{
    state_t state;
    _Alignas(16) uint8_t stack[4096];
    uint64_t registers[4] = {a, b, c, d}, top = (uintptr_t)(stack + sizeof stack), result;
    memset(&state, 0, sizeof state);
    memcpy(state.bytes + XL_OFFSET_X0, registers, sizeof registers);
    memcpy(state.bytes + XL_OFFSET_SP, &top, sizeof top);
    function(state.bytes);
    memcpy(&result, state.bytes + XL_OFFSET_X0, sizeof result);
    return result;
}

static uint64_t run(int worker, uint64_t a, uint64_t b, uint64_t c, uint64_t d)
{
    switch (worker) {
    case PAIR_ADD:
        return lifted(SUB_pair_add, a, b, c, d);
    case PAIR_CAS:
        return lifted(SUB_pair_cas, a, b, c, d);
    case PAIR_SWAP:
        return lifted(SUB_pair_swap, a, b, c, d);
    case PAIR_STORE:
        return lifted(SUB_pair_store, a, b, c, d);
    case PAIR_TORN:
        return lifted(SUB_pair_torn, a, b, c, d);
    case PAIR32_ADD:
        return lifted(SUB_pair32_add, a, b, c, d);
    default:
        return lifted(SUB_pair_bare, a, b, c, d);
    }
}

static void monitor(const char *name, void (*function)(void *), uint64_t wanted, u128 left, const char *what)
{
    static _Alignas(16) u128 cells[2];
    cells[0] = token(1);
    cells[1] = token(2);
    uint64_t status = lifted(function, (uintptr_t)&cells[0], (uintptr_t)&cells[1], 0, 0);
    if (status != wanted || cells[0] != left || cells[1] != token(2)) {
        printf("FAIL %s: %s answered %llu and left the pair %s\n", name, what, (unsigned long long)status, cells[0] != left || cells[1] != token(2) ? "changed" : "as it was");
        failures++;
    } else {
        printf("ok %s: %s\n", name, what);
    }
}

static void crashed(int signal)
{
    char line[320];
    struct xl_pair_count count;
    (void)signal;
    xl_pair_read(&count);
    write(1, line, xl_pair_line(line, sizeof line, &count, NULL));
    _exit(count.held == 1 ? 0 : 3);
}

static int fault(void)
{
    uint64_t *page = mmap(NULL, 16384, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    page[0] = 5;
    page[1] = 6;
    mprotect(page, 16384, PROT_READ);
    struct sigaction action = {0};
    action.sa_handler = crashed;
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    uint32_t status = rellume_aarch64_stxp(page, 1, 5, 6, 7, 8);
    printf("FAIL pairs.fault: a pair store into a page that cannot be written answered %u\n", status);
    return 1;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    alarm(120);
    if (argc > 1 && !strcmp(argv[1], "--fault"))
        return fault();
    scenarios();
    monitor("pairs.elsewhere", SUB_pair_elsewhere, 1, token(1), "a pair store at another address than its load failed and stored nothing");
    monitor("pairs.after-single", SUB_pair_after_single, 1, token(1), "a pair store after a single-word exclusive load failed and stored nothing");
    monitor("pairs.single-after", SUB_single_after_pair, 1, token(1), "a single-word exclusive store after a pair load failed and stored nothing");
    monitor("pairs.twice", SUB_pair_twice, 2, ((u128)1 << 64) | ~(uint64_t)1, "of two pair stores after one load the first stored and the second failed");
    char line[320];
    struct xl_pair_count count;
    xl_pair_read(&count);
    write(1, line, xl_pair_line(line, sizeof line, &count, NULL));
    printf("done\n");
    return failures != 0;
}
