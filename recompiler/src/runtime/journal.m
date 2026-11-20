#include <errno.h>
#include <fcntl.h>
#include <malloc/malloc.h>
#include <mach/mach.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "xl_diag.h"
#include "xl_proxy.h"

struct xl_journal_entry {
    uint32_t sequence;
    uint32_t thread;
    uint32_t pointer;
    uint32_t extra;
    uint32_t isa;
    uint32_t caller;
    const char *op;
};

struct xl_journal_name {
    volatile uint32_t cls;
    char text[60];
};

#define XL_JOURNAL_SIZE 262144u
#define XL_JOURNAL_POOL_SLOTS 16u
#define XL_JOURNAL_POOL_MAX 8192u
#define XL_JOURNAL_SET 32768u
#define XL_JOURNAL_RECENT 3000u
#define XL_JOURNAL_LINES 30000u

struct xl_journal_pool_record {
    volatile uint32_t thread;
    uint32_t count;
    uint32_t token;
    uint32_t entries[XL_JOURNAL_POOL_MAX];
};
#define XL_JOURNAL_NAMES 1024u

struct xl_journal_tables {
    struct xl_journal_entry ring[XL_JOURNAL_SIZE];
    struct xl_journal_pool_record pools[XL_JOURNAL_POOL_SLOTS];
    uint32_t set[XL_JOURNAL_SET];
};

static struct xl_journal_tables *xl_journal_tables;
static struct xl_journal_name xl_journal_names[XL_JOURNAL_NAMES];
static volatile uint32_t xl_journal_count;
static volatile int xl_journal_state;
static pthread_once_t xl_journal_once = PTHREAD_ONCE_INIT;
static int xl_journal_fd = -1;

static int xl_journal_read(uintptr_t address, void *buffer, size_t size)
{
    vm_size_t got = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)address, size, (vm_address_t)buffer, &got) == KERN_SUCCESS && got == size;
}

const char *xl_journal_class_name(uint32_t cls)
{
    if (!cls)
        return "nil";
    struct xl_journal_name *slot = &xl_journal_names[(cls >> 4) % XL_JOURNAL_NAMES];
    if (slot->cls == cls)
        return slot->text;
    uint32_t bits, flags, ro, name;
    if (!xl_journal_read(cls + 0x10, &bits, 4))
        return "?class-unreadable";
    uint32_t data = bits & ~3u;
    if (!xl_journal_read(data, &flags, 4))
        return "?data-unreadable";
    ro = data;
    int realized = (flags & 0x80000000u) != 0;
    if (realized && !xl_journal_read(data + 8, &ro, 4))
        return "?rw-unreadable";
    if (!xl_journal_read(ro + 0x10, &name, 4))
        return "?ro-unreadable";
    char text[sizeof slot->text];
    size_t length = 0;
    if (!realized) {
        text[0] = 'u';
        text[1] = ':';
        length = 2;
    }
    while (length < sizeof text - 1 && xl_journal_read(name + length, &text[length], 1) && text[length])
        length++;
    text[length] = 0;
    slot->cls = 0;
    memcpy(slot->text, text, length + 1);
    slot->cls = cls;
    return slot->text;
}

static void xl_journal_set_add(uint32_t value)
{
    uint32_t h = (value * 2654435761u) >> 17;
    for (unsigned n = 0; n < XL_JOURNAL_SET; n++, h = (h + 1) & (XL_JOURNAL_SET - 1)) {
        if (!xl_journal_tables->set[h]) {
            xl_journal_tables->set[h] = value;
            return;
        }
        if (xl_journal_tables->set[h] == value)
            return;
    }
}

static int xl_journal_set_has(uint32_t value)
{
    uint32_t h = (value * 2654435761u) >> 17;
    for (unsigned n = 0; n < XL_JOURNAL_SET; n++, h = (h + 1) & (XL_JOURNAL_SET - 1)) {
        if (!xl_journal_tables->set[h])
            return 0;
        if (xl_journal_tables->set[h] == value)
            return 1;
    }
    return 0;
}

static void xl_journal_write(const char *line, int length)
{
    if (length <= 0)
        return;
    if (length > 255)
        length = 255;
    write(2, line, (size_t)length);
    if (xl_journal_fd >= 0)
        write(xl_journal_fd, line, (size_t)length);
}

void xl_journal_dump(const char *why)
{
    char line[256];
    if (!xl_journal_tables)
        return;
    uint32_t count = xl_journal_count;
    uint32_t first = count > XL_JOURNAL_SIZE ? count - XL_JOURNAL_SIZE : 0;
    uint32_t self = (uint32_t)(uintptr_t)pthread_self();
    const struct xl_journal_pool_record *pool = NULL;
    for (unsigned s = 0; s < XL_JOURNAL_POOL_SLOTS; s++)
        if (xl_journal_tables->pools[s].thread == self)
            pool = &xl_journal_tables->pools[s];
    memset(xl_journal_tables->set, 0, sizeof xl_journal_tables->set);
    if (pool) {
        for (uint32_t k = 0; k < pool->count; k++)
            xl_journal_set_add(pool->entries[k]);
        xl_journal_write(line, snprintf(line, sizeof line, "xlate-journal: the last pop of thread %x: token %x, %u entries\n", self, pool->token, pool->count));
    }
    xl_journal_write(line, snprintf(line, sizeof line, "xlate-journal: %s in thread %x: %u events, the ring holds %u; the last %u and every one of a pool entry follow\n", why, self, count, count - first, XL_JOURNAL_RECENT));
    unsigned lines = 0;
    for (uint32_t i = first; i < count; i++) {
        const struct xl_journal_entry *e = &xl_journal_tables->ring[i % XL_JOURNAL_SIZE];
        if (e->sequence != i || !e->op)
            continue;
        if (i + XL_JOURNAL_RECENT < count && !(pool && xl_journal_set_has(e->pointer)))
            continue;
        if (++lines > XL_JOURNAL_LINES)
            break;
        xl_journal_write(line, snprintf(line, sizeof line, "xlate-journal: #%u t=%x %s %x extra=%x caller=%x isa=%x %s\n", e->sequence, e->thread,
                                        e->op, e->pointer, e->extra, e->caller, e->isa, e->isa ? xl_journal_class_name(e->isa) : "-"));
    }
    xl_journal_write(line, snprintf(line, sizeof line, "xlate-journal: end\n"));
}

