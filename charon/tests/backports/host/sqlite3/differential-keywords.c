// The keyword functions of packages/a/apple-backports/SQLite3/Keywords.c against the HOST's libsqlite3, in one process. The
// port's functions are compiled with their names renamed to charon_port_* (run.sh), so each check calls the host and the port
// with the same input and compares the answers: the return code, the name and its length, and whether the output was written.
// Each check prints "ok <name>" or "FAIL <name> <what>", and the process exits with the number of failures.
#include <stdio.h>
#include <string.h>
#include <sqlite3.h>

// the host's own
int sqlite3_keyword_count(void);
int sqlite3_keyword_name(int, const char **, int *);
int sqlite3_keyword_check(const char *, int);

// the port's, renamed at build time
int charon_port_sqlite3_keyword_count(void);
int charon_port_sqlite3_keyword_name(int, const char **, int *);
int charon_port_sqlite3_keyword_check(const char *, int);

static int failures;

static void report(const char *name, int bad, const char *what)
{
    if (bad) {
        printf("FAIL %s %s\n", name, what);
        failures++;
    } else {
        printf("ok %s\n", name);
    }
}

static void check_count(void)
{
    int h = sqlite3_keyword_count(), p = charon_port_sqlite3_keyword_count();
    char what[96];
    snprintf(what, sizeof what, "host=%d port=%d", h, p);
    report("keyword-count", h != p, what);
}

// every index from before the table to past it: the name, the length, and what is written on a failure
static void check_names(void)
{
    int count = sqlite3_keyword_count();
    static const char sentinel[] = "untouched";
    for (int i = -2; i <= count + 1; i++) {
        const char *hz = sentinel, *pz = sentinel;
        int hn = -7, pn = -7;
        int hr = sqlite3_keyword_name(i, &hz, &hn);
        int pr = charon_port_sqlite3_keyword_name(i, &pz, &pn);
        char what[160];
        if (hr != pr) {
            snprintf(what, sizeof what, "index=%d rc host=%d port=%d", i, hr, pr);
            report("keyword-name", 1, what);
            return;
        }
        if (hr == 0) {
            // the host's names are not NUL-terminated (they are slices of one table), so the length is what is compared
            if (hn != pn || memcmp(hz, pz, hn) != 0) {
                snprintf(what, sizeof what, "index=%d host=[%.*s]/%d port=[%.*s]/%d", i, hn, hz, hn, pn, pn, pz, pn);
                report("keyword-name", 1, what);
                return;
            }
        } else if (hz != NULL || pz != NULL || hn != -7 || pn != -7) {
            // on failure the text is NULL and the length is not written
            snprintf(what, sizeof what, "index=%d on failure host=(%p,%d) port=(%p,%d)", i, (void *)hz, hn, (void *)pz, pn);
            report("keyword-name", 1, what);
            return;
        }
    }
    report("keyword-name", 0, "");
}

// one check of keyword_check, with the input and the length as given
static int check_one(const char *word, int n, const char *label)
{
    int h = sqlite3_keyword_check(word, n), p = charon_port_sqlite3_keyword_check(word, n);
    if (h != p) {
        char what[200];
        snprintf(what, sizeof what, "%s [%s] n=%d host=%d port=%d", label, word, n, h, p);
        report("keyword-check", 1, what);
        return 1;
    }
    return 0;
}

static void check_check(void)
{
    int bad = 0;
    int count = sqlite3_keyword_count();
    for (int i = 0; i < count; i++) {
        const char *k = NULL;
        int kn = 0;
        sqlite3_keyword_name(i, &k, &kn);
        char lower[64], upper[64], mixed[64], longer[64], wrong[64];
        for (int j = 0; j < kn; j++) {
            lower[j] = (char)(k[j] >= 'A' && k[j] <= 'Z' ? k[j] + 32 : k[j]);
            upper[j] = (char)(k[j] >= 'a' && k[j] <= 'z' ? k[j] - 32 : k[j]);
            mixed[j] = (char)(j % 2 ? lower[j] : upper[j]);
            wrong[j] = k[j];
        }
        lower[kn] = upper[kn] = mixed[kn] = wrong[kn] = '\0';
        bad |= check_one(upper, -1, "upper");
        bad |= check_one(upper, kn, "upper-exact");
        bad |= check_one(lower, -1, "lower");
        bad |= check_one(mixed, kn, "mixed");
        bad |= check_one(k, kn - 1, "shorter-than-keyword");
        bad |= check_one(k, 0, "zero-length");
        if (kn > 0) {
            wrong[kn - 1] = 'Q';
            bad |= check_one(wrong, kn, "last-letter-changed");
        }
        // the host's names are slices of one table, so a longer word is built here, not read past the name
        memcpy(longer, upper, kn);
        longer[kn] = 'X';
        longer[kn + 1] = '\0';
        bad |= check_one(longer, kn + 1, "longer-than-keyword");
        bad |= check_one(longer, -1, "keyword-plus-letter");
    }
    static const char *const others[] = {
        "", "X", "SELECTX", "SELEC", "select1", "sel\xc3\xa9" "ct", "SELECT\0JUNK", "_", "CURRENT_DATE_", "not a keyword",
        "\xff\xfe", "ABC", "a", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
    };
    for (size_t j = 0; j < sizeof others / sizeof others[0]; j++) {
        bad |= check_one(others[j], -1, "other");
        bad |= check_one(others[j], 0, "other-zero");
        bad |= check_one(others[j], 1, "other-one");
    }
    bad |= check_one("SELECT", 6, "exact-n");
    bad |= check_one("SELECTX", 6, "prefix-n");
    bad |= check_one("SELECT", 3, "short-n");
    if (!bad)
        printf("ok keyword-check\n");
}

int main(void)
{
    check_count();
    check_names();
    check_check();
    if (failures == 0)
        printf("checks=all failures=0\n");
    else
        printf("checks=failed failures=%d\n", failures);
    return failures;
}
