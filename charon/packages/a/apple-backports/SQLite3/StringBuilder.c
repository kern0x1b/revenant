#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <malloc/malloc.h>
#include <sqlite3.h>

struct sqlite3_str {
    sqlite3 *db;
    char *text;
    size_t allocated;
    size_t limit;
    size_t length;
    int error;
};

enum { kDefaultLengthLimit = 1000000000 };

#define SQLITE3_EXPORT __attribute__((visibility("default")))

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
