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
