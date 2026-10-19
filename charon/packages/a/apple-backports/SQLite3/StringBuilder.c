#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <malloc/malloc.h>
#include <sqlite3.h>

// The sqlite3_str string builder, over the buffer and printf calls every libsqlite3 has (sqlite3_malloc, sqlite3_realloc,
// sqlite3_vmprintf, sqlite3_limit). The formats are the sqlite printf dialect, because sqlite3_vmprintf is that dialect, and
// the limit is the database's SQLITE_LIMIT_LENGTH, or the compile-time default with no database. The answers for an
// empty builder, a builder that reached its limit, and a reset are the host's, measured in
// tests/backports/host/sqlite3/run.sh and described in facts/SQLite3/StringBuilder.md.

// The object behind the opaque sqlite3_str of the header.
struct sqlite3_str {
    sqlite3 *db;
    char *text;
    size_t allocated;
    size_t limit;
    size_t length;
    int error;
};

// The compile-time length limit of sqlite, used when the builder has no database.
enum { kDefaultLengthLimit = 1000000000 };

// The C sources of a backport are compiled -fvisibility=hidden, so the entry points of the API are marked here, and
// nothing else of this file is.
#define SQLITE3_EXPORT __attribute__((visibility("default")))

// Makes room for extra more bytes and the terminating NUL, as sqlite does: the text fits while it is within the capacity the
// allocator reports for the buffer (malloc_size, not the size asked for), and the buffer grows only when it does not. Growth
// past the limit sets SQLITE_TOOBIG, and the builder then holds nothing (measured: the text is dropped, not kept); a buffer
// that cannot be allocated sets SQLITE_NOMEM. Returns non-zero when the append may proceed.
static int reserve(sqlite3_str *p, size_t extra)
{
    if (p->error)
        return 0;
    size_t needed = p->length + extra + 1;
    if (needed <= p->allocated)
        return 1;
    if (needed > p->limit) {
        p->error = SQLITE_TOOBIG;
        sqlite3_free(p->text);
        p->text = NULL;
        p->allocated = 0;
        p->length = 0;
        return 0;
    }
    // sqlite doubles the size while the doubled size stays within the limit, so a builder that grows by appends does not
    // reallocate on every one
    size_t size = needed;
    if (size + p->length <= p->limit)
        size += p->length;
    char *grown = sqlite3_realloc(p->text, (int)size);
    if (grown == NULL) {
        p->error = SQLITE_NOMEM;
        return 0;
    }
    p->text = grown;
    p->allocated = malloc_size(grown);
    return 1;
}

static void append(sqlite3_str *p, const char *z, size_t n)
{
    if (p == NULL || n == 0)
        return;
    if (!reserve(p, n))
        return;
    memcpy(p->text + p->length, z, n);
    p->length += n;
    p->text[p->length] = '\0';
}

SQLITE3_EXPORT sqlite3_str *sqlite3_str_new(sqlite3 *db)
{
    sqlite3_str *p = sqlite3_malloc(sizeof(*p));
    if (p == NULL)
        return NULL;
    memset(p, 0, sizeof(*p));
    p->db = db;
    p->limit = db != NULL ? (size_t)sqlite3_limit(db, SQLITE_LIMIT_LENGTH, -1) : kDefaultLengthLimit;
    return p;
}

SQLITE3_EXPORT char *sqlite3_str_finish(sqlite3_str *p)
{
    if (p == NULL)
        return NULL;
    char *text = p->error ? NULL : p->text;
    if (p->error)
        sqlite3_free(p->text);
    sqlite3_free(p);
    return text;
}

SQLITE3_EXPORT void sqlite3_str_append(sqlite3_str *p, const char *zIn, int N)
{
    if (N > 0)
        append(p, zIn, (size_t)N);
}

SQLITE3_EXPORT void sqlite3_str_appendall(sqlite3_str *p, const char *zIn)
{
    append(p, zIn, strlen(zIn));
}

SQLITE3_EXPORT void sqlite3_str_appendchar(sqlite3_str *p, int N, char C)
{
    for (int i = 0; i < N; i++)
        append(p, &C, 1);
}

SQLITE3_EXPORT void sqlite3_str_vappendf(sqlite3_str *p, const char *zFormat, va_list ap)
{
    if (p == NULL)
        return;
    char *z = sqlite3_vmprintf(zFormat, ap);
    if (z == NULL) {
        if (p->error == 0)
            p->error = SQLITE_NOMEM;
        return;
    }
    append(p, z, strlen(z));
    sqlite3_free(z);
}

SQLITE3_EXPORT void sqlite3_str_appendf(sqlite3_str *p, const char *zFormat, ...)
{
    va_list ap;
    va_start(ap, zFormat);
    sqlite3_str_vappendf(p, zFormat, ap);
    va_end(ap);
}

SQLITE3_EXPORT void sqlite3_str_reset(sqlite3_str *p)
{
    if (p == NULL)
        return;
    sqlite3_free(p->text);
    p->text = NULL;
    p->allocated = 0;
    p->length = 0;
}

SQLITE3_EXPORT int sqlite3_str_errcode(sqlite3_str *p)
{
    return p == NULL ? SQLITE_NOMEM : p->error;
}

SQLITE3_EXPORT int sqlite3_str_length(sqlite3_str *p)
{
    return p == NULL ? 0 : (int)p->length;
}

SQLITE3_EXPORT char *sqlite3_str_value(sqlite3_str *p)
{
    return p == NULL ? NULL : p->text;
}