static void xl_journal_signal(int signal_number)
{
    static volatile int dumping;
    if (!__sync_bool_compare_and_swap(&dumping, 0, 1))
        return;
    char why[32];
    snprintf(why, sizeof why, "signal %d", signal_number);
    xl_journal_dump(why);
}

static void xl_journal_setup(void)
{
    static struct xl_diag_flag poolcheck = {"xl-poolcheck", 0};
    if (!xl_diag_on(&poolcheck)) {
        xl_journal_state = 2;
        return;
    }
    void *tables = mmap(NULL, sizeof(struct xl_journal_tables), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (tables == MAP_FAILED) {
        dprintf(2, "xlate-journal: xl-poolcheck is on and the %lu bytes of the journal cannot be mapped (errno %d): nothing is recorded\n",
                (unsigned long)sizeof(struct xl_journal_tables), errno);
        xl_journal_state = 2;
        return;
    }
    xl_journal_tables = tables;
    xl_journal_fd = xl_diag_open("xl-journal.log", O_TRUNC);
    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_handler = xl_journal_signal;
    action.sa_flags = SA_RESETHAND;
    sigemptyset(&action.sa_mask);
    sigaction(SIGABRT, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    xl_journal_state = 1;
}

int xl_journal_enabled(void)
{
    if (xl_journal_state == 0)
        pthread_once(&xl_journal_once, xl_journal_setup);
    return xl_journal_state == 1;
}

void xl_journal_note3(const char *op, uintptr_t pointer, uintptr_t extra, uintptr_t caller)
{
    if (xl_journal_state == 2 || !xl_journal_enabled())
        return;
    uint32_t index = __sync_fetch_and_add(&xl_journal_count, 1);
    struct xl_journal_entry *e = &xl_journal_tables->ring[index % XL_JOURNAL_SIZE];
    uint32_t isa = 0;
    if (pointer >= 0x1000 && pointer < 0xFFFFF000u)
        xl_journal_read(pointer, &isa, 4);
    e->sequence = index + 1;
    e->thread = (uint32_t)(uintptr_t)pthread_self();
    e->pointer = (uint32_t)pointer;
    e->extra = (uint32_t)extra;
    e->isa = isa;
    e->caller = (uint32_t)caller;
    e->op = op;
    e->sequence = index;
}

void xl_journal_note(const char *op, uintptr_t pointer, uintptr_t extra)
{
    xl_journal_note3(op, pointer, extra, 0);
}

static struct xl_journal_pool_record *xl_journal_pool_record_of(uint32_t self)
{
    for (unsigned s = 0; s < XL_JOURNAL_POOL_SLOTS; s++)
        if (xl_journal_tables->pools[s].thread == self)
            return &xl_journal_tables->pools[s];
    for (unsigned s = 0; s < XL_JOURNAL_POOL_SLOTS; s++)
        if (__sync_bool_compare_and_swap(&xl_journal_tables->pools[s].thread, 0, self))
            return &xl_journal_tables->pools[s];
    return NULL;
}

void xl_journal_pool_pop(uintptr_t token)
{
    if (!xl_journal_enabled())
        return;
    xl_journal_note("pool-pop", token, 0);
    struct xl_journal_pool_record *record = xl_journal_pool_record_of((uint32_t)(uintptr_t)pthread_self());
    if (record) {
        record->count = 0;
        record->token = (uint32_t)token;
    }
    uintptr_t page = token & ~0xfffu;
    uint32_t magic = 0;
    if (!token || !xl_journal_read(page, &magic, 4) || magic != 0xa1a1a1a1u) {
        xl_journal_note("pool-pop-bad-token", token, magic);
        return;
    }
    uintptr_t start = token + 4;
    for (unsigned depth = 0; page && depth < 64; depth++) {
        uint32_t next = 0, child = 0;
        if (!xl_journal_read(page + 0x10, &next, 4) || !xl_journal_read(page + 0x1c, &child, 4))
            break;
        for (uintptr_t cursor = start; cursor < next && cursor < page + 0x1000; cursor += 4) {
            uint32_t entry;
            if (!xl_journal_read(cursor, &entry, 4))
                break;
            xl_journal_note("pool-entry", entry, entry >= 0x1000 ? malloc_size((const void *)(uintptr_t)entry) : 0);
            if (record && record->count < XL_JOURNAL_POOL_MAX)
                record->entries[record->count++] = entry;
        }
        page = child;
        start = page + 0x28;
        if (page && (!xl_journal_read(page, &magic, 4) || magic != 0xa1a1a1a1u))
            break;
    }
}
