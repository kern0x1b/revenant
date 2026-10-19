// The sqlite3_str string builder of packages/a/apple-backports/SQLite3/StringBuilder.c against the HOST's libsqlite3, in one
// process. The port's functions are compiled with their names renamed to charon_port_* (run.sh), so each scenario drives a
// host builder and a port builder with the same steps and compares, after every step, the length, the error code, the text
// and the finished string. Each scenario prints "ok <name>" or "FAIL <name> step=<step>", and the process exits with the number
// of failures.
#include <stdio.h>
#include <string.h>
#include <sqlite3.h>

// the host's own, under the names the library exports
sqlite3_str *sqlite3_str_new(sqlite3 *);
char *sqlite3_str_finish(sqlite3_str *);
void sqlite3_str_append(sqlite3_str *, const char *, int);
void sqlite3_str_appendall(sqlite3_str *, const char *);
void sqlite3_str_appendchar(sqlite3_str *, int, char);
void sqlite3_str_appendf(sqlite3_str *, const char *, ...);
void sqlite3_str_reset(sqlite3_str *);
int sqlite3_str_errcode(sqlite3_str *);
int sqlite3_str_length(sqlite3_str *);
char *sqlite3_str_value(sqlite3_str *);

// the port's, renamed at build time
sqlite3_str *charon_port_sqlite3_str_new(sqlite3 *);
char *charon_port_sqlite3_str_finish(sqlite3_str *);
void charon_port_sqlite3_str_append(sqlite3_str *, const char *, int);
void charon_port_sqlite3_str_appendall(sqlite3_str *, const char *);
void charon_port_sqlite3_str_appendchar(sqlite3_str *, int, char);
void charon_port_sqlite3_str_appendf(sqlite3_str *, const char *, ...);
void charon_port_sqlite3_str_reset(sqlite3_str *);
int charon_port_sqlite3_str_errcode(sqlite3_str *);
int charon_port_sqlite3_str_length(sqlite3_str *);
char *charon_port_sqlite3_str_value(sqlite3_str *);

static int failures;

// one host builder and one port builder, driven together
struct pair {
    sqlite3_str *host, *port;
    const char *scenario;
    int failed;
};

static void fail(struct pair *x, const char *step, const char *what)
{
    if (!x->failed) {
        printf("FAIL %s step=%s %s\n", x->scenario, step, what);
        failures++;
        x->failed = 1;
    }
}

static void same_text(struct pair *x, const char *step, const char *a, const char *b, const char *label)
{
    if ((a == NULL) != (b == NULL) || (a != NULL && strcmp(a, b) != 0)) {
        char what[256];
        snprintf(what, sizeof what, "%s host=[%s] port=[%s]", label, a ? a : "(null)", b ? b : "(null)");
        fail(x, step, what);
    }
}

// the observable state of both builders must agree after every step
static void compare(struct pair *x, const char *step)
{
    char what[128];
    int hl = sqlite3_str_length(x->host), pl = charon_port_sqlite3_str_length(x->port);
    if (hl != pl) {
        snprintf(what, sizeof what, "length host=%d port=%d", hl, pl);
        fail(x, step, what);
    }
    int he = sqlite3_str_errcode(x->host), pe = charon_port_sqlite3_str_errcode(x->port);
    if (he != pe) {
        snprintf(what, sizeof what, "errcode host=%d port=%d", he, pe);
        fail(x, step, what);
    }
    same_text(x, step, sqlite3_str_value(x->host), charon_port_sqlite3_str_value(x->port), "value");
}

static void finish(struct pair *x, const char *step)
{
    char *h = sqlite3_str_finish(x->host);
    char *p = charon_port_sqlite3_str_finish(x->port);
    same_text(x, step, h, p, "finish");
    sqlite3_free(h);
    sqlite3_free(p);
    x->host = x->port = NULL;
}

static void report(struct pair *x)
{
    if (!x->failed)
        printf("ok %s\n", x->scenario);
}

static void append(struct pair *x, const char *z, int n, const char *step)
{
    sqlite3_str_append(x->host, z, n);
    charon_port_sqlite3_str_append(x->port, z, n);
    compare(x, step);
}

static void appendall(struct pair *x, const char *z, const char *step)
{
    sqlite3_str_appendall(x->host, z);
    charon_port_sqlite3_str_appendall(x->port, z);
    compare(x, step);
}

static void appendchar(struct pair *x, int n, char c, const char *step)
{
    sqlite3_str_appendchar(x->host, n, c);
    charon_port_sqlite3_str_appendchar(x->port, n, c);
    compare(x, step);
}

static void appendf_int(struct pair *x, const char *format, long long v, const char *step)
{
    sqlite3_str_appendf(x->host, format, v);
    charon_port_sqlite3_str_appendf(x->port, format, v);
    compare(x, step);
}

static void appendf_text(struct pair *x, const char *format, const char *v, const char *step)
{
    sqlite3_str_appendf(x->host, format, v);
    charon_port_sqlite3_str_appendf(x->port, format, v);
    compare(x, step);
}

static void reset(struct pair *x, const char *step)
{
    sqlite3_str_reset(x->host);
    charon_port_sqlite3_str_reset(x->port);
    compare(x, step);
}

static void begin(struct pair *x, const char *scenario, sqlite3 *db)
{
    memset(x, 0, sizeof *x);
    x->scenario = scenario;
    x->host = sqlite3_str_new(db);
    x->port = charon_port_sqlite3_str_new(db);
    if (x->host == NULL || x->port == NULL) {
        fail(x, "new", "a builder is NULL");
        return;
    }
    compare(x, "new");
}

