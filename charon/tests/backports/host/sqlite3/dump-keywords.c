// Dumps the host's keyword table for packages/a/apple-backports/SQLite3/Keywords.c, which is generated from this output:
//   xcrun clang -O2 -w dump-keywords.c -lsqlite3 -o dump-keywords && ./dump-keywords > keywords-host.txt
// Each keyword row is "<return code> <length> <name>", in the order sqlite3_keyword_name answers them.
#include <stdio.h>
#include <sqlite3.h>

int main(void)
{
    printf("version %s\n", sqlite3_libversion());
    int n = sqlite3_keyword_count();
    printf("count %d\n", n);
    for (int i = 0; i < n; i++) {
        const char *z = NULL;
        int len = 0;
        int rc = sqlite3_keyword_name(i, &z, &len);
        printf("%d %d %.*s\n", rc, len, len, z);
    }
    const char *z = NULL;
    int len = 0;
    printf("out-of-range %d\n", sqlite3_keyword_name(n, &z, &len));
    return 0;
}
