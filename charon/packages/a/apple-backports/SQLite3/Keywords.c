#include <string.h>
#include <sqlite3.h>

// The keyword functions of libsqlite3, over the table of its keywords. The table is the host's: the 147 names sqlite3_keyword_name
// answers, in its order, which is part of the API. It is generated from the host's dump (tests/backports/host/sqlite3/dump-keywords.c):
//   awk 'NR>=3 && $1 == 0 { print "    \"" $3 "\"," }' keywords-host.txt
// The table is sqlite 3.54.0's. The keyword list iOS 12's libsqlite3 carries is not measured here, see facts/SQLite3/Keywords.md.

// The C sources of a backport are compiled -fvisibility=hidden, so the entry points of the API are marked here, and
// nothing else of this file is.
#define SQLITE3_EXPORT __attribute__((visibility("default")))

static const char *const kKeywords[] = {
    "REINDEX",
    "INDEXED",
    "INDEX",
    "DESC",
    "ESCAPE",
    "EACH",
    "CHECK",
    "KEY",
    "BEFORE",
    "FOREIGN",
    "FOR",
    "IGNORE",
    "REGEXP",
    "EXPLAIN",
    "INSTEAD",
    "ADD",
    "DATABASE",
    "AS",
    "SELECT",
    "TABLE",
    "LEFT",
    "THEN",
    "END",
    "DEFERRABLE",
    "ELSE",
    "EXCLUDE",
    "DELETE",
    "TEMPORARY",
    "TEMP",
    "OR",
    "ISNULL",
    "NULLS",
    "SAVEPOINT",
    "INTERSECT",
    "TIES",
    "NOTNULL",
    "NOT",
    "NO",
    "NULL",
    "LIKE",
    "EXCEPT",
    "TRANSACTION",
    "ACTION",
    "ON",
    "NATURAL",
    "ALTER",
    "RAISE",
    "EXCLUSIVE",
    "EXISTS",
    "CONSTRAINT",
    "INTO",
    "OFFSET",
    "OF",
    "SET",
    "TRIGGER",
    "RANGE",
    "GENERATED",
    "DETACH",
    "HAVING",
    "GLOB",
    "BEGIN",
    "INNER",
    "REFERENCES",
    "UNIQUE",
    "QUERY",
    "WITHOUT",
    "WITH",
    "OUTER",
    "RELEASE",
    "ATTACH",
    "BETWEEN",
    "NOTHING",
    "GROUPS",
    "GROUP",
    "CASCADE",
    "ASC",
    "DEFAULT",
    "CASE",
    "COLLATE",
    "CREATE",
    "CURRENT_DATE",
    "IMMEDIATE",
    "JOIN",
    "INSERT",
    "MATCH",
    "PLAN",
    "ANALYZE",
    "PRAGMA",
    "MATERIALIZED",
    "DEFERRED",
    "DISTINCT",
    "IS",
    "UPDATE",
    "VALUES",
    "VIRTUAL",
    "ALWAYS",
    "WHEN",
    "WHERE",
    "RECURSIVE",
    "ABORT",
    "AFTER",
    "RENAME",
    "AND",
    "DROP",
    "PARTITION",
    "AUTOINCREMENT",
    "TO",
    "IN",
    "CAST",
    "COLUMN",
    "COMMIT",
    "CONFLICT",
    "CROSS",
    "CURRENT_TIMESTAMP",
    "CURRENT_TIME",
    "CURRENT",
    "PRECEDING",
    "FAIL",
    "LAST",
    "FILTER",
    "REPLACE",
    "FIRST",
    "FOLLOWING",
    "FROM",
    "FULL",
    "LIMIT",
    "IF",
    "ORDER",
    "RESTRICT",
    "OTHERS",
    "OVER",
    "RETURNING",
    "RIGHT",
    "ROLLBACK",
    "ROWS",
    "ROW",
    "UNBOUNDED",
    "UNION",
    "USING",
    "VACUUM",
    "VIEW",
    "WINDOW",
    "DO",
    "BY",
    "INITIALLY",
    "ALL",
    "PRIMARY",
};

enum { kKeywordCount = sizeof kKeywords / sizeof kKeywords[0] };

SQLITE3_EXPORT int sqlite3_keyword_count(void)
{
    return kKeywordCount;
}

// On an index out of range the host sets the text to NULL and leaves the length alone (measured).
SQLITE3_EXPORT int sqlite3_keyword_name(int i, const char **pz, int *pn)
{
    if (i < 0 || i >= kKeywordCount) {
        *pz = NULL;
        return SQLITE_ERROR;
    }
    *pz = kKeywords[i];
    *pn = (int)strlen(kKeywords[i]);
    return SQLITE_OK;
}

// sqlite folds ASCII letters only, so the comparison is ASCII-only too.
static int lower(int c)
{
    return c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
}

// n is the exact byte length of z, not a NUL-terminated string's: a negative n, which the host measures as no keyword at all,
// matches no entry here either, because no keyword has a negative length.
SQLITE3_EXPORT int sqlite3_keyword_check(const char *z, int n)
{
    for (int i = 0; i < kKeywordCount; i++) {
        const char *k = kKeywords[i];
        if ((int)strlen(k) != n)
            continue;
        int j = 0;
        while (j < n && lower((unsigned char)z[j]) == lower((unsigned char)k[j]))
            j++;
        if (j == n)
            return 1;
    }
    return 0;
}
