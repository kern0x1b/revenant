#include <string.h>
#include <sqlite3.h>

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

static int lower(int c)
{
    return c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
}

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