static void scenario_empty(void)
{
    struct pair x;
    begin(&x, "empty-no-database", NULL);
    finish(&x, "finish-empty");
    report(&x);
}

static void scenario_appends(void)
{
    struct pair x;
    begin(&x, "appends-no-database", NULL);
    append(&x, "hello", 5, "append-5");
    append(&x, "world", 0, "append-0");
    append(&x, "XYZ", -1, "append-negative");
    appendall(&x, "!", "appendall");
    appendall(&x, "", "appendall-empty");
    appendchar(&x, 3, '-', "appendchar-3");
    appendchar(&x, 0, '#', "appendchar-0");
    appendchar(&x, -2, '#', "appendchar-negative");
    append(&x, "\0tail", 5, "append-embedded-nul");
    finish(&x, "finish");
    report(&x);
}

static void scenario_formats(void)
{
    struct pair x;
    begin(&x, "formats-no-database", NULL);
    appendf_int(&x, "%lld", 42, "lld-small");
    appendf_int(&x, "[%5lld]", -7, "width");
    appendf_int(&x, "%lld", 9007199254740993LL, "lld");
    appendf_text(&x, "<%s>", "plain", "s");
    appendf_text(&x, "%q", "it's", "q");
    appendf_text(&x, "%Q", "it's", "Q");
    appendf_text(&x, "%w", "a\"b", "w");
    appendf_text(&x, "%.3s", "truncate", "precision");
    appendf_text(&x, "100%%", "", "percent");
    appendf_text(&x, "%Q", NULL, "Q-null");
    finish(&x, "finish");
    report(&x);
}

static void scenario_reset(void)
{
    struct pair x;
    begin(&x, "reset-then-append", NULL);
    append(&x, "first", 5, "append-first");
    reset(&x, "reset");
    append(&x, "second", 6, "append-second");
    reset(&x, "reset-again");
    finish(&x, "finish-after-reset");
    report(&x);
}

// sqlite clamps a length limit to 30 bytes at least, so the smallest limit a database can carry is 30. An append that
// must grow the buffer past the limit is SQLITE_TOOBIG, and the text is then dropped.
static void scenario_limit(void)
{
    sqlite3 *db = NULL;
    sqlite3_open(":memory:", &db);
    sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 30);
    struct pair x;
    begin(&x, "limit-toobig", db);
    append(&x, "abcdefghijklmnopqrstuvwxy", 25, "append-25");
    append(&x, "0123456789", 10, "append-over-limit");
    append(&x, "k", 1, "append-after-error");
    appendchar(&x, 2, 'z', "appendchar-after-error");
    appendf_int(&x, "%lld", 7, "appendf-after-error");
    finish(&x, "finish-after-toobig");
    report(&x);
    sqlite3_close(db);
}

// Just under the limit the text is kept, and finishes as it was written.
static void scenario_limit_under(void)
{
    sqlite3 *db = NULL;
    sqlite3_open(":memory:", &db);
    sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 30);
    struct pair x;
    begin(&x, "limit-just-under", db);
    append(&x, "abcdefghijklmnopqrstuvwxyz012", 29, "append-to-29");
    finish(&x, "finish-at-29");
    report(&x);
    sqlite3_close(db);
}

// The boundary is where the allocator's usable size is, not the length: the host keeps text past the limit while the
// buffer it already has still holds it (malloc_size), and reaches SQLITE_TOOBIG only on a grow past the limit. Measured
// on the host: an exact-limit append from empty is TOOBIG, 29 then 1 keeps 30, and 31 single bytes keep 31.
static void scenario_limit_boundary(void)
{
    sqlite3 *db = NULL;
    sqlite3_open(":memory:", &db);
    sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 30);
    struct pair x;
    begin(&x, "limit-boundary", db);
    append(&x, "abcdefghijklmnopqrstuvwxy", 25, "append-25");
    append(&x, "0123", 4, "append-to-29");
    append(&x, "Z", 1, "append-to-30");
    append(&x, "Q", 1, "append-to-31");
    finish(&x, "finish-boundary");
    report(&x);
    sqlite3_close(db);
    sqlite3_open(":memory:", &db);
    sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 30);
    begin(&x, "limit-exact-from-empty", db);
    append(&x, "abcdefghijklmnopqrstuvwxyz0123", 30, "append-30");
    finish(&x, "finish-exact");
    report(&x);
    sqlite3_close(db);
    sqlite3_open(":memory:", &db);
    sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 30);
    begin(&x, "limit-single-bytes", db);
    for (int i = 0; i < 31; i++)
        append(&x, "k", 1, "append-byte");
    finish(&x, "finish-bytes");
    report(&x);
    sqlite3_close(db);
}

// Calls on a NULL builder must not crash, and answer what the host answers.
static void scenario_null(void)
{
    struct pair x;
    memset(&x, 0, sizeof x);
    x.scenario = "null-builder";
    append(&x, "x", 1, "append-null");
    appendall(&x, "x", "appendall-null");
    appendchar(&x, 2, 'x', "appendchar-null");
    appendf_int(&x, "%lld", 1, "appendf-null");
    reset(&x, "reset-null");
    compare(&x, "null-state");
    char *h = sqlite3_str_finish(NULL), *p = charon_port_sqlite3_str_finish(NULL);
    same_text(&x, "finish-null", h, p, "finish");
    report(&x);
}

int main(void)
{
    scenario_empty();
    scenario_appends();
    scenario_formats();
    scenario_reset();
    scenario_limit();
    scenario_limit_under();
    scenario_limit_boundary();
    scenario_null();
    if (failures == 0)
        printf("checks=all failures=0\n");
    else
        printf("checks=failed failures=%d\n", failures);
    return failures;
}
